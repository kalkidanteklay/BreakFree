package com.example.breakfree

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.breakfree/native"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getState" -> result.success(readState())
                        "setMode" -> {
                            call.argument<Int>("mode")?.let { Prefs.setMode(this, it) }
                            result.success(true)
                        }
                        "setQuota" -> {
                            call.argument<Int>("minutes")?.let { Prefs.setQuotaMinutes(this, it) }
                            result.success(true)
                        }
                        "openAccessibilitySettings" -> {
                            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                            result.success(true)
                        }
                        "openOverlaySettings" -> {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("NATIVE_ERROR", e.message, null)
                }
            }
    }

    private fun readState(): Map<String, Any?> {
        Prefs.applyDailyRollover(this)
        return mapOf(
            "mode" to Prefs.getMode(this),
            "quotaMin" to Prefs.getQuotaMinutes(this),
            "usedTodayMs" to Prefs.getUsedTodayMs(this),
            "serviceEnabled" to isAccessibilityEnabled(),
            "overlayGranted" to canDrawOverlays(),
        )
    }

    private fun isAccessibilityEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val component = "$packageName/${BreakFreeAccessibilityService::class.java.name}"
        return enabled.split(':').any { it.equals(component, ignoreCase = true) }
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)
}