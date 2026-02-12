package dev.neostream.app.ui.tv.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.ui.mobile.screens.HomeViewModel
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.TextSecondary
import dev.neostream.app.ui.tv.LocalTvDimens
import dev.neostream.app.ui.tv.components.TvButton
import dev.neostream.app.ui.tv.components.TvRow
import dev.neostream.app.ui.tv.components.TvSidebar
import dev.neostream.app.ui.tv.components.TvShimmerHeroBanner
import dev.neostream.app.ui.tv.components.TvShimmerRow
import dev.neostream.app.ui.mobile.screens.WatchProgressViewModel
import androidx.lifecycle.viewmodel.compose.viewModel as androidViewModel

/**
 * Écran d'accueil TV avec sidebar et rows de contenus
 */
@Composable
fun TvHomeScreen(
    onNavigateToDetail: (String, String) -> Unit,
    onNavigateToMovies: () -> Unit,
    onNavigateToSeries: () -> Unit,
    onNavigateToFavorites: () -> Unit,
    onNavigateToSettings: () -> Unit,
    viewModel: HomeViewModel = viewModel(),
    watchProgressViewModel: WatchProgressViewModel = androidViewModel()
) {
    val d = LocalTvDimens.current
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    val inProgressItems by watchProgressViewModel.inProgressItems.collectAsState()
    
    LaunchedEffect(Unit) {
        viewModel.refresh()
        watchProgressViewModel.loadInProgress(context)
    }
    
    var currentRoute by remember { mutableStateOf("home") }
    var shouldRequestFocus by remember { mutableStateOf(true) }
    
    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
    ) {
        // Sidebar gauche
        TvSidebar(
            currentRoute = currentRoute,
            requestInitialFocus = shouldRequestFocus,
            onNavigate = { route ->
                currentRoute = route
                shouldRequestFocus = false // Ne pas re-focus après la navigation initiale
                when (route) {
                    "home" -> { /* Already here */ }
                    "movies" -> onNavigateToMovies()
                    "series" -> onNavigateToSeries()
                    "favorites" -> onNavigateToFavorites()
                    "settings" -> onNavigateToSettings()
                }
            }
        )
        
        // Content principal
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f),
            verticalArrangement = Arrangement.spacedBy(d.sectionSpacing),
            contentPadding = PaddingValues(bottom = d.contentPadding)
        ) {
            // État de chargement initial
            if (state.isLoading && state.trending.isEmpty()) {
                item {
                    TvShimmerHeroBanner()
                }
                item {
                    TvShimmerRow(title = "Tendances")
                }
                item {
                    TvShimmerRow(title = "Films récents")
                }
                item {
                    TvShimmerRow(title = "Séries récentes")
                }
            } else {
                // Hero Banner Featured
                if (state.trending.isNotEmpty()) {
                    item {
                        TvHeroBanner(
                            item = state.trending.first(),
                            onPlayClick = { 
                                onNavigateToDetail(state.trending.first().id, if (state.trending.first().isSerie) "serie" else "film")
                            },
                            onInfoClick = {
                                onNavigateToDetail(state.trending.first().id, if (state.trending.first().isSerie) "serie" else "film")
                            }
                        )
                    }
                }
                
                // Continuer à regarder (Reprise de progression)
                if (inProgressItems.isNotEmpty()) {
                    item {
                        TvRow(
                            title = "Continuer à regarder",
                            items = inProgressItems.mapNotNull { progress ->
                                // Convertir WatchProgressEntity en MediaItem
                                MediaItem(
                                    id = progress.mediaId,
                                    title = progress.title,
                                    poster = progress.imageUrl,
                                    type = if (progress.contentType == "episode") "serie" else "film",
                                    year = progress.year,
                                    rating = 0f
                                )
                            },
                            onItemClick = { item ->
                                onNavigateToDetail(item.id, if (item.isSerie) "serie" else "film")
                            }
                        )
                    }
                }
                
                // Tendances
                if (state.trending.isNotEmpty()) {
                    item {
                        TvRow(
                            title = "Tendances",
                            items = state.trending.drop(1), // Skip first (used in hero)
                            onItemClick = { item ->
                                onNavigateToDetail(item.id, if (item.isSerie) "serie" else "film")
                            }
                        )
                    }
                }
                
                // Films récents
                if (state.recentFilms.isNotEmpty()) {
                    item {
                        TvRow(
                            title = "Films récents",
                            items = state.recentFilms,
                            onItemClick = { item ->
                                onNavigateToDetail(item.id, "film")
                            }
                        )
                    }
                }
                
                // Séries récentes
                if (state.recentSeries.isNotEmpty()) {
                    item {
                        TvRow(
                            title = "Séries récentes",
                            items = state.recentSeries,
                            onItemClick = { item ->
                                onNavigateToDetail(item.id, "serie")
                            }
                        )
                    }
                }
                
                // Top rated
                if (state.topRated.isNotEmpty()) {
                    item {
                        TvRow(
                            title = "Mieux notés",
                            items = state.topRated,
                            onItemClick = { item ->
                                onNavigateToDetail(item.id, if (item.isSerie) "serie" else "film")
                            }
                        )
                    }
                }
                
                // Random picks
                if (state.randomPicks.isNotEmpty()) {
                    item {
                        TvRow(
                            title = "Sélection aléatoire",
                            items = state.randomPicks,
                            onItemClick = { item ->
                                onNavigateToDetail(item.id, if (item.isSerie) "serie" else "film")
                            }
                        )
                    }
                }
            }
        }
    }
}

/**
 * Bannière Hero style Netflix/Prime Video
 * Affiche le contenu featured avec image de fond, titre, description et actions
 */
@Composable
private fun TvHeroBanner(
    item: MediaItem,
    onPlayClick: () -> Unit,
    onInfoClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val d = LocalTvDimens.current
    
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(540.dp) // 16:9 ratio for TV
    ) {
        // Background image avec blur
        AsyncImage(
            model = item.poster,
            contentDescription = null,
            modifier = Modifier
                .fillMaxSize()
                .blur(8.dp),
            contentScale = ContentScale.Crop,
            alpha = 0.4f
        )
        
        // Gradient overlay pour lisibilité
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(
                            DeepBlack.copy(alpha = 0.95f),
                            DeepBlack.copy(alpha = 0.7f),
                            Color.Transparent
                        ),
                        startX = 0f,
                        endX = 1200f
                    )
                )
        )
        
        // Contenu textuel
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = d.rowPadding, end = d.rowPadding * 2, top = d.contentPadding, bottom = d.contentPadding),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier
                    .weight(0.5f)
                    .padding(end = d.gridSpacing),
                verticalArrangement = Arrangement.spacedBy(d.rowSpacing)
            ) {
                // Badge "En vedette"
                Box(
                    modifier = Modifier
                        .background(
                            color = AccentCyan.copy(alpha = 0.2f),
                            shape = RoundedCornerShape(8.dp)
                        )
                        .padding(horizontal = d.seasonPaddingH, vertical = d.seasonPaddingV)
                ) {
                    Text(
                        text = "EN VEDETTE",
                        color = AccentCyan,
                        fontSize = d.smallSize,
                        fontWeight = FontWeight.Bold
                    )
                }
                
                // Titre
                Text(
                    text = item.title,
                    color = Color.White,
                    fontSize = d.detailTitleSize,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                
                // Métadonnées
                Row(
                    horizontalArrangement = Arrangement.spacedBy(d.episodePadding),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (item.rating > 0) {
                        Text(
                            text = "★ %.1f/10".format(item.rating),
                            color = AccentCyan,
                            fontSize = d.detailMetaSize,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    
                    if (item.year.isNotEmpty()) {
                        Text(
                            text = item.year,
                            color = TextSecondary,
                            fontSize = d.detailMetaSize
                        )
                    }
                    
                    if (item.genres.isNotEmpty()) {
                        Text(
                            text = item.genres.take(2).joinToString(" • "),
                            color = TextSecondary,
                            fontSize = d.detailMetaSize,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
                
                // Synopsis
                if (item.synopsis.isNotEmpty()) {
                    Text(
                        text = item.synopsis,
                        color = Color.White.copy(alpha = 0.9f),
                        fontSize = d.detailSynopsisSize,
                        lineHeight = d.detailLineHeight,
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                
                Spacer(Modifier.height(d.episodePadding))
                
                // Boutons d'action
                Row(
                    horizontalArrangement = Arrangement.spacedBy(d.rowSpacing)
                ) {
                    TvButton(
                        text = "Lecture",
                        onClick = onPlayClick,
                        icon = Icons.Rounded.PlayArrow,
                        isPrimary = true
                    )
                    
                    TvButton(
                        text = "Plus d'infos",
                        onClick = onInfoClick,
                        icon = Icons.Rounded.Info,
                        isPrimary = false
                    )
                }
            }
        }
    }
}
