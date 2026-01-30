import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_butler_client/flutter_butler_client.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_butler_flutter/services/bluetooth_monitor.dart';
import 'package:flutter_butler_flutter/services/emergency_contact_manager.dart';
import 'package:flutter_butler_flutter/services/motion_service.dart';
import 'package:flutter_butler_flutter/services/app_state.dart';
import 'package:flutter_butler_flutter/services/security_event_logger.dart';
import 'package:flutter_butler_flutter/app_config.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service responsible for managing the foreground process and hosting the Bluetooth monitor.
class ButlerBackgroundService {
  static final ButlerBackgroundService _instance = ButlerBackgroundService._internal();
  factory ButlerBackgroundService() => _instance;
  ButlerBackgroundService._internal();

  final _statusController = StreamController<BluetoothStatus>.broadcast();

  /// Stream of Bluetooth stability status relayed from the background service.
  Stream<BluetoothStatus> get statusStream => _statusController.stream;

  /// Initializes the background service configuration.
  /// This should be called once at app startup.
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        initialNotificationTitle: 'Flutter Butler',
        initialNotificationContent: 'Butler is ready to be armed.',
        foregroundServiceTypes: [
          AndroidForegroundType.connectedDevice,
          AndroidForegroundType.location,
        ],
        autoStartOnBoot: false,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (ServiceInstance service) => true,
      ),
    );

    // Listen for status updates from the background isolate.
    service.on('statusUpdate').listen((event) {
      if (event != null && event['status'] != null) {
        final statusName = event['status'] as String;
        try {
          final status = BluetoothStatus.values.byName(statusName);
          _statusController.add(status);
        } catch (_) {
          // Ignore invalid status names.
        }
      }
    });
  }

  /// Starts the foreground service and begins monitoring the specified device.
  Future<void> start(String deviceId, {String? phoneNumber}) async {
    final service = FlutterBackgroundService();
    
    // CRITICAL: Last-line defense - check notification permission
    final hasNotificationPermission = await Permission.notification.isGranted;
    if (!hasNotificationPermission) {
      debugPrint('CRITICAL: Cannot start foreground service - notification permission denied');
      throw Exception('Notification permission required for foreground service on Android 13+');
    }
    
    // CRITICAL: Ensure service starts from foreground context
    try {
      // Check if service is already running
      final isRunning = await service.isRunning();
      if (!isRunning) {
        debugPrint('Starting foreground service...');
        
        // Start service - this will trigger onStart which calls setAsForegroundService immediately
        await service.startService();
        
        // Give service time to call startForeground() - Android 13 requires within 5 seconds
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Verify service actually started and is in foreground mode
        final isRunningAfterStart = await service.isRunning();
        if (!isRunningAfterStart) {
          throw Exception('Foreground service failed to start - check Android 13 compliance');
        }
        
        debugPrint('Foreground service started successfully');
      }
      
      // Send monitoring command to the running service
      service.invoke('startMonitoring', {
        'deviceId': deviceId,
        'phoneNumber': phoneNumber ?? '',
      });
      
      debugPrint('Monitoring command sent to service');
      
    } catch (e) {
      debugPrint('CRITICAL: Foreground service start failed: $e');
      rethrow;
    }
  }

  /// Stops the background monitoring and kills the foreground service.
  Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}

/// Entry point for the background isolate.
/// Note: This function runs in a completely separate isolate.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // CRITICAL: Call setAsForegroundService IMMEDIATELY (Android 13 requirement)
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    // Set initial notification immediately to prevent crash
    service.setForegroundNotificationInfo(
      title: "Flutter Butler",
      content: "Initializing security service...",
    );
  }

  // Ensure Flutter engine is initialized for the new isolate.
  DartPluginRegistrant.ensureInitialized();

  final bluetoothMonitor = BluetoothMonitor.instance;
  final emergencyManager = EmergencyContactManager();
  final motionService = MotionService();
  
  // Initialize AppState and SecurityLogger for persistence in background isolate.
  final appState = AppState();
  await appState.initialize();
  final logger = SecurityEventLogger();

  // Re-initialize Serverpod client for this isolate.
  final client = Client(AppConfig.serverUrl); 

  String? trustedPhoneNumber = appState.armedPhoneNumber;
  String? armedDeviceId = appState.armedDeviceId;
  int? currentAlertId;
  bool motionDetected = false;
  Timer? motionResetTimer;

  // Auto-resume if previously armed (e.g. after reboot or process kill)
  if (appState.isArmed && armedDeviceId != null) {
     debugPrint('Butler Auto-Resume: Checking connection for $armedDeviceId');
     await logger.logEvent('REBOOT_RESUME', 'Device: $armedDeviceId');
     
     // Start monitoring to check connection state
     await BluetoothMonitor.instance.startMonitoring(armedDeviceId);
     
     // Wait a moment for connection state to be determined
     await Future.delayed(const Duration(seconds: 2));
     
     // Check if device is actually connected after monitoring starts
     final isConnected = appState.isTrustedDeviceConnected;
     if (isConnected) {
       debugPrint('Butler Auto-Resume: Device connected, resuming monitoring');
       motionService.startListening();
       if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Flutter Butler",
            content: "Butler Resumed - Monitoring...",
          );
        }
     } else {
       debugPrint('Butler Auto-Resume: Device not connected, disarming');
       await appState.setIsArmed(false);
       await BluetoothMonitor.instance.stopMonitoring();
       if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Flutter Butler",
            content: "Auto-disarmed - Device not connected",
          );
        }
     }
  } else {
    // Set ready state notification
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Flutter Butler",
        content: "Butler is ready to be armed.",
      );
    }
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Handle stop command.
  service.on('stopService').listen((event) async {
    // Clear persisted armed state
    await appState.setIsArmed(false);
    
    await BluetoothMonitor.instance.stopMonitoring();
    motionService.stopListening();
    
    if (currentAlertId != null) {
      try {
        await client.alert.resolveAlert(currentAlertId!);
      } catch (_) {
        // Silent fail in production
      }
      currentAlertId = null;
    }
    
    service.stopSelf();
  });

  // Handle start monitoring command.
  service.on('startMonitoring').listen((event) async {
    try {
      final deviceId = event?['deviceId'] as String?;
      trustedPhoneNumber = event?['phoneNumber'] as String?;
      
      if (deviceId != null) {
        // CRITICAL: Final permission check in background isolate
        final hasNotificationPermission = await Permission.notification.isGranted;
        if (!hasNotificationPermission) {
          debugPrint('CRITICAL: Background isolate - notification permission denied, stopping service');
          service.stopSelf();
          return;
        }

        // CRITICAL: Verify device is actually connected before arming
        final isConnected = AppState().isTrustedDeviceConnected;
        if (!isConnected) {
          debugPrint('CRITICAL: Cannot arm - trusted device not connected');
          service.invoke('armingFailed', {'reason': 'Device not connected'});
          return;
        }

        // Persist state for auto-resume
        await appState.setArmedState(
          armed: true, 
          deviceId: deviceId, 
          phoneNumber: trustedPhoneNumber
        );

        await BluetoothMonitor.instance.stopMonitoring();
        motionService.stopListening();
        
        await BluetoothMonitor.instance.startMonitoring(deviceId);
        motionService.startListening();
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Flutter Butler",
            content: "Armed and monitoring device...",
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting monitoring in background: $e');
      // If critical error, stop service safely
      service.stopSelf();
    }
  });

  // Start listening to motion events.
  motionService.movementDetectedStream.listen((detected) {
    if (detected) {
      motionDetected = true;
      bluetoothMonitor.setHighFrequencyPolling(true);
      
      // Reset motion detected flag after 5 seconds of no activity.
      motionResetTimer?.cancel();
      motionResetTimer = Timer(const Duration(seconds: 5), () {
        motionDetected = false;
        bluetoothMonitor.setHighFrequencyPolling(false);
      });
    }
  });

  // Relay status changes from the monitor back to the main UI and trigger alerts.
  bluetoothMonitor.statusStream.listen((BluetoothStatus status) async {
    try {
      service.invoke('statusUpdate', {'status': status.name});

      if (status == BluetoothStatus.disconnectedConfirmed) {
        // THEFT EVENT ESCALATION: 
        await logger.logEvent('SIGNAL_LOST_CONFIRMED', 'Status: $status, Motion: $motionDetected');
        
        if (motionDetected) {
          // INSTANT ALERT: Signal lost and phone is moving
          await logger.logEvent('ALARM_TRIGGERED', 'Reason: Signal lost + motion');
        } else {
          // DELAYED ALERT: Signal lost but phone is still. Wait for motion or longer blip.
          await Future.delayed(const Duration(seconds: 5));
          
          if (motionDetected) {
             await logger.logEvent('ALARM_TRIGGERED', 'Reason: Sustained disconnect + late motion');
          } else {
             await logger.logEvent('ALARM_TRIGGERED', 'Reason: Sustained disconnect (15s limit)');
          }
        }

        if (trustedPhoneNumber != null && trustedPhoneNumber!.isNotEmpty) {
          await emergencyManager.sendSms(
            phoneNumber: trustedPhoneNumber!,
            message: "🚨 ALERT: Possible phone theft! Connection lost and movement detected.",
          );
          await emergencyManager.placeCall(trustedPhoneNumber!);
        }

        try {
          currentAlertId = await client.alert.createAlert(1, DateTime.now());
        } catch (_) {}

      } else if (status == BluetoothStatus.connected) {
        // AUTO RECOVER: If device is found again, stop all alerts.
        
        if (currentAlertId != null) {
          try {
            await client.alert.resolveAlert(currentAlertId!);
            currentAlertId = null;
          } catch (_) {}
        }
      }

      if (service is AndroidServiceInstance) {
        String message = "Safe - Connected";
        if (status == BluetoothStatus.gracePeriod) {
          message = "WARNING: Connection dropped (Grace Period)";
        } else if (status == BluetoothStatus.disconnectedConfirmed) {
          message = "ALERT: Device lost - Theft suspected!";
        }
        
        service.setForegroundNotificationInfo(
          title: "Flutter Butler",
          content: message,
        );
      }
    } catch (e) {
      debugPrint('Error handling status change in background: $e');
    }
  });
}
