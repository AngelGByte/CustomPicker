package com.mypocket.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONException

class CalendarHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val events = try {
            JSONArray(widgetData.getString("agendaEvents", "[]"))
        } catch (error: JSONException) {
            Log.e("CalendarHomeWidget", "Could not read the shared agenda data.", error)
            JSONArray()
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.calendar_widget)
            val launchIntent =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.calendar_widget_root, launchIntent)
            views.setTextViewText(R.id.calendar_widget_title, "Agenda MyPocket")

            val visibleCount = minOf(events.length(), 3)
            views.setViewVisibility(
                R.id.calendar_widget_empty,
                if (visibleCount == 0) android.view.View.VISIBLE else android.view.View.GONE,
            )
            for (index in 0 until 3) {
                val rowId = rowIds[index]
                if (index >= visibleCount) {
                    views.setViewVisibility(rowId.container, android.view.View.GONE)
                    continue
                }
                val event = events.getJSONObject(index)
                views.setViewVisibility(rowId.container, android.view.View.VISIBLE)
                views.setTextViewText(
                    rowId.dateTime,
                    "${event.optString("day")} · ${event.optString("time")}",
                )
                views.setTextViewText(rowId.title, event.optString("title"))
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private data class EventRowIds(
        val container: Int,
        val dateTime: Int,
        val title: Int,
    )

    private val rowIds = listOf(
        EventRowIds(R.id.calendar_event_1, R.id.calendar_event_1_time, R.id.calendar_event_1_title),
        EventRowIds(R.id.calendar_event_2, R.id.calendar_event_2_time, R.id.calendar_event_2_title),
        EventRowIds(R.id.calendar_event_3, R.id.calendar_event_3_time, R.id.calendar_event_3_title),
    )
}
