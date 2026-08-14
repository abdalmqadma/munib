package com.example.munib

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import com.example.munib.R

class PrayerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget_layout)
            
            val nextPrayer = widgetData.getString("next_prayer", "") ?: ""

            if (nextPrayer.isEmpty() || nextPrayer == "---") {
                // Show Empty State matching your design
                views.setViewVisibility(R.id.widget_active_layout, View.GONE)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
            } else {
                // Show Active State with prayer times
                views.setViewVisibility(R.id.widget_active_layout, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty_layout, View.GONE)

                val currentTime = widgetData.getString("current_time", "--:--") ?: "--:--"
                val timeLeft = widgetData.getString("time_left", "--:--:--") ?: "--:--:--"

                views.setTextViewText(R.id.widget_current_time, currentTime)
                views.setTextViewText(R.id.widget_next_prayer, nextPrayer.uppercase())
                views.setTextViewText(R.id.widget_time_left, timeLeft)

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
