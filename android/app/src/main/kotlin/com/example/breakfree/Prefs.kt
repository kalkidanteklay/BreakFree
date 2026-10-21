package com.example.breakfree

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Single source of truth for BreakFree state on the native side.
 * Shared between the Flutter UI (via MethodChannel) and the accessibility service.
 */
object Prefs {
    private const val FILE = "breakfree_prefs"

    const val MODE_OFF = 0
    const val MODE_LEVEL1_TIMER = 1
    const val MODE_LEVEL2_STRICT = 2
    const val MODE_LEVEL3_STRICT = 3

    private const val KEY_MODE = "mode"
    private const val KEY_QUOTA_MIN = "quota_min"
    private const val KEY_USED_TODAY_MS = "used_today_ms"
    private const val KEY_RESET_DATE = "reset_date"
    private const val KEY_SESSION_ACTIVE = "session_active"
    private const val KEY_SESSION_LAST_TICK = "session_last_tick_ms"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    // Clock helpers
    private fun todayKey(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    fun isLevel1(context: Context): Boolean = getMode(context) == MODE_LEVEL1_TIMER

    /**
     * Rolls daily counters over to zero when the stored date is not today.
     * Safe to call on every read/write access point.
     */
    fun applyDailyRollover(context: Context) {
        val p = prefs(context)
        val today = todayKey()
        if (p.getString(KEY_RESET_DATE, today) != today) {
            p.edit()
                .putString(KEY_RESET_DATE, today)
                .putLong(KEY_USED_TODAY_MS, 0L)
                .apply()
        }
    }

    fun getMode(context: Context): Int =
        prefs(context).getInt(KEY_MODE, MODE_OFF)

    fun setMode(context: Context, mode: Int) {
        prefs(context).edit().putInt(KEY_MODE, mode).apply()
    }

    fun getQuotaMinutes(context: Context): Int =
        prefs(context).getInt(KEY_QUOTA_MIN, 30)

    fun setQuotaMinutes(context: Context, minutes: Int) {
        prefs(context).edit().putInt(KEY_QUOTA_MIN, minutes.coerceAtLeast(1)).apply()
    }

    fun getUsedTodayMs(context: Context): Long {
        applyDailyRollover(context)
        return prefs(context).getLong(KEY_USED_TODAY_MS, 0L)
    }

    fun setUsedTodayMs(context: Context, usedMs: Long) {
        applyDailyRollover(context)
        prefs(context).edit().putLong(KEY_USED_TODAY_MS, usedMs).apply()
    }

    fun addUsedTodayMs(context: Context, ms: Long) {
        if (ms <= 0) return
        setUsedTodayMs(context, getUsedTodayMs(context) + ms)
    }

    // Transient session state (only meaningful while TikTok is focused)
    fun isSessionActive(context: Context): Boolean =
        prefs(context).getBoolean(KEY_SESSION_ACTIVE, false)

    fun setSessionActive(context: Context, active: Boolean) {
        prefs(context).edit().putBoolean(KEY_SESSION_ACTIVE, active).apply()
    }

    fun getSessionLastTick(context: Context): Long =
        prefs(context).getLong(KEY_SESSION_LAST_TICK, 0L)

    fun setSessionLastTick(context: Context, tickMs: Long) {
        prefs(context).edit().putLong(KEY_SESSION_LAST_TICK, tickMs).apply()
    }
}