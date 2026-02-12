package dev.neostream.app.ui.player

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.media3.ui.PlayerView
import dev.neostream.app.player.PlayerManager
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.NeoStreamTheme
import dev.neostream.app.util.PlatformDetector
import kotlinx.coroutines.delay

class VideoPlayerActivity : ComponentActivity() {
    
    companion object {
        private const val EXTRA_VIDEO_URL = "video_url"
        private const val EXTRA_VIDEO_TITLE = "video_title"
        private const val EXTRA_HEADERS = "headers"
        private const val EXTRA_MEDIA_ID = "media_id"
        private const val EXTRA_MEDIA_TITLE = "media_title"
        private const val EXTRA_MEDIA_TYPE = "media_type"
        private const val EXTRA_SEASON = "season"
        private const val EXTRA_EPISODE = "episode"
        
        fun start(
            context: Context,
            videoUrl: String,
            title: String,
            headers: Map<String, String>,
            mediaId: String = "",
            mediaTitle: String = "",
            mediaType: String = "film", // "film" ou "serie"
            season: Int = 0,
            episode: Int = 0
        ) {
            val intent = Intent(context, VideoPlayerActivity::class.java).apply {
                putExtra(EXTRA_VIDEO_URL, videoUrl)
                putExtra(EXTRA_VIDEO_TITLE, title)
                putExtra(EXTRA_HEADERS, HashMap(headers))
                putExtra(EXTRA_MEDIA_ID, mediaId)
                putExtra(EXTRA_MEDIA_TITLE, mediaTitle)
                putExtra(EXTRA_MEDIA_TYPE, mediaType)
                putExtra(EXTRA_SEASON, season)
                putExtra(EXTRA_EPISODE, episode)
                // Add FLAG_ACTIVITY_NEW_TASK when called from non-Activity context
                if (context !is android.app.Activity) {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
            context.startActivity(intent)
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Force landscape
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        
        // Fullscreen immersive
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.hide(WindowInsetsCompat.Type.systemBars())
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        
        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        val videoUrl = intent.getStringExtra(EXTRA_VIDEO_URL) ?: ""
        val title = intent.getStringExtra(EXTRA_VIDEO_TITLE) ?: ""
        @Suppress("UNCHECKED_CAST")
        val headers = intent.getSerializableExtra(EXTRA_HEADERS) as? Map<String, String> ?: emptyMap()
        val mediaId = intent.getStringExtra(EXTRA_MEDIA_ID) ?: ""
        val mediaTitle = intent.getStringExtra(EXTRA_MEDIA_TITLE) ?: ""
        val mediaType = intent.getStringExtra(EXTRA_MEDIA_TYPE) ?: "film"
        val season = intent.getIntExtra(EXTRA_SEASON, 0)
        val episode = intent.getIntExtra(EXTRA_EPISODE, 0)
        
        setContent {
            NeoStreamTheme {
                PlayerScreen(
                    videoUrl = videoUrl,
                    title = title,
                    headers = headers,
                    mediaId = mediaId,
                    mediaTitle = mediaTitle,
                    mediaType = mediaType,
                    season = season,
                    episode = episode,
                    onBack = { finish() }
                )
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        PlayerManager.release()
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Gestion des touches télécommande TV
        return when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                // Bascule play/pause
                if (PlayerManager.isPlaying) {
                    PlayerManager.pause()
                } else {
                    PlayerManager.resume()
                }
                true
            }
            KeyEvent.KEYCODE_MEDIA_PLAY -> {
                PlayerManager.resume()
                true
            }
            KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                PlayerManager.pause()
                true
            }
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_MEDIA_REWIND -> {
                // Reculer de 10 secondes
                PlayerManager.seekTo((PlayerManager.currentPosition - 10000).coerceAtLeast(0))
                true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
                // Avancer de 10 secondes
                PlayerManager.seekTo((PlayerManager.currentPosition + 10000).coerceAtMost(PlayerManager.duration))
                true
            }
            KeyEvent.KEYCODE_BACK -> {
                finish()
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }
}

@Composable
fun PlayerScreen(
    videoUrl: String,
    title: String,
    headers: Map<String, String>,
    mediaId: String,
    mediaTitle: String,
    mediaType: String,
    season: Int,
    episode: Int,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    var showControls by remember { mutableStateOf(true) }
    var isPlaying by remember { mutableStateOf(false) }
    var currentPosition by remember { mutableStateOf(0L) }
    var duration by remember { mutableStateOf(0L) }
    var hasResumed by remember { mutableStateOf(false) }
    
    // Sur TV, afficher les contrôles plus longtemps (détection via PlatformDetector)
    val controlsTimeout = if (PlatformDetector.isTV(context)) 5000L else 3000L
    
    // Charger et jouer la vidéo
    LaunchedEffect(videoUrl) {
        PlayerManager.play(context, videoUrl, headers)
        
        // Charger la progression sauvegardée pour reprendre la lecture
        if (mediaId.isNotEmpty() && !hasResumed) {
            val repository = dev.neostream.app.data.repository.WatchProgressRepository(context)
            val progressId = if (mediaType == "serie" && season > 0 && episode > 0) {
                val accountId = dev.neostream.app.data.local.SessionManager.currentAccountId.value ?: 0L
                "${accountId}_${mediaId}_S${season}E${episode}"
            } else {
                val accountId = dev.neostream.app.data.local.SessionManager.currentAccountId.value ?: 0L
                "${accountId}_${mediaId}"
            }
            
            val savedProgress = repository.getProgressById(progressId)
            savedProgress?.let { progress ->
                // Ne reprendre que si la vidéo n'est pas terminée (au moins 10 minutes restantes)
                if (!progress.isCompleted && progress.currentPosition > 10000) {
                    // Attendre que le player soit prêt avant de seek
                    delay(1000)
                    PlayerManager.seekTo(progress.currentPosition)
                    hasResumed = true
                }
            }
        }
    }
    
    // Mettre à jour l'état du player
    LaunchedEffect(Unit) {
        while (true) {
            delay(500)
            isPlaying = PlayerManager.isPlaying
            currentPosition = PlayerManager.currentPosition
            duration = PlayerManager.duration
        }
    }
    
    // Auto-hide controls (timeout plus long sur TV)
    LaunchedEffect(showControls, isPlaying) {
        if (showControls && isPlaying) {
            delay(controlsTimeout)
            showControls = false
        }
    }
    
    // Sauvegarder la progression toutes les 10s
    LaunchedEffect(Unit) {
        while (true) {
            delay(10000) // Attendre 10 secondes entre chaque sauvegarde
            if (currentPosition > 0 && duration > 0 && mediaId.isNotEmpty()) {
                val repository = dev.neostream.app.data.repository.WatchProgressRepository(context)
                try {
                    if (mediaType == "serie" && season > 0 && episode > 0) {
                        repository.saveEpisodeProgress(
                            seriesId = mediaId,
                            seasonNumber = season,
                            episodeNumber = episode,
                            seriesTitle = mediaTitle,
                            episodeTitle = title,
                            currentPosition = currentPosition,
                            duration = duration
                        )
                    } else {
                        repository.saveMovieProgress(
                            movieId = mediaId,
                            title = mediaTitle.ifEmpty { title },
                            currentPosition = currentPosition,
                            duration = duration
                        )
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
    
    // Sauvegarder la progression au retour (back button)
    DisposableEffect(Unit) {
        onDispose {
            if (currentPosition > 0 && duration > 0 && mediaId.isNotEmpty()) {
                kotlinx.coroutines.runBlocking {
                    val repository = dev.neostream.app.data.repository.WatchProgressRepository(context)
                    try {
                        if (mediaType == "serie" && season > 0 && episode > 0) {
                            repository.saveEpisodeProgress(
                                seriesId = mediaId,
                                seasonNumber = season,
                                episodeNumber = episode,
                                seriesTitle = mediaTitle,
                                episodeTitle = title,
                                currentPosition = currentPosition,
                                duration = duration
                            )
                        } else {
                            repository.saveMovieProgress(
                                movieId = mediaId,
                                title = mediaTitle.ifEmpty { title },
                                currentPosition = currentPosition,
                                duration = duration
                            )
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }
        }
    }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .clickable { showControls = !showControls }
    ) {
        // Player view
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    player = PlayerManager.getPlayer(ctx)
                    useController = false
                    keepScreenOn = true
                }
            },
            modifier = Modifier.fillMaxSize()
        )
        
        // Controls overlay
        if (showControls) {
            // Top gradient
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Black.copy(alpha = 0.7f),
                                Color.Transparent
                            )
                        )
                    )
            )
            
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.Rounded.ArrowBack,
                        contentDescription = "Retour",
                        tint = Color.White,
                        modifier = Modifier.size(28.dp)
                    )
                }
                
                Column(modifier = Modifier.weight(1f).padding(horizontal = 16.dp)) {
                    Text(
                        text = title,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        maxLines = 1
                    )
                    if (mediaType == "serie" && season > 0 && episode > 0) {
                        Text(
                            text = "S${season}E${episode}",
                            fontSize = 14.sp,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                }
            }
            
            // Center controls
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.Center)
                    .padding(horizontal = 32.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Rewind 10s
                PlayerButton(
                    icon = Icons.Rounded.Replay10,
                    onClick = { PlayerManager.seekTo((currentPosition - 10000).coerceAtLeast(0)) }
                )
                
                Spacer(Modifier.width(48.dp))
                
                // Play/Pause
                PlayerButton(
                    icon = if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                    onClick = {
                        if (isPlaying) PlayerManager.pause() else PlayerManager.resume()
                    },
                    size = 80.dp,
                    iconSize = 48.dp
                )
                
                Spacer(Modifier.width(48.dp))
                
                // Forward 10s
                PlayerButton(
                    icon = Icons.Rounded.Forward10,
                    onClick = { PlayerManager.seekTo((currentPosition + 10000).coerceAtMost(duration)) }
                )
            }
            
            // Bottom gradient & progress
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(150.dp)
                    .align(Alignment.BottomCenter)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                Color.Black.copy(alpha = 0.7f)
                            )
                        )
                    )
            )
            
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .padding(24.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = formatTime(currentPosition),
                        fontSize = 12.sp,
                        color = Color.White
                    )
                    Text(
                        text = formatTime(duration),
                        fontSize = 12.sp,
                        color = Color.White
                    )
                }
                
                Spacer(Modifier.height(8.dp))
                
                val progress = if (duration > 0) currentPosition.toFloat() / duration else 0f
                Slider(
                    value = progress,
                    onValueChange = { PlayerManager.seekTo((it * duration).toLong()) },
                    colors = SliderDefaults.colors(
                        thumbColor = AccentCyan,
                        activeTrackColor = AccentCyan,
                        inactiveTrackColor = Color.White.copy(alpha = 0.3f)
                    )
                )
            }
        }
    }
}

@Composable
private fun PlayerButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
    size: androidx.compose.ui.unit.Dp = 56.dp,
    iconSize: androidx.compose.ui.unit.Dp = 32.dp
) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.2f))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(iconSize)
        )
    }
}

private fun formatTime(millis: Long): String {
    val hours = millis / 3600000
    val minutes = (millis % 3600000) / 60000
    val seconds = (millis % 60000) / 1000
    
    return if (hours > 0) {
        String.format("%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format("%d:%02d", minutes, seconds)
    }
}
