package eu.neostream.neo_stream.player

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.ui.PlayerView

/**
 * Lecteur natif ExoPlayer plein écran — fiable sur Freebox Mini 4K / Android TV.
 *
 * Multi-sources :
 *  - 1 seule tentative par source (pas de retry en boucle sur la même URL)
 *  - bascule immédiate vers la source suivante SANS fermer l'Activity
 *    (évite l'écran noir Flutter entre deux sources)
 *  - échec final seulement quand toutes les sources ont été essayées
 */
@UnstableApi
class NativeVideoActivity : Activity(), Player.Listener {

    private var player: ExoPlayer? = null
    private var playerView: PlayerView? = null
    private var loadingView: ProgressBar? = null
    private var errorView: TextView? = null
    private var sourceLabelView: TextView? = null

    private var streamUrls: List<String> = emptyList()
    private var sourceIndex: Int = 0
    private var isLive: Boolean = false
    private var headers: Map<String, String> = emptyMap()
    /** Headers par source (index aligné sur [streamUrls]). */
    private var headersList: List<Map<String, String>> = emptyList()
    private var startPosition: Long = 0L
    /** Position à reprendre après bascule de source VOD. */
    private var resumePositionOnSwitch: Long = 0L

    private val mainHandler = Handler(Looper.getMainLooper())
    private var switchRunnable: Runnable? = null
    private var finishRunnable: Runnable? = null
    private var finishedWithError = false
    private var hasPlayedSuccessfully = false
    private var switchingSource = false

    private val streamUrl: String
        get() = if (sourceIndex in streamUrls.indices) streamUrls[sourceIndex] else ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        @Suppress("DEPRECATION")
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)

        streamUrls = readUrls(intent)
        if (streamUrls.isEmpty()) {
            finishWithResult(error = "URL manquante")
            return
        }
        sourceIndex = 0
        isLive = intent.getBooleanExtra(EXTRA_IS_LIVE, detectLive(streamUrls.first()))
        startPosition = intent.getIntExtra(EXTRA_POSITION, 0).toLong().coerceAtLeast(0L)
        headers = readHeaders(intent)
        headersList = readHeadersList(intent)

        val root = FrameLayout(this).apply {
            setBackgroundColor(0xFF000000.toInt())
            keepScreenOn = true
        }

        playerView = PlayerView(this).apply {
            useController = true
            controllerShowTimeoutMs = 4_000
            controllerHideOnTouch = true
            setKeepContentOnPlayerReset(true)
            setShowBuffering(PlayerView.SHOW_BUFFERING_WHEN_PLAYING)
            controllerAutoShow = true
        }
        root.addView(
            playerView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        loadingView = ProgressBar(this).apply {
            isIndeterminate = true
            visibility = View.VISIBLE
        }
        root.addView(
            loadingView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        )

        sourceLabelView = TextView(this).apply {
            setTextColor(0xCCFFFFFF.toInt())
            textSize = 12f
            setPadding(24, 16, 24, 16)
            visibility = if (streamUrls.size > 1) View.VISIBLE else View.GONE
            setBackgroundColor(0x66000000.toInt())
        }
        root.addView(
            sourceLabelView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.END
            ).apply {
                topMargin = 24
                marginEnd = 24
            }
        )

        errorView = TextView(this).apply {
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            visibility = View.GONE
            setBackgroundColor(0xCC000000.toInt())
        }
        root.addView(
            errorView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        setContentView(root)
        updateSourceLabel()
        buildAndStartPlayer()
    }

    private fun updateSourceLabel() {
        sourceLabelView?.text =
            "Source ${sourceIndex + 1}/${streamUrls.size}"
        sourceLabelView?.visibility =
            if (streamUrls.size > 1) View.VISIBLE else View.GONE
    }

    /** Headers pour la source courante (liste par index ou fallback global). */
    private fun currentHeaders(): Map<String, String> {
        if (sourceIndex in headersList.indices && headersList[sourceIndex].isNotEmpty()) {
            return headersList[sourceIndex]
        }
        return headers
    }

    private fun buildAndStartPlayer() {
        switchRunnable?.let { mainHandler.removeCallbacks(it) }
        switchRunnable = null
        finishRunnable?.let { mainHandler.removeCallbacks(it) }
        finishRunnable = null

        // Ne pas release+rebuild si on bascule juste d'URL : réutiliser le player
        // quand possible pour éviter un flash noir trop long sur Freebox.
        val existing = player
        finishedWithError = false
        switchingSource = false
        errorView?.visibility = View.GONE
        loadingView?.visibility = View.VISIBLE
        updateSourceLabel()

        val url = streamUrl
        if (url.isEmpty()) {
            finishWithResult(error = "URL manquante")
            return
        }

        val dsFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(12_000)
            .setReadTimeoutMs(15_000)
            .setUserAgent(
                currentHeaders()["User-Agent"]
                    ?: "Mozilla/5.0 (Linux; Android 12; Freebox Player Mini 4K) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
            )

        val requestHeaders = currentHeaders().toMutableMap()
        if (!requestHeaders.containsKey("User-Agent")) {
            requestHeaders["User-Agent"] =
                "Mozilla/5.0 (Linux; Android 12; Freebox Player Mini 4K) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
        }
        if (!requestHeaders.containsKey("Accept")) {
            requestHeaders["Accept"] = if (isHls(url)) {
                "application/vnd.apple.mpegurl, application/x-mpegURL, */*"
            } else {
                "*/*"
            }
        }
        if (requestHeaders.isNotEmpty()) {
            dsFactory.setDefaultRequestProperties(requestHeaders)
        }

        val p = if (existing != null) {
            existing
        } else {
            val renderersFactory = DefaultRenderersFactory(this)
                .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)
                .setEnableDecoderFallback(true)
                .setEnableAudioFloatOutput(false)

            val loadControl = DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    /* minBufferMs */ if (isLive) 6_000 else 15_000,
                    /* maxBufferMs */ if (isLive) 40_000 else 50_000,
                    /* bufferForPlaybackMs */ if (isLive) 2_000 else 2_500,
                    /* bufferForPlaybackAfterRebufferMs */ if (isLive) 4_000 else 5_000
                )
                .build()

            ExoPlayer.Builder(this, renderersFactory)
                .setMediaSourceFactory(DefaultMediaSourceFactory(dsFactory))
                .setLoadControl(loadControl)
                .setSeekBackIncrementMs(10_000)
                .setSeekForwardIncrementMs(10_000)
                .build()
                .also { created ->
                    created.addListener(this)
                    created.playWhenReady = true
                    created.volume = 1.0f
                    if (isLive) created.setPlaybackSpeed(1.0f)
                    player = created
                    playerView?.player = created
                }
        }

        try {
            // Stop current media before switching source (évite decoder lock Freebox).
            p.stop()
            p.clearMediaItems()

            val uri = Uri.parse(url)
            val mediaItem = MediaItem.Builder()
                .setUri(uri)
                .setLiveConfiguration(
                    MediaItem.LiveConfiguration.Builder()
                        .setMaxPlaybackSpeed(1.02f)
                        .build()
                )
                .build()

            // DataSource headers : rebuild media source with current factory
            val source = when {
                isHls(url) -> HlsMediaSource.Factory(dsFactory)
                    .setAllowChunklessPreparation(true)
                    .createMediaSource(mediaItem)
                else -> ProgressiveMediaSource.Factory(dsFactory)
                    .createMediaSource(mediaItem)
            }

            p.setMediaSource(source)
            // Seek VOD : position initiale ou reprise après bascule source
            if (!isLive) {
                val seekPos = when {
                    sourceIndex == 0 && startPosition > 0L && !hasPlayedSuccessfully ->
                        startPosition
                    resumePositionOnSwitch > 0L -> resumePositionOnSwitch
                    else -> 0L
                }
                if (seekPos > 0L) p.seekTo(seekPos)
            }
            p.prepare()
            p.playWhenReady = true

            // Ré-attacher la vue (évite surface noire après bascule Freebox)
            playerView?.player = null
            playerView?.player = p
            playerView?.requestFocus()
            if (hasPlayedSuccessfully) {
                playerView?.hideController()
            } else {
                playerView?.showController()
            }

            android.util.Log.i(
                TAG,
                "play source ${sourceIndex + 1}/${streamUrls.size} live=$isLive url=${url.take(120)}"
            )
        } catch (e: Exception) {
            android.util.Log.e(TAG, "buildAndStartPlayer failed: ${e.message}", e)
            tryNextSourceOrFail(e.message ?: "prepare_failed")
        }
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        when (playbackState) {
            Player.STATE_BUFFERING -> {
                loadingView?.visibility = View.VISIBLE
                errorView?.visibility = View.GONE
            }
            Player.STATE_READY -> {
                loadingView?.visibility = View.GONE
                errorView?.visibility = View.GONE
                finishedWithError = false
                hasPlayedSuccessfully = true
                switchingSource = false
            }
            Player.STATE_ENDED -> {
                if (isLive) {
                    // Live coupé : bascule source suivante (1 try déjà consommé sur celle-ci)
                    tryNextSourceOrFail("Flux live interrompu")
                } else {
                    finishWithResult(completed = true)
                }
            }
            Player.STATE_IDLE -> { /* no-op */ }
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        val msg = error.localizedMessage ?: error.errorCodeName
        android.util.Log.e(
            TAG,
            "ExoPlayer error source ${sourceIndex + 1}/${streamUrls.size}: $msg",
            error
        )

        if (switchingSource) return

        tryNextSourceOrFail(msg)
    }

    /**
     * Bascule vers la source suivante sans fermer l'Activity.
     * Une seule tentative a déjà été faite sur la source courante.
     */
    private fun tryNextSourceOrFail(reason: String) {
        if (switchingSource || isFinishing) return

        val next = sourceIndex + 1
        if (next < streamUrls.size) {
            // Sauvegarder la position avant bascule (VOD)
            if (!isLive) {
                val pos = player?.currentPosition ?: 0L
                if (pos > 1000L) resumePositionOnSwitch = pos
            }
            switchingSource = true
            val failedIndex = sourceIndex
            sourceIndex = next
            loadingView?.visibility = View.VISIBLE
            errorView?.apply {
                text = "Source ${failedIndex + 1}/${streamUrls.size} HS\nBascule source ${sourceIndex + 1}…"
                visibility = View.VISIBLE
            }
            Toast.makeText(
                this,
                "Source ${failedIndex + 1}/${streamUrls.size} HS → ${sourceIndex + 1}",
                Toast.LENGTH_SHORT
            ).show()

            // Bascule quasi-immédiate (petit délai pour laisser ExoPlayer relâcher le décodeur)
            switchRunnable?.let { mainHandler.removeCallbacks(it) }
            val runnable = Runnable {
                if (!isFinishing) buildAndStartPlayer()
            }
            switchRunnable = runnable
            mainHandler.postDelayed(runnable, 350L)
            return
        }

        // Toutes les sources ont échoué
        finishedWithError = true
        loadingView?.visibility = View.GONE
        errorView?.apply {
            text = "Impossible de lire ce flux.\n$reason\n\n${streamUrls.size} source(s) testée(s)."
            visibility = View.VISIBLE
        }
        Toast.makeText(this, "Toutes les sources ont échoué", Toast.LENGTH_SHORT).show()
        val runnable = Runnable {
            if (!isFinishing) {
                finishWithResult(error = reason)
            }
        }
        finishRunnable = runnable
        mainHandler.postDelayed(runnable, 900L)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // OK / Enter sur écran d'erreur final → recommencer depuis la 1re source
        if (errorView?.visibility == View.VISIBLE &&
            finishedWithError &&
            (keyCode == KeyEvent.KEYCODE_DPAD_CENTER ||
                keyCode == KeyEvent.KEYCODE_ENTER ||
                keyCode == KeyEvent.KEYCODE_MEDIA_PLAY ||
                keyCode == KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
        ) {
            sourceIndex = 0
            finishedWithError = false
            buildAndStartPlayer()
            return true
        }
        if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
            finishWithResult(error = if (finishedWithError) "playback_error" else null)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        finishWithResult(error = if (finishedWithError) "playback_error" else null)
    }

    private fun finishWithResult(completed: Boolean = false, error: String? = null) {
        val p = player
        val resultIntent = Intent().apply {
            putExtra(EXTRA_POSITION, (p?.currentPosition ?: 0L).toInt())
            putExtra(EXTRA_COMPLETED, completed || p?.playbackState == Player.STATE_ENDED)
            if (error != null) putExtra(EXTRA_ERROR, error)
            putExtra(EXTRA_HAD_ERROR, finishedWithError || error != null)
            putExtra(EXTRA_SOURCE_INDEX, sourceIndex)
        }
        setResult(
            if (error != null || finishedWithError) Activity.RESULT_CANCELED else Activity.RESULT_OK,
            resultIntent
        )
        finish()
    }

    private fun releasePlayer() {
        switchRunnable?.let { mainHandler.removeCallbacks(it) }
        switchRunnable = null
        finishRunnable?.let { mainHandler.removeCallbacks(it) }
        finishRunnable = null
        playerView?.player = null
        player?.removeListener(this)
        player?.release()
        player = null
    }

    private var wasPlayingBeforeStop = false

    override fun onStop() {
        wasPlayingBeforeStop = player?.playWhenReady ?: false
        player?.playWhenReady = false
        super.onStop()
    }

    override fun onStart() {
        super.onStart()
        if (wasPlayingBeforeStop) player?.playWhenReady = true
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "NativeVideoActivity"

        const val EXTRA_URL = "url"
        const val EXTRA_URLS = "urls"
        const val EXTRA_POSITION = "position"
        const val EXTRA_IS_LIVE = "isLive"
        const val EXTRA_COMPLETED = "completed"
        const val EXTRA_ERROR = "error"
        const val EXTRA_HAD_ERROR = "hadError"
        const val EXTRA_HEADERS = "headers"
        const val EXTRA_HEADERS_LIST = "headersList"
        const val EXTRA_SOURCE_INDEX = "sourceIndex"

        private fun detectLive(url: String): Boolean {
            val u = url.lowercase()
            return u.contains("/live/") ||
                u.contains("/live?") ||
                u.contains("live_proxy") ||
                u.contains("iptv") ||
                (u.contains(".m3u8") && (u.contains("/live") || u.contains("iptv")))
        }

        private fun isHls(url: String): Boolean {
            val u = url.lowercase()
            return u.contains(".m3u8") ||
                u.contains("m3u8") ||
                u.contains("application/vnd.apple.mpegurl") ||
                u.contains("format=m3u8") ||
                u.contains("live_proxy")
        }

        private fun readHeaders(intent: Intent): Map<String, String> {
            val bundle = intent.getBundleExtra(EXTRA_HEADERS) ?: return emptyMap()
            val map = mutableMapOf<String, String>()
            for (key in bundle.keySet()) {
                bundle.getString(key)?.let { map[key] = it }
            }
            return map
        }

        private fun readHeadersList(intent: Intent): List<Map<String, String>> {
            val list = intent.getParcelableArrayListExtra<Bundle>(EXTRA_HEADERS_LIST)
                ?: return emptyList()
            return list.map { bundle ->
                val map = mutableMapOf<String, String>()
                for (key in bundle.keySet()) {
                    bundle.getString(key)?.let { map[key] = it }
                }
                map
            }
        }

        /** Accepte `urls` (liste) et/ou `url` (single) — déduplique en gardant l'ordre. */
        private fun readUrls(intent: Intent): List<String> {
            val out = LinkedHashSet<String>()
            val list = intent.getStringArrayListExtra(EXTRA_URLS)
            if (list != null) {
                for (u in list) {
                    val t = u?.trim().orEmpty()
                    if (t.startsWith("http://") || t.startsWith("https://")) out.add(t)
                }
            }
            intent.getStringExtra(EXTRA_URL)?.trim()?.let { u ->
                if (u.startsWith("http://") || u.startsWith("https://")) out.add(u)
            }
            return out.toList()
        }
    }
}
