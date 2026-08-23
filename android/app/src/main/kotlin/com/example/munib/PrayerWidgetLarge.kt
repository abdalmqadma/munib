package com.example.munib

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidgetLarge : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        PrayerWidgetScheduler.refresh(context)
    }
}
