package com.taezeem.spotify_newpipe.spotify_newpipe

import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.sqrt

class MainActivity : AudioServiceActivity(), SensorEventListener {
    private val WIDGET_CHANNEL = "com.taezeem.spotify_newpipe/widget"
    private val GESTURE_CHANNEL = "com.taezeem.spotify_newpipe/gestures"
    private val STORAGE_CHANNEL = "com.taezeem.spotify_newpipe/storage"

    companion object {
        private const val REQ_SAVE_JSON = 9101
        private const val REQ_PICK_JSON = 9102
    }

    private var gestureChannel: MethodChannel? = null
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null

    private var isShakeToSkipEnabled = false
    private var isFlipToPauseEnabled = false

    private var lastShakeTime = 0L
    private var isFlippedDown = false

    private var pendingSaveContent: String? = null
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Home Screen Widget & Media Opener Channel
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
                        ) { _, _ -> }
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

        // 2. Motion Sensors Gesture Channel (Shake to Skip & Flip to Pause)
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

        // 3. Native Storage & MediaStore Bridge (SAF Export/Import, File Share & Device Audio Query)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryDeviceAudio" -> {
                    Thread {
                        try {
                            val tracks = queryAllDeviceAudioFiles()
                            runOnUiThread { result.success(tracks) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("MEDIASTORE_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "saveDocumentJson" -> {
                    val fileName = call.argument<String>("fileName") ?: "sine_export.json"
                    val content = call.argument<String>("content") ?: ""
                    try {
                        pendingSaveResult?.success(mapOf("saved" to false, "cancelled" to true))
                        pendingSaveContent = content
                        pendingSaveResult = result

                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQ_SAVE_JSON)
                    } catch (e: Exception) {
                        pendingSaveContent = null
                        pendingSaveResult = null
                        result.error("SAF_SAVE_ERROR", e.message, null)
                    }
                }
                "pickDocumentJson" -> {
                    try {
                        pendingPickResult?.success(null)
                        pendingPickResult = result

                        // Use */* with CATEGORY_OPENABLE so OEM file managers (Samsung, Xiaomi, Vivo)
                        // never grey out .json files whose MIME type was indexed as octet-stream/unknown.
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQ_PICK_JSON)
                    } catch (e: Exception) {
                        pendingPickResult = null
                        result.error("SAF_PICK_ERROR", e.message, null)
                    }
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val shareTitle = call.argument<String>("title") ?: "Share Sine JSON"
                    val mimeType = call.argument<String>("mimeType") ?: "application/json"
                    if (!filePath.isNullOrBlank()) {
                        val file = File(filePath)
                        if (file.exists()) {
                            try {
                                val uri = FileProvider.getUriForFile(
                                    context,
                                    "${context.packageName}.fileprovider",
                                    file
                                )
                                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = mimeType
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                val chooser = Intent.createChooser(sendIntent, shareTitle).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(chooser)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SHARE_ERROR", e.message, null)
                            }
                        } else {
                            result.error("FILE_NOT_FOUND", "File does not exist at $filePath", null)
                        }
                    } else {
                        result.error("INVALID_PATH", "filePath is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    }

    private fun resolveDisplayName(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        val name = cursor.getString(idx)
                        if (!name.isNullOrBlank()) return name
                    }
                }
            }
        } catch (_: Exception) {}
        return uri.lastPathSegment ?: "selected_file.json"
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQ_SAVE_JSON) {
            val cb = pendingSaveResult
            val content = pendingSaveContent
            pendingSaveResult = null
            pendingSaveContent = null

            if (cb == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null || content == null) {
                cb.success(mapOf("saved" to false, "cancelled" to true))
                return
            }

            val targetUri = data.data!!
            Thread {
                try {
                    contentResolver.openOutputStream(targetUri, "wt")?.use { out ->
                        out.write(content.toByteArray(Charsets.UTF_8))
                        out.flush()
                    } ?: contentResolver.openOutputStream(targetUri)?.use { out ->
                        out.write(content.toByteArray(Charsets.UTF_8))
                        out.flush()
                    } ?: throw IllegalStateException("Could not open output stream for selected destination")

                    val name = resolveDisplayName(targetUri)
                    runOnUiThread {
                        cb.success(
                            mapOf(
                                "saved" to true,
                                "cancelled" to false,
                                "uri" to targetUri.toString(),
                                "name" to name
                            )
                        )
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        cb.error("SAF_WRITE_FAILED", e.message, null)
                    }
                }
            }.start()
            return
        }

        if (requestCode == REQ_PICK_JSON) {
            val cb = pendingPickResult
            pendingPickResult = null
            if (cb == null) return

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                cb.success(null)
                return
            }

            val pickedUri = data.data!!
            Thread {
                try {
                    val text = contentResolver.openInputStream(pickedUri)?.bufferedReader(Charsets.UTF_8)?.use {
                        it.readText()
                    } ?: throw IllegalStateException("Unable to read selected file")
                    val name = resolveDisplayName(pickedUri)
                    runOnUiThread {
                        cb.success(
                            mapOf(
                                "name" to name,
                                "uri" to pickedUri.toString(),
                                "content" to text
                            )
                        )
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        cb.error("SAF_READ_FAILED", e.message, null)
                    }
                }
            }.start()
            return
        }
    }

    private fun queryAllDeviceAudioFiles(): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        val seenIds = HashSet<Long>()

        val collectionUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        @Suppress("DEPRECATION")
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE
        )

        val sortOrder = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"

        contentResolver.query(collectionUri, projection, null, null, sortOrder)?.use { cursor ->
            val idCol = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val durCol = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
            @Suppress("DEPRECATION")
            val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
            val nameCol = cursor.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
            val sizeCol = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)

            while (cursor.moveToNext()) {
                if (idCol < 0) continue
                val id = cursor.getLong(idCol)
                if (!seenIds.add(id)) continue

                val dataPath = if (dataCol >= 0) (cursor.getString(dataCol) ?: "") else ""
                if (dataPath.startsWith("/system/") || dataPath.contains("/ringtones/", ignoreCase = true) && dataPath.startsWith("/product/")) {
                    continue
                }

                val sizeBytes = if (sizeCol >= 0) cursor.getLong(sizeCol) else 0L
                val durationMs = if (durCol >= 0) cursor.getLong(durCol) else 0L

                // Skip tiny UI click / notification sound effects (< 4s) or empty 0-byte stubs
                if (durationMs in 1..3999) continue
                if (durationMs <= 0L && sizeBytes in 1..24576) continue

                val displayName = if (nameCol >= 0) (cursor.getString(nameCol) ?: "") else ""
                val rawTitle = if (titleCol >= 0) (cursor.getString(titleCol) ?: "") else ""
                val rawArtist = if (artistCol >= 0) (cursor.getString(artistCol) ?: "") else ""
                val rawAlbum = if (albumCol >= 0) (cursor.getString(albumCol) ?: "") else ""

                val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id).toString()

                results.add(
                    mapOf(
                        "id" to "media_$id",
                        "title" to rawTitle,
                        "artist" to rawArtist,
                        "album" to rawAlbum,
                        "displayName" to displayName,
                        "durationMs" to durationMs,
                        "sizeBytes" to sizeBytes,
                        "filePath" to dataPath,
                        "contentUri" to contentUri
                    )
                )
            }
        }

        return results
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
            if (z < -8.2f && !isFlippedDown) {
                isFlippedDown = true
                runOnUiThread {
                    gestureChannel?.invokeMethod("onFlipDown", null)
                }
            } else if (z > 6.0f && isFlippedDown) {
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
