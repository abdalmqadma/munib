package com.example.munib

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PrayerWidgetUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        PrayerWidgetScheduler.refresh(context)
    }

    companion object {
        const val ACTION_REFRESH = "com.example.munib.PRAYER_WIDGET_REFRESH"
    }
}
