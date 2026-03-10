package com.bazooka.alerts.app

import android.app.KeyguardManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.bazooka.alerts/device_state"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "isDeviceLocked" -> {
                            val keyguardManager =
                                    getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                            result.success(keyguardManager.isKeyguardLocked)
                        }
                        else -> result.notImplemented()
                    }
                }
    }
}
