package eu.neostream.neo_stream.player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

@UnstableApi
class SurfacePlayerView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    args: Map<String, Any?>
) : PlatformView, MethodChannel.MethodCallHandler, Player.Listener {

    private val player: ExoPlayer
    private val playerView: PlayerView
    private val channel: MethodChannel
    private var isDisposed = false
    private var isPrepared = false
    private var wasPlayingBeforePause = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private val progressIntervalMs = 1000L
    private val progressRunnable = object : Runnable {
        override fun run() {
            if (isDisposed) return
            if (isPrepared && player.isPlaying) {
                channel.invokeMethod("onPosition", player.currentPosition)
                channel.invokeMethod("onDuration", player.duration)
            }
            mainHandler.postDelayed(this, progressIntervalMs)
        }
    }

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onStop(owner: LifecycleOwner) {
            wasPlayingBeforePause = player.playWhenReady
            player.playWhenReady = false
            mainHandler.removeCallbacks(progressRunnable)
        }

        override fun onStart(owner: LifecycleOwner) {
            if (wasPlayingBeforePause) player.playWhenReady = true
            if (isPrepared) mainHandler.post(progressRunnable)
        }
    }
    private var lifecycle: Lifecycle? = null

    init {
        val channelName = args["channelName"] as? String ?: "surface_player_$viewId"

        val renderersFactory = DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)
            .setEnableDecoderFallback(true)

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(15_000, 50_000, 2_500, 5_000)
            .build()

        player = ExoPlayer.Builder(context, renderersFactory)
            .setLoadControl(loadControl)
            .setSeekBackIncrementMs(10_000)
            .setSeekForwardIncrementMs(10_000)
            .build()
        player.addListener(this)

        playerView = PlayerView(context).apply {
            this.player = this@SurfacePlayerView.player
            useController = false
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        }

        channel = MethodChannel(messenger, channelName)
        channel.setMethodCallHandler(this)

        (context as? LifecycleOwner)?.let { owner ->
            lifecycle = owner.lifecycle
            owner.lifecycle.addObserver(lifecycleObserver)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (isDisposed) {
            result.error("DISPOSED", "Player already disposed", null)
            return
        }
        when (call.method) {
            "setUrl" -> {
                val url = call.argument<String>("url") ?: ""
                @Suppress("UNCHECKED_CAST")
                val rawHeaders = call.argument<Map<String, Any>>("headers") ?: emptyMap()
                val headers = rawHeaders.entries.associate { (k, v) -> k to v.toString() }
                setUrl(url, headers)
                result.success(null)
            }
            "play" -> {
                player.play()
                result.success(null)
            }
            "pause" -> {
                player.pause()
                result.success(null)
            }
            "seekTo" -> {
                val pos = call.argument<Number>("position")?.toLong() ?: 0L
                player.seekTo(pos)
                result.success(null)
            }
            "setVolume" -> {
                val vol = (call.argument<Number>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f)
                player.volume = vol
                result.success(null)
            }
            "setRate" -> {
                val rate = (call.argument<Number>("rate") ?: 1.0).toFloat().coerceIn(0.25f, 2.0f)
                player.setPlaybackSpeed(rate)
                result.success(null)
            }
            "showControls" -> {
                playerView.useController = true
                result.success(null)
            }
            "hideControls" -> {
                playerView.useController = false
                result.success(null)
            }
            "getPosition" -> result.success(player.currentPosition)
            "getDuration" -> result.success(player.duration)
            "isPlaying" -> result.success(player.isPlaying)
            "isPrepared" -> result.success(isPrepared)
            "dispose" -> {
                dispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun setUrl(url: String, headers: Map<String, String>) {
        isPrepared = false
        val uri = Uri.parse(url)

        val dsFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(12_000)
            .setReadTimeoutMs(15_000)
            .setUserAgent(
                headers["User-Agent"] ?: "Mozilla/5.0 (Linux; Android 12; Freebox Player Mini 4K) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
            )

        val requestHeaders = headers.toMutableMap()
        if (!requestHeaders.containsKey("User-Agent")) {
            requestHeaders["User-Agent"] = "Mozilla/5.0 (Linux; Android 12; Freebox Player Mini 4K) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
        }
        if (!requestHeaders.containsKey("Accept")) {
            requestHeaders["Accept"] = if (isHls(url)) {
                "application/vnd.apple.mpegurl, application/x-mpegURL, */*"
            } else {
                "*/*"
            }
        }
        dsFactory.setDefaultRequestProperties(requestHeaders)

        val mediaItem = MediaItem.Builder().setUri(uri).build()

        val source = if (isHls(url)) {
            HlsMediaSource.Factory(dsFactory)
                .setAllowChunklessPreparation(true)
                .createMediaSource(mediaItem)
        } else {
            ProgressiveMediaSource.Factory(dsFactory).createMediaSource(mediaItem)
        }

        player.setMediaSource(source)
        player.prepare()
        player.playWhenReady = true
    }

    private fun isHls(url: String): Boolean {
        val u = url.lowercase()
        return u.contains(".m3u8") || u.contains("m3u8") || u.contains("live_proxy")
    }

    override fun onPlaybackStateChanged(state: Int) {
        when (state) {
            Player.STATE_READY -> {
                isPrepared = true
                channel.invokeMethod("onReady", null)
                mainHandler.removeCallbacks(progressRunnable)
                mainHandler.post(progressRunnable)
            }
            Player.STATE_ENDED -> {
                channel.invokeMethod("onCompleted", null)
                mainHandler.removeCallbacks(progressRunnable)
            }
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        channel.invokeMethod("onError", error.localizedMessage ?: "Unknown error")
        mainHandler.removeCallbacks(progressRunnable)
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        channel.invokeMethod("onPlayingChanged", isPlaying)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        if (isDisposed) return
        isDisposed = true
        mainHandler.removeCallbacks(progressRunnable)
        channel.setMethodCallHandler(null)
        player.removeListener(this)
        playerView.player = null
        player.release()
        lifecycle?.removeObserver(lifecycleObserver)
    }
}
