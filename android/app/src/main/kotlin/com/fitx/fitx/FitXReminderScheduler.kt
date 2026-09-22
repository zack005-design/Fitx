package com.fitx.fitx

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.time.ZoneId
import java.time.LocalDate
import java.time.ZonedDateTime

/** Owns durable local-time schedules; no Flutter process is needed for delivery. */
class FitXReminderScheduler(private val context: Context) {
    private val preferences = context.getSharedPreferences("fitx_reminders", Context.MODE_PRIVATE)
    private val alarms = context.getSystemService(AlarmManager::class.java)
    private val notifications = context.getSystemService(NotificationManager::class.java)

    init {
        notifications.createNotificationChannel(NotificationChannel(
            CHANNEL_ID, "FitX reminders", NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { description = "Optional local FitX reminders" })
    }

    private fun read(): List<JSONObject> {
        val array = JSONArray(preferences.getString("schedules", "[]"))
        return (0 until array.length()).map { array.getJSONObject(it) }
    }

    private fun save(items: List<JSONObject>) {
        check(preferences.edit().putString("schedules", JSONArray(items).toString()).commit()) {
            "Unable to save reminders"
        }
    }

    fun notificationsEnabled(): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled() &&
            notifications.getNotificationChannel(CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE

    private fun pending(id: Int): PendingIntent = PendingIntent.getBroadcast(
        context, id, Intent(context, FitXReminderReceiver::class.java)
            .setAction(ACTION_DELIVER).putExtra("id", id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun update(replaceIds: List<Int>, replacements: List<Map<*, *>>) {
        require(replaceIds.all { it in REMINDER_IDS })
        val additions = replacements.map { entry ->
            val id = (entry["id"] as Number).toInt()
            val hour = (entry["hour"] as Number).toInt()
            val minute = (entry["minute"] as Number).toInt()
            require(id in replaceIds && hour in 0..23 && minute in 0..59)
            JSONObject().put("id", id).put("hour", hour).put("minute", minute)
                .put("title", entry["title"] as String).put("body", entry["body"] as String)
                .put("precise", entry["precise"] as Boolean)
                .put("smart", entry["smart"] as? Boolean ?: false)
                .put("final", entry["final"] as? Boolean ?: false)
        }
        require(additions.map { it.getInt("id") }.distinct().size == additions.size)
        val items = read().filterNot { it.getInt("id") in replaceIds } + additions
        save(items)
        replaceIds.forEach { alarms.cancel(pending(it)); notifications.cancel(it) }
        reconcile()
    }

    fun reconcile() {
        val enabled = notificationsEnabled()
        val items = read()
        for (item in items) {
            if (enabled) {
                schedule(item)
            } else {
                alarms.cancel(pending(item.getInt("id")))
                item.remove("nextEpochMillis")
                item.put("mode", "blocked")
            }
        }
        save(items)
    }

    private fun schedule(item: JSONObject) {
        val next = ReminderTime.next(item.getInt("hour"), item.getInt("minute"), ZonedDateTime.now())
        val timestamp = next.toInstant().toEpochMilli()
        val operation = pending(item.getInt("id"))
        var exact = item.getBoolean("precise") && alarms.canScheduleExactAlarms()
        if (exact) {
            try {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestamp, operation)
            } catch (_: SecurityException) {
                // Access can change between checking and setting the alarm.
                exact = false
            }
        }
        if (!exact) alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestamp, operation)
        item.put("nextEpochMillis", timestamp).put("timeZone", next.zone.id)
            .put("mode", if (exact) "exact" else "approximate")
    }

    fun deliver(id: Int) {
        val items = read()
        val item = items.firstOrNull { it.getInt("id") == id } ?: return
        try {
            if (notificationsEnabled() && shouldDeliver(item)) {
                val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                val tap = launch?.let {
                    PendingIntent.getActivity(context, id, it,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                }
                notifications.notify(id, NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_notification)
                    .setContentTitle(item.getString("title"))
                    .setContentText(item.getString("body"))
                    .setStyle(NotificationCompat.BigTextStyle().bigText(item.getString("body")))
                    .setContentIntent(tap).setAutoCancel(true)
                    .setPriority(NotificationCompat.PRIORITY_HIGH).build())
                if (item.optBoolean("smart")) {
                    preferences.edit().putString("smart_alarm_fired", LocalDate.now().toString()).apply()
                }
            }
        } catch (error: SecurityException) {
            Log.w("FitXReminders", "Notification permission changed during delivery", error)
        } finally {
            // Re-read permission and calculate tomorrow from the calendar, not +24h.
            reconcile()
        }
    }

    private fun shouldDeliver(item: JSONObject): Boolean {
        if (!item.optBoolean("smart")) return true
        val today = LocalDate.now().toString()
        if (preferences.getString("smart_alarm_fired", null) == today) return false
        if (item.optBoolean("final")) return true
        val sleep = context.getSharedPreferences("fitx_phone_sleep", Context.MODE_PRIVATE)
        if (!sleep.getBoolean("tracking", false)) return false
        val epochs = JSONArray(sleep.getString("epochs", "[]"))
        if (epochs.length() == 0) return false
        val recent = epochs.getJSONObject(epochs.length() - 1)
        val age = System.currentTimeMillis() - recent.optLong("startMs", 0)
        if (age !in 0..120_000) return false
        return recent.optDouble("accelerationRms", 0.0) >= 0.035 ||
            recent.optDouble("gyroscopeRms", 0.0) >= 0.025
    }

    fun status(): Map<String, Any> = mapOf(
        "notificationsEnabled" to notificationsEnabled(),
        "exactAlarmsAllowed" to alarms.canScheduleExactAlarms(),
        "timeZone" to ZoneId.systemDefault().id,
        "reminders" to read().map { item ->
            item.keys().asSequence().associateWith { key -> item.get(key) }
        },
    )

    companion object {
        const val CHANNEL_ID = "fitx_main"
        const val ACTION_DELIVER = "com.fitx.fitx.DELIVER_REMINDER"
        val REMINDER_IDS = listOf(1, 2, 3) + (10..22) + (100..123)

        fun attach(context: Context, messenger: BinaryMessenger) {
            MethodChannel(messenger, "fitx/reminders").setMethodCallHandler { call, result ->
                try {
                    val scheduler = FitXReminderScheduler(context)
                    when (call.method) {
                        "status" -> result.success(scheduler.status())
                        "reconcile" -> { scheduler.reconcile(); result.success(scheduler.status()) }
                        "update" -> {
                            scheduler.update(call.argument<List<Int>>("replaceIds")!!,
                                call.argument<List<Map<*, *>>>("reminders")!!)
                            result.success(scheduler.status())
                        }
                        "openNotificationSettings" -> {
                            context.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("reminder_error", error.message, null)
                }
            }
        }
    }
}

class FitXReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val scheduler = FitXReminderScheduler(context)
            when (intent.action) {
                FitXReminderScheduler.ACTION_DELIVER -> scheduler.deliver(intent.getIntExtra("id", -1))
                Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_TIME_CHANGED,
                AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> scheduler.reconcile()
            }
        } catch (error: Exception) {
            Log.e("FitXReminders", "Unable to restore reminders; retry on app resume", error)
        }
    }
}
