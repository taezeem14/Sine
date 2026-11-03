package com.taezeem.spotify_newpipe.spotify_newpipe

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val WIDGET_CHANNEL = "com.taezeem.spotify_newpipe/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val title = call.argument<String>("title")
                val artist = call.argument<String>("artist")
                val isPlaying = call.argument<Boolean>("isPlaying") ?: false

                SineMusicWidgetProvider.updateAllWidgets(context, title, artist, isPlaying)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
