package com.example.flutter_butler_flutter

import android.content.Context
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AudioVolumeLock private constructor() {
    companion object {
        private const val TAG = "AUDIO_VOLUME_LOCK"
        private const val CHANNEL = "flutter_butler_flutter/audio_volume"
        private const val VOLUME_REASSERT_INTERVAL_MS = 300L
        
        @Volatile
        private var instance: AudioVolumeLock? = null
        private var flutterEngine: FlutterEngine? = null
        
        fun getInstance(): AudioVolumeLock {
            return instance ?: synchronized(this) {
                instance ?: AudioVolumeLock().also { instance = it }
            }
        }
        
        fun initialize(engine: FlutterEngine) {
            flutterEngine = engine
            getInstance().initializeMethodChannel()
        }
    }
    
    private var context: Context? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var isVolumeLocked = false
    private var volumeReassertHandler: Handler? = null
    private var volumeReassertRunnable: Runnable? = null
    private var maxMusicVolume = 0
    
    private fun initializeMethodChannel() {
        val methodChannel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "lockVolume" -> {
                    val success = lockVolume()
                    result.success(success)
                }
                "unlockVolume" -> {
                    unlockVolume()
                    result.success(null)
                }
                "isVolumeLocked" -> {
                    result.success(isVolumeLocked)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    fun setContext(context: Context) {
        this.context = context
        this.audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        this.maxMusicVolume = audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
        this.volumeReassertHandler = Handler(Looper.getMainLooper())
    }
    
    fun lockVolume(): Boolean {
        val audioManager = this.audioManager ?: return false
        
        try {
            Log.w(TAG, "LOCKING SYSTEM VOLUME TO MAXIMUM")
            
            // 1. Force STREAM_MUSIC to maximum immediately
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusicVolume, 0)
            
            // 2. Request exclusive audio focus
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setOnAudioFocusChangeListener { focusChange ->
                        Log.d(TAG, "Audio focus changed: $focusChange")
                        // Reassert focus and volume if lost
                        if (focusChange != AudioManager.AUDIOFOCUS_GAIN) {
                            Handler(Looper.getMainLooper()).postDelayed({
                                if (isVolumeLocked) {
                                    reassertVolumeLock()
                                }
                            }, 100)
                        }
                    }
                    .build()
                
                val focusResult = audioManager.requestAudioFocus(audioFocusRequest!!)
                Log.i(TAG, "Audio focus request result: $focusResult")
            } else {
                @Suppress("DEPRECATION")
                val focusResult = audioManager.requestAudioFocus(
                    { focusChange ->
                        if (focusChange != AudioManager.AUDIOFOCUS_GAIN && isVolumeLocked) {
                            Handler(Looper.getMainLooper()).postDelayed({
                                reassertVolumeLock()
                            }, 100)
                        }
                    },
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
                )
                Log.i(TAG, "Audio focus request result (legacy): $focusResult")
            }
            
            // 3. Start periodic volume reassertion
            startVolumeReassertion()
            
            isVolumeLocked = true
            Log.i(TAG, "Volume lock ACTIVATED - max volume: $maxMusicVolume")
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to lock volume: ${e.message}", e)
            return false
        }
    }
    
    fun unlockVolume() {
        Log.w(TAG, "UNLOCKING SYSTEM VOLUME")
        
        try {
            // Stop periodic reassertion
            stopVolumeReassertion()
            
            // Release audio focus
            audioFocusRequest?.let { request ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    audioManager?.abandonAudioFocusRequest(request)
                } else {
                    @Suppress("DEPRECATION")
                    audioManager?.abandonAudioFocus(null)
                }
            }
            
            isVolumeLocked = false
            Log.i(TAG, "Volume lock DEACTIVATED")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unlock volume: ${e.message}", e)
        }
    }
    
    private fun startVolumeReassertion() {
        stopVolumeReassertion()
        
        volumeReassertRunnable = object : Runnable {
            override fun run() {
                if (isVolumeLocked) {
                    reassertVolumeLock()
                    // Schedule next reassertion
                    volumeReassertHandler?.postDelayed(this, VOLUME_REASSERT_INTERVAL_MS)
                }
            }
        }
        
        volumeReassertHandler?.post(volumeReassertRunnable!!)
        Log.d(TAG, "Volume reassertion started (interval: ${VOLUME_REASSERT_INTERVAL_MS}ms)")
    }
    
    private fun stopVolumeReassertion() {
        volumeReassertRunnable?.let { runnable ->
            volumeReassertHandler?.removeCallbacks(runnable)
            volumeReassertRunnable = null
        }
        Log.d(TAG, "Volume reassertion stopped")
    }
    
    private fun reassertVolumeLock() {
        if (!isVolumeLocked) return
        
        try {
            val currentVolume = audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0
            
            if (currentVolume < maxMusicVolume) {
                Log.w(TAG, "VOLUME ATTACK DETECTED! Current: $currentVolume, Forcing back to: $maxMusicVolume")
                audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusicVolume, 0)
                
                // Notify Flutter that volume was forced back
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, CHANNEL).invokeMethod("volumeForced", mapOf(
                        "from" to currentVolume,
                        "to" to maxMusicVolume
                    ))
                }
            }
            
            // Also reassert audio focus if needed
            audioFocusRequest?.let { request ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    audioManager?.requestAudioFocus(request)
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reassert volume: ${e.message}", e)
        }
    }
}
