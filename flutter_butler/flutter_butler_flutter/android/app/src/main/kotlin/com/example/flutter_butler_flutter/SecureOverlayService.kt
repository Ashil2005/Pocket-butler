package com.example.flutter_butler_flutter

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class SecureOverlayService : Service() {
    companion object {
        private const val TAG = "SECURE_OVERLAY"
        private const val CHANNEL = "flutter_butler_flutter/secure_overlay"
        
        @Volatile
        private var instance: SecureOverlayService? = null
        private var flutterEngine: FlutterEngine? = null
        private var isArmed = false
        
        fun initialize(engine: FlutterEngine) {
            flutterEngine = engine
        }
        
        fun setArmed(armed: Boolean) {
            isArmed = armed
            Log.d(TAG, "Armed state synced: $armed")
            if (armed) {
                instance?.startDetection()
            } else {
                instance?.stopDetection()
                instance?.hideOverlayInternal()
            }
        }
        
        fun showOverlay(context: Context) {
            // PHASE 1: Mandatory Logs
            Log.e(TAG, "[SECURE_OVERLAY] showOverlay invoked")
            
            val intent = Intent(context, SecureOverlayService::class.java).apply {
                action = "SHOW_OVERLAY"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun hideOverlay() {
            instance?.hideOverlayInternal()
        }
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayActive = false
    private var pinEditText: EditText? = null
    private var detectionThread: Thread? = null
    private var isDetecting = false
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        if (isArmed) {
            startDetection()
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "SHOW_OVERLAY" -> {
                showOverlayInternal()
                startForeground(9999, createNotification())
                stopDetection()
            }
            "HIDE_OVERLAY" -> {
                hideOverlayInternal()
                stopSelf()
            }
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun showOverlayInternal() {
        if (isOverlayActive) return
        
        try {
            // Create overlay view
            overlayView = LayoutInflater.from(this).inflate(R.layout.secure_overlay, null)
            
            // PHASE 3 & 4: OEM HARDENING - Consume all touches at root level
            overlayView?.setOnTouchListener { _, _ -> true }
            
            // Find views
            val titleText = overlayView?.findViewById<TextView>(R.id.overlay_title)
            val subtitleText = overlayView?.findViewById<TextView>(R.id.overlay_subtitle)
            pinEditText = overlayView?.findViewById(R.id.pin_input)
            val submitButton = overlayView?.findViewById<Button>(R.id.pin_submit)
            
            titleText?.text = "⚠️ SECURITY PROTECTION ACTIVE"
            subtitleText?.text = "This phone is protected by Butler\nEnter PIN to access power options"
            
            submitButton?.setOnClickListener {
                val pin = pinEditText?.text?.toString()
                if (!pin.isNullOrEmpty()) {
                    verifyPinWithFlutter(pin)
                } else {
                    Toast.makeText(this, "Please enter PIN", Toast.LENGTH_SHORT).show()
                }
            }
            
            val params = WindowManager.LayoutParams().apply {
                type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                
                // PHASE 3: MANDATORY FLAGS
                flags = WindowManager.LayoutParams.FLAG_FULLSCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                
                // Ensure no bypass flags exist
                // FLAG_NOT_TOUCHABLE and FLAG_NOT_FOCUSABLE are NOT added
                
                width = WindowManager.LayoutParams.MATCH_PARENT
                height = WindowManager.LayoutParams.MATCH_PARENT
                gravity = Gravity.TOP or Gravity.LEFT
                format = PixelFormat.TRANSLUCENT
            }
            
            windowManager?.addView(overlayView, params)
            isOverlayActive = true
            
            // PHASE 5: Hard Proof Log
            Log.e("POWER_TRACE", "OVERLAY_ATTACHED")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay: ${e.message}", e)
        }
    }
    
    private fun hideOverlayInternal() {
        if (!isOverlayActive) return
        try {
            overlayView?.let { view ->
                windowManager?.removeView(view)
                overlayView = null
            }
            isOverlayActive = false
            Log.i(TAG, "[SECURE_OVERLAY] PIN verified — overlay dismissed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hide overlay: ${e.message}")
        }
    }
    
    private fun verifyPinWithFlutter(pin: String) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("verifyPin", mapOf("pin" to pin), object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (result as? Boolean == true) {
                        hideOverlayInternal()
                        stopSelf()
                    } else {
                        pinEditText?.text?.clear()
                        Toast.makeText(this@SecureOverlayService, "Invalid PIN", Toast.LENGTH_SHORT).show()
                    }
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })
        }
    }
    
    private fun createNotification(): android.app.Notification {
        val channelId = "secure_overlay_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.createNotificationChannel(android.app.NotificationChannel(channelId, "Security Overlay", android.app.NotificationManager.IMPORTANCE_LOW))
        }
        return android.app.Notification.Builder(this, channelId)
            .setContentTitle("Security Protection Active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopDetection()
        hideOverlayInternal()
        instance = null
    }

    private fun startDetection() {
        if (isDetecting) return
        isDetecting = true
        detectionThread = Thread {
            Log.d(TAG, "Starting Power Menu detection thread")
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            
            while (isDetecting) {
                if (isArmed && !isOverlayActive) {
                    try {
                        // Polling ActivityManager for SystemUI window detection (OEM Fallback)
                        @Suppress("DEPRECATION")
                        val tasks = activityManager.getRunningTasks(1)
                        if (tasks.isNotEmpty()) {
                            val topActivity = tasks[0].topActivity
                            val packageName = topActivity?.packageName ?: ""
                            val className = topActivity?.className ?: ""
                            
                            // Check for SystemUI Power Menu window titles/components
                            if (packageName.contains("systemui", ignoreCase = true) || 
                                className.contains("GlobalActions", ignoreCase = true) ||
                                className.contains("PowerUI", ignoreCase = true)) {
                                
                                Log.e("POWER_TRACE", "SystemUI power menu window detected")
                                // Switch to main thread to show overlay
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    showOverlayInternal()
                                }
                            }
                        }
                    } catch (e: Exception) {
                        // Ignore periodic errors during polling
                    }
                }
                Thread.sleep(500)
            }
        }.apply { start() }
    }

    private fun stopDetection() {
        isDetecting = false
        detectionThread?.interrupt()
        detectionThread = null
    }
}
