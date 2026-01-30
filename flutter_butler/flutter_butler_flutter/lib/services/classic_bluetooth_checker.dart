import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Platform channel wrapper for Classic Bluetooth connection detection
/// Uses Android native APIs as authoritative source for Classic Bluetooth devices
class ClassicBluetoothChecker {
  static const MethodChannel _channel = MethodChannel('butler.bluetooth/classic');

  /// Check if a Classic Bluetooth device is connected using Android native APIs
  /// Returns true if device is connected via A2DP, HEADSET, or ACL
  static Future<bool> isClassicDeviceConnected(String deviceMac) async {
    try {
      final result = await _channel.invokeMethod<bool>('isClassicDeviceConnected', {
        'deviceMac': deviceMac,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[CLASSIC_BT] Error checking Classic Bluetooth connection: $e');
      return false;
    }
  }
}
