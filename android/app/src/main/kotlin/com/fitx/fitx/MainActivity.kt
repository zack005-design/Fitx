package com.fitx.fitx

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener, EventChannel.StreamHandler {
    private lateinit var sensorManager: SensorManager
    private var sensorEvents: EventChannel.EventSink? = null
    private var pendingFileResult: MethodChannel.Result? = null
    private var pendingBackupText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FitXReminderScheduler.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitx/android_widget")
            .setMethodCallHandler { call, result ->
                if (call.method != "updateDailyOverview") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val recovery = call.argument<Int>("recovery") ?: -1
                val sleep = call.argument<Int>("sleep") ?: -1
                val strain = call.argument<String>("strain") ?: "—"
                FitXDailyOverviewWidget.saveAndUpdate(this, recovery, sleep, strain, call.argument<String>("sourceLabel") ?: "Open FitX to sync Health Connect")
                result.success(null)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitx/device_sensors")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCapabilities" -> result.success(sensorCapabilities())
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "fitx/device_sensor_events")
            .setStreamHandler(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitx/sleep_tracking")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getState" -> result.success(SleepTrackingService.state(this))
                    "start" -> result.success(SleepTrackingService.start(this))
                    "stop" -> result.success(SleepTrackingService.stop(this))
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitx/data_files")
            .setMethodCallHandler { call, result ->
                if (pendingFileResult != null) {
                    result.error("file_busy", "A document picker is already open.", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "saveText" -> {
                        pendingFileResult = result
                        pendingBackupText = call.argument<String>("content") ?: ""
                        startActivityForResult(
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("suggestedName"))
                            },
                            REQUEST_SAVE_BACKUP,
                        )
                    }
                    "openText" -> {
                        pendingFileResult = result
                        startActivityForResult(
                            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                            },
                            REQUEST_OPEN_BACKUP,
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android; FlutterActivity still forwards picker results here.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_SAVE_BACKUP && requestCode != REQUEST_OPEN_BACKUP) return
        val result = pendingFileResult ?: return
        pendingFileResult = null
        val text = pendingBackupText
        pendingBackupText = null
        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri = data.data!!
        try {
            if (requestCode == REQUEST_SAVE_BACKUP) {
                contentResolver.openOutputStream(uri, "wt")!!.bufferedWriter().use {
                    it.write(text ?: "")
                }
                result.success(true)
            } else {
                val content = contentResolver.openInputStream(uri)!!.bufferedReader().use {
                    it.readText()
                }
                result.success(content)
            }
        } catch (error: Exception) {
            if (requestCode == REQUEST_SAVE_BACKUP) {
                // A failed stream must not leave a truncated file that looks valid.
                runCatching { contentResolver.delete(uri, null, null) }
            }
            result.error("file_error", error.message, null)
        }
    }

    private fun sensorCapabilities(): Map<String, Boolean> = mapOf(
        "stepCounter" to (sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null),
        "stepDetector" to (sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR) != null),
        "accelerometer" to (sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
        "gyroscope" to (sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null),
        "activityRecognitionGranted" to (
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) ==
                PackageManager.PERMISSION_GRANTED
        ),
    )

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sensorEvents = events
        registerSensor(Sensor.TYPE_ACCELEROMETER, SensorManager.SENSOR_DELAY_NORMAL)
        registerSensor(Sensor.TYPE_GYROSCOPE, SensorManager.SENSOR_DELAY_NORMAL)

        val activityGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACTIVITY_RECOGNITION,
        ) == PackageManager.PERMISSION_GRANTED
        if (activityGranted) {
            registerSensor(Sensor.TYPE_STEP_COUNTER, SensorManager.SENSOR_DELAY_NORMAL)
            registerSensor(Sensor.TYPE_STEP_DETECTOR, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    private fun registerSensor(type: Int, delay: Int) {
        sensorManager.getDefaultSensor(type)?.let {
            sensorManager.registerListener(this, it, delay)
        }
    }

    override fun onCancel(arguments: Any?) {
        sensorManager.unregisterListener(this)
        sensorEvents = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val type = when (event.sensor.type) {
            Sensor.TYPE_STEP_COUNTER -> "stepCounter"
            Sensor.TYPE_STEP_DETECTOR -> "stepDetector"
            Sensor.TYPE_ACCELEROMETER -> "accelerometer"
            Sensor.TYPE_GYROSCOPE -> "gyroscope"
            else -> return
        }
        sensorEvents?.success(
            mapOf(
                "type" to type,
                "timestampNanos" to event.timestamp,
                "values" to event.values.map { it.toDouble() },
            ),
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onPause() {
        // Raw motion streams are deliberately foreground-only to protect battery.
        sensorManager.unregisterListener(this)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (sensorEvents != null) {
            onListen(null, sensorEvents)
        }
    }

    companion object {
        private const val REQUEST_SAVE_BACKUP = 7201
        private const val REQUEST_OPEN_BACKUP = 7202
    }
}
