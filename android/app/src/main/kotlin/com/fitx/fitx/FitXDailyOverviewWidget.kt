package com.fitx.fitx

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews

class FitXDailyOverviewWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context, manager, ids)
    }

    companion object {
        private const val preferencesName = "fitx_daily_overview"

        fun update(context: Context, manager: AppWidgetManager? = null, ids: IntArray? = null) {
            val prefs = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.fitx_daily_overview_widget)
            views.setTextViewText(R.id.widget_source, prefs.getString("sourceLabel", "Open FitX to sync"))
            views.setTextViewText(R.id.widget_recovery_value, if (!prefs.contains("sourceLabel") || prefs.getInt("recovery", -1) < 0) "—" else "${prefs.getInt("recovery", -1)}%")
            views.setTextViewText(R.id.widget_sleep_value, if (!prefs.contains("sourceLabel") || prefs.getInt("sleep", -1) < 0) "—" else "${prefs.getInt("sleep", -1)}%")
            views.setTextViewText(R.id.widget_strain_value, if (!prefs.contains("sourceLabel")) "—" else prefs.getString("strain", "—") ?: "—")

            val widgetManager = manager ?: AppWidgetManager.getInstance(context)
            val widgetIds = ids ?: widgetManager.getAppWidgetIds(
                ComponentName(context, FitXDailyOverviewWidget::class.java)
            )
            widgetManager.updateAppWidget(widgetIds, views)
        }

        fun saveAndUpdate(context: Context, recovery: Int, sleep: Int, strain: String, sourceLabel: String) {
            context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE).edit()
                .putInt("recovery", recovery)
                .putInt("sleep", sleep)
                .putString("strain", strain)
                .putString("sourceLabel", sourceLabel)
                .apply()
            update(context)
        }
    }
}
