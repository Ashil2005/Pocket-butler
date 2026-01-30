import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service responsible for managing the security PIN.
/// PIN is stored securely using the platform's keychain/keystore.
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _pinKey = 'user_security_pin';

  /// Returns true if a PIN has already been set.
  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  /// Sets a new security PIN.
  Future<void> setPin(String pin) async {
    // Basic validation: 4-6 digits (enforced by UI as well)
    if (pin.length < 4 || pin.length > 6) {
      throw Exception('PIN must be 4-6 digits long.');
    }
    await _storage.write(key: _pinKey, value: pin);
  }

  /// Verifies if the provided PIN matches the stored PIN.
  Future<bool> verifyPin(String inputPin) async {
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin == inputPin;
  }

  /// Clears the PIN (only for testing, normally protected).
  Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
  }
}
