package com.example.munib

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidgetSmall : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_small)
            val nextPrayer = widgetData.getString("next_prayer", "") ?: ""

            if (nextPrayer.isEmpty() || nextPrayer == "---") {
                views.setViewVisibility(R.id.widget_active_layout, View.GONE)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_active_layout, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty_layout, View.GONE)
                
                views.setTextViewText(R.id.widget_next_prayer, nextPrayer)
                views.setTextViewText(R.id.widget_time_left, widgetData.getString("time_left", "00:00"))
                views.setTextViewText(R.id.widget_current_time, widgetData.getString("current_time", "00:00"))

                // Dynamic background update
                val bgRes = when (nextPrayer.lowercase()) {
                    "fajr", "sunrise" -> R.drawable.widget_bg_fajr
                    "dhuhr", "asr" -> R.drawable.widget_bg_dhuhr
                    "maghrib" -> R.drawable.widget_bg_maghrib
                    else -> R.drawable.widget_bg_isha
                }
                try {
                    views.setInt(R.id.widget_root, "setBackgroundResource", bgRes)
                } catch (e: Exception) {}
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
