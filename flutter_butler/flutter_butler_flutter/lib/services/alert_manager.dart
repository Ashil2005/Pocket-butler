import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_butler_flutter/services/app_state.dart';
import 'package:flutter_butler_flutter/services/audio_volume_lock.dart';
import 'package:flutter_butler_flutter/services/alert_service.dart';

/// Service responsible for the active phase of an alert.
/// Handles audio alarms, voice announcements, and live GPS tracking.
class AlertManager {
  static final AlertManager _instance = AlertManager._internal();
  factory AlertManager() => _instance;
  AlertManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  
  bool _isAlertActive = false;
  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<Position>.broadcast();
  Timer? _volumeLockTimer;
  Timer? _ttsLoopTimer;
  bool _isTtsSpeaking = false;

  /// Returns true if an alert is currently triggering.
  bool get isAlertActive => _isAlertActive;

  /// Stream of live GPS coordinates during an active alert.
  Stream<Position> get locationStream => _locationController.stream;

  /// Starts the automated alert sequence.
  /// 
  /// This includes forcing max volume, looping an alarm sound,
  /// speaking a warning via TTS, and starting high-accuracy GPS tracking.
  Future<void> startAlert() async {
    if (_isAlertActive) return; // Prevent multiple triggers.
    _isAlertActive = true;
    
    // 🔥 VERIFICATION LOG - PROVE THIS CODE IS RUNNING
    debugPrint("🔥 ALERT_MANAGER_VERSION = 2026-01-30-FULL-RESET");
    
    debugPrint('[ALERT_AUDIO] started - theft alarm activated');

    try {
      // 1. ACTIVATE NATIVE VOLUME LOCK - Force system volume to maximum
      final volumeLockSuccess = await AudioVolumeLock().lockVolume();
      if (volumeLockSuccess) {
        debugPrint('[ALERT_AUDIO] 🔒 NATIVE VOLUME LOCK ACTIVATED');
      } else {
        debugPrint('[ALERT_AUDIO] ⚠️ Native volume lock failed, using fallback');
      }

      // 2. Start alarm audio (custom or TTS)
      final alarmType = AppState().alarmSoundType;
      final customPath = AppState().alarmSoundPath;
      
      if (alarmType == 'custom' && customPath != null && customPath.isNotEmpty) {
        debugPrint('[ALERT_AUDIO] Using custom alarm: $customPath');
        await _startCustomAlarm(customPath);
      } else {
        debugPrint('[ALERT_AUDIO] Using default TTS alarm');
        await _startContinuousTheftAlarm();
      }

      // 3. GPS Tracking (Continuous)
      await _startGpsTracking();

      // 4. Start NATIVE alert service (vibration + alarm control)
      AlertService().startAlert();

      debugPrint('[ALERT_AUDIO] Alarm sequence started successfully');

    } catch (e) {
      debugPrint('[ALERT_AUDIO] Error starting alarm: $e - falling back to TTS');
      // Fallback to TTS if custom audio fails
      try {
        await _startContinuousTheftAlarm();
        await _startGpsTracking();
      } catch (fallbackError) {
        debugPrint('[ALERT_AUDIO] Fallback also failed: $fallbackError');
      }
    }
  }

  /// Start custom audio alarm from file path
  Future<void> _startCustomAlarm(String filePath) async {
    try {
      debugPrint('[ALERT_AUDIO] Starting custom audio playback');
      
      // Configure audio player for looping
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      
      // Play the custom audio file
      await _audioPlayer.play(DeviceFileSource(filePath));
      
      debugPrint('[ALERT_AUDIO] Custom alarm started successfully');
    } catch (e) {
      debugPrint('[ALERT_AUDIO] Failed to start custom alarm: $e');
      // Re-throw to trigger fallback
      rethrow;
    }
  }

  /// Starts continuous TTS alarm that repeats the theft message
  Future<void> _startContinuousTheftAlarm() async {
    await _tts.setVolume(1.0);
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.8); // Slightly slower for urgency
    
    // Set completion handler to know when TTS finishes
    _tts.setCompletionHandler(() {
      _isTtsSpeaking = false;
      debugPrint('[ALERT_AUDIO] TTS utterance completed');
    });
    
    debugPrint('[ALERT_AUDIO] TTS configured - starting controlled loop');
    // Start controlled TTS loop
    _startTtsLoop();
  }

  /// Controlled TTS loop using Timer - no recursion, no overlapping calls
  void _startTtsLoop() {
    if (!_isAlertActive) {
      debugPrint('[ALERT_AUDIO] Loop stopped - alarm no longer active');
      return;
    }
    
    // Only speak if not already speaking
    if (!_isTtsSpeaking) {
      const theftMessage = "HELP! HELP! THIS PHONE IS BEING STOLEN! CALL THE POLICE! HELP! HELP!";
      debugPrint('[ALERT_AUDIO] speaking theft message');
      
      _isTtsSpeaking = true;
      _tts.speak(theftMessage);
    }
    
    // Schedule next loop iteration
    _ttsLoopTimer = Timer(const Duration(milliseconds: 500), () {
      if (_isAlertActive) {
        debugPrint('[ALERT_AUDIO] continuing controlled loop');
        _startTtsLoop(); // Controlled loop, not recursion
      } else {
        debugPrint('[ALERT_AUDIO] loop stopped - alarm no longer active');
      }
    });
  }

  /// Stops all alert activities and cleans up resources.
  Future<void> stopAlert() async {
    if (!_isAlertActive) return;
    _isAlertActive = false;
    debugPrint('[ALERT_AUDIO] stopping alarm');

    // Stop TTS loop timer
    _ttsLoopTimer?.cancel();
    _ttsLoopTimer = null;
    
    // Stop TTS
    await _tts.stop();
    _isTtsSpeaking = false;
    
    // Stop audio player
    await _audioPlayer.stop();
    
    // Stop GPS tracking
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    
    // CRITICAL: Stop NATIVE alert service (vibration + alarm)
    AlertService().stopAlert();
    
    // UNLOCK NATIVE VOLUME LOCK
    await AudioVolumeLock().unlockVolume();
    debugPrint('[ALERT_AUDIO] 🔓 NATIVE VOLUME LOCK RELEASED');
    
    debugPrint('[ALERT_AUDIO] alarm stopped cleanly');
  }

  /// Starts the continuous GPS tracking stream.
  Future<void> _startGpsTracking() async {
    // Ensure permissions are handled (this is checked again in the background Isolate).
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // In a real app, we'd prompt here, but in background we rely on pre-granted permissions.
      return;
    }

    // High accuracy tracking with small distance filter for real-time updates.
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // 5 meters
      ),
    ).listen((Position position) {
      _locationController.add(position);
    });
  }

  /// Cleanup.
  void dispose() {
    stopAlert();
    _locationController.close();
    _audioPlayer.dispose();
  }
}
