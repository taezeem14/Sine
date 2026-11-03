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
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_TITLE, title ?: "No Song Playing")
                .putString(KEY_ARTIST, artist ?: "Tap to open Sine")
                .putBoolean(KEY_PLAYING, isPlaying)
                .apply()

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, SineMusicWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)

            for (widgetId in allWidgetIds) {
                val views = buildRemoteViews(context, title, artist, isPlaying)
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
            val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                setPackage(context.packageName)
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
            context.sendOrderedBroadcast(downIntent, null)

            val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                setPackage(context.packageName)
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
            }
            context.sendOrderedBroadcast(upIntent, null)
        } catch (_: Exception) {
        }
    }
}
