package com.example.flutter_butler_flutter

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import kotlin.jvm.Volatile

class PowerMenuBlockAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "POWER_BLOCK"
        
        @Volatile
        private var armedStateInternal = false
        
        fun setArmed(context: android.content.Context, armed: Boolean) {
            armedStateInternal = armed
            Log.w(TAG, "ARMED STATE UPDATED: $armed")
            
            // Persist state for service restarts
            val prefs = context.getSharedPreferences("butler_prefs", android.content.Context.MODE_PRIVATE)
            prefs.edit().putBoolean("is_armed", armed).apply()
        }
        
        fun isArmed(context: android.content.Context): Boolean {
            val prefs = context.getSharedPreferences("butler_prefs", android.content.Context.MODE_PRIVATE)
            return prefs.getBoolean("is_armed", false)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isDetectionRunning = false

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // Broad sync for armed state
        val armedNow = isArmed(this)
        if (armedStateInternal != armedNow) {
            armedStateInternal = armedNow
            Log.w(TAG, "Dynamic Armed Check: $armedStateInternal")
        }
        
        if (!armedStateInternal) return

        val eventType = event.eventType
        val packageName = event.packageName?.toString() ?: ""
        val className = event.className?.toString() ?: ""

        // Ultra-aggressive detection: Any window change in system processes while armed
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || 
            eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
            eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED ||
            eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED ||
            eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            
            val isSystemProcess = packageName.contains("systemui", ignoreCase = true) || 
                                 packageName == "android" || 
                                 packageName.contains("power", ignoreCase = true)
            
            val indicatesPowerMenu = className.contains("GlobalActions", ignoreCase = true) ||
                                    className.contains("PowerOptions", ignoreCase = true) ||
                                    className.contains("Shutdown", ignoreCase = true) ||
                                    className.contains("PowerUI", ignoreCase = true) ||
                                    className.contains("SystemUI", ignoreCase = true) ||
                                    (isSystemProcess && className.contains("Dialog", ignoreCase = true))
            
            if (isSystemProcess && indicatesPowerMenu) {
                Log.e(TAG, "MANDATORY PROOF: Power menu detected ($packageName / $className) → Rapid BACK firing")
                
                // Fire immediately
                performGlobalAction(GLOBAL_ACTION_BACK)
                
                // Immediately start/refresh loop
                startRapidBlockLoop()
            }
        }
    }

    private fun startRapidBlockLoop() {
        // ALWAYS refresh the loop if detected to prolong the blocking if the user persists
        isDetectionRunning = true
        handler.removeCallbacksAndMessages("BLOCK_LOOP") 
        
        val runnable = object : Runnable {
            override fun run() {
                if (!armedStateInternal || !isDetectionRunning) return
                
                // Industrial speed (50ms) to beat the refresh rate of the power menu
                performGlobalAction(GLOBAL_ACTION_BACK)
                handler.postAtTime(this, "BLOCK_LOOP", SystemClock.uptimeMillis() + 50)
            }
        }
        handler.postAtTime(runnable, "BLOCK_LOOP", SystemClock.uptimeMillis() + 50)
        
        // Extended safety timeout to 10 seconds to cover long-press duration
        handler.removeCallbacksAndMessages("BLOCK_TIMEOUT")
        val timeoutRunnable = Runnable { isDetectionRunning = false }
        handler.postAtTime(timeoutRunnable, "BLOCK_TIMEOUT", SystemClock.uptimeMillis() + 10000)
    }

    override fun onInterrupt() {
        isDetectionRunning = false
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        
        val info = android.accessibilityservice.AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or 
                        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                        AccessibilityEvent.TYPE_WINDOWS_CHANGED
            
            feedbackType = android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 0
            flags = 32 or // FLAG_RETRIEVE_INTERACTIVE_WINDOWS
                    2 or  // FLAG_INCLUDE_NOT_FOCUSED_WINDOWS
                    16    // FLAG_REPORT_VIEW_IDS
        }
        this.serviceInfo = info
        
        // Initial sync
        armedStateInternal = isArmed(this)
        Log.e(TAG, "MANDATORY PROOF: PowerMenuBlockAccessibilityService connected (isArmed=$armedStateInternal)")

        // Verification handle
        val filter = android.content.IntentFilter()
        filter.addAction("com.example.flutter_butler_flutter.ACTION_SET_ARMED")
        
        val receiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: android.content.Context?, intent: android.content.Intent?) {
                val armed = intent?.getBooleanExtra("armed", false) ?: false
                if (context != null) {
                    setArmed(context, armed)
                    Log.e(TAG, "MANDATORY PROOF: Armed state changed via Broadcast: $armed")
                }
            }
        }
        
        if (android.os.Build.VERSION.SDK_INT >= 33) { // TIRAMISU
            // Use 2 (RECEIVER_EXPORTED) to avoid unresolved reference on older SDKs
            registerReceiver(receiver, filter, 2) 
        } else {
            registerReceiver(receiver, filter)
        }
    }
}
