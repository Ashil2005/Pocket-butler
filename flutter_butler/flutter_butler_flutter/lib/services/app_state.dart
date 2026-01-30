import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized state management for UI preferences and configuration.
/// Uses SharedPreferences for persistence across app restarts.
class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences. Must be called before using AppState.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    // Reset live connection state on app initialization
    _isTrustedDeviceConnected = false;
    _currentRssi = null;
  }

  // ========== Bluetooth Device Selection ==========

  /// Get the name of the selected trusted Bluetooth device.
  String? get selectedDeviceName => _prefs?.getString('selected_device_name');

  /// Set the name of the selected trusted Bluetooth device.
  Future<void> setSelectedDeviceName(String? name) async {
    if (name == null) {
      await _prefs?.remove('selected_device_name');
    } else {
      await _prefs?.setString('selected_device_name', name);
    }
  }

  /// Get the ID (MAC address) of the selected trusted Bluetooth device.
  String? get selectedDeviceId => _prefs?.getString('selected_device_id');

  /// Set the ID (MAC address) of the selected trusted Bluetooth device.
  Future<void> setSelectedDeviceId(String? id) async {
    if (id == null) {
      await _prefs?.remove('selected_device_id');
    } else {
      await _prefs?.setString('selected_device_id', id);
    }
  }

  /// Set both device name and ID together.
  Future<void> setSelectedDevice(String? name, String? id) async {
    await setSelectedDeviceName(name);
    await setSelectedDeviceId(id);
  }

  // ========== Emergency Options ==========

  /// Get whether emergency alerts are enabled.
  bool get emergencyAlertsEnabled => _prefs?.getBool('emergency_alerts_enabled') ?? false;

  /// Set whether emergency alerts are enabled.
  Future<void> setEmergencyAlertsEnabled(bool enabled) async {
    await _prefs?.setBool('emergency_alerts_enabled', enabled);
  }

  /// Get the emergency contact phone number.
  String? get emergencyPhoneNumber => _prefs?.getString('emergency_phone_number');

  /// Set the emergency contact phone number.
  Future<void> setEmergencyPhoneNumber(String? number) async {
    if (number == null || number.isEmpty) {
      await _prefs?.remove('emergency_phone_number');
    } else {
      await _prefs?.setString('emergency_phone_number', number);
    }
  }

  // ========== Alarm Sound Selection ==========

  /// Get the type of alarm sound selected ('default' or 'custom').
  String get alarmSoundType => _prefs?.getString('alarm_sound_type') ?? 'default';

  /// Set the type of alarm sound ('default' or 'custom').
  Future<void> setAlarmSoundType(String type) async {
    await _prefs?.setString('alarm_sound_type', type);
  }

  /// Get the path to a custom alarm sound file.
  String? get alarmSoundPath => _prefs?.getString('alarm_sound_path');

  /// Set the path to a custom alarm sound file.
  Future<void> setAlarmSoundPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs?.remove('alarm_sound_path');
    } else {
      await _prefs?.setString('alarm_sound_path', path);
    }
  }

  /// Set alarm sound configuration (type and optional path).
  Future<void> setAlarmSound(String type, {String? path}) async {
    await setAlarmSoundType(type);
    await setAlarmSoundPath(path);
  }

  // ========== Armed State Persistence ==========

  /// Get whether the Butler is currently armed.
  bool get isArmed => _prefs?.getBool('is_armed') ?? false;

  /// Set whether the Butler is currently armed.
  Future<void> setIsArmed(bool armed) async {
    await _prefs?.setBool('is_armed', armed);
  }

  /// Get the device ID currently being monitored.
  String? get armedDeviceId => _prefs?.getString('armed_device_id');

  /// Set the device ID currently being monitored.
  Future<void> setArmedDeviceId(String? id) async {
    if (id == null) {
      await _prefs?.remove('armed_device_id');
    } else {
      await _prefs?.setString('armed_device_id', id);
    }
  }

  /// Get the phone number used for emergency alerts when armed.
  String? get armedPhoneNumber => _prefs?.getString('armed_phone_number');

  /// Set the phone number used for emergency alerts when armed.
  Future<void> setArmedPhoneNumber(String? number) async {
    if (number == null) {
      await _prefs?.remove('armed_phone_number');
    } else {
      await _prefs?.setString('armed_phone_number', number);
    }
  }

  /// Set all armed state data together.
  Future<void> setArmedState({required bool armed, String? deviceId, String? phoneNumber}) async {
    await setIsArmed(armed);
    await setArmedDeviceId(deviceId);
    await setArmedPhoneNumber(phoneNumber);
  }

  // ========== Live Bluetooth Connection State ==========

  /// SINGLE SOURCE OF TRUTH: Is the trusted device currently connected?
  bool _isTrustedDeviceConnected = false;
  
  /// Current RSSI value from the trusted device.
  int? _currentRssi;

  /// Get whether the trusted device is currently connected (live state).
  bool get isTrustedDeviceConnected {
    debugPrint('[APPSTATE_DEBUG] isTrustedDeviceConnected getter called, returning: $_isTrustedDeviceConnected');
    return _isTrustedDeviceConnected;
  }

  /// Get the current RSSI value.
  int? get currentRssi => _currentRssi;

  /// Set the live connection state of the trusted device.
  /// ONLY BluetoothMonitor should call this.
  void setTrustedDeviceConnection(bool connected) {
    debugPrint('[APPSTATE_DEBUG] setTrustedDeviceConnection($connected) | hash=${identityHashCode(this)}');
    _isTrustedDeviceConnected = connected;
    if (!connected) {
      _currentRssi = null; // Clear RSSI when disconnected
    }
  }

  /// Update the current RSSI value.
  /// ONLY BluetoothMonitor should call this.
  void updateRssi(int? rssi) {
    _currentRssi = rssi;
  }

  /// Check if the device is at a safe distance based on RSSI.
  bool get isSafeDistance {
    if (!_isTrustedDeviceConnected || _currentRssi == null) {
      return false; // Not connected = not safe
    }
    return _currentRssi! > -85; // Safe if RSSI > -85 dBm
  }

  // ========== Utility Methods ==========

  /// Clear all stored preferences (for testing or reset).
  Future<void> clearAll() async {
    await _prefs?.clear();
    // Reset live state
    _isTrustedDeviceConnected = false;
    _currentRssi = null;
  }

  /// Get a human-readable display name for the selected alarm.
  String get alarmSoundDisplayName {
    if (alarmSoundType == 'custom' && alarmSoundPath != null) {
      // Extract filename from path
      final parts = alarmSoundPath!.split('/');
      return parts.isEmpty ? 'Custom Sound' : parts.last;
    }
    return 'Default Alarm';
  }
}
