import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Native Alert Service interface
/// Controls native Android vibration and alarm
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  static const MethodChannel _channel = MethodChannel('flutter_butler_flutter/alert_service');
  bool _isInitialized = false;

  /// Initialize the alert service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      _isInitialized = true;
      debugPrint('[ALERT_SERVICE] Service initialized');
    } catch (e) {
      debugPrint('[ALERT_SERVICE] Failed to initialize: $e');
    }
  }

  /// Start native alert (vibration + alarm)
  Future<void> startAlert() async {
    if (!_isInitialized) {
      debugPrint('[ALERT_SERVICE] Service not initialized');
      return;
    }

    try {
      // This will trigger native Android AlertService (Vibration Only)
      debugPrint('[FLUTTER_ALERT] calling AlertService.startVibration');
      await _channel.invokeMethod('startAlert');
    } catch (e) {
      debugPrint('[ALERT_SERVICE] Error starting alert: $e');
    }
  }

  /// Stop native alert
  Future<void> stopAlert() async {
    if (!_isInitialized) return;

    try {
      debugPrint('[ALERT_SERVICE] 🔓 Triggering native stopAlert');
      await _channel.invokeMethod('stopAlert');
    } catch (e) {
      debugPrint('[ALERT_SERVICE] Error stopping alert: $e');
    }
  }

  /// Check if alert is active
  Future<bool> isAlertActive() async {
    if (!_isInitialized) return false;

    try {
      // Note: This will check native service state
      return false; // Placeholder
    } catch (e) {
      debugPrint('[ALERT_SERVICE] Error checking alert status: $e');
      return false;
    }
  }

  /// Handle method calls from native Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAlertStarted':
        debugPrint('[ALERT_SERVICE] 🚨 Native alert started');
        // Can trigger Flutter-side effects if needed
        break;
      case 'onAlertStopped':
        debugPrint('[ALERT_SERVICE] 🔓 Native alert stopped');
        // Can trigger Flutter-side cleanup if needed
        break;
      default:
        debugPrint('[ALERT_SERVICE] Unknown method: ${call.method}');
        break;
    }
  }
}
