package com.example.flutter_butler_flutter

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.*
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AlertService : Service() {
    companion object {
        private const val TAG = "ALERT_SERVICE"
        private const val CHANNEL = "flutter_butler_flutter/alert_service"
        private const val NOTIFICATION_ID = 1001
        
        @Volatile
        private var instance: AlertService? = null
        private var flutterEngine: FlutterEngine? = null
        
        // SINGLE SOURCE OF TRUTH: Armed state
        @Volatile
        private var isArmed = false
        
        fun getInstance(): AlertService? = instance
        
        fun initialize(engine: FlutterEngine, context: Context) {
            flutterEngine = engine
            
            // Register MethodChannel to LISTEN for Flutter commands
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlert" -> {
                        Log.e(TAG, "📥 METHODCHANNEL RECEIVED startVibration")
                        startAlert(context)
                        result.success(null)
                    }
                    "stopAlert" -> {
                        Log.i(TAG, "Received stopAlert from Flutter")
                        stopAlert(context)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        
        /**
         * Set armed state - MUST be called before any alert can start
         */
        fun setArmed(armed: Boolean) {
            isArmed = armed
            Log.w(TAG, "ARMED STATE CHANGED: $armed")
            if (!armed) {
                // CRITICAL: Stop any active alert when disarming
                instance?.stopAlertInternal()
            }
        }
        
        fun getArmedState(): Boolean = isArmed
        
        fun startAlert(context: Context) {
            // GUARD: Reject if not armed
            if (!isArmed) {
                Log.w(TAG, "❌ startAlert REJECTED - Butler is NOT armed")
                return
            }
            
            val intent = Intent(context, AlertService::class.java).apply {
                action = "START_ALERT"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopAlert(context: Context) {
            Log.i(TAG, "stopAlert called from context")
            instance?.stopAlertInternal()
            // Also stop service
            val intent = Intent(context, AlertService::class.java).apply {
                action = "STOP_ALERT"
            }
            context.startService(intent)
        }
        
        /**
         * Force stop all alerts unconditionally - for emergency cleanup
         */
        fun forceStopAll() {
            Log.w(TAG, "⚠️ FORCE STOP ALL - Unconditional vibration cancel")
            instance?.cancelVibrationUnconditionally()
        }
        
        fun isAlertActive(): Boolean = instance?.isAlertActive ?: false
    }
    
    private var vibrator: Vibrator? = null
    private var vibrationId: Int? = null
    private var isAlertActive = false
    private var notificationManager: NotificationManager? = null
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        Log.i(TAG, "AlertService created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_ALERT" -> {
                startAlertInternal()
                startForeground(NOTIFICATION_ID, createNotification())
            }
            "STOP_ALERT" -> {
                stopAlertInternal()
                stopSelf()
            }
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    // --- ALERT LOGIC ---
    
    private fun startAlertInternal() {
        // GUARD: Check armed state and active state
        if (!isArmed || isAlertActive) {
            Log.w(TAG, "startAlertInternal rejected: isArmed=$isArmed, isAlertActive=$isAlertActive")
            return
        }
    
        isAlertActive = true
    
        // 1. START VIBRATION ONLY (Audio is handled by Flutter)
        startNativeVibration()
    
        // 2. FORCE MAX VOLUME
        startVolumeLock()
    }
    
    private fun stopAlertInternal() {
        if (!isAlertActive) return
    
        isAlertActive = false
    
        // STOP VIBRATION (UNCONDITIONAL)
        stopNativeVibration()
    
        // RELEASE VOLUME LOCK
        stopVolumeLock()
    }
    
    private fun startNativeVibration() {
        try {
            vibrator?.cancel()
            val pattern = longArrayOf(0, 800, 400, 800)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(pattern, 0)
                vibrator?.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
            
            Log.e("ALERT_SERVICE", "📳 vibrator.vibrate CALLED")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start native vibration: ${e.message}", e)
        }
    }
    
    private fun stopNativeVibration() {
        try {
            vibrator?.cancel()
            // Unconditional nuclear option
            cancelVibrationUnconditionally() 
            Log.e("ALERT_SERVICE", "🛑 VIBRATION STOPPED WITH ALARM")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop native vibration: ${e.message}", e)
        }
    }
    
    /**
     * UNCONDITIONALLY cancel vibration - the nuclear option
     * Called on ALL exit paths to prevent zombie vibrations
     */
    private fun cancelVibrationUnconditionally() {
        try {
            vibrator?.cancel()
            Log.e("ALERT_SERVICE", "🛑 vibrator.cancel CALLED")
            
            // Also stop volume lock here to be safe (double check)
            stopVolumeLock()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel vibration: ${e.message}", e)
        }
    }
    
    // NOTE: startNativeVibration and stopNativeVibration REMOVED (inlined into startAlertInternal)
    
    // --- VOLUME LOCK LOGIC ---
    
    private var volumeObserver: android.database.ContentObserver? = null
    private var initialVolumeMusic: Int = 0
    private var initialVolumeAlarm: Int = 0
    private var audioManager: android.media.AudioManager? = null
    
    private fun startVolumeLock() {
        try {
            audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
            
            // Store initial volumes to restore later
            initialVolumeMusic = audioManager?.getStreamVolume(android.media.AudioManager.STREAM_MUSIC) ?: 0
            initialVolumeAlarm = audioManager?.getStreamVolume(android.media.AudioManager.STREAM_ALARM) ?: 0
            
            // Set MAX volume immediately
            forceMaxVolume()
            
            // Register observer
            if (volumeObserver == null) {
                volumeObserver = object : android.database.ContentObserver(Handler(Looper.getMainLooper())) {
                    override fun onChange(selfChange: Boolean) {
                        super.onChange(selfChange)
                        Log.w(TAG, "🚨 VOLUME MOVEMENT DETECTED - RESETTING TO MAX")
                        forceMaxVolume()
                    }
                }
                
                contentResolver.registerContentObserver(
                    android.provider.Settings.System.CONTENT_URI, 
                    true, 
                    volumeObserver!!
                )
                Log.i(TAG, "🔊 Volume lock engaged (Observer registered)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start volume lock: ${e.message}", e)
        }
    }
    
    private fun forceMaxVolume() {
        try {
            audioManager?.let { am ->
                val maxMusic = am.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                am.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, maxMusic, android.media.AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE)
                
                val maxAlarm = am.getStreamMaxVolume(android.media.AudioManager.STREAM_ALARM)
                am.setStreamVolume(android.media.AudioManager.STREAM_ALARM, maxAlarm, android.media.AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE)
                
                Log.d(TAG, "🔊 Volume forced to MAX: Music=$maxMusic, Alarm=$maxAlarm")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to force max volume: ${e.message}", e)
        }
    }
    
    private fun stopVolumeLock() {
        try {
            // Unregister observer
            volumeObserver?.let {
                contentResolver.unregisterContentObserver(it)
                volumeObserver = null
                Log.i(TAG, "🔊 Volume lock disengaged")
            }
            
            // Restore previous volume (optional but nice)
            audioManager?.let { am ->
                am.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, initialVolumeMusic, 0)
                am.setStreamVolume(android.media.AudioManager.STREAM_ALARM, initialVolumeAlarm, 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop volume lock: ${e.message}", e)
        }
    }

    private fun createNotification(): Notification {
        val channelId = "alert_service_channel"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Alert Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Anti-theft alarm service"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            
            notificationManager?.createNotificationChannel(channel)
        }
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
                .setContentTitle("🚨 THEFT ALERT ACTIVE")
                .setContentText("Anti-theft protection is running")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_HIGH)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("🚨 THEFT ALERT ACTIVE")
                .setContentText("Anti-theft protection is running")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_HIGH)
                .setSound(null)
                .build()
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.w(TAG, "⚠️ AlertService onDestroy - UNCONDITIONAL vibration cancel")
        cancelVibrationUnconditionally()
        isAlertActive = false
        instance = null
        Log.d(TAG, "AlertService destroyed")
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.w(TAG, "⚠️ Task removed - UNCONDITIONAL vibration cancel (NOT starting new alert)")
        // CRITICAL: NEVER start alert on task removed, ONLY cancel vibration
        cancelVibrationUnconditionally()
    }
}
