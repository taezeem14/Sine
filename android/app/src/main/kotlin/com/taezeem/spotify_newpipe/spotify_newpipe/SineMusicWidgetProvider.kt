package com.taezeem.spotify_newpipe.spotify_newpipe

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.widget.RemoteViews
import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class SineMusicWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_UPDATE_WIDGET = "com.taezeem.spotify_newpipe.ACTION_UPDATE_WIDGET"
        const val ACTION_WIDGET_PLAY_PAUSE = "com.taezeem.spotify_newpipe.ACTION_WIDGET_PLAY_PAUSE"
        const val ACTION_WIDGET_NEXT = "com.taezeem.spotify_newpipe.ACTION_WIDGET_NEXT"
        const val ACTION_WIDGET_PREV = "com.taezeem.spotify_newpipe.ACTION_WIDGET_PREV"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_ARTIST = "extra_artist"
        const val EXTRA_IS_PLAYING = "extra_is_playing"
        const val EXTRA_ARTWORK = "extra_artwork"

        private const val PREFS_NAME = "sine_widget_prefs"
        private const val KEY_TITLE = "widget_title"
        private const val KEY_ARTIST = "widget_artist"
        private const val KEY_PLAYING = "widget_playing"
        private const val KEY_ARTWORK = "widget_artwork"

        private val executor = Executors.newSingleThreadExecutor()
        private val mainHandler = Handler(Looper.getMainLooper())
        private var cachedBitmap: Bitmap? = null
        private var cachedArtworkUrl: String? = null

        fun updateAllWidgets(
            context: Context,
            title: String?,
            artist: String?,
            isPlaying: Boolean,
            artworkUrl: String? = null
        ) {
            val appContext = context.applicationContext ?: context
            val safeTitle = if (title.isNullOrBlank()) "No Song Playing" else title
            val safeArtist = if (artist.isNullOrBlank()) "Tap to open Sine" else artist

            val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val prevTitle = prefs.getString(KEY_TITLE, null)
            val prevArtist = prefs.getString(KEY_ARTIST, null)
            val prevPlaying = prefs.getBoolean(KEY_PLAYING, false)
            val prevArtwork = prefs.getString(KEY_ARTWORK, null)

            val safeArtwork = artworkUrl ?: prevArtwork

            if (prevTitle == safeTitle && prevArtist == safeArtist && prevPlaying == isPlaying && prevArtwork == safeArtwork) {
                return
            }

            prefs.edit()
                .putString(KEY_TITLE, safeTitle)
                .putString(KEY_ARTIST, safeArtist)
                .putBoolean(KEY_PLAYING, isPlaying)
                .putString(KEY_ARTWORK, safeArtwork)
                .apply()

            val appWidgetManager = AppWidgetManager.getInstance(appContext)
            val thisWidget = ComponentName(appContext, SineMusicWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)

            if (allWidgetIds.isEmpty()) {
                return
            }

            // Immediately render current state with existing cached bitmap or fallback
            val currentBitmap = if (safeArtwork != null && safeArtwork == cachedArtworkUrl) cachedBitmap else null
            for (widgetId in allWidgetIds) {
                val views = buildRemoteViews(appContext, safeTitle, safeArtist, isPlaying, currentBitmap)
                appWidgetManager.updateAppWidget(widgetId, views)
            }

            // If artwork changed or not cached, load asynchronously
            if (!safeArtwork.isNullOrBlank() && (safeArtwork != cachedArtworkUrl || cachedBitmap == null)) {
                executor.execute {
                    val loadedBitmap = loadArtworkBitmap(appContext, safeArtwork)
                    if (loadedBitmap != null) {
                        cachedArtworkUrl = safeArtwork
                        cachedBitmap = loadedBitmap
                        mainHandler.post {
                            for (widgetId in allWidgetIds) {
                                val views = buildRemoteViews(appContext, safeTitle, safeArtist, isPlaying, loadedBitmap)
                                appWidgetManager.updateAppWidget(widgetId, views)
                            }
                        }
                    }
                }
            } else if (safeArtwork.isNullOrBlank()) {
                cachedArtworkUrl = null
                cachedBitmap = null
            }
        }

        private fun loadArtworkBitmap(context: Context, pathOrUrl: String): Bitmap? {
            try {
                var stream: InputStream? = null
                if (pathOrUrl.startsWith("http://") || pathOrUrl.startsWith("https://")) {
                    val connection = URL(pathOrUrl).openConnection() as HttpURLConnection
                    connection.connectTimeout = 4000
                    connection.readTimeout = 4000
                    connection.doInput = true
                    connection.connect()
                    stream = connection.inputStream
                } else {
                    val file = File(pathOrUrl)
                    if (file.exists()) {
                        stream = file.inputStream()
                    }
                }

                if (stream != null) {
                    val raw = BitmapFactory.decodeStream(stream)
                    stream.close()
                    if (raw != null) {
                        val scaled = Bitmap.createScaledBitmap(raw, 160, 160, true)
                        return getRoundedCornerBitmap(scaled, 28f)
                    }
                }
            } catch (_: Exception) {}
            return null
        }

        private fun getRoundedCornerBitmap(bitmap: Bitmap, pixels: Float): Bitmap {
            val output = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            val color = -0xbdbdbe
            val paint = Paint()
            val rect = Rect(0, 0, bitmap.width, bitmap.height)
            val rectF = RectF(rect)

            paint.isAntiAlias = true
            canvas.drawARGB(0, 0, 0, 0)
            paint.color = color
            canvas.drawRoundRect(rectF, pixels, pixels, paint)

            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            canvas.drawBitmap(bitmap, rect, rect, paint)
            return output
        }

        private fun buildRemoteViews(
            context: Context,
            title: String?,
            artist: String?,
            isPlaying: Boolean,
            artworkBitmap: Bitmap?
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.sine_music_widget)

            views.setTextViewText(R.id.widget_song_title, title ?: "No Song Playing")
            views.setTextViewText(R.id.widget_song_artist, artist ?: "Tap to open Sine")
            views.setImageViewResource(
                R.id.widget_btn_play,
                if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
            )
            views.setProgressBar(
                R.id.widget_progress_bar,
                100,
                if (isPlaying) 45 else 0,
                false
            )

            if (artworkBitmap != null) {
                views.setImageViewBitmap(R.id.widget_album_art, artworkBitmap)
            } else {
                views.setImageViewResource(R.id.widget_album_art, R.drawable.ic_widget_sine)
            }

            val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or (
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }
            )

            // Open Sine MainActivity on tapping widget body
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                pendingFlags
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_info_container, openAppPendingIntent)

            // Play/Pause Action
            if (title == "No Song Playing" || title.isNullOrBlank()) {
                views.setOnClickPendingIntent(R.id.widget_btn_play, openAppPendingIntent)
            } else {
                val playIntent = Intent(context, SineMusicWidgetProvider::class.java).apply {
                    action = ACTION_WIDGET_PLAY_PAUSE
                }
                val playPendingIntent = PendingIntent.getBroadcast(
                    context,
                    1,
                    playIntent,
                    pendingFlags
                )
                views.setOnClickPendingIntent(R.id.widget_btn_play, playPendingIntent)
            }

            // Next Action
            val nextIntent = Intent(context, SineMusicWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_NEXT
            }
            val nextPendingIntent = PendingIntent.getBroadcast(
                context,
                2,
                nextIntent,
                pendingFlags
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
                pendingFlags
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
        val appContext = context.applicationContext ?: context
        val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val title = prefs.getString(KEY_TITLE, "No Song Playing")
        val artist = prefs.getString(KEY_ARTIST, "Tap to open Sine")
        val isPlaying = prefs.getBoolean(KEY_PLAYING, false)
        val artwork = prefs.getString(KEY_ARTWORK, null)

        for (appWidgetId in appWidgetIds) {
            val views = buildRemoteViews(appContext, title, artist, isPlaying, cachedBitmap)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        if (!artwork.isNullOrBlank() && cachedBitmap == null) {
            updateAllWidgets(appContext, title, artist, isPlaying, artwork)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_UPDATE_WIDGET -> {
                val title = intent.getStringExtra(EXTRA_TITLE)
                val artist = intent.getStringExtra(EXTRA_ARTIST)
                val isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, false)
                val artwork = intent.getStringExtra(EXTRA_ARTWORK)
                updateAllWidgets(context, title, artist, isPlaying, artwork)
            }
            ACTION_WIDGET_PLAY_PAUSE -> {
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
                val appContext = context.applicationContext ?: context
                val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val currentPlaying = prefs.getBoolean(KEY_PLAYING, false)
                val newPlaying = !currentPlaying
                val title = prefs.getString(KEY_TITLE, "No Song Playing")
                val artist = prefs.getString(KEY_ARTIST, "Tap to open Sine")
                val artwork = prefs.getString(KEY_ARTWORK, null)
                updateAllWidgets(appContext, title, artist, newPlaying, artwork)

                if (title == "No Song Playing" || title.isNullOrEmpty()) {
                    try {
                        val openAppIntent = Intent(appContext, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        }
                        appContext.startActivity(openAppIntent)
                    } catch (_: Exception) {}
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
        val appContext = context.applicationContext ?: context
        try {
            try {
                val audioServiceClass = Class.forName("com.ryanheise.audioservice.AudioService")
                val instanceField = audioServiceClass.getDeclaredField("instance")
                instanceField.isAccessible = true
                val audioServiceInstance = instanceField.get(null)
                if (audioServiceInstance != null) {
                    val mediaSessionField = audioServiceClass.getDeclaredField("mediaSession")
                    mediaSessionField.isAccessible = true
                    val mediaSession = mediaSessionField.get(audioServiceInstance)
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

            fallbackToMediaButtonReceiver(appContext, keyCode)
        } catch (_: Exception) {}
    }

    private fun fallbackToMediaButtonReceiver(appContext: Context, keyCode: Int) {
        try {
            val component = ComponentName(appContext, "com.ryanheise.audioservice.MediaButtonReceiver")

            val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                this.component = component
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
            appContext.sendOrderedBroadcast(downIntent, null)

            val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                this.component = component
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
            }
            appContext.sendOrderedBroadcast(upIntent, null)
        } catch (_: Exception) {
            try {
                val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    setPackage(appContext.packageName)
                    putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
                }
                appContext.sendBroadcast(downIntent)
            } catch (_: Exception) {}
        }
    }
}
