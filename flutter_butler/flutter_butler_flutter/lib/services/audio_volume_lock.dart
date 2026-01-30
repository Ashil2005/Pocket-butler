import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Native Android audio volume lock service
/// Uses AudioManager to force STREAM_MUSIC to maximum volume
class AudioVolumeLock {
  static final AudioVolumeLock _instance = AudioVolumeLock._internal();
  factory AudioVolumeLock() => _instance;
  AudioVolumeLock._internal();

  static const MethodChannel _channel = MethodChannel('flutter_butler_flutter/audio_volume');
  bool _isInitialized = false;
  bool _isLocked = false;

  /// Initialize the audio volume lock service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      _isInitialized = true;
      debugPrint('[AUDIO_VOLUME_LOCK] Service initialized');
    } catch (e) {
      debugPrint('[AUDIO_VOLUME_LOCK] Failed to initialize: $e');
    }
  }

  /// Lock system volume to maximum
  Future<bool> lockVolume() async {
    if (!_isInitialized) {
      debugPrint('[AUDIO_VOLUME_LOCK] Service not initialized');
      return false;
    }

    try {
      final success = await _channel.invokeMethod<bool>('lockVolume') ?? false;
      _isLocked = success;
      
      if (success) {
        debugPrint('[AUDIO_VOLUME_LOCK] 🔒 SYSTEM VOLUME LOCKED TO MAXIMUM');
      } else {
        debugPrint('[AUDIO_VOLUME_LOCK] Failed to lock volume');
      }
      
      return success;
    } catch (e) {
      debugPrint('[AUDIO_VOLUME_LOCK] Error locking volume: $e');
      return false;
    }
  }

  /// Unlock system volume
  Future<void> unlockVolume() async {
    if (!_isInitialized) return;

    try {
      await _channel.invokeMethod('unlockVolume');
      _isLocked = false;
      debugPrint('[AUDIO_VOLUME_LOCK] 🔓 SYSTEM VOLUME UNLOCKED');
    } catch (e) {
      debugPrint('[AUDIO_VOLUME_LOCK] Error unlocking volume: $e');
    }
  }

  /// Check if volume is currently locked
  Future<bool> isVolumeLocked() async {
    if (!_isInitialized) return false;

    try {
      return await _channel.invokeMethod<bool>('isVolumeLocked') ?? false;
    } catch (e) {
      debugPrint('[AUDIO_VOLUME_LOCK] Error checking lock status: $e');
      return false;
    }
  }

  /// Handle method calls from native Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'volumeForced':
        final from = call.arguments['from'];
        final to = call.arguments['to'];
        debugPrint('[AUDIO_VOLUME_LOCK] 🚨 VOLUME ATTACK DETECTED! Forced $from → $to');
        break;
      default:
        debugPrint('[AUDIO_VOLUME_LOCK] Unknown method: ${call.method}');
    }
  }

  bool get isLocked => _isLocked;
}
