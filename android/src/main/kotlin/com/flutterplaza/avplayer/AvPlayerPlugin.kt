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
import android.content.ComponentCallbacks2
import android.content.res.Configuration
import androidx.media3.common.Tracks
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
import java.net.URL

class AvPlayerPlugin : FlutterPlugin, AvPlayerHostApi, ActivityAware, ComponentCallbacks2 {
    private var binaryMessenger: BinaryMessenger? = null
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
        binaryMessenger = binding.binaryMessenger
        AvPlayerHostApi.setUp(binding.binaryMessenger, this)
        binding.applicationContext.registerComponentCallbacks(this)
    }

    // =========================================================================
    // Lifecycle
    // =========================================================================

    override fun create(source: VideoSourceMessage, callback: (Result<Long>) -> Unit) {
        val binding = flutterPluginBinding
        val ctx = activity ?: binding?.applicationContext
        if (binding == null || ctx == null) {
            callback(Result.failure(FlutterError("NO_CONTEXT", "No Flutter binding or activity available.", null)))
            return
        }

        val url = source.url
        val assetPath = source.assetPath
        val filePath = source.filePath

        // Create texture entry
        val textureEntry = binding.textureRegistry.createSurfaceTexture()
        val textureId = textureEntry.id()

        // Build ExoPlayer
        val trackSelector = DefaultTrackSelector(ctx)
        val player = ExoPlayer.Builder(ctx).setTrackSelector(trackSelector).build()
        val surface = android.view.Surface(textureEntry.surfaceTexture())
        player.setVideoSurface(surface)

        // Build media item based on source type
        val mediaItem = when (source.type) {
            SourceType.NETWORK -> {
                if (url == null) {
                    callback(Result.failure(FlutterError("INVALID_SOURCE", "Network source requires 'url'.", null)))
                    player.release()
                    textureEntry.release()
                    return
                }
                MediaItem.fromUri(url)
            }
            SourceType.ASSET -> {
                if (assetPath == null) {
                    callback(Result.failure(FlutterError("INVALID_SOURCE", "Asset source requires 'assetPath'.", null)))
                    player.release()
                    textureEntry.release()
                    return
                }
                val assetKey = binding.flutterAssets.getAssetFilePathByName(assetPath)
                MediaItem.fromUri("asset:///$assetKey")
            }
            SourceType.FILE -> {
                if (filePath == null) {
                    callback(Result.failure(FlutterError("INVALID_SOURCE", "File source requires 'filePath'.", null)))
                    player.release()
                    textureEntry.release()
                    return
                }
                MediaItem.fromUri(filePath)
            }
        }

        // Set up event channel for this player
        val eventChannel = EventChannel(
            binding.binaryMessenger,
            "$EVENT_CHANNEL_PREFIX/events/$textureId"
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
        instance.trackSelector = trackSelector

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

        callback(Result.success(textureId))
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

    override fun dispose(playerId: Long, callback: (Result<Unit>) -> Unit) {
        disposePlayer(playerId)
        callback(Result.success(Unit))
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

    override fun play(playerId: Long, callback: (Result<Unit>) -> Unit) {
        val instance = getPlayerInstance(playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player $playerId not found.", null)))
            return
        }
        instance.player.play()
        callback(Result.success(Unit))
    }

    override fun pause(playerId: Long, callback: (Result<Unit>) -> Unit) {
        val instance = getPlayerInstance(playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player $playerId not found.", null)))
            return
        }
        instance.player.pause()
        callback(Result.success(Unit))
    }

    override fun seekTo(playerId: Long, positionMs: Long, callback: (Result<Unit>) -> Unit) {
        val instance = getPlayerInstance(playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player $playerId not found.", null)))
            return
        }
        instance.player.seekTo(positionMs)
        callback(Result.success(Unit))
    }

    override fun setPlaybackSpeed(playerId: Long, speed: Double, callback: (Result<Unit>) -> Unit) {
        val instance = getPlayerInstance(playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player $playerId not found.", null)))
            return
        }
        instance.player.playbackParameters = PlaybackParameters(speed.toFloat())
        callback(Result.success(Unit))
    }

    override fun setLooping(playerId: Long, looping: Boolean, callback: (Result<Unit>) -> Unit) {
        val instance = getPlayerInstance(playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player $playerId not found.", null)))
            return
        }
        instance.player.repeatMode = if (looping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
        callback(Result.success(Unit))
    }

    override fun setVolume(playerId: Long, volume: Double, callback: (Result<Unit>) -> Unit) {
        val instance = getPlayerInstance(playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player $playerId not found.", null)))
            return
        }
        instance.player.volume = volume.toFloat().coerceIn(0.0f, 1.0f)
        callback(Result.success(Unit))
    }

    override fun setAbrConfig(request: SetAbrConfigRequest, callback: (Result<Unit>) -> Unit) {
        val instance = getPlayerInstance(request.playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player ${request.playerId} not found.", null)))
            return
        }
        val ts = instance.trackSelector
        if (ts != null) {
            val params = ts.buildUponParameters()
            request.config.maxBitrateBps?.let { params.setMaxVideoBitrate(it.toInt()) }
            request.config.minBitrateBps?.let { params.setMinVideoBitrate(it.toInt()) }
            val maxW = request.config.preferredMaxWidth?.toInt() ?: Int.MAX_VALUE
            val maxH = request.config.preferredMaxHeight?.toInt() ?: Int.MAX_VALUE
            if (request.config.preferredMaxWidth != null || request.config.preferredMaxHeight != null) {
                params.setMaxVideoSize(maxW, maxH)
            }
            ts.setParameters(params)
        }
        callback(Result.success(Unit))
    }

    override fun getDecoderInfo(playerId: Long, callback: (Result<DecoderInfoMessage>) -> Unit) {
        val instance = getPlayerInstance(playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player $playerId not found.", null)))
            return
        }
        try {
            val format = instance.player.videoFormat
            val mimeType = format?.sampleMimeType
            if (mimeType != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val codecList = android.media.MediaCodecList(android.media.MediaCodecList.REGULAR_CODECS)
                val codecInfo = codecList.codecInfos.firstOrNull { info ->
                    !info.isEncoder && info.supportedTypes.any { it.equals(mimeType, ignoreCase = true) }
                }
                if (codecInfo != null) {
                    callback(Result.success(DecoderInfoMessage(
                        isHardwareAccelerated = codecInfo.isHardwareAccelerated,
                        decoderName = codecInfo.name,
                        codec = mimeType,
                    )))
                    return
                }
            }
            callback(Result.success(DecoderInfoMessage(
                isHardwareAccelerated = false,
                decoderName = null,
                codec = mimeType,
            )))
        } catch (e: Exception) {
            callback(Result.success(DecoderInfoMessage(
                isHardwareAccelerated = false,
                decoderName = null,
                codec = null,
            )))
        }
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

    override fun isPipAvailable(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(isPipSupported))
    }

    override fun enterPip(request: EnterPipRequest, callback: (Result<Unit>) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            callback(Result.failure(FlutterError("UNSUPPORTED", "PIP requires Android 8.0+.", null)))
            return
        }
        val act = activity
        if (act == null) {
            callback(Result.failure(FlutterError("NO_ACTIVITY", "Activity not available.", null)))
            return
        }

        val aspectRatioArg = request.aspectRatio
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
        callback(Result.success(Unit))
    }

    override fun exitPip(playerId: Long, callback: (Result<Unit>) -> Unit) {
        // Android doesn't have a programmatic exit PIP, but we can notify state
        players.values.forEach { instance ->
            instance.eventSink.success(mapOf(
                "type" to "pipChanged",
                "isInPipMode" to false,
            ))
        }
        callback(Result.success(Unit))
    }

    // =========================================================================
    // System controls
    // =========================================================================

    override fun setSystemVolume(volume: Double, callback: (Result<Unit>) -> Unit) {
        val audioManager = activity?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager == null) {
            callback(Result.failure(FlutterError("NO_SERVICE", "AudioManager not available.", null)))
            return
        }
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val targetVolume = (volume * maxVolume).toInt().coerceIn(0, maxVolume)
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0)
        callback(Result.success(Unit))
    }

    override fun getSystemVolume(callback: (Result<Double>) -> Unit) {
        val audioManager = activity?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager == null) {
            callback(Result.failure(FlutterError("NO_SERVICE", "AudioManager not available.", null)))
            return
        }
        val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        callback(Result.success(if (max > 0) current.toDouble() / max else 0.0))
    }

    override fun setScreenBrightness(brightness: Double, callback: (Result<Unit>) -> Unit) {
        val act = activity
        if (act == null) {
            callback(Result.failure(FlutterError("NO_ACTIVITY", "Activity not available.", null)))
            return
        }
        val layoutParams = act.window.attributes
        layoutParams.screenBrightness = brightness.toFloat().coerceIn(0.0f, 1.0f)
        act.window.attributes = layoutParams
        callback(Result.success(Unit))
    }

    override fun getScreenBrightness(callback: (Result<Double>) -> Unit) {
        val act = activity
        if (act == null) {
            callback(Result.failure(FlutterError("NO_ACTIVITY", "Activity not available.", null)))
            return
        }
        val brightness = act.window.attributes.screenBrightness
        if (brightness < 0) {
            // System default: read system setting
            try {
                val systemBrightness = Settings.System.getInt(
                    act.contentResolver, Settings.System.SCREEN_BRIGHTNESS
                )
                callback(Result.success(systemBrightness.toDouble() / 255.0))
            } catch (e: Settings.SettingNotFoundException) {
                callback(Result.success(0.5))
            }
        } else {
            callback(Result.success(brightness.toDouble()))
        }
    }

    override fun setWakelock(enabled: Boolean, callback: (Result<Unit>) -> Unit) {
        val act = activity
        if (act == null) {
            callback(Result.failure(FlutterError("NO_ACTIVITY", "Activity not available.", null)))
            return
        }
        if (enabled) {
            act.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            act.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        callback(Result.success(Unit))
    }

    // =========================================================================
    // Media Session & Notification
    // =========================================================================

    override fun setMediaMetadata(request: MediaMetadataRequest, callback: (Result<Unit>) -> Unit) {
        val instance = getPlayerInstance(request.playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player ${request.playerId} not found.", null)))
            return
        }

        val metadata = request.metadata
        instance.metadataTitle = metadata.title
        instance.metadataArtist = metadata.artist
        instance.metadataAlbum = metadata.album
        val artworkUrl = metadata.artworkUrl

        // Update the media session metadata
        val ctx = activity ?: flutterPluginBinding?.applicationContext
        if (ctx != null) {
            ensureMediaSession(instance, ctx)
            updateMediaSessionMetadata(instance, artworkUrl)
            if (instance.notificationEnabled) {
                showMediaNotification(instance, ctx)
            }
        }

        callback(Result.success(Unit))
    }

    override fun setNotificationEnabled(playerId: Long, enabled: Boolean, callback: (Result<Unit>) -> Unit) {
        val instance = getPlayerInstance(playerId)
        if (instance == null) {
            callback(Result.failure(FlutterError("NO_PLAYER", "Player $playerId not found.", null)))
            return
        }
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

        callback(Result.success(Unit))
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

    private fun getPlayerInstance(playerId: Long): PlayerInstance? {
        return players[playerId]
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
        flutterPluginBinding?.applicationContext?.unregisterComponentCallbacks(this)
        val messenger = binaryMessenger
        if (messenger != null) {
            AvPlayerHostApi.setUp(messenger, null)
        }
        binaryMessenger = null
        flutterPluginBinding = null
    }

    // =========================================================================
    // Memory Pressure (ComponentCallbacks2)
    // =========================================================================

    override fun onTrimMemory(level: Int) {
        val pressureLevel = when {
            level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL -> "critical"
            level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW -> "warning"
            else -> return
        }
        players.values.forEach { instance ->
            instance.eventSink.success(mapOf(
                "type" to "memoryPressure",
                "level" to pressureLevel,
            ))
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {}

    override fun onLowMemory() {
        onTrimMemory(ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL)
    }

    companion object {
        private const val EVENT_CHANNEL_PREFIX = "com.flutterplaza.av_player_android"

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
    var trackSelector: DefaultTrackSelector? = null
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
