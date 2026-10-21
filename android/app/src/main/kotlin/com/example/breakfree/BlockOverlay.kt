package com.example.breakfree

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager

/**
 * Full-screen overlay shown while TikTok is blocked.
 * Falls back to no-op (with auto press-back still active) if overlay permission is missing
 * or on very old Android versions.
 */
class BlockOverlay(private val context: Context) {

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private var overlayView: View? = null

    val isShowing: Boolean get() = overlayView != null

    private fun canShowOverlay(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) return false
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.N // TYPE_PHONE from N
    }

    fun show() {
        if (overlayView != null) return
        if (!canShowOverlay()) return

        val view = LayoutInflater.from(context).inflate(R.layout.blocker_overlay, null)
        view.findViewById<View>(R.id.btnOpenApp).setOnClickListener {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    context.startActivity(launch)
                } catch (_: Exception) {
                }
            }
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 0

        try {
            windowManager.addView(view, params)
            overlayView = view
        } catch (_: Exception) {
            overlayView = null
        }
    }

    fun dismiss() {
        overlayView?.let { view ->
            try {
                windowManager.removeView(view)
            } catch (_: Exception) {
                // view already removed
            }
            overlayView = null
        }
    }
}