package com.taezeem.spotify_newpipe.spotify_newpipe

import android.content.Intent
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val WIDGET_CHANNEL = "com.taezeem.spotify_newpipe/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false

                    SineMusicWidgetProvider.updateAllWidgets(context, title, artist, isPlaying)
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
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
