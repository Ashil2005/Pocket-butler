package com.example.flutter_butler_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// NOTE: Vibrator imports REMOVED - AlertService is the SINGLE SOURCE OF TRUTH for vibration

class PowerOffProtection private constructor() {
    companion object {
        private const val TAG = "POWER_OFF_PROTECTION"
        private const val CHANNEL = "flutter_butler_flutter/power_off"
        
        @Volatile
        private var instance: PowerOffProtection? = null
        private var flutterEngine: FlutterEngine? = null
        
        fun getInstance(): PowerOffProtection {
            return instance ?: synchronized(this) {
                instance ?: PowerOffProtection().also { instance = it }
            }
        }
        
        fun initialize(engine: FlutterEngine) {
            flutterEngine = engine
            getInstance().initializeMethodChannel()
        }
    }
    
    private var context: Context? = null
    private var isArmed = false
    private var isProtectionActive = false
    // NOTE: Vibrator REMOVED - AlertService is the SINGLE SOURCE OF TRUTH
    private var cameraManager: CameraManager? = null
    private var powerManager: PowerManager? = null
    
    // Broadcast receivers
    private var shutdownReceiver: BroadcastReceiver? = null
    private var screenOffReceiver: BroadcastReceiver? = null
    private var powerMenuReceiver: BroadcastReceiver? = null
    private var volumeKeyReceiver: VolumeKeyInterceptor? = null
    
    private fun initializeMethodChannel() {
        val methodChannel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setArmed" -> {
                    val armed = call.argument<Boolean>("armed") ?: false
                    setArmed(armed)
                    result.success(null)
                }
                "isProtectionActive" -> {
                    result.success(isProtectionActive)
                }
                "triggerEmergencyAlarm" -> {
                    triggerEmergencyAlarm("FLUTTER_TRIGGER")
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    fun setContext(context: Context) {
        this.context = context
        // NOTE: Vibrator initialization REMOVED - AlertService owns vibration
        this.cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        this.powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    }
    
    fun setArmed(armed: Boolean) {
        Log.w(TAG, "ARMED STATE CHANGED: $armed")
        isArmed = armed
        
        // CRITICAL: Sync armed state with AlertService
        AlertService.setArmed(armed)
        
        if (armed) {
            activateProtection()
        } else {
            deactivateProtection()
        }
    }
    
    private fun activateProtection() {
        if (isProtectionActive) {
            Log.d(TAG, "Protection already active")
            return
        }
        
        Log.w(TAG, "ACTIVATING POWER OFF PROTECTION")
        
        try {
            // Register shutdown receiver
            registerShutdownReceiver()
            
            // Register screen off receiver
            registerScreenOffReceiver()
            
            // Register power menu receiver
            registerPowerMenuReceiver()
            
            // Register volume key interceptor
            registerVolumeKeyInterceptor()
            
            isProtectionActive = true
            Log.i(TAG, "Power off protection ACTIVATED")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to activate protection: ${e.message}", e)
        }
    }
    
    private fun deactivateProtection() {
        if (!isProtectionActive) {
            Log.d(TAG, "Protection already inactive")
            return
        }
        
        Log.w(TAG, "DEACTIVATING POWER OFF PROTECTION")
        
        try {
            // Unregister all receivers
            context?.unregisterReceiver(shutdownReceiver)
            context?.unregisterReceiver(screenOffReceiver)
            context?.unregisterReceiver(powerMenuReceiver)
            
            // Stop volume key interceptor
            volumeKeyReceiver?.stop()
            
            isProtectionActive = false
            Log.i(TAG, "Power off protection DEACTIVATED")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to deactivate protection: ${e.message}", e)
        }
    }
    
    private fun registerShutdownReceiver() {
        shutdownReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                // GUARD: Only act if armed
                if (!isArmed) {
                    Log.d(TAG, "Shutdown detected but NOT armed - ignoring")
                    return
                }
                Log.e(TAG, "🚨 SHUTDOWN DETECTED WHILE ARMED - TRIGGERING EMERGENCY ALARM")
                triggerEmergencyAlarm("ACTION_SHUTDOWN")
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SHUTDOWN)
            addAction("android.intent.action.QUICKBOOT_POWEROFF")
            addAction("android.intent.action.REBOOT")
        }
        
        context?.registerReceiver(shutdownReceiver, filter)
        Log.d(TAG, "Shutdown receiver registered")
    }
    
    // NOTE: SCREEN_OFF receiver REMOVED - screen off should NOT trigger alarm
    private fun registerScreenOffReceiver() {
        // INTENTIONALLY EMPTY - Screen off does NOT trigger alarm
        // This is a security decision: only actual shutdown/reboot attempts trigger alarm
        Log.d(TAG, "Screen off receiver NOT registered (by design)")
    }
    
    private fun registerPowerMenuReceiver() {
        powerMenuReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                // GUARD: Only act if armed
                if (!isArmed) {
                    Log.d(TAG, "Power menu detected but NOT armed - ignoring")
                    return
                }
                
                if (intent?.action == Intent.ACTION_CLOSE_SYSTEM_DIALOGS) {
                    val reason = intent.getStringExtra("reason")
                    Log.w(TAG, "System dialog closed - reason: $reason")
                    
                    // Only show overlay for power menu (globalactions)
                    if (reason == "globalactions") {
                        Log.w(TAG, "🚨 POWER MENU DETECTED WHILE ARMED - SHOWING OVERLAY ONLY")
                        // CRITICAL: Show overlay ONLY - do NOT start alarm here
                        // Overlay blocks power menu, alarm is NOT triggered by overlay
                        showSecurityOverlayOnly()
                    }
                }
            }
        }
        
        val filter = IntentFilter(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
        context?.registerReceiver(powerMenuReceiver, filter)
        Log.d(TAG, "Power menu receiver registered")
    }
    
    /**
     * Show security overlay WITHOUT triggering alarm
     * Overlay is defensive only - blocks power menu interaction
     */
    private fun showSecurityOverlayOnly() {
        try {
            context?.let { ctx ->
                SecureOverlayService.showOverlay(ctx)
                Log.i(TAG, "✅ Security overlay shown (NO alarm triggered)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay: ${e.message}", e)
        }
    }
    
    private fun registerVolumeKeyInterceptor() {
        volumeKeyReceiver = VolumeKeyInterceptor(context) { keyCode ->
            // GUARD: Only intercept if armed
            if (!isArmed) {
                return@VolumeKeyInterceptor false
            }
            
            if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                Log.w(TAG, "🚨 VOLUME KEY PRESSED WHILE ARMED - TRIGGERING EMERGENCY")
                triggerEmergencyAlarm("VOLUME_KEY_PRESSED")
                true // Intercept the event
            } else {
                false // Allow normal handling
            }
        }
        volumeKeyReceiver?.start()
        Log.d(TAG, "Volume key interceptor registered")
    }
    
    private fun triggerEmergencyAlarm(triggerType: String) {
        // GUARD: Double-check armed state
        if (!isArmed) {
            Log.w(TAG, "❌ triggerEmergencyAlarm REJECTED - NOT armed (trigger: $triggerType)")
            return
        }
        
        Log.e(TAG, "🚨 EMERGENCY ALARM TRIGGERED: $triggerType")
        
        try {
            // 1. SHOW SECURITY OVERLAY IMMEDIATELY - This blocks power menu interaction
            Log.w(TAG, "🛡️ ACTIVATING SECURITY OVERLAY TO BLOCK POWER MENU")
            context?.let { SecureOverlayService.showOverlay(it) }
            
            // 2. Notify Flutter immediately
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("emergencyAlarm", mapOf(
                    "triggerType" to triggerType,
                    "timestamp" to System.currentTimeMillis()
                ))
            }
            
            // 3. DELEGATE vibration to AlertService - SINGLE SOURCE OF TRUTH
            Log.w(TAG, "🔊 Delegating vibration to AlertService (SINGLE SOURCE)")
            context?.let { AlertService.startAlert(it) }
            
            // 4. Turn on flashlight (if available)
            startEmergencyFlashlight()
            
            // 5. Wake up screen
            wakeUpScreen()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger emergency alarm: ${e.message}", e)
        }
    }
    
    // NOTE: startEmergencyVibration() DELETED - AlertService is the SINGLE SOURCE OF TRUTH
    // All vibration MUST go through AlertService.startAlert()
    
    private fun startEmergencyFlashlight() {
        try {
            cameraManager?.let { cm ->
                val cameraId = cm.cameraIdList.firstOrNull()
                cameraId?.let { id ->
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        cm.turnOnTorchWithStrengthLevel(id, 1)
                    }
                }
            }
            Log.d(TAG, "Emergency flashlight started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start flashlight: ${e.message}", e)
        }
    }
    
    private fun wakeUpScreen() {
        try {
            // This is a best-effort attempt - may not work on all devices
            val wakeLock = powerManager?.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "Butler:EmergencyWakeLock"
            )
            wakeLock?.acquire(3000) // Wake for 3 seconds
            Log.d(TAG, "Screen wake-up attempted")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to wake up screen: ${e.message}", e)
        }
    }
    
    fun stopEmergencyEffects() {
        try {
            // DELEGATE vibration stop to AlertService - SINGLE SOURCE OF TRUTH
            Log.w(TAG, "🔇 Delegating vibration stop to AlertService (SINGLE SOURCE)")
            context?.let { AlertService.stopAlert(it) }
            
            // Stop flashlight
            cameraManager?.let { cm ->
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        cm.cameraIdList.firstOrNull()?.let { cameraId ->
                            cm.setTorchMode(cameraId, false)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to turn off flashlight: ${e.message}", e)
                }
            }
            
            // HIDE SECURITY OVERLAY when protection is deactivated
            if (!isArmed) {
                Log.w(TAG, "🔓 HIDING SECURITY OVERLAY - Protection deactivated")
                SecureOverlayService.hideOverlay()
            }
            
            Log.d(TAG, "Emergency effects stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop emergency effects: ${e.message}", e)
        }
    }
}
