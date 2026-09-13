package com.example.munib

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PrayerLockWidgetUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        PrayerLockWidgetRenderer.refresh(context)
    }

    companion object {
        const val ACTION_REFRESH = "com.example.munib.PRAYER_LOCK_WIDGET_REFRESH"
    }
}
