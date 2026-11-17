package com.taezeem.spotify_newpipe.spotify_newpipe

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.MediaScannerConnection
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.sqrt

class MainActivity : AudioServiceActivity(), SensorEventListener {
    private val WIDGET_CHANNEL = "com.taezeem.spotify_newpipe/widget"
    private val GESTURE_CHANNEL = "com.taezeem.spotify_newpipe/gestures"

    private var gestureChannel: MethodChannel? = null
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null

    private var isShakeToSkipEnabled = false
    private var isFlipToPauseEnabled = false

    private var lastShakeTime = 0L
    private var isFlippedDown = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Home Screen Widget Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val artworkUrl = call.argument<String>("artworkUrl")

                    SineMusicWidgetProvider.updateAllWidgets(context, title, artist, isPlaying, artworkUrl)
                    result.success(true)
                }
                "openVideo" -> {
                    val filePath = call.argument<String>("filePath")
                    if (!filePath.isNullOrBlank()) {
                        val file = File(filePath)
                        if (file.exists()) {
                            try {
                                val uri = FileProvider.getUriForFile(
                                    context,
                                    "${context.packageName}.fileprovider",
                                    file
                                )
                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "video/*")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                val chooser = Intent.createChooser(intent, "Play Video with").apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(chooser)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("OPEN_ERROR", e.message, null)
                            }
                        } else {
                            result.error("FILE_NOT_FOUND", "Video file does not exist at: $filePath", null)
                        }
                    } else {
                        result.error("INVALID_PATH", "filePath argument is missing", null)
                    }
                }
                "scanMediaFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (!filePath.isNullOrBlank()) {
                        MediaScannerConnection.scanFile(
                            context,
                            arrayOf(filePath),
                            null
                        ) { path, uri -> }
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "filePath argument is missing", null)
                    }
                }
                "openImage" -> {
                    val filePath = call.argument<String>("filePath")
                    if (!filePath.isNullOrBlank()) {
                        val file = File(filePath)
                        if (file.exists()) {
                            try {
                                val uri = FileProvider.getUriForFile(
                                    context,
                                    "${context.packageName}.fileprovider",
                                    file
                                )
                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "image/*")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                val chooser = Intent.createChooser(intent, "View Image with").apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(chooser)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("OPEN_ERROR", e.message, null)
                            }
                        } else {
                            result.error("FILE_NOT_FOUND", "Image file does not exist at: $filePath", null)
                        }
                    } else {
                        result.error("INVALID_PATH", "filePath argument is missing", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 2. Motion Sensors Gesture Channel (Feature 13: Shake to Skip & Flip to Pause)
        gestureChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GESTURE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setShakeToSkipEnabled" -> {
                        isShakeToSkipEnabled = call.argument<Boolean>("enabled") ?: false
                        syncSensorListener()
                        result.success(true)
                    }
                    "setFlipToPauseEnabled" -> {
                        isFlipToPauseEnabled = call.argument<Boolean>("enabled") ?: false
                        syncSensorListener()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    }

    private fun syncSensorListener() {
        val needsSensor = isShakeToSkipEnabled || isFlipToPauseEnabled
        if (needsSensor) {
            accelerometer?.let {
                sensorManager?.unregisterListener(this)
                sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
            }
        } else {
            sensorManager?.unregisterListener(this)
        }
    }

    override fun onResume() {
        super.onResume()
        if (isShakeToSkipEnabled || isFlipToPauseEnabled) {
            syncSensorListener()
        }
    }

    override fun onPause() {
        super.onPause()
        // If gestures are enabled, keep or pause depending on need.
        // For battery saving, unregister unless flip to pause is explicitly active
        if (!isFlipToPauseEnabled && !isShakeToSkipEnabled) {
            sensorManager?.unregisterListener(this)
        }
    }

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        val now = System.currentTimeMillis()

        // 1. Shake Detection
        if (isShakeToSkipEnabled) {
            val gForce = sqrt((x * x + y * y + z * z).toDouble()) - SensorManager.GRAVITY_EARTH
            if (gForce > 12.0 && now - lastShakeTime > 1000L) {
                lastShakeTime = now
                runOnUiThread {
                    gestureChannel?.invokeMethod("onShakeDetected", null)
                }
            }
        }

        // 2. Flip to Pause / Resume Detection
        if (isFlipToPauseEnabled) {
            // Z-axis pointing downward strongly (face down on table: z approx -9.8 m/s^2)
            if (z < -8.2f && !isFlippedDown) {
                isFlippedDown = true
                runOnUiThread {
                    gestureChannel?.invokeMethod("onFlipDown", null)
                }
            } else if (z > 6.0f && isFlippedDown) {
                // Face back up
                isFlippedDown = false
                runOnUiThread {
                    gestureChannel?.invokeMethod("onFlipUp", null)
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No-op
    }
}
