package com.taezeem.spotify_newpipe.spotify_newpipe

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.widget.RemoteViews

class SineMusicWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_UPDATE_WIDGET = "com.taezeem.spotify_newpipe.ACTION_UPDATE_WIDGET"
        const val ACTION_WIDGET_PLAY_PAUSE = "com.taezeem.spotify_newpipe.ACTION_WIDGET_PLAY_PAUSE"
        const val ACTION_WIDGET_NEXT = "com.taezeem.spotify_newpipe.ACTION_WIDGET_NEXT"
        const val ACTION_WIDGET_PREV = "com.taezeem.spotify_newpipe.ACTION_WIDGET_PREV"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_ARTIST = "extra_artist"
        const val EXTRA_IS_PLAYING = "extra_is_playing"

        private const val PREFS_NAME = "sine_widget_prefs"
        private const val KEY_TITLE = "widget_title"
        private const val KEY_ARTIST = "widget_artist"
        private const val KEY_PLAYING = "widget_playing"

        fun updateAllWidgets(context: Context, title: String?, artist: String?, isPlaying: Boolean) {
            val safeTitle = if (title.isNullOrBlank()) "No Song Playing" else title
            val safeArtist = if (artist.isNullOrBlank()) "Tap to open Sine" else artist

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val prevTitle = prefs.getString(KEY_TITLE, null)
            val prevArtist = prefs.getString(KEY_ARTIST, null)
            val prevPlaying = prefs.getBoolean(KEY_PLAYING, false)

            // Always persist state to SharedPreferences first so any widget added later is immediately hydrated
            prefs.edit()
                .putString(KEY_TITLE, safeTitle)
                .putString(KEY_ARTIST, safeArtist)
                .putBoolean(KEY_PLAYING, isPlaying)
                .apply()

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, SineMusicWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)

            if (allWidgetIds.isEmpty()) {
                return
            }

            // Deduplicate: avoid thrashing Android AppWidgetManager IPC if values are identical
            if (prevTitle == safeTitle && prevArtist == safeArtist && prevPlaying == isPlaying) {
                return
            }

            for (widgetId in allWidgetIds) {
                val views = buildRemoteViews(context, safeTitle, safeArtist, isPlaying)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }

        private fun buildRemoteViews(
            context: Context,
            title: String?,
            artist: String?,
            isPlaying: Boolean
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.sine_music_widget)

            views.setTextViewText(R.id.widget_song_title, title ?: "No Song Playing")
            views.setTextViewText(R.id.widget_song_artist, artist ?: "Tap to open Sine")
            views.setImageViewResource(
                R.id.widget_btn_play,
                if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
            )

            // Open Sine MainActivity on tapping widget body
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_info_container, openAppPendingIntent)

            // Play/Pause Action
            val playIntent = Intent(context, SineMusicWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_PLAY_PAUSE
            }
            val playPendingIntent = PendingIntent.getBroadcast(
                context,
                1,
                playIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_play, playPendingIntent)

            // Next Action
            val nextIntent = Intent(context, SineMusicWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_NEXT
            }
            val nextPendingIntent = PendingIntent.getBroadcast(
                context,
                2,
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_next, nextPendingIntent)

            // Prev Action
            val prevIntent = Intent(context, SineMusicWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_PREV
            }
            val prevPendingIntent = PendingIntent.getBroadcast(
                context,
                3,
                prevIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_prev, prevPendingIntent)

            return views
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val title = prefs.getString(KEY_TITLE, "No Song Playing")
        val artist = prefs.getString(KEY_ARTIST, "Tap to open Sine")
        val isPlaying = prefs.getBoolean(KEY_PLAYING, false)

        for (appWidgetId in appWidgetIds) {
            val views = buildRemoteViews(context, title, artist, isPlaying)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_UPDATE_WIDGET -> {
                val title = intent.getStringExtra(EXTRA_TITLE)
                val artist = intent.getStringExtra(EXTRA_ARTIST)
                val isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, false)
                updateAllWidgets(context, title, artist, isPlaying)
            }
            ACTION_WIDGET_PLAY_PAUSE -> {
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
                // Optimistically toggle icon state immediately in SharedPreferences & RemoteViews
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val currentPlaying = prefs.getBoolean(KEY_PLAYING, false)
                val newPlaying = !currentPlaying
                val title = prefs.getString(KEY_TITLE, "No Song Playing")
                val artist = prefs.getString(KEY_ARTIST, "Tap to open Sine")
                updateAllWidgets(context, title, artist, newPlaying)

                // If no song was ever loaded, launch app so user can choose music
                if (title == "No Song Playing" || title.isNullOrEmpty()) {
                    val openAppIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    }
                    context.startActivity(openAppIntent)
                }
            }
            ACTION_WIDGET_NEXT -> {
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            }
            ACTION_WIDGET_PREV -> {
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            }
        }
    }

    private fun sendMediaKeyEvent(context: Context, keyCode: Int) {
        try {
            // Direct AudioService transport dispatch if available (bypasses Android 12+ background broadcast restrictions)
            try {
                val audioServiceClass = Class.forName("com.ryanheise.audioservice.AudioService")
                val instanceField = audioServiceClass.getDeclaredField("instance")
                instanceField.isAccessible = true
                val audioServiceInstance = instanceField.get(null)
                if (audioServiceInstance != null) {
                    val getMediaSessionMethod = audioServiceClass.getMethod("getMediaSession")
                    val mediaSession = getMediaSessionMethod.invoke(audioServiceInstance)
                    if (mediaSession != null) {
                        val controllerMethod = mediaSession.javaClass.getMethod("getController")
                        val controller = controllerMethod.invoke(mediaSession)
                        if (controller != null) {
                            val transportControlsMethod = controller.javaClass.getMethod("getTransportControls")
                            val transportControls = transportControlsMethod.invoke(controller)
                            if (transportControls != null) {
                                when (keyCode) {
                                    KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                                        val getPlaybackStateMethod = controller.javaClass.getMethod("getPlaybackState")
                                        val playbackState = getPlaybackStateMethod.invoke(controller)
                                        val getStateMethod = playbackState?.javaClass?.getMethod("getState")
                                        val state = getStateMethod?.invoke(playbackState) as? Int ?: 0
                                        // 3 == PlaybackStateCompat.STATE_PLAYING
                                        if (state == 3) {
                                            transportControls.javaClass.getMethod("pause").invoke(transportControls)
                                        } else {
                                            transportControls.javaClass.getMethod("play").invoke(transportControls)
                                        }
                                        return
                                    }
                                    KeyEvent.KEYCODE_MEDIA_NEXT -> {
                                        transportControls.javaClass.getMethod("skipToNext").invoke(transportControls)
                                        return
                                    }
                                    KeyEvent.KEYCODE_MEDIA_PREVIOUS -> {
                                        transportControls.javaClass.getMethod("skipToPrevious").invoke(transportControls)
                                        return
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (_: Throwable) {}

            // Fallback: Explicit component routing for Android 8+ (Oreo through Android 15)
            val component = ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver")

            val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                this.component = component
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
            context.sendOrderedBroadcast(downIntent, null)

            val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                this.component = component
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
            }
            context.sendOrderedBroadcast(upIntent, null)
        } catch (_: Exception) {
            try {
                val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    setPackage(context.packageName)
                    putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
                }
                context.sendBroadcast(downIntent)
            } catch (_: Exception) {}
        }
    }
}
