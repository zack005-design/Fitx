package com.fitx.fitx

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.sqrt

class SleepTrackingService : Service(), SensorEventListener {
    private lateinit var sensors: SensorManager
    private var epochStartMs = 0L
    private var accelSquares = 0.0
    private var accelCount = 0
    private var gyroSquares = 0.0
    private var gyroCount = 0
    private var luxSum = 0.0
    private var luxCount = 0
    private val gravity = DoubleArray(3)

    override fun onCreate() {
        super.onCreate()
        current = this
        sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finish()
            return START_NOT_STICKY
        }
        startForeground(NOTIFICATION_ID, notification())
        val prefs = prefs(this)
        if (!prefs.getBoolean(KEY_TRACKING, false)) {
            prefs.edit()
                .putBoolean(KEY_TRACKING, true)
                .putLong(KEY_STARTED, System.currentTimeMillis())
                .putString(KEY_EPOCHS, "[]")
                .apply()
        }
        epochStartMs = (System.currentTimeMillis() / EPOCH_MS) * EPOCH_MS
        registerSensors()
        return START_STICKY
    }

    private fun registerSensors() {
        sensors.unregisterListener(this)
        sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
            sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE)?.let {
            sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        sensors.getDefaultSensor(Sensor.TYPE_LIGHT)?.let {
            sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        val now = System.currentTimeMillis()
        if (epochStartMs == 0L) epochStartMs = (now / EPOCH_MS) * EPOCH_MS
        if (now >= epochStartMs + EPOCH_MS) {
            flushEpoch()
            epochStartMs = (now / EPOCH_MS) * EPOCH_MS
        }
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                var square = 0.0
                for (i in 0..2) {
                    gravity[i] = .9 * gravity[i] + .1 * event.values[i]
                    val linear = event.values[i] - gravity[i]
                    square += linear * linear
                }
                accelSquares += square
                accelCount++
            }
            Sensor.TYPE_GYROSCOPE -> {
                gyroSquares += event.values.fold(0.0) { sum, value ->
                    sum + (value * value).toDouble()
                }
                gyroCount++
            }
            Sensor.TYPE_LIGHT -> {
                luxSum += event.values.firstOrNull()?.toDouble() ?: 0.0
                luxCount++
            }
        }
    }

    private fun flushEpoch() {
        if (accelCount == 0) return
        val item = JSONObject()
            .put("startMs", epochStartMs)
            .put("durationSeconds", 30)
            .put("accelerationRms", sqrt(accelSquares / accelCount))
            .put("gyroscopeRms", if (gyroCount == 0) 0.0 else sqrt(gyroSquares / gyroCount))
            .put("averageLux", if (luxCount == 0) -1.0 else luxSum / luxCount)
            .put("accelerometerSamples", accelCount)
            .put("gyroscopeSamples", gyroCount)
        val preferences = prefs(this)
        val epochs = JSONArray(preferences.getString(KEY_EPOCHS, "[]"))
        epochs.put(item)
        // Sixteen hours at 30-second resolution is the maximum valid session.
        val trimmed = if (epochs.length() <= MAX_EPOCHS) epochs else JSONArray().also { result ->
            for (i in epochs.length() - MAX_EPOCHS until epochs.length()) result.put(epochs.get(i))
        }
        preferences.edit().putString(KEY_EPOCHS, trimmed.toString()).apply()
        accelSquares = 0.0
        accelCount = 0
        gyroSquares = 0.0
        gyroCount = 0
        luxSum = 0.0
        luxCount = 0
    }

    fun finish(): Map<String, Any?> {
        flushEpoch()
        sensors.unregisterListener(this)
        prefs(this).edit().putBoolean(KEY_TRACKING, false).apply()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        current = null
        return state(this)
    }

    override fun onDestroy() {
        sensors.unregisterListener(this)
        current = null
        super.onDestroy()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(
            CHANNEL_ID,
            "Sleep tracking",
            NotificationManager.IMPORTANCE_LOW,
        ))
    }

    private fun notification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_notification)
        .setContentTitle("FitX is estimating sleep")
        .setContentText("Phone motion is being summarized locally. Tap FitX when you wake up.")
        .setOngoing(true)
        .setContentIntent(PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        ))
        .build()

    companion object {
        private const val ACTION_START = "com.fitx.fitx.START_SLEEP"
        private const val ACTION_STOP = "com.fitx.fitx.STOP_SLEEP"
        private const val CHANNEL_ID = "fitx_sleep_tracking"
        private const val NOTIFICATION_ID = 4012
        private const val PREFS = "fitx_phone_sleep"
        private const val KEY_TRACKING = "tracking"
        private const val KEY_STARTED = "started_at"
        private const val KEY_EPOCHS = "epochs"
        private const val EPOCH_MS = 30_000L
        private const val MAX_EPOCHS = 1_920
        @Volatile private var current: SleepTrackingService? = null

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun start(context: Context): Map<String, Any?> {
            prefs(context).edit()
                .putBoolean(KEY_TRACKING, true)
                .putLong(KEY_STARTED, System.currentTimeMillis())
                .putString(KEY_EPOCHS, "[]")
                .apply()
            val intent = Intent(context, SleepTrackingService::class.java).setAction(ACTION_START)
            context.startForegroundService(intent)
            return state(context, forceTracking = true)
        }

        fun stop(context: Context): Map<String, Any?> =
            current?.finish() ?: run {
                context.stopService(Intent(context, SleepTrackingService::class.java).setAction(ACTION_STOP))
                prefs(context).edit().putBoolean(KEY_TRACKING, false).apply()
                state(context)
            }

        fun state(context: Context, forceTracking: Boolean? = null): Map<String, Any?> {
            val preferences = prefs(context)
            val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            val array = JSONArray(preferences.getString(KEY_EPOCHS, "[]"))
            val epochs = ArrayList<Map<String, Any?>>(array.length())
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                epochs.add(mapOf(
                    "startMs" to item.getLong("startMs"),
                    "durationSeconds" to item.optInt("durationSeconds", 30),
                    "accelerationRms" to item.optDouble("accelerationRms", 0.0),
                    "gyroscopeRms" to item.optDouble("gyroscopeRms", 0.0),
                    "averageLux" to item.optDouble("averageLux", -1.0),
                    "accelerometerSamples" to item.optInt("accelerometerSamples", 0),
                    "gyroscopeSamples" to item.optInt("gyroscopeSamples", 0),
                ))
            }
            val started = preferences.getLong(KEY_STARTED, 0L)
            return mapOf(
                "isTracking" to (forceTracking ?: preferences.getBoolean(KEY_TRACKING, false)),
                "startedAtMs" to if (started > 0) started else null,
                "epochs" to epochs,
                "hasAccelerometer" to (manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                "hasGyroscope" to (manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null),
                "hasLightSensor" to (manager.getDefaultSensor(Sensor.TYPE_LIGHT) != null),
            )
        }
    }
}
