package com.example.flutter_butler_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * ShutdownReceiver - Handles system events for anti-theft protection
 * 
 * CRITICAL RULES:
 * - NEVER trigger alarm on SCREEN_OFF
 * - ONLY show overlay on POWER_MENU (globalactions)
 * - Overlay does NOT start alarm - it only blocks power menu interaction
 */
class ShutdownReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SHUTDOWN_RECEIVER"
        private const val CHANNEL = "flutter_butler_flutter/shutdown"
        private var flutterEngine: FlutterEngine? = null
        
        @Volatile
        private var isArmed = false
        
        fun setFlutterEngine(engine: FlutterEngine) {
            flutterEngine = engine
        }
        
        fun setArmed(armed: Boolean) {
            isArmed = armed
            Log.w(TAG, "ARMED STATE UPDATED: $armed")
        }
        
        fun getArmedState(): Boolean = isArmed
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.e("POWER_TRACE", "onReceive action=${intent.action} reason=${intent.getStringExtra("reason")}")
        // PHASE 1: Mandatory Logs
        Log.e(TAG, "[SHUTDOWN_RECEIVER] onReceive called")
        
        val armedStatus = isArmed
        
        when (intent.action) {
            Intent.ACTION_CLOSE_SYSTEM_DIALOGS -> {
                val reason = intent.getStringExtra("reason")
                // PHASE 1: Mandatory Logs
                Log.e(TAG, "[SHUTDOWN_RECEIVER] reason=$reason armed=$armedStatus")
                
                // PHASE 2: Intercept ONLY globalactions when ARMED
                if (reason == "globalactions" && armedStatus) {
                    Log.e("POWER_TRACE", "Overlay requested from receiver")
                    try {
                        // Ensure main thread for service start consistency
                        context.mainExecutor.execute {
                            SecureOverlayService.showOverlay(context)
                        }
                        notifyFlutter(context, "POWER_MENU")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to show overlay: ${e.message}", e)
                    }
                }
            }
            
            Intent.ACTION_SHUTDOWN -> {
                if (armedStatus) {
                    Log.w(TAG, "🚨 SYSTEM SHUTDOWN DETECTED WHILE ARMED")
                    notifyFlutter(context, "SYSTEM_SHUTDOWN")
                }
            }
        }
    }

    private fun notifyFlutter(context: Context, triggerType: String) {
        try {
            flutterEngine?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                    "onSecurityEvent", 
                    mapOf("triggerType" to triggerType)
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify Flutter: ${e.message}")
        }
    }
}
