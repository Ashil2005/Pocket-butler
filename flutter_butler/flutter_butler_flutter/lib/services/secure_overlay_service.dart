import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_butler_flutter/services/security_service.dart';

/// Security overlay service for blocking power menu access
/// Integrates with native Android overlay to prevent shutdown
class SecureOverlayService {
  static final SecureOverlayService _instance = SecureOverlayService._internal();
  factory SecureOverlayService() => _instance;
  SecureOverlayService._internal();

  static const MethodChannel _channel = MethodChannel('flutter_butler_flutter/secure_overlay');
  bool _isInitialized = false;

  /// Initialize the secure overlay service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      _isInitialized = true;
      debugPrint('[SECURE_OVERLAY] Service initialized');
    } catch (e) {
      debugPrint('[SECURE_OVERLAY] Failed to initialize: $e');
    }
  }

  /// Show the security overlay to block power menu
  Future<void> showOverlay() async {
    if (!_isInitialized) {
      debugPrint('[SECURE_OVERLAY] Service not initialized');
      return;
    }

    try {
      await _channel.invokeMethod('showOverlay');
      debugPrint('[SECURE_OVERLAY] 🛡️ SECURITY OVERLAY ACTIVATED - Power menu blocked');
    } catch (e) {
      debugPrint('[SECURE_OVERLAY] Error showing overlay: $e');
    }
  }

  /// Hide the security overlay
  Future<void> hideOverlay() async {
    if (!_isInitialized) return;

    try {
      await _channel.invokeMethod('hideOverlay');
      debugPrint('[SECURE_OVERLAY] 🔓 SECURITY OVERLAY HIDDEN - Power menu accessible');
    } catch (e) {
      debugPrint('[SECURE_OVERLAY] Error hiding overlay: $e');
    }
  }

  /// Check if overlay is currently visible
  Future<bool> isOverlayVisible() async {
    if (!_isInitialized) return false;

    try {
      return await _channel.invokeMethod<bool>('isOverlayVisible') ?? false;
    } catch (e) {
      debugPrint('[SECURE_OVERLAY] Error checking overlay visibility: $e');
      return false;
    }
  }

  /// Handle method calls from native Android (PIN verification)
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'verifyPin':
        final pin = call.arguments['pin'] as String?;
        if (pin != null) {
          final isValid = await _verifyPin(pin);
          debugPrint('[SECURE_OVERLAY] PIN verification result: $isValid');
          return isValid;
        }
        return false;
      default:
        debugPrint('[SECURE_OVERLAY] Unknown method: ${call.method}');
        return false;
    }
  }

  /// Verify PIN using SecurityService (single source of truth)
  Future<bool> _verifyPin(String pin) async {
    try {
      final securityService = SecurityService();
      final isValid = await securityService.verifyPin(pin);
      
      if (isValid) {
        debugPrint('[SECURE_OVERLAY] ✅ PIN VERIFIED - Dismissing overlay');
      } else {
        debugPrint('[SECURE_OVERLAY] ❌ INVALID PIN - Keeping overlay active');
      }
      
      return isValid;
    } catch (e) {
      debugPrint('[SECURE_OVERLAY] Error verifying PIN: $e');
      return false;
    }
  }
}
