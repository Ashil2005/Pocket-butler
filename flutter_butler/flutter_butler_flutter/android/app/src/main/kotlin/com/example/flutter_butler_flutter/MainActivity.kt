package com.example.flutter_butler_flutter

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CLASSIC_BT_CHANNEL = "butler.bluetooth/classic"
    private val SHUTDOWN_CHANNEL = "flutter_butler_flutter/shutdown"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize native protection services
        AudioVolumeLock.initialize(flutterEngine)
        PowerOffProtection.initialize(flutterEngine)
        SecureOverlayService.initialize(flutterEngine)
        AlertService.initialize(flutterEngine, this)
        
        // Set context for native services
        AudioVolumeLock.getInstance().setContext(this)
        PowerOffProtection.getInstance().setContext(this)
        
        // Initial sync of armed state from persistence
        val prefs = getSharedPreferences("butler_prefs", android.content.Context.MODE_PRIVATE)
        val initiallyArmed = prefs.getBoolean("is_armed", false)
        ShutdownReceiver.setArmed(initiallyArmed)
        AlertService.setArmed(initiallyArmed)
        SecureOverlayService.setArmed(initiallyArmed)
        PowerMenuBlockAccessibilityService.setArmed(this, initiallyArmed)
        
        // Classic Bluetooth method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLASSIC_BT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "isClassicDeviceConnected") {
                    val deviceMac = call.argument<String>("deviceMac")
                    if (deviceMac == null) {
                        result.error("INVALID_ARGUMENT", "deviceMac is required", null)
                        return@setMethodCallHandler
                    }
                    
                    val isConnected = isClassicDeviceConnected(deviceMac)
                    result.success(isConnected)
                } else {
                    result.notImplemented()
                }
            }
            
        // Shutdown protection method channel - handles armed state sync
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHUTDOWN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setArmed" -> {
                        val armed = call.argument<Boolean>("armed") ?: false
                        android.util.Log.w("MAIN_ACTIVITY", "Armed state received from Flutter: $armed")
                        
                        // CRITICAL: Sync armed state to ALL native services
                        ShutdownReceiver.setArmed(armed)
                        AlertService.setArmed(armed)
                        SecureOverlayService.setArmed(armed)
                        PowerMenuBlockAccessibilityService.setArmed(this@MainActivity, armed)
                        // PowerOffProtection syncs AlertService internally
                        PowerOffProtection.getInstance().setArmed(armed)
                        
                        android.util.Log.i("MAIN_ACTIVITY", "Armed state synced to all native services")
                        result.success(null)
                    }
                    "onShutdownAttempt" -> {
                        val triggerType = call.argument<String>("triggerType") ?: "UNKNOWN"
                        handleShutdownAttempt(triggerType)
                        result.success(null)
                    }
                    "openAccessibilitySettings" -> {
                        val intent = android.content.Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Clean up native services
        AudioVolumeLock.getInstance().unlockVolume()
        PowerOffProtection.getInstance().setArmed(false)
    }
    
    private fun handleShutdownAttempt(triggerType: String) {
        // This will be called when shutdown/screen off is detected while armed
        // The Flutter side will handle the actual alarm triggering
        android.util.Log.w("SHUTDOWN_PROTECTION", "Shutdown attempt detected: $triggerType")
    }

    private fun isClassicDeviceConnected(deviceMac: String): Boolean {
        val bluetoothManager =
            getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = bluetoothManager.adapter ?: return false

        if (!adapter.isEnabled) return false

        var connected = false

        // Check A2DP profile connection state
        try {
            val a2dpState = adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.A2DP)
            if (a2dpState == android.bluetooth.BluetoothProfile.STATE_CONNECTED) {
                // Additional check: verify our specific device is connected
                val bondedDevices = adapter.bondedDevices
                val targetDevice = bondedDevices?.find { 
                    it.address.equals(deviceMac, ignoreCase = true) 
                }
                if (targetDevice != null) {
                    connected = true
                }
            }
        } catch (e: Exception) {
            // A2DP check failed
        }

        // Check HEADSET profile connection state
        try {
            val headsetState = adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.HEADSET)
            if (headsetState == android.bluetooth.BluetoothProfile.STATE_CONNECTED) {
                // Additional check: verify our specific device is connected
                val bondedDevices = adapter.bondedDevices
                val targetDevice = bondedDevices?.find { 
                    it.address.equals(deviceMac, ignoreCase = true) 
                }
                if (targetDevice != null) {
                    connected = true
                }
            }
        } catch (e: Exception) {
            // HEADSET check failed
        }

        return connected
    }
}
