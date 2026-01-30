import 'package:url_launcher/url_launcher.dart';

/// Service responsible for emergency communication like SMS and phone calls.
class EmergencyContactManager {
  static final EmergencyContactManager _instance = EmergencyContactManager._internal();
  factory EmergencyContactManager() => _instance;
  EmergencyContactManager._internal();

  /// Sends an emergency SMS to the specified [phoneNumber] with a [message].
  /// Uses url_launcher to open SMS app with pre-filled message.
  Future<void> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    } catch (_) {
      // Fail silently in production
    }
  }

  /// Initiates a phone call to the specified [phoneNumber].
  /// This normally requires user interaction or specific accessibility permissions
  /// for a "direct" call. We use url_launcher as a standard method.
  Future<void> placeCall(String phoneNumber) async {
    try {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );
      
      // Note: In background service, launching a UI dialer may be restricted.
      // But we attempt it as requested.
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (_) {
      // Fail silently in production
    }
  }
}
