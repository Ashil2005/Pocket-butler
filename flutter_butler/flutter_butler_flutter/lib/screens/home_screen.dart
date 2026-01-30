import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_butler_flutter/services/background_service.dart';
import 'package:flutter_butler_flutter/services/bluetooth_monitor.dart';
import 'package:flutter_butler_flutter/services/app_state.dart';
import 'package:flutter_butler_flutter/screens/device_selection_screen.dart';
import 'package:flutter_butler_flutter/screens/alarm_selection_screen.dart';
import 'package:flutter_butler_flutter/services/security_service.dart';
import 'package:flutter_butler_flutter/screens/security_lock_screen.dart';
import 'package:flutter_butler_flutter/services/alert_manager.dart';
import 'package:flutter_butler_flutter/services/power_off_protection.dart';
import 'package:flutter_butler_flutter/services/audio_volume_lock.dart';
import 'package:flutter_butler_flutter/services/secure_overlay_service.dart';
import 'package:flutter_butler_flutter/services/alert_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isArmed = false;
  bool _emergencyAlertsEnabled = false;
  final TextEditingController _phoneNumberController = TextEditingController();
  BluetoothStatus _status = BluetoothStatus.disconnectedConfirmed;
  int _graceCountdown = 0;
  Timer? _countdownTimer;
  
  // Connection state update timer
  Timer? _connectionStateTimer;
  
  // Direct alarm trigger timer
  Timer? _directAlarmTimer;
  
  // Track previous connection state to detect changes
  bool _wasConnected = true;

  @override
  void initState() {
    super.initState();
    debugPrint('[ARM_TRACE] initState called');
    
    // Initialize enhanced protection services
    AudioVolumeLock().initialize();
    PowerOffProtection().initialize();
    SecureOverlayService().initialize();
    AlertService().initialize();
    
    _loadSavedState();
    
    // Listen for status updates from the background service.
    ButlerBackgroundService().statusStream.listen((status) async {
      if (mounted) {
        setState(() {
          _status = status;

          if (status == BluetoothStatus.gracePeriod) {
            _startGraceCountdown();
            HapticFeedback.heavyImpact();
          } else if (status == BluetoothStatus.disconnectedConfirmed) {
            _stopGraceCountdown();
            HapticFeedback.vibrate();
          } else if (status == BluetoothStatus.connected) {
            _stopGraceCountdown();
          }
        });

        // Phase 3: If alert is active, force security lock screen if not already showing.
        if (status == BluetoothStatus.disconnectedConfirmed && _isArmed) {
          debugPrint('[ALERT] Bluetooth disconnected while armed - starting alarm');
          AlertManager().startAlert();
          final verified = await _showSecurityLock(LockScreenMode.verify, title: 'THEFT DETECTED');
          if (verified == true) {
            debugPrint('[SECURITY] Butler disarmed after alarm PIN verification');
            await _disarmButler();
          }
        }
        
        // SAFETY: Force reset _isArmed if device disconnects while not armed
        if (!_isArmed && !AppState().isTrustedDeviceConnected) {
          setState(() {
            _isArmed = false;
          });
        }
      }
    });

    // DIRECT ALARM TRIGGER: Monitor AppState connection changes directly
    _directAlarmTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final isConnected = AppState().isTrustedDeviceConnected;
      
      // Check for state change: connected → disconnected while armed
      if (_isArmed && _wasConnected && !isConnected) {
        debugPrint('[ALERT] Direct trigger - Bluetooth disconnected while armed - starting alarm');
        AlertManager().startAlert();
        
        // Show security lock screen
        _showSecurityLock(LockScreenMode.verify, title: 'THEFT DETECTED').then((verified) {
          if (verified == true) {
            debugPrint('[SECURITY] Butler disarmed after alarm PIN verification');
            _disarmButler();
          }
        });
      }
      
      // Update previous state
      _wasConnected = isConnected;
    });
    
    // Start periodic UI updates for connection state
    _startConnectionStateUpdates();
  }

  @override
  void dispose() {
    _stopGraceCountdown();
    _stopConnectionStateUpdates();
    _directAlarmTimer?.cancel();
    super.dispose();
  }

  void _startConnectionStateUpdates() {
    _connectionStateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild to show current connection state
        });
      }
    });
  }

  void _stopConnectionStateUpdates() {
    _connectionStateTimer?.cancel();
    _connectionStateTimer = null;
  }

  void _startGraceCountdown() {
    _stopGraceCountdown();
    _graceCountdown = 10;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_graceCountdown > 0) {
            _graceCountdown--;
            HapticFeedback.selectionClick();
          } else {
            _stopGraceCountdown();
          }
        });
      }
    });
  }

  void _stopGraceCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Load saved state from AppState.
  Future<void> _loadSavedState() async {
    debugPrint('[ARM_TRACE] _loadSavedState called');
    setState(() {
      _emergencyAlertsEnabled = AppState().emergencyAlertsEnabled;
      _phoneNumberController.text = AppState().emergencyPhoneNumber ?? '';
    });
    
    // CRITICAL: Start Bluetooth monitoring if device is already selected
    final deviceId = AppState().selectedDeviceId;
    debugPrint('[ARM_TRACE] Checking device selection: $deviceId');
    if (deviceId != null && deviceId.isNotEmpty) {
      debugPrint('[ARM_TRACE] Auto-starting Bluetooth monitoring for saved device: $deviceId');
      try {
        await BluetoothMonitor.instance.startMonitoring(deviceId);
        debugPrint('[ARM_TRACE] Bluetooth monitoring started successfully');
      } catch (e) {
        debugPrint('[ARM_TRACE] Failed to start Bluetooth monitoring: $e');
      }
    } else {
      debugPrint('[ARM_TRACE] No device selected, skipping Bluetooth monitoring');
    }
  }

  /// Toggles the background service on or off.
  void _toggleArming() async {
    if (_isArmed) {
      // Phase 3: PIN is REQUIRED to disarm
      final verified = await _showSecurityLock(LockScreenMode.verify);
      if (verified != true) return;

      // Disarm: Stop the background service.
      await _disarmButler();
    } else {
      // Phase 3: PIN is REQUIRED to arm (Setup if missing)
      final hasPin = await SecurityService().hasPin();
      if (!hasPin) {
        final setup = await _showSecurityLock(LockScreenMode.setup, 
          title: 'Setup Security PIN', 
          subtitle: 'Create a PIN to protect your device before arming.'
        );
        if (setup != true) return;
      }

      // Arm: Start the background service.
      await _armButler();
    }
  }

  /// Helper to show security lock screen and return result.
  bool _isLockScreenShowing = false;
  Future<bool?> _showSecurityLock(LockScreenMode mode, {String? title, String? subtitle}) async {
    if (_isLockScreenShowing) return null;
    _isLockScreenShowing = true;
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SecurityLockScreen(
          mode: mode,
          title: title ?? (mode == LockScreenMode.setup ? 'Setup PIN' : 'Security PIN Required'),
          subtitle: subtitle ?? (mode == LockScreenMode.setup 
              ? 'Please create a 4-6 digit security PIN.' 
              : 'Enter PIN to proceed.'),
        ),
      ),
    );
    
    _isLockScreenShowing = false;
    return result;
  }

  /// Check and request overlay permission
  Future<bool> _checkOverlayPermission() async {
    try {
      final status = await Permission.systemAlertWindow.status;
      debugPrint('[OVERLAY_PERMISSION] Current status: $status');
      
      if (status.isGranted) {
        debugPrint('[OVERLAY_PERMISSION] ✅ Permission granted');
        return true;
      } else {
        debugPrint('[OVERLAY_PERMISSION] ❌ Permission denied - requesting');
        final result = await Permission.systemAlertWindow.request();
        
        if (result.isGranted) {
          debugPrint('[OVERLAY_PERMISSION] ✅ Permission granted after request');
          return true;
        } else {
          debugPrint('[OVERLAY_PERMISSION] ❌ Permission permanently denied');
          // Show dialog to guide user to settings
          _showOverlayPermissionDialog();
          return false;
        }
      }
    } catch (e) {
      debugPrint('[OVERLAY_PERMISSION] Error checking permission: $e');
      return false;
    }
  }

  /// Show dialog to guide user to enable overlay permission
  void _showOverlayPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🛡️ Overlay Permission Required'),
        content: const Text(
          'Butler needs overlay permission to block the power menu.\n\n'
          'This allows Butler to show a security screen that prevents shutdown when armed.\n\n'
          'Please enable "Display over other apps" permission in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Arm Butler with enhanced protection.
  Future<void> _armButler() async {
    debugPrint('[ARM_TRACE] _armButler called');
    
    // CRITICAL: Check overlay permission before arming
    final hasOverlayPermission = await _checkOverlayPermission();
    if (!hasOverlayPermission) {
      debugPrint('[ARM_TRACE] ❌ Overlay permission denied - cannot arm');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Overlay permission required for security protection'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // CRITICAL: Check if device is selected
    final selectedDeviceName = AppState().selectedDeviceName;
    final selectedDeviceId = AppState().selectedDeviceId;
    if (selectedDeviceName == null || selectedDeviceId == null) {
      debugPrint('[ARM_TRACE] ❌ No device selected - cannot arm');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a device first'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // CRITICAL: Check if device is connected
    final isConnected = AppState().isTrustedDeviceConnected;
    if (!isConnected) {
      debugPrint('[ARM_TRACE] ❌ Device not connected - cannot arm');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device must be connected to arm Butler'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // CRITICAL: Check notification permission BEFORE requesting others
    final notificationGranted = await Permission.notification.isGranted;
    if (!notificationGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission is required to arm Butler on Android 13+. Please grant in Settings.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // CRITICAL: Check Bluetooth permission BEFORE requesting others
    final bluetoothGranted = await Permission.bluetoothConnect.isGranted;
    if (!bluetoothGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bluetooth permission is required to monitor your trusted device. Please grant in Settings.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // CRITICAL: Check location permission BEFORE requesting others
    final locationGranted = await Permission.location.isGranted;
    if (!locationGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required for security monitoring. Please grant in Settings.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    final deviceId = selectedDeviceId;

    // Get phone number if emergency alerts are enabled
    final phoneNumber = _emergencyAlertsEnabled ? _phoneNumberController.text.trim() : '';

    // Request remaining permissions (optional ones)
    final statuses = await [
      Permission.locationAlways,
      if (_emergencyAlertsEnabled && phoneNumber.isNotEmpty) Permission.sms,
      if (_emergencyAlertsEnabled && phoneNumber.isNotEmpty) Permission.phone,
    ].request();

    // Permission Feedback for optional features.
    bool anyOptionalDenied = statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied);
    if (anyOptionalDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some features limited due to permissions.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    
    // Start the background service with error handling.
    try {
      await ButlerBackgroundService().start(deviceId, phoneNumber: phoneNumber);
      if (mounted) {
        setState(() {
          _isArmed = true;
          HapticFeedback.mediumImpact();
        });
        // Enable enhanced power-off protection when armed
        PowerOffProtection().setArmed(true);
        debugPrint('[POWER_OFF_PROTECTION] 🛡️ ENHANCED PROTECTION ACTIVATED - Butler is now armed');
        
        // Show warning about power-off protection
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛡️ BUTLER ARMED - Power menu will be blocked by security overlay'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('FAILED TO START BUTLER: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Failed to Start Butler'),
            content: Text(
              'Could not start monitoring. Please ensure all permissions are granted and try again.\n\nError: $e'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Disarm the Butler (stop monitoring).
  Future<void> _disarmButler() async {
    // Note: PIN verification already handled in _toggleArming

    // Stop the background service.
    await ButlerBackgroundService().stop();
    if (mounted) {
      setState(() {
        _isArmed = false;
        _status = BluetoothStatus.disconnectedConfirmed;
        HapticFeedback.lightImpact();
        _stopGraceCountdown();
      });
      // Disable enhanced power-off protection when disarmed
      PowerOffProtection().setArmed(false);
      // Hide security overlay when disarmed
      SecureOverlayService().hideOverlay();
      debugPrint('[SECURE_OVERLAY] 🔓 SECURITY OVERLAY HIDDEN - Butler is now disarmed');
      debugPrint('[POWER_OFF_PROTECTION] 🔓 ENHANCED PROTECTION DEACTIVATED - Butler is now disarmed');
    }
  }

  /// Navigate to device selection screen.
  Future<void> _selectDevice() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const DeviceSelectionScreen()),
    );
    
    if (result == true && mounted) {
      setState(() {}); // Refresh to show newly selected device
      
      // CRITICAL: Start Bluetooth monitoring to detect connection state
      final deviceId = AppState().selectedDeviceId;
      if (deviceId != null && deviceId.isNotEmpty) {
        try {
          await BluetoothMonitor.instance.startMonitoring(deviceId);
          debugPrint('[ARM_TRACE] Bluetooth monitoring started for device: $deviceId');
        } catch (e) {
          debugPrint('[ARM_TRACE] Failed to start Bluetooth monitoring: $e');
        }
      }
    }
  }

  /// Navigate to alarm selection screen.
  Future<void> _selectAlarmSound() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AlarmSelectionScreen()),
    );
    
    if (result == true && mounted) {
      setState(() {}); // Refresh to show updated alarm sound
    }
  }

  Future<void> _openAccessibilitySettings() async {
    const channel = MethodChannel('flutter_butler_flutter/shutdown');
    try {
      await channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('Error opening accessibility settings: $e');
    }
  }

  /// Build the status indicator widget.
  Widget _buildStatusIndicator() {
    final isConnected = AppState().isTrustedDeviceConnected;
    
    // UI TRACE LOG - Print every frame when armed
    debugPrint('[UI_TRACE] armed=$_isArmed connected=$isConnected status=$_status');

    if (!_isArmed) {
      if (isConnected) {
        // Show ready connected UI
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            children: [
              Icon(Icons.bluetooth_connected, color: Colors.green, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Connected',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Ready to arm Butler',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        // Show ready disconnected UI
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange),
          ),
          child: Row(
            children: [
              Icon(Icons.bluetooth_disabled, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Disconnected',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Connect device to arm Butler',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    } else if (_isArmed && !isConnected) {
      // Show theft alert UI
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚨 THEFT ALERT',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Alarm active - Enter PIN to disarm',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (_status == BluetoothStatus.gracePeriod) {
      // Show warning UI
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.yellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.yellow),
        ),
        child: Row(
          children: [
            Icon(Icons.timer, color: Colors.yellow[800], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ DISCONNECTION WARNING',
                    style: TextStyle(
                      color: Colors.yellow[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Reconnect in $_graceCountdown seconds or alarm will trigger',
                    style: TextStyle(
                      color: Colors.yellow[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Show armed UI
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue),
        ),
        child: Row(
          children: [
            Icon(Icons.security, color: Colors.blue, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🛡️ BUTLER ARMED',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Security protection active',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pocket Butler'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Indicator
            _buildStatusIndicator(),
            const SizedBox(height: 24),

            // Arm/Disarm Button
            ElevatedButton.icon(
              onPressed: _toggleArming,
              icon: Icon(_isArmed ? Icons.lock : Icons.lock_open),
              label: Text(_isArmed ? 'Disarm Butler' : 'Arm Butler'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isArmed ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),

            // Device Selection
            Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('Trusted Device'),
                subtitle: Text(
                  AppState().selectedDeviceName ?? 'No device selected',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectDevice,
              ),
            ),
            const SizedBox(height: 16),

            // Alarm Sound Selection
            Card(
              child: ListTile(
                leading: const Icon(Icons.alarm),
                title: const Text('Alarm Sound'),
                subtitle: Text(
                  () {
                    final type = AppState().alarmSoundType;
                    final path = AppState().alarmSoundPath;
                    if (type == 'custom' && path != null && path.isNotEmpty) {
                      return 'Custom sound';
                    } else {
                      return 'Default alarm';
                    }
                  }(),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectAlarmSound,
              ),
            ),
            // Accessibility Service Prompt
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.accessibility_new, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Enhanced Shutdown Protection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If you want shutdown protection, enable Butler Accessibility Service. '
                      'This allows Butler to instantly close the power menu when armed.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _openAccessibilitySettings,
                        child: const Text('Grant Accessibility Permission'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Emergency Alerts Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emergency, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Emergency Alerts',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Enable Emergency Alerts'),
                      subtitle: const Text('Send SMS alerts when theft is detected'),
                      value: _emergencyAlertsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _emergencyAlertsEnabled = value;
                        });
                        AppState().setEmergencyAlertsEnabled(value);
                      },
                    ),
                    if (_emergencyAlertsEnabled) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Emergency Phone Number',
                          hintText: 'Enter phone number for SMS alerts',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        onChanged: (value) {
                          AppState().setEmergencyPhoneNumber(value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
