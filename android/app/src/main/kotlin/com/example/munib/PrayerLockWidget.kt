package com.example.munib

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerLockWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        PrayerLockWidgetRenderer.refresh(context)
    }

    override fun onDisabled(context: Context) {
        PrayerLockWidgetRenderer.disable(context)
        super.onDisabled(context)
    }
}
