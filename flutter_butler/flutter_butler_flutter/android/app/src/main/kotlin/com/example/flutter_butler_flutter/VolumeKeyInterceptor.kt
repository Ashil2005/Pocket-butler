package com.example.flutter_butler_flutter

import android.content.Context
import android.hardware.input.InputManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.InputDevice

class VolumeKeyInterceptor(private val context: Context?, private val onVolumeKeyPressed: (keyCode: Int) -> Boolean) {
    companion object {
        private const val TAG = "VOLUME_INTERCEPTOR"
    }
    
    private var inputManager: InputManager? = null
    private var isIntercepting = false
    private var handler: Handler? = null
    
    private val inputDeviceListener = object : InputManager.InputDeviceListener {
        override fun onInputDeviceAdded(deviceId: Int) {
            Log.d(TAG, "Input device added: $deviceId")
        }
        
        override fun onInputDeviceRemoved(deviceId: Int) {
            Log.d(TAG, "Input device removed: $deviceId")
        }
        
        override fun onInputDeviceChanged(deviceId: Int) {
            Log.d(TAG, "Input device changed: $deviceId")
        }
    }
    
    fun start() {
        if (isIntercepting) {
            Log.d(TAG, "Volume key interception already active")
            return
        }
        
        try {
            inputManager = context?.getSystemService(Context.INPUT_SERVICE) as? InputManager
            handler = Handler(Looper.getMainLooper())
            
            inputManager?.registerInputDeviceListener(inputDeviceListener, handler)
            
            isIntercepting = true
            Log.i(TAG, "Volume key interception started")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start volume key interception: ${e.message}", e)
        }
    }
    
    fun stop() {
        if (!isIntercepting) {
            Log.d(TAG, "Volume key interception already stopped")
            return
        }
        
        try {
            inputManager?.unregisterInputDeviceListener(inputDeviceListener)
            
            isIntercepting = false
            Log.i(TAG, "Volume key interception stopped")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop volume key interception: ${e.message}", e)
        }
    }
}
