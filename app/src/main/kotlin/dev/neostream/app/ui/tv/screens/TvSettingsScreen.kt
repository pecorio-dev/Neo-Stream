package dev.neostream.app.ui.tv.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.data.local.SessionManager
import dev.neostream.app.data.repository.ViewingStatsCalculator
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.TextSecondary
import dev.neostream.app.ui.tv.LocalTvDimens
import dev.neostream.app.ui.tv.components.TvFocusableSimple
import dev.neostream.app.ui.tv.components.TvSidebar
import kotlinx.coroutines.launch

/**
 * Écran Paramètres pour TV
 */
@Composable
fun TvSettingsScreen(
   onNavigateToHome: () -> Unit,
   onNavigateToMovies: () -> Unit,
   onNavigateToSeries: () -> Unit,
   onNavigateToFavorites: () -> Unit,
) {
    val d = LocalTvDimens.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val currentRoute = "settings"
    var stats by remember { mutableStateOf<ViewingStatsCalculator.ViewingStats?>(null) }
    
    LaunchedEffect(Unit) {
        scope.launch {
            stats = ViewingStatsCalculator.calculateStats(context)
        }
    }
    
    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
    ) {
        // Sidebar
        TvSidebar(
            currentRoute = currentRoute,
            onNavigate = { route ->
               when (route) {
                   "settings" -> { /* Already here */ }
                   "home" -> onNavigateToHome()
                   "movies" -> onNavigateToMovies()
                   "series" -> onNavigateToSeries()
                   "favorites" -> onNavigateToFavorites()
               }
           }
        )
        
        // Content
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
                .padding(
                    horizontal = d.contentPadding,
                    vertical = d.gridSpacing
                ),
            verticalArrangement = Arrangement.spacedBy(d.sectionSpacing) // Plus d'espace entre sections
        ) {
            // Header
            item {
                Text(
                    text = "Paramètres",
                    color = Color.White,
                    fontSize = d.largeTitleSize,
                    fontWeight = FontWeight.Bold
                )
            }
            
            // Section Compte
            item {
                TvSettingsSection(title = "Compte") {
                    val accountId = SessionManager.currentAccountId.collectAsState(initial = 0L)
                    
                    TvSettingsItem(
                        icon = Icons.Rounded.AccountCircle,
                        title = "Compte actuel",
                        subtitle = "Compte #${accountId.value}",
                        onClick = { /* Navigate to account picker */ }
                    )
                }
            }
            
            // Section Statistiques
            item {
                TvSettingsSection(title = "Vos statistiques") {
                    stats?.let { viewingStats ->
                        TvSettingsItem(
                            icon = Icons.Rounded.Movie,
                            title = "Contenus regardés",
                            subtitle = "${viewingStats.totalFilmsWatched} films • ${viewingStats.totalEpisodesWatched} épisodes",
                            onClick = {}
                        )
                        
                        TvSettingsItem(
                            icon = Icons.Rounded.MonetizationOn,
                            title = "Économies réalisées",
                            subtitle = "${viewingStats.formatSaved()} économisés vs streaming",
                            onClick = {}
                        )
                        
                        if (viewingStats.savedAmount > 0) {
                            TvSettingsItem(
                                icon = Icons.Rounded.LocalCafe,
                                title = "Équivalent en donations Ko-fi",
                                subtitle = "${ViewingStatsCalculator.getCoffeeEquivalent(viewingStats)} cafés de 3€",
                                onClick = {}
                            )
                        }
                    } ?: run {
                        TvSettingsItem(
                            icon = Icons.Rounded.Sync,
                            title = "Chargement des statistiques...",
                            subtitle = "",
                            onClick = {}
                        )
                    }
                }
            }
            
            // Section Application
            item {
                TvSettingsSection(title = "Application") {
                    TvSettingsItem(
                        icon = Icons.Rounded.Info,
                        title = "Version",
                        subtitle = "NeoStream 1.0.0 TV",
                        onClick = {}
                    )
                    
                    TvSettingsItem(
                        icon = Icons.Rounded.Favorite,
                        title = "Soutenir le projet",
                        subtitle = "Offrir un café au développeur (Ko-fi)",
                        onClick = {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://ko-fi.com/pecorio"))
                            context.startActivity(intent)
                        }
                    )
                }
            }
        }
    }
}

/**
 * Section de paramètres
 */
@Composable
private fun TvSettingsSection(
    title: String,
    content: @Composable () -> Unit
) {
    val d = LocalTvDimens.current
    Column(
        verticalArrangement = Arrangement.spacedBy(d.episodePadding)
    ) {
        Text(
            text = title,
            color = AccentCyan,
            fontSize = d.sectionTitleSize,
            fontWeight = FontWeight.Bold
        )
        
        content()
    }
}

/**
 * Item de paramètre
 */
@Composable
private fun TvSettingsItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    val d = LocalTvDimens.current
    TvFocusableSimple(
        onClick = onClick,
        enabled = onClick != {}
    ) { isFocused ->
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = if (isFocused) Color.White.copy(alpha = 0.15f) else Color.White.copy(alpha = 0.05f),
                    shape = RoundedCornerShape(12.dp)
                )
                .padding(d.settingsItemPadding),
            horizontalArrangement = Arrangement.spacedBy(d.settingsItemPadding),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isFocused) AccentCyan else Color.White.copy(alpha = 0.7f),
                modifier = Modifier.size(d.settingsIconSize)
            )
            
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = title,
                    color = Color.White,
                    fontSize = d.settingsTitleSize,
                    fontWeight = if (isFocused) FontWeight.Bold else FontWeight.Normal
                )
                
                if (subtitle.isNotEmpty()) {
                    Text(
                        text = subtitle,
                        color = TextSecondary,
                        fontSize = d.settingsSubtitleSize
                    )
                }
            }
            
            if (onClick != {}) {
                Icon(
                    imageVector = Icons.Rounded.ChevronRight,
                    contentDescription = null,
                    tint = if (isFocused) AccentCyan else TextSecondary,
                    modifier = Modifier.size(d.settingsChevronSize)
                )
            }
        }
    }
}
