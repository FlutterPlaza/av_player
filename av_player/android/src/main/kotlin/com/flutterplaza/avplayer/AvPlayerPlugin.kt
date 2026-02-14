package com.flutterplaza.avplayer

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Rational
import android.view.WindowManager
import androidx.annotation.NonNull
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry
import java.net.URL

class AvPlayerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activity: Activity? = null

    // Multi-player support: textureId -> PlayerInstance
    private val players = mutableMapOf<Long, PlayerInstance>()
    private var nextPlayerId = 0L

    private val mainHandler = Handler(Looper.getMainLooper())

    private val pipActionsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.action?.let { action ->
                // Route PIP / notification actions to the active player
                players.values.firstOrNull()?.let { instance ->
                    when (action) {
                        ACTION_PLAY -> {
                            instance.player.play()
                            instance.eventSink.success(mapOf(
                                "type" to "mediaCommand",
                                "command" to "play",
                            ))
                        }
                        ACTION_PAUSE -> {
                            instance.player.pause()
                            instance.eventSink.success(mapOf(
                                "type" to "mediaCommand",
                                "command" to "pause",
                            ))
                        }
                        ACTION_NEXT -> {
                            instance.eventSink.success(mapOf(
                                "type" to "mediaCommand",
                                "command" to "next",
                            ))
                        }
                        ACTION_PREVIOUS -> {
                            instance.eventSink.success(mapOf(
                                "type" to "mediaCommand",
                                "command" to "previous",
                            ))
                        }
                    }
                }
            }
        }
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "create" -> handleCreate(call, result)
            "dispose" -> handleDispose(call, result)
            "play" -> handlePlayerAction(call, result) { it.play() }
            "pause" -> handlePlayerAction(call, result) { it.pause() }
            "seekTo" -> handleSeekTo(call, result)
            "setPlaybackSpeed" -> handleSetPlaybackSpeed(call, result)
            "setLooping" -> handleSetLooping(call, result)
            "setVolume" -> handleSetVolume(call, result)
            "isPipAvailable" -> result.success(isPipSupported)
            "enterPip" -> handleEnterPip(call, result)
            "exitPip" -> handleExitPip(call, result)
            "setSystemVolume" -> handleSetSystemVolume(call, result)
            "getSystemVolume" -> handleGetSystemVolume(result)
            "setScreenBrightness" -> handleSetScreenBrightness(call, result)
            "getScreenBrightness" -> handleGetScreenBrightness(result)
            "setWakelock" -> handleSetWakelock(call, result)
            "setMediaMetadata" -> handleSetMediaMetadata(call, result)
            "setNotificationEnabled" -> handleSetNotificationEnabled(call, result)
            else -> result.notImplemented()
        }
    }

    // =========================================================================
    // Lifecycle
    // =========================================================================

    private fun handleCreate(call: MethodCall, result: Result) {
        val binding = flutterPluginBinding
        val ctx = activity ?: binding?.applicationContext
        if (binding == null || ctx == null) {
            result.error("NO_CONTEXT", "No Flutter binding or activity available.", null)
            return
        }

        val type = call.argument<String>("type") ?: "network"
        val url = call.argument<String>("url")
        val assetPath = call.argument<String>("assetPath")
        val filePath = call.argument<String>("filePath")

        // Create texture entry
        val textureEntry = binding.textureRegistry.createSurfaceTexture()
        val textureId = textureEntry.id()

        // Build ExoPlayer
        val player = ExoPlayer.Builder(ctx).build()
        val surface = android.view.Surface(textureEntry.surfaceTexture())
        player.setVideoSurface(surface)

        // Build media item based on source type
        val mediaItem = when (type) {
            "network" -> {
                if (url == null) {
                    result.error("INVALID_SOURCE", "Network source requires 'url'.", null)
                    player.release()
                    textureEntry.release()
                    return
                }
                MediaItem.fromUri(url)
            }
            "asset" -> {
                if (assetPath == null) {
                    result.error("INVALID_SOURCE", "Asset source requires 'assetPath'.", null)
                    player.release()
                    textureEntry.release()
                    return
                }
                val assetKey = binding.flutterAssets.getAssetFilePathByName(assetPath)
                MediaItem.fromUri("asset:///$assetKey")
            }
            "file" -> {
                if (filePath == null) {
                    result.error("INVALID_SOURCE", "File source requires 'filePath'.", null)
                    player.release()
                    textureEntry.release()
                    return
                }
                MediaItem.fromUri(filePath)
            }
            else -> {
                result.error("INVALID_SOURCE", "Unknown source type: $type", null)
                player.release()
                textureEntry.release()
                return
            }
        }

        // Set up event channel for this player
        val eventChannel = EventChannel(
            binding.binaryMessenger,
            "$CHANNEL/events/$textureId"
        )
        val eventSink = QueuingEventSink()
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink.setDelegate(events)
            }
            override fun onCancel(arguments: Any?) {
                eventSink.setDelegate(null)
            }
        })

        // Store player instance
        val instance = PlayerInstance(
            player = player,
            textureEntry = textureEntry,
            surface = surface,
            eventSink = eventSink,
        )
        players[textureId] = instance

        // Set up player listener
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                val state = when (playbackState) {
                    Player.STATE_IDLE -> "idle"
                    Player.STATE_BUFFERING -> "buffering"
                    Player.STATE_READY -> "ready"
                    Player.STATE_ENDED -> "completed"
                    else -> "idle"
                }
                eventSink.success(mapOf(
                    "type" to "playbackStateChanged",
                    "state" to if (playbackState == Player.STATE_READY && player.playWhenReady) "playing" else state,
                ))
                if (playbackState == Player.STATE_ENDED) {
                    eventSink.success(mapOf("type" to "completed"))
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                eventSink.success(mapOf(
                    "type" to "playbackStateChanged",
                    "state" to if (isPlaying) "playing" else "paused",
                ))
            }

            override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
                if (videoSize.width > 0 && videoSize.height > 0) {
                    eventSink.success(mapOf(
                        "type" to "initialized",
                        "duration" to player.duration.coerceAtLeast(0),
                        "width" to videoSize.width,
                        "height" to videoSize.height,
                        "textureId" to textureId,
                    ))
                }
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                eventSink.success(mapOf(
                    "type" to "error",
                    "message" to (error.message ?: "Unknown playback error"),
                    "code" to error.errorCodeName,
                ))
            }
        })

        // Start position reporting
        startPositionReporting(textureId, instance)

        // Prepare and load
        player.setMediaItem(mediaItem)
        player.prepare()

        result.success(textureId)
    }

    private fun startPositionReporting(textureId: Long, instance: PlayerInstance) {
        val runnable = object : Runnable {
            override fun run() {
                if (players.containsKey(textureId)) {
                    val player = instance.player
                    if (player.isPlaying) {
                        instance.eventSink.success(mapOf(
                            "type" to "positionChanged",
                            "position" to player.currentPosition.coerceAtLeast(0),
                        ))
                        instance.eventSink.success(mapOf(
                            "type" to "bufferingUpdate",
                            "buffered" to player.bufferedPosition.coerceAtLeast(0),
                        ))
                    }
                    mainHandler.postDelayed(this, 200)
                }
            }
        }
        mainHandler.postDelayed(runnable, 200)
    }

    private fun handleDispose(call: MethodCall, result: Result) {
        val playerId = call.argument<Number>("playerId")?.toLong()
        if (playerId == null) {
            result.error("INVALID_ARGS", "playerId is required.", null)
            return
        }
        disposePlayer(playerId)
        result.success(null)
    }

    private fun disposePlayer(playerId: Long) {
        players.remove(playerId)?.let { instance ->
            instance.mediaSession?.release()
            instance.mediaSession = null
            if (instance.notificationEnabled) {
                val ctx = activity ?: flutterPluginBinding?.applicationContext
                if (ctx != null) dismissNotification(ctx)
            }
            instance.player.release()
            instance.surface.release()
            instance.textureEntry.release()
        }
    }

    // =========================================================================
    // Playback
    // =========================================================================

    private fun handlePlayerAction(call: MethodCall, result: Result, action: (ExoPlayer) -> Unit) {
        val instance = getPlayerInstance(call, result) ?: return
        action(instance.player)
        result.success(null)
    }

    private fun handleSeekTo(call: MethodCall, result: Result) {
        val instance = getPlayerInstance(call, result) ?: return
        val position = call.argument<Number>("position")?.toLong() ?: 0L
        instance.player.seekTo(position)
        result.success(null)
    }

    private fun handleSetPlaybackSpeed(call: MethodCall, result: Result) {
        val instance = getPlayerInstance(call, result) ?: return
        val speed = call.argument<Number>("speed")?.toFloat() ?: 1.0f
        instance.player.playbackParameters = PlaybackParameters(speed)
        result.success(null)
    }

    private fun handleSetLooping(call: MethodCall, result: Result) {
        val instance = getPlayerInstance(call, result) ?: return
        val looping = call.argument<Boolean>("looping") ?: false
        instance.player.repeatMode = if (looping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
        result.success(null)
    }

    private fun handleSetVolume(call: MethodCall, result: Result) {
        val instance = getPlayerInstance(call, result) ?: return
        val volume = call.argument<Number>("volume")?.toFloat() ?: 1.0f
        instance.player.volume = volume.coerceIn(0.0f, 1.0f)
        result.success(null)
    }

    // =========================================================================
    // PIP
    // =========================================================================

    private val isPipSupported: Boolean by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            activity?.packageManager?.hasSystemFeature(
                PackageManager.FEATURE_PICTURE_IN_PICTURE
            ) ?: false
        } else {
            false
        }
    }

    private fun handleEnterPip(call: MethodCall, result: Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("UNSUPPORTED", "PIP requires Android 8.0+.", null)
            return
        }
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available.", null)
            return
        }

        val aspectRatioArg = call.argument<Number>("aspectRatio")?.toDouble()
        val rational = if (aspectRatioArg != null && aspectRatioArg > 0) {
            // Convert double aspect ratio to rational (e.g., 1.778 -> 16/9)
            Rational((aspectRatioArg * 1000).toInt(), 1000)
        } else {
            Rational(16, 9)
        }

        val playIntent = createActionPendingIntent(act, ACTION_PLAY)
        val pauseIntent = createActionPendingIntent(act, ACTION_PAUSE)
        val nextIntent = createActionPendingIntent(act, ACTION_NEXT)
        val previousIntent = createActionPendingIntent(act, ACTION_PREVIOUS)

        val playAction = RemoteAction(
            Icon.createWithResource(act, R.drawable.ic_play),
            "Play", "Play Video", playIntent
        )
        val pauseAction = RemoteAction(
            Icon.createWithResource(act, R.drawable.ic_pause),
            "Pause", "Pause Video", pauseIntent
        )
        val nextAction = RemoteAction(
            Icon.createWithResource(act, R.drawable.ic_next),
            "Next", "Next Video", nextIntent
        )
        val previousAction = RemoteAction(
            Icon.createWithResource(act, R.drawable.ic_previous),
            "Previous", "Previous Video", previousIntent
        )

        val builder = PictureInPictureParams.Builder()
            .setActions(listOf(previousAction, playAction, pauseAction, nextAction))
            .setAspectRatio(rational)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(true)
        }

        act.enterPictureInPictureMode(builder.build())

        // Notify all players of PIP state
        players.values.forEach { instance ->
            instance.eventSink.success(mapOf(
                "type" to "pipChanged",
                "isInPipMode" to true,
            ))
        }
        result.success(null)
    }

    private fun handleExitPip(call: MethodCall, result: Result) {
        // Android doesn't have a programmatic exit PIP, but we can notify state
        players.values.forEach { instance ->
            instance.eventSink.success(mapOf(
                "type" to "pipChanged",
                "isInPipMode" to false,
            ))
        }
        result.success(null)
    }

    // =========================================================================
    // System controls
    // =========================================================================

    private fun handleSetSystemVolume(call: MethodCall, result: Result) {
        val volume = call.argument<Number>("volume")?.toDouble() ?: return result.error(
            "INVALID_ARGS", "volume is required.", null
        )
        val audioManager = activity?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager == null) {
            result.error("NO_SERVICE", "AudioManager not available.", null)
            return
        }
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val targetVolume = (volume * maxVolume).toInt().coerceIn(0, maxVolume)
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0)
        result.success(null)
    }

    private fun handleGetSystemVolume(result: Result) {
        val audioManager = activity?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager == null) {
            result.error("NO_SERVICE", "AudioManager not available.", null)
            return
        }
        val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        result.success(if (max > 0) current.toDouble() / max else 0.0)
    }

    private fun handleSetScreenBrightness(call: MethodCall, result: Result) {
        val brightness = call.argument<Number>("brightness")?.toFloat() ?: return result.error(
            "INVALID_ARGS", "brightness is required.", null
        )
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available.", null)
            return
        }
        val layoutParams = act.window.attributes
        layoutParams.screenBrightness = brightness.coerceIn(0.0f, 1.0f)
        act.window.attributes = layoutParams
        result.success(null)
    }

    private fun handleGetScreenBrightness(result: Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available.", null)
            return
        }
        val brightness = act.window.attributes.screenBrightness
        if (brightness < 0) {
            // System default: read system setting
            try {
                val systemBrightness = Settings.System.getInt(
                    act.contentResolver, Settings.System.SCREEN_BRIGHTNESS
                )
                result.success(systemBrightness.toDouble() / 255.0)
            } catch (e: Settings.SettingNotFoundException) {
                result.success(0.5)
            }
        } else {
            result.success(brightness.toDouble())
        }
    }

    private fun handleSetWakelock(call: MethodCall, result: Result) {
        val enabled = call.argument<Boolean>("enabled") ?: return result.error(
            "INVALID_ARGS", "enabled is required.", null
        )
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available.", null)
            return
        }
        if (enabled) {
            act.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            act.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        result.success(null)
    }

    // =========================================================================
    // Media Session & Notification
    // =========================================================================

    private fun handleSetMediaMetadata(call: MethodCall, result: Result) {
        val instance = getPlayerInstance(call, result) ?: return
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("INVALID_ARGS", "Arguments required.", null)
            return
        }

        instance.metadataTitle = args["title"] as? String
        instance.metadataArtist = args["artist"] as? String
        instance.metadataAlbum = args["album"] as? String
        val artworkUrl = args["artworkUrl"] as? String

        // Update the media session metadata
        val ctx = activity ?: flutterPluginBinding?.applicationContext
        if (ctx != null) {
            ensureMediaSession(instance, ctx)
            updateMediaSessionMetadata(instance, artworkUrl)
            if (instance.notificationEnabled) {
                showMediaNotification(instance, ctx)
            }
        }

        result.success(null)
    }

    private fun handleSetNotificationEnabled(call: MethodCall, result: Result) {
        val instance = getPlayerInstance(call, result) ?: return
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("INVALID_ARGS", "Arguments required.", null)
            return
        }
        val enabled = args["enabled"] as? Boolean ?: false
        instance.notificationEnabled = enabled

        val ctx = activity ?: flutterPluginBinding?.applicationContext
        if (ctx != null) {
            if (enabled) {
                ensureMediaSession(instance, ctx)
                updateMediaSessionPlaybackState(instance)
                showMediaNotification(instance, ctx)
            } else {
                dismissNotification(ctx)
                instance.mediaSession?.release()
                instance.mediaSession = null
            }
        }

        result.success(null)
    }

    private fun ensureMediaSession(instance: PlayerInstance, ctx: Context) {
        if (instance.mediaSession != null) return

        val session = MediaSession(ctx, "AVPiP_${System.currentTimeMillis()}")
        session.setCallback(object : MediaSession.Callback() {
            override fun onPlay() {
                instance.player.play()
                instance.eventSink.success(mapOf(
                    "type" to "mediaCommand",
                    "command" to "play",
                ))
            }

            override fun onPause() {
                instance.player.pause()
                instance.eventSink.success(mapOf(
                    "type" to "mediaCommand",
                    "command" to "pause",
                ))
            }

            override fun onSkipToNext() {
                instance.eventSink.success(mapOf(
                    "type" to "mediaCommand",
                    "command" to "next",
                ))
            }

            override fun onSkipToPrevious() {
                instance.eventSink.success(mapOf(
                    "type" to "mediaCommand",
                    "command" to "previous",
                ))
            }

            override fun onSeekTo(pos: Long) {
                instance.player.seekTo(pos)
                instance.eventSink.success(mapOf(
                    "type" to "mediaCommand",
                    "command" to "seekTo",
                    "seekPosition" to pos,
                ))
            }

            override fun onStop() {
                instance.player.pause()
                instance.eventSink.success(mapOf(
                    "type" to "mediaCommand",
                    "command" to "stop",
                ))
            }
        })

        session.isActive = true
        instance.mediaSession = session

        // Attach a listener to auto-update playback state on player changes
        instance.player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                updateMediaSessionPlaybackState(instance)
                val ctx2 = activity ?: flutterPluginBinding?.applicationContext
                if (ctx2 != null && instance.notificationEnabled) {
                    showMediaNotification(instance, ctx2)
                }
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                updateMediaSessionPlaybackState(instance)
            }
        })
    }

    private fun updateMediaSessionMetadata(instance: PlayerInstance, artworkUrl: String?) {
        val session = instance.mediaSession ?: return
        val builder = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, instance.metadataTitle ?: "")
            .putString(MediaMetadata.METADATA_KEY_ARTIST, instance.metadataArtist ?: "")
            .putString(MediaMetadata.METADATA_KEY_ALBUM, instance.metadataAlbum ?: "")
            .putLong(MediaMetadata.METADATA_KEY_DURATION, instance.player.duration.coerceAtLeast(0))

        // If we already have a cached bitmap, use it
        if (instance.artworkBitmap != null) {
            builder.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, instance.artworkBitmap)
        }

        session.setMetadata(builder.build())

        // Load artwork in background if URL changed
        if (artworkUrl != null && artworkUrl != instance.artworkUrl) {
            instance.artworkUrl = artworkUrl
            Thread {
                try {
                    val connection = URL(artworkUrl).openConnection()
                    connection.connectTimeout = 5000
                    connection.readTimeout = 5000
                    val bitmap = BitmapFactory.decodeStream(connection.inputStream)
                    if (bitmap != null) {
                        mainHandler.post {
                            instance.artworkBitmap = bitmap
                            val metaBuilder = MediaMetadata.Builder()
                                .putString(MediaMetadata.METADATA_KEY_TITLE, instance.metadataTitle ?: "")
                                .putString(MediaMetadata.METADATA_KEY_ARTIST, instance.metadataArtist ?: "")
                                .putString(MediaMetadata.METADATA_KEY_ALBUM, instance.metadataAlbum ?: "")
                                .putLong(MediaMetadata.METADATA_KEY_DURATION, instance.player.duration.coerceAtLeast(0))
                                .putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, bitmap)
                            session.setMetadata(metaBuilder.build())

                            val ctx = activity ?: flutterPluginBinding?.applicationContext
                            if (ctx != null && instance.notificationEnabled) {
                                showMediaNotification(instance, ctx)
                            }
                        }
                    }
                } catch (_: Exception) {
                    // Artwork loading failed — not critical
                }
            }.start()
        }
    }

    private fun updateMediaSessionPlaybackState(instance: PlayerInstance) {
        val session = instance.mediaSession ?: return
        val player = instance.player

        val state = when {
            player.isPlaying -> PlaybackState.STATE_PLAYING
            player.playbackState == Player.STATE_BUFFERING -> PlaybackState.STATE_BUFFERING
            player.playbackState == Player.STATE_ENDED -> PlaybackState.STATE_STOPPED
            else -> PlaybackState.STATE_PAUSED
        }

        val actions = PlaybackState.ACTION_PLAY or
                PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_PLAY_PAUSE or
                PlaybackState.ACTION_SEEK_TO or
                PlaybackState.ACTION_SKIP_TO_NEXT or
                PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                PlaybackState.ACTION_STOP

        val playbackState = PlaybackState.Builder()
            .setState(state, player.currentPosition.coerceAtLeast(0), player.playbackParameters.speed)
            .setActions(actions)
            .build()

        session.setPlaybackState(playbackState)
    }

    private fun showMediaNotification(instance: PlayerInstance, ctx: Context) {
        val session = instance.mediaSession ?: return
        val notificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel (API 26+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Media Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows media playback controls"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val isPlaying = instance.player.isPlaying

        // Build notification actions
        val prevAction = Notification.Action.Builder(
            Icon.createWithResource(ctx, android.R.drawable.ic_media_previous),
            "Previous",
            createMediaActionIntent(ctx, ACTION_PREVIOUS)
        ).build()

        val playPauseAction = if (isPlaying) {
            Notification.Action.Builder(
                Icon.createWithResource(ctx, android.R.drawable.ic_media_pause),
                "Pause",
                createMediaActionIntent(ctx, ACTION_PAUSE)
            ).build()
        } else {
            Notification.Action.Builder(
                Icon.createWithResource(ctx, android.R.drawable.ic_media_play),
                "Play",
                createMediaActionIntent(ctx, ACTION_PLAY)
            ).build()
        }

        val nextAction = Notification.Action.Builder(
            Icon.createWithResource(ctx, android.R.drawable.ic_media_next),
            "Next",
            createMediaActionIntent(ctx, ACTION_NEXT)
        ).build()

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(ctx, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(ctx)
        }

        builder.setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(instance.metadataTitle ?: "")
            .setContentText(instance.metadataArtist ?: "")
            .setSubText(instance.metadataAlbum)
            .setOngoing(isPlaying)
            .setStyle(Notification.MediaStyle()
                .setMediaSession(session.sessionToken)
                .setShowActionsInCompactView(0, 1, 2))
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
            .setVisibility(Notification.VISIBILITY_PUBLIC)

        if (instance.artworkBitmap != null) {
            builder.setLargeIcon(instance.artworkBitmap)
        }

        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun dismissNotification(ctx: Context) {
        val notificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }

    private fun createMediaActionIntent(ctx: Context, action: String): PendingIntent {
        val intent = Intent(action)
        return PendingIntent.getBroadcast(
            ctx, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private fun getPlayerInstance(call: MethodCall, result: Result): PlayerInstance? {
        val playerId = call.argument<Number>("playerId")?.toLong()
        if (playerId == null) {
            result.error("INVALID_ARGS", "playerId is required.", null)
            return null
        }
        val instance = players[playerId]
        if (instance == null) {
            result.error("NO_PLAYER", "Player $playerId not found.", null)
            return null
        }
        return instance
    }

    private fun createActionPendingIntent(activity: Activity, action: String): PendingIntent {
        val intent = Intent(action)
        return PendingIntent.getBroadcast(
            activity, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // =========================================================================
    // Activity lifecycle
    // =========================================================================

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        registerPipReceiver()
    }

    override fun onDetachedFromActivity() {
        unregisterPipReceiver()
        players.keys.toList().forEach { disposePlayer(it) }
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        registerPipReceiver()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        unregisterPipReceiver()
        activity = null
    }

    private fun registerPipReceiver() {
        val filter = IntentFilter().apply {
            addAction(ACTION_PLAY)
            addAction(ACTION_PAUSE)
            addAction(ACTION_NEXT)
            addAction(ACTION_PREVIOUS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity?.registerReceiver(pipActionsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity?.registerReceiver(pipActionsReceiver, filter)
        }
    }

    private fun unregisterPipReceiver() {
        try {
            activity?.unregisterReceiver(pipActionsReceiver)
        } catch (_: IllegalArgumentException) {
            // Receiver was not registered
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        flutterPluginBinding = null
    }

    companion object {
        private const val CHANNEL = "com.flutterplaza.av_player_android"

        private const val ACTION_PLAY = "com.flutterplaza.avpip.ACTION_PLAY"
        private const val ACTION_PAUSE = "com.flutterplaza.avpip.ACTION_PAUSE"
        private const val ACTION_NEXT = "com.flutterplaza.avpip.ACTION_NEXT"
        private const val ACTION_PREVIOUS = "com.flutterplaza.avpip.ACTION_PREVIOUS"

        private const val NOTIFICATION_CHANNEL_ID = "av_pip_media_playback"
        private const val NOTIFICATION_ID = 9527
    }
}

// =============================================================================
// Player instance data
// =============================================================================

private class PlayerInstance(
    val player: ExoPlayer,
    val textureEntry: TextureRegistry.SurfaceTextureEntry,
    val surface: android.view.Surface,
    val eventSink: QueuingEventSink,
) {
    var mediaSession: MediaSession? = null
    var notificationEnabled: Boolean = false
    var metadataTitle: String? = null
    var metadataArtist: String? = null
    var metadataAlbum: String? = null
    var artworkUrl: String? = null
    var artworkBitmap: Bitmap? = null
}

// =============================================================================
// Queuing event sink — buffers events if no listener is attached yet
// =============================================================================

private class QueuingEventSink {
    private var delegate: EventChannel.EventSink? = null
    private val queue = mutableListOf<Any>()
    private var done = false

    fun setDelegate(sink: EventChannel.EventSink?) {
        delegate = sink
        if (sink != null) {
            queue.forEach { sink.success(it) }
            queue.clear()
        }
    }

    fun success(event: Any) {
        if (done) return
        val d = delegate
        if (d != null) {
            d.success(event)
        } else {
            queue.add(event)
        }
    }

    fun error(code: String, message: String?, details: Any?) {
        if (done) return
        delegate?.error(code, message, details)
    }

    fun endOfStream() {
        done = true
        delegate?.endOfStream()
    }
}
