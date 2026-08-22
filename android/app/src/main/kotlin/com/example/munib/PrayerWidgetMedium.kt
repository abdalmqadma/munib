package com.example.munib

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import com.example.munib.R

class PrayerWidgetMedium : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val dhikrs = arrayOf(
            "سبحان الله وبحمده",
            "أستغفر الله وأتوب إليه",
            "اللهم صل وسلم على نبينا محمد",
            "لا حول ولا قوة إلا بالله",
            "سبحان الله العظيم",
        )

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_medium)
            val nextPrayer = widgetData.getString("next_prayer", "") ?: ""

            if (nextPrayer.isEmpty() || nextPrayer == "---") {
                views.setViewVisibility(R.id.widget_active_layout, View.GONE)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_active_layout, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty_layout, View.GONE)

                views.setTextViewText(R.id.widget_next_prayer, nextPrayer.uppercase())
                views.setTextViewText(
                    R.id.widget_time_left,
                    widgetData.getString("time_left", "00:00:00"),
                )
                views.setTextViewText(
                    R.id.widget_current_time,
                    widgetData.getString("current_time", "--:--"),
                )
                views.setTextViewText(R.id.widget_dhikr, dhikrs.random())

                val nextLower = nextPrayer.lowercase()
                val bgRes = when (nextLower) {
                    "fajr", "sunrise" -> R.drawable.widget_bg_fajr
                    "dhuhr" -> R.drawable.widget_bg_dhuhr
                    "asr" -> R.drawable.widget_bg_asr
                    "maghrib" -> R.drawable.widget_bg_maghrib
                    else -> R.drawable.widget_bg_isha
                }

                val iconRes = when (nextLower) {
                    "fajr", "maghrib", "isha" -> R.drawable.ic_crescent
                    else -> R.drawable.ic_sun
                }

                try {
                    views.setInt(R.id.widget_root, "setBackgroundResource", bgRes)
                    views.setImageViewResource(R.id.widget_bg_icon, iconRes)
                } catch (_: Exception) {
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
