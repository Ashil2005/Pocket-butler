import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'alert_manager.dart';

/// Enhanced power-off protection service with native Android integration
class PowerOffProtection {
  static final PowerOffProtection _instance = PowerOffProtection._internal();
  factory PowerOffProtection() => _instance;
  PowerOffProtection._internal();

  static const MethodChannel _channel = MethodChannel('flutter_butler_flutter/power_off');
  bool _isInitialized = false;
  bool _isArmed = false;

  /// Initialize the power-off protection service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      _isInitialized = true;
      debugPrint('[POWER_OFF_PROTECTION] Service initialized');
    } catch (e) {
      debugPrint('[POWER_OFF_PROTECTION] Failed to initialize: $e');
    }
  }

  /// Set armed state to activate/deactivate protection
  Future<void> setArmed(bool armed) async {
    if (!_isInitialized) {
      debugPrint('[POWER_OFF_PROTECTION] Service not initialized');
      return;
    }

    try {
      await _channel.invokeMethod('setArmed', {'armed': armed});
      _isArmed = armed;
      
      if (armed) {
        debugPrint('[POWER_OFF_PROTECTION] 🛡️ POWER OFF PROTECTION ACTIVATED');
      } else {
        debugPrint('[POWER_OFF_PROTECTION] 🔓 POWER OFF PROTECTION DEACTIVATED');
      }
    } catch (e) {
      debugPrint('[POWER_OFF_PROTECTION] Error setting armed state: $e');
    }
  }

  /// Check if protection is currently active
  Future<bool> isProtectionActive() async {
    if (!_isInitialized) return false;

    try {
      return await _channel.invokeMethod<bool>('isProtectionActive') ?? false;
    } catch (e) {
      debugPrint('[POWER_OFF_PROTECTION] Error checking protection status: $e');
      return false;
    }
  }

  /// Manually trigger emergency alarm
  Future<void> triggerEmergencyAlarm() async {
    if (!_isInitialized) return;

    try {
      await _channel.invokeMethod('triggerEmergencyAlarm');
      debugPrint('[POWER_OFF_PROTECTION] 🚨 MANUAL EMERGENCY ALARM TRIGGERED');
    } catch (e) {
      debugPrint('[POWER_OFF_PROTECTION] Error triggering emergency alarm: $e');
    }
  }

  /// Handle method calls from native Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'emergencyAlarm':
        final triggerType = call.arguments['triggerType'] as String? ?? 'UNKNOWN';
        final timestamp = call.arguments['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        _handleEmergencyAlarm(triggerType, timestamp);
        break;
      default:
        debugPrint('[POWER_OFF_PROTECTION] Unknown method: ${call.method}');
    }
  }

  /// Handle emergency alarm triggered from native Android
  void _handleEmergencyAlarm(String triggerType, int timestamp) {
    debugPrint('[POWER_OFF_PROTECTION] 🚨🚨🚨 EMERGENCY ALARM RECEIVED: $triggerType');
    
    // Start the alarm immediately at maximum intensity
    AlertManager().startAlert();
    
    debugPrint('[POWER_OFF_PROTECTION] Emergency alarm activated due to: $triggerType');
  }

  bool get isArmed => _isArmed;
}
