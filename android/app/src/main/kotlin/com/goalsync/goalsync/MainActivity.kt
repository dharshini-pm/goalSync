package com.goalsync.goalsync

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "com.goalsync.goalsync/sms_receiver"
        private const val SMS_PERMISSION_REQUEST_CODE = 1001

        private var methodChannel: MethodChannel? = null
        private val pendingSmsQueue = mutableListOf<Map<String, Any>>()

        /**
         * Called by SmsReceiver when an eligible financial SMS broadcast arrives.
         */
        fun onSmsReceived(sender: String, body: String, timestamp: Long) {
            val payload = mapOf(
                "sender" to sender,
                "body" to body,
                "timestamp" to timestamp
            )

            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod("onSmsReceived", payload)
            } else {
                // Buffer if Flutter is initializing
                synchronized(pendingSmsQueue) {
                    if (pendingSmsQueue.size < 50) {
                        pendingSmsQueue.add(payload)
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(
                            Manifest.permission.RECEIVE_SMS,
                            Manifest.permission.READ_SMS
                        ),
                        SMS_PERMISSION_REQUEST_CODE
                    )
                    result.success(true)
                }
                "isReceiverActive" -> {
                    result.success(true)
                }
                "simulateSms" -> {
                    val sender = call.argument<String>("sender") ?: "SIM-TEST"
                    val body = call.argument<String>("body") ?: ""
                    val timestamp = call.argument<Long>("timestamp") ?: System.currentTimeMillis()
                    onSmsReceived(sender, body, timestamp)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Flush any pending messages that arrived before Flutter was ready
        synchronized(pendingSmsQueue) {
            for (sms in pendingSmsQueue) {
                channel.invokeMethod("onSmsReceived", sms)
            }
            pendingSmsQueue.clear()
        }
    }

    override fun onDestroy() {
        methodChannel = null
        super.onDestroy()
    }
}
