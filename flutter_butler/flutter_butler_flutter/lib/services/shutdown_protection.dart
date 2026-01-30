import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to handle shutdown protection events
/// 
/// CRITICAL: This is a PASSIVE service
/// - It LOGS events from native layer
/// - It SYNCS armed state TO native layer
/// - It does NOT trigger alarms (AlertService handles that)
class ShutdownProtection {
  static final ShutdownProtection _instance = ShutdownProtection._internal();
  factory ShutdownProtection() => _instance;
  ShutdownProtection._internal();

  static const MethodChannel _channel = MethodChannel('flutter_butler_flutter/shutdown');
  bool _isInitialized = false;
  bool _isArmed = false;

  /// Initialize shutdown protection service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      _isInitialized = true;
      debugPrint('[SHUTDOWN_PROTECTION] Service initialized (PASSIVE MODE)');
    } catch (e) {
      debugPrint('[SHUTDOWN_PROTECTION] Failed to initialize: $e');
    }
  }

  /// Set armed state and sync to native layer
  /// This is the ONLY way to update armed state
  Future<void> setArmed(bool armed) async {
    _isArmed = armed;
    debugPrint('[SHUTDOWN_PROTECTION] Armed state updated: $armed');
    
    // Sync armed state to native ShutdownReceiver
    try {
      await _channel.invokeMethod('setArmed', {'armed': armed});
      debugPrint('[SHUTDOWN_PROTECTION] Armed state synced to native');
    } catch (e) {
      debugPrint('[SHUTDOWN_PROTECTION] Failed to sync armed state: $e');
    }
  }

  bool get isArmed => _isArmed;

  /// Handle events from native Android
  /// NOTE: This is for LOGGING ONLY - no alarm triggering here
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSecurityEvent':
        final triggerType = call.arguments['triggerType'] as String? ?? 'UNKNOWN';
        _onSecurityEvent(triggerType);
        break;
      case 'onShutdownAttempt':
        // Legacy handler - redirect to new method
        final triggerType = call.arguments['triggerType'] as String? ?? 'UNKNOWN';
        _onSecurityEvent(triggerType);
        break;
      default:
        debugPrint('[SHUTDOWN_PROTECTION] Unknown method: ${call.method}');
    }
  }

  /// Log security events - NO ALARM TRIGGERING
  /// AlertService (native) is the SINGLE SOURCE OF TRUTH for alarms
  void _onSecurityEvent(String triggerType) {
    if (!_isArmed) {
      debugPrint('[SHUTDOWN_PROTECTION] Security event received but not armed - ignoring: $triggerType');
      return;
    }

    debugPrint('[SHUTDOWN_PROTECTION] 🔔 SECURITY EVENT: $triggerType');
    debugPrint('[SHUTDOWN_PROTECTION] ℹ️ NOTE: Alarm handled by native AlertService (not Flutter)');
    
    // Additional logging could be added here:
    // - Write to security event log
    // - Send analytics
    // - Update UI state
    // 
    // BUT: Do NOT call AlertManager().startAlert() !!!
    // AlertService (native) is the SINGLE SOURCE OF TRUTH
  }
}

