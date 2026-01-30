import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_butler_flutter/services/security_event_logger.dart';
import 'package:flutter_butler_flutter/services/app_state.dart';
import 'package:flutter_butler_flutter/services/classic_bluetooth_checker.dart';

/// Represents the refined states of a monitored Bluetooth device connection.
enum BluetoothStatus {
  /// The device is currently connected and active.
  connected,

  /// The device has disconnected, and we are within the allowed grace period
  /// to see if it reconnects automatically.
  gracePeriod,

  /// The device remained disconnected beyond the grace period.
  /// This typically indicates a potential theft or loss event.
  disconnectedConfirmed
}

/// Service responsible for monitoring a single trusted Bluetooth device.
/// It tracks the connection state and manages a grace period for disconnections
/// to avoid false positives from brief signal drops.
class BluetoothMonitor {
  BluetoothMonitor._internal() {
    debugPrint('[BT_MONITOR] Singleton instance created');
  }
  static final BluetoothMonitor instance = BluetoothMonitor._internal();

  factory BluetoothMonitor() => instance;

  /// Duration to wait before confirming a disconnection as permanent.
  final Duration gracePeriodDuration = const Duration(seconds: 10);

  /// Internal state management.
  BluetoothStatus _currentStatus = BluetoothStatus.disconnectedConfirmed;
  final StreamController<BluetoothStatus> _statusController =
      StreamController<BluetoothStatus>.broadcast();

  BluetoothDevice? _targetDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _graceTimer;
  bool _isDisposed = false;

  // RSSI Tracking (Phase 3)
  Timer? _rssiPollTimer;
  Timer? _connectionCheckTimer;
  final List<int> _rssiHistory = [];
  static const int _historyLimit = 10;
  static const int _rssiAlertThreshold = -85; // ~5-7 meters depending on environment
  static const int _snatchDropThreshold = 20; // 20 dBm drop is significant

  Duration _rssiInterval = const Duration(milliseconds: 500);


  /// Emits the current [BluetoothStatus] whenever it changes.
  Stream<BluetoothStatus> get statusStream => _statusController.stream;

  /// Returns the current known status of the monitored device.
  BluetoothStatus get currentStatus => _currentStatus;

  /// Returns the ID of the device currently being monitored, if any.
  String? get monitoredDeviceId => _targetDevice?.remoteId.str;

  /// Starts monitoring a specific Bluetooth device by its unique identifier.
  ///
  /// [deviceId] is the remote identifier (MAC address on Android).
  Future<void> startMonitoring(String deviceId) async {
    debugPrint('[BT_MONITOR] startMonitoring called for $deviceId | instance=${identityHashCode(this)}');
    // Ensure any previous monitoring is stopped cleanly.
    await stopMonitoring();

    try {
      // Check if Bluetooth adapter is available and enabled.
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        // Bluetooth is off - set disconnected state but continue monitoring
        _confirmDisconnection();
      }

      // Create a device instance from the ID.
      _targetDevice = BluetoothDevice.fromId(deviceId);

      // Check initial connection state using Android native APIs (AUTHORITATIVE)
      bool isInitiallyConnected = false;
      try {
        isInitiallyConnected = await ClassicBluetoothChecker.isClassicDeviceConnected(deviceId);
        debugPrint('[BT_MONITOR][CLASSIC] Initial check - Android reports connected=$isInitiallyConnected for $deviceId');
      } catch (e) {
        debugPrint('[BT_MONITOR][CLASSIC] Initial check failed: $e');
      }
      
      // Update AppState with initial connection state
      if (isInitiallyConnected) {
        debugPrint('[APPSTATE] trustedDeviceConnected=true (initial Classic BT)');
        AppState().setTrustedDeviceConnection(true);
        _updateStatus(BluetoothStatus.connected);
      } else {
        debugPrint('[APPSTATE] trustedDeviceConnected=false (initial Classic BT)');
        AppState().setTrustedDeviceConnection(false);
        _updateStatus(BluetoothStatus.disconnectedConfirmed);
      }

      // Attempt to connect in the background (autoConnect is critical for bonded devices)
      if (_targetDevice != null) {
        _targetDevice!.connect(autoConnect: true).catchError((e) {
          debugPrint('Auto-connect initialization failed: $e');
        });

        // Listen to connection state changes from the library.
        _connectionSubscription = _targetDevice!.connectionState.listen(
          _handleConnectionStateChange,
          onError: (error) {
            _confirmDisconnection();
          },
        );
      }

      // CRITICAL: ALWAYS start monitoring infrastructure
      _startRssiPolling();
      
      // Start periodic connection verification
      debugPrint('BluetoothMonitor: About to start periodic connection check');
      _startConnectionCheck();
      
      debugPrint('[BT_MONITOR] startMonitoring COMPLETED — timers active');
    } catch (e) {
      // If initialization fails, still try to start monitoring
      debugPrint('BluetoothMonitor: Initialization error: $e');
      _confirmDisconnection();
      
      // CRITICAL: Even on error, attempt to start monitoring
      try {
        _startRssiPolling();
        _startConnectionCheck();
        debugPrint('[BT_MONITOR] startMonitoring COMPLETED with error — timers active');
      } catch (timerError) {
        debugPrint('BluetoothMonitor: Failed to start timers: $timerError');
      }
    }
  }

  /// Stops all monitoring activities, cancels listeners, and resets state.
  Future<void> stopMonitoring() async {
    _cancelGraceTimer();
    _stopRssiPolling();
    _stopConnectionCheck();
    if (_targetDevice != null) {
      try {
        await _targetDevice!.disconnect().catchError((_) {});
      } catch (_) {}
    }
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _targetDevice = null;
    // Update AppState with disconnected state
    AppState().setTrustedDeviceConnection(false);
    _updateStatus(BluetoothStatus.disconnectedConfirmed);
  }

  /// Handles FlutterBluePlus connection state events.
  void _handleConnectionStateChange(BluetoothConnectionState state) {
    debugPrint('[BT_MONITOR] connectionState=$state | instance=${identityHashCode(this)}');
    
    // IGNORE connectionState for Classic Bluetooth - it's BLE-only
    // Periodic check using connectedDevices is the authority
    debugPrint('[BT_MONITOR] connectionState ignored - using connectedDevices authority');
  }

  /// Starts periodic RSSI polling to detect distance and snatching.
  void _startRssiPolling() {
    _stopRssiPolling();
    if (_targetDevice == null) return;

    _rssiPollTimer = Timer.periodic(_rssiInterval, (timer) async {
      if (_targetDevice == null || _currentStatus != BluetoothStatus.connected || _isDisposed) {
        timer.cancel();
        return;
      }

      try {
        // Extra guard: only read if still connected
        if (await _targetDevice!.connectionState.first == BluetoothConnectionState.connected) {
          final rssi = await _targetDevice!.readRssi();
          _processRssi(rssi);
        }
      } catch (_) {
        // Occasional failures are normal if device is moving away.
      }
    });
  }

  void _stopRssiPolling() {
    _rssiPollTimer?.cancel();
    _rssiPollTimer = null;
    _rssiHistory.clear();
  }

  /// Starts periodic connection verification to ensure we have real connection state.
  void _startConnectionCheck() {
    _stopConnectionCheck();
    
    debugPrint('BluetoothMonitor: Starting periodic connection check (3-second interval)');
    
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      debugPrint('[BT_MONITOR] connectionCheck tick | instance=${identityHashCode(this)}');
      if (_targetDevice == null || _isDisposed) {
        timer.cancel();
        return;
      }

      try {
        debugPrint('BluetoothMonitor: Periodic check - evaluating connection state for ${_targetDevice!.remoteId.str}');
        
        // USE Android native APIs as AUTHORITATIVE source for Classic Bluetooth
        final deviceMac = _targetDevice!.remoteId.str;
        final isActuallyConnected = await ClassicBluetoothChecker.isClassicDeviceConnected(deviceMac);
        
        debugPrint(
          '[BT_MONITOR][CLASSIC] Android reports connected=$isActuallyConnected for $deviceMac',
        );
        
        if (isActuallyConnected) {
          if (!AppState().isTrustedDeviceConnected) {
            debugPrint('[APPSTATE] trustedDeviceConnected=true (Classic BT)');
            AppState().setTrustedDeviceConnection(true);
            _updateStatus(BluetoothStatus.connected);
          }
        } else {
          if (AppState().isTrustedDeviceConnected) {
            debugPrint('[APPSTATE] trustedDeviceConnected=false (Classic BT)');
            // Start grace period before confirming disconnection
            if (_currentStatus == BluetoothStatus.connected) {
              _startGraceTimer();
              _updateStatus(BluetoothStatus.gracePeriod);
            } else {
              AppState().setTrustedDeviceConnection(false);
              _updateStatus(BluetoothStatus.disconnectedConfirmed);
            }
          }
        }
        
      } catch (e) {
        debugPrint('BluetoothMonitor: Connection check failed: $e');
        // On error, assume disconnected for safety
        AppState().setTrustedDeviceConnection(false);
      }
    });
  }

  void _stopConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }

  /// Adjusts the RSSI polling frequency to save battery.
  /// [isHighFrequency] : true for 500ms, false for 2000ms.
  void setHighFrequencyPolling(bool isHighFrequency) {
    if (_isDisposed) return;
    final newInterval = isHighFrequency 
        ? const Duration(milliseconds: 500) 
        : const Duration(milliseconds: 2000);
    
    if (_rssiInterval != newInterval) {
      _rssiInterval = newInterval;
      // Restart polling with new interval if currently polling
      if (_rssiPollTimer != null) {
        _startRssiPolling();
      }
    }
  }

  /// Processes RSSI value to detect distance and snatching patterns.
  void _processRssi(int rssi) {
    if (_rssiHistory.length >= _historyLimit) {
      _rssiHistory.removeAt(0);
    }
    
    _rssiHistory.add(rssi);
    
    // Update AppState with current RSSI
    AppState().updateRssi(rssi);

    // Median filter for smoothing outliers
    final sortedHistory = List<int>.from(_rssiHistory)..sort();
    final medianRssi = sortedHistory[sortedHistory.length ~/ 2];
    
    // Check for "Snatch" (Rapid RSSI drop)
    // We compare the current raw reading against the median of recent history
    if (_rssiHistory.length >= 5) {
      if (rssi < medianRssi - _snatchDropThreshold) {
        // INSTANT ALERT: Rapid signal drop indicates snatch or shielding.
        SecurityEventLogger().logEvent('SNATCH_DETECTED', 'RSSI: $rssi, Median: $medianRssi, Drop: ${medianRssi - rssi}');
        _confirmDisconnection();
        return;
      }
    }

    // Check for "Distance" (Smoothed threshold)
    if (medianRssi < _rssiAlertThreshold) {
      // Transition to grace period for distance-based loss.
      // This gives the user a chance to step back into range.
      if (_currentStatus == BluetoothStatus.connected) {
        _startGraceTimer();
        _updateStatus(BluetoothStatus.gracePeriod);
      }
    } else {
      // If we were in grace period but RSSI improved, recover.
      if (_currentStatus == BluetoothStatus.gracePeriod) {
        _cancelGraceTimer();
        _updateStatus(BluetoothStatus.connected);
      }
    }
  }

  /// Starts the countdown for confirming a disconnection.
  void _startGraceTimer() {
    _cancelGraceTimer();
    _graceTimer = Timer(gracePeriodDuration, () {
      _confirmDisconnection();
    });
  }

  /// Cancels any active grace period timer.
  void _cancelGraceTimer() {
    _graceTimer?.cancel();
    _graceTimer = null;
  }

  /// Transitions strictly to the disconnectedConfirmed state.
  void _confirmDisconnection() {
    _cancelGraceTimer();
    // Update AppState with disconnected state
    AppState().setTrustedDeviceConnection(false);
    _updateStatus(BluetoothStatus.disconnectedConfirmed);
  }

  /// Updates the internal status and informs listeners if a change occurred.
  void _updateStatus(BluetoothStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  /// Cleans up resources. Should be called when the service is no longer needed.
  void dispose() {
    _isDisposed = true;
    _stopConnectionCheck();
    stopMonitoring();
    _statusController.close();
  }
}
