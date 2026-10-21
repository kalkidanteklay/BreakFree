package com.example.breakfree

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * Enforcement engine.
 *
 * Level 1 (daily quota): measures how long TikTok stays the focused app and accumulates
 * that time into a per-day budget. When the budget is exhausted the service shows a
 * full-screen overlay and repeatedly presses Back to push the user out of TikTok.
 *
 * The service reads/writes state through [Prefs], so it keeps enforcing even when the
 * Flutter UI process/activity is paused or killed.
 */
class BreakFreeAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "BreakFree"
        private const val TIKTOK_PACKAGE = "com.zhiliaoapp.musically"

        /** Enforcement tick: checks the focused window and re-applies the block. */
        private const val TICK_MS = 700L
    }

    private val handler = Handler(Looper.getMainLooper())

    private lateinit var overlay: BlockOverlay
    private var inTikTok = false
    private var lastTickAt = 0L

    private val ticker = object : Runnable {
        override fun run() {
            tick()
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        overlay = BlockOverlay(this)

        // Recover from an unclean shutdown: if a TikTok session was left open and the
        // process was killed, count the dangling elapsed time toward the quota.
        if (Prefs.isSessionActive(this)) {
            val tick = Prefs.getSessionLastTick(this)
            val now = System.currentTimeMillis()
            if (tick > 0 && now > tick) {
                Prefs.addUsedTodayMs(this, now - tick)
            }
            Prefs.setSessionActive(this, false)
            Prefs.setSessionLastTick(this, 0L)
        }

        handler.post(ticker)
        Log.d(TAG, "Service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg != TIKTOK_PACKAGE) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> markFocused(true)
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> tick() // hot path: keep count fresh
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Service interrupted")
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        if (inTikTok) endSession()
        overlay.dismiss()
        super.onDestroy()
    }

    // ------------------------------------------------------------------ tracking

    private fun markFocused(focused: Boolean) {
        if (focused && !inTikTok) {
            inTikTok = true
            val now = System.currentTimeMillis()
            lastTickAt = now
            Prefs.setSessionActive(this, true)
            Prefs.setSessionLastTick(this, now)
        } else if (!focused && inTikTok) {
            endSession()
        }
    }

    private fun endSession() {
        val now = System.currentTimeMillis()
        if (lastTickAt > 0 && now > lastTickAt) {
            Prefs.addUsedTodayMs(this, now - lastTickAt)
        }
        inTikTok = false
        lastTickAt = 0L
        Prefs.setSessionActive(this, false)
        Prefs.setSessionLastTick(this, 0L)
    }

    private fun tick() {
        Prefs.applyDailyRollover(this)

        // Account focused time while TikTok is in the foreground.
        if (inTikTok) {
            val now = System.currentTimeMillis()
            if (lastTickAt > 0 && now > lastTickAt) {
                Prefs.addUsedTodayMs(this, now - lastTickAt)
            }
            lastTickAt = now
            Prefs.setSessionLastTick(this, now)
        }

        // Re-derive focus from the active window in case events stopped arriving.
        val activePackage = rootInActiveWindow?.packageName?.toString()
        val tikTokFocusedNow = activePackage == TIKTOK_PACKAGE
        if (tikTokFocusedNow != inTikTok) {
            markFocused(tikTokFocusedNow)
        }

        updateBlockUi()
    }

    // ------------------------------------------------------------------- blocking

    private fun blocked(): Boolean {
        if (!Prefs.isLevel1(this)) return false
        val used = Prefs.getUsedTodayMs(this)
        val quota = Prefs.getQuotaMinutes(this) * 60_000L
        return quota > 0 && used >= quota
    }

    private fun updateBlockUi() {
        if (blocked() && inTikTok) {
            overlay.show()
            if (!overlay.isShowing) {
                // Overlay unavailable (e.g. permission missing): fall back to press-back only.
                Log.d(TAG, "Overlay not shown, pressing back")
            }
            performGlobalAction(GLOBAL_ACTION_BACK)
        } else {
            overlay.dismiss()
        }
    }
}