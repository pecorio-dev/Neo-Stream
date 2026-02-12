package dev.neostream.app.ui.tv.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import dev.neostream.app.data.extractor.UqloadExtractor
import dev.neostream.app.ui.mobile.screens.DetailViewModel
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.AccentPurple
import dev.neostream.app.ui.theme.CardSurface
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.GlassBorder
import dev.neostream.app.ui.theme.TextSecondary
import dev.neostream.app.ui.tv.LocalTvDimens
import dev.neostream.app.ui.tv.components.TvCardCompact
import dev.neostream.app.ui.tv.components.TvFocusable
import dev.neostream.app.ui.tv.components.TvFocusableSimple
import dev.neostream.app.ui.mobile.screens.WatchProgressViewModel
import androidx.lifecycle.viewmodel.compose.viewModel as androidViewModel

@Composable
fun TvDetailScreen(
   mediaId: String,
   mediaType: String,
   onBack: () -> Unit,
   onNavigateToDetail: (String, String) -> Unit,
   viewModel: DetailViewModel = viewModel(),
   watchProgressViewModel: WatchProgressViewModel = androidViewModel()
) {
    val d = LocalTvDimens.current
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    
    // Charger la progression pour cet item
    var savedProgress by remember { mutableStateOf<Long?>(null) }
    
    LaunchedEffect(mediaId, mediaType) {
        viewModel.loadDetail(mediaId, mediaType)
        // Charger la progression sauvegardée
        savedProgress = watchProgressViewModel.getProgress(context, mediaId)?.currentPosition
    }
    
    val item = state.item
    
    if (item == null) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(DeepBlack),
            contentAlignment = Alignment.Center
        ) {
            Text("Chargement...", color = Color.White, fontSize = 24.sp)
        }
        return
    }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
    ) {
        AsyncImage(
            model = item.poster,
            contentDescription = null,
            modifier = Modifier
                .fillMaxSize()
                .blur(50.dp),
            contentScale = ContentScale.Crop,
            alpha = 0.3f
        )
        
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            DeepBlack.copy(alpha = 0.7f),
                            DeepBlack.copy(alpha = 0.95f),
                            DeepBlack
                        )
                    )
                )
        )
        
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                horizontal = d.contentPadding,
                vertical = d.gridSpacing // Réduit de contentPadding pour meilleur usage de l'espace
            ),
            verticalArrangement = Arrangement.spacedBy(d.gridSpacing)
        ) {
            item {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(d.gridSpacing)
                ) {
                    AsyncImage(
                        model = item.poster,
                        contentDescription = item.title,
                        modifier = Modifier
                            .width(d.detailPosterWidth)
                            .height(d.detailPosterHeight),
                        contentScale = ContentScale.Crop
                    )
                    
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(d.rowSpacing) // Augmenté pour meilleure respiration
                    ) {
                        Text(
                            text = item.title,
                            color = Color.White,
                            fontSize = d.detailTitleSize,
                            fontWeight = FontWeight.Bold
                        )
                        
                        if (item.originalTitle.isNotBlank() && item.originalTitle != item.title) {
                            Text(
                                text = item.originalTitle,
                                color = TextSecondary,
                                fontSize = d.detailMetaSize
                            )
                        }
                        
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(d.episodePadding)
                        ) {
                            if (item.rating > 0) {
                                Text(
                                    text = "%.1f/10".format(item.rating),
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
                            
                            if (item.isSerie) {
                                Text(
                                    text = "${item.seasonsCount} saison(s)",
                                    color = TextSecondary,
                                    fontSize = d.detailMetaSize
                                )
                            }
                        }
                        
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(d.seasonPaddingV),
                            modifier = Modifier.horizontalScroll(rememberScrollState())
                        ) {
                            if (item.quality.isNotBlank()) {
                                TvMetadataChip(text = item.quality, isAccent = true)
                            }
                            if (item.version.isNotBlank()) {
                                TvMetadataChip(text = item.version)
                            }
                            if (item.language.isNotBlank()) {
                                TvMetadataChip(text = item.language)
                            }
                            if (item.isSerie) {
                                TvMetadataChip(text = "Serie")
                            }
                        }
                        
                        if (item.genres.isNotEmpty()) {
                            Text(
                                text = item.genres.joinToString(" • "),
                                color = TextSecondary,
                                fontSize = d.detailSynopsisSize
                            )
                        }
                        
                        if (item.directors.isNotEmpty()) {
                            Column {
                                Text(
                                    text = "Realisateur",
                                    color = Color.White,
                                    fontSize = d.smallSize,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = item.directors.joinToString(", "),
                                    color = TextSecondary,
                                    fontSize = d.tinySize
                                )
                            }
                        }
                        
                        if (item.actors.isNotEmpty()) {
                            Column {
                                Text(
                                    text = "Acteurs",
                                    color = Color.White,
                                    fontSize = d.smallSize,
                                    fontWeight = FontWeight.Bold
                                )
                                Spacer(Modifier.height(4.dp))
                                Row(
                                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                                    horizontalArrangement = Arrangement.spacedBy(d.seasonPaddingV)
                                ) {
                                    item.actors.forEach { actor ->
                                        TvMetadataChip(text = actor)
                                    }
                                }
                            }
                        }
                        
                        if (item.synopsis.isNotEmpty()) {
                            Text(
                                text = item.synopsis,
                                color = Color.White.copy(alpha = 0.9f),
                                fontSize = d.detailSynopsisSize,
                                lineHeight = d.detailLineHeight
                            )
                        }
                        
                        Spacer(Modifier.height(d.episodePadding))
                        
                        if (state.isExtracting) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                CircularProgressIndicator(
                                    color = AccentCyan,
                                    modifier = Modifier.size(d.settingsIconSize),
                                    strokeWidth = 2.dp
                                )
                                Spacer(Modifier.width(d.seasonPaddingV))
                                Text(
                                    "Extraction en cours...",
                                    color = TextSecondary,
                                    fontSize = d.tinySize
                                )
                            }
                        }
                        
                        if (state.extractionError != null) {
                            Text(
                                text = state.extractionError ?: "",
                                color = Color(0xFFFF5252),
                                fontSize = d.tinySize
                            )
                        }
                        
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(d.episodePadding)
                        ) {
                            if (!item.isSerie) {
                                val uqloadLinks = item.watchLinks.filter { UqloadExtractor.isUqloadLink(it.url) }
                                if (uqloadLinks.isNotEmpty()) {
                                    TvButton(
                                        text = if (state.isExtracting) {
                                            "Extraction..."
                                        } else if (savedProgress != null && savedProgress!! > 0) {
                                            "Reprendre"
                                        } else {
                                            "Lecture"
                                        },
                                        onClick = {
                                            if (!state.isExtracting) {
                                                viewModel.playLink(uqloadLinks.first())
                                            }
                                        },
                                        isPrimary = true
                                    )
                                    
                                    // Indicateur de progression si existe
                                    if (savedProgress != null && savedProgress!! > 0) {
                                        Text(
                                            text = "Progression : ${(savedProgress!! / 60000).toInt()} min",
                                            color = TextSecondary,
                                            fontSize = d.smallSize,
                                            modifier = Modifier.align(Alignment.CenterVertically)
                                        )
                                    }
                                }
                            }
                            
                            TvButton(
                                text = if (state.isFavorite) "Retirer des favoris" else "Ajouter aux favoris",
                                onClick = { viewModel.toggleFavorite() },
                                isPrimary = false
                            )
                        }
                        
                        if (!item.isSerie) {
                            val uqloadLinks = item.watchLinks.filter { UqloadExtractor.isUqloadLink(it.url) }
                            if (uqloadLinks.size > 1) {
                                Spacer(Modifier.height(d.episodePadding))
                                Text(
                                    text = "Liens de lecture",
                                    color = Color.White,
                                    fontSize = d.smallSize,
                                    fontWeight = FontWeight.Bold
                                )
                                Spacer(Modifier.height(d.seasonPaddingV))
                                Column(
                                    verticalArrangement = Arrangement.spacedBy(d.seasonPaddingV)
                                ) {
                                    uqloadLinks.forEachIndexed { idx, link ->
                                        TvWatchLinkItem(
                                            server = link.server.ifBlank { "Uqload ${idx + 1}" },
                                            onClick = { viewModel.playLink(link) },
                                            isExtracting = state.isExtracting
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if (item.isSerie && item.episodes.isNotEmpty()) {
                item {
                    TvEpisodesSection(
                        episodes = item.episodes,
                        selectedSeason = state.selectedSeason,
                        onSeasonSelect = { viewModel.selectSeason(it) },
                        onPlayEpisode = { episode ->
                            val uqloadLinks = episode.watchLinks.filter { UqloadExtractor.isUqloadLink(it.url) }
                            val link = uqloadLinks.firstOrNull()
                            if (link != null) {
                                viewModel.playEpisodeLink(link, episode)
                            }
                        },
                        isExtracting = state.isExtracting,
                        extractionError = state.extractionError
                    )
                }
            }
            
            if (state.recommendations.isNotEmpty()) {
                item {
                    Column {
                        Text(
                            text = "Recommandations similaires",
                            color = Color.White,
                            fontSize = d.titleSize,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(bottom = d.episodePadding)
                        )
                        
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(d.rowSpacing)
                        ) {
                            items(state.recommendations) { rec ->
                                TvCardCompact(
                                   title = rec.title,
                                   posterUrl = rec.poster,
                                   onClick = {
                                       onNavigateToDetail(rec.id, if (rec.isSerie) "serie" else "film")
                                   }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TvMetadataChip(
    text: String,
    isAccent: Boolean = false
) {
    val d = LocalTvDimens.current
    Box(
        modifier = Modifier
            .background(
                color = if (isAccent) AccentCyan.copy(alpha = 0.15f) else CardSurface,
                shape = RoundedCornerShape(8.dp)
            )
            .padding(horizontal = d.seasonPaddingH, vertical = d.seasonPaddingV)
    ) {
        Text(
            text = text,
            color = if (isAccent) AccentCyan else Color.White,
            fontSize = d.tinySize,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun TvButton(
    text: String,
    onClick: () -> Unit,
    isPrimary: Boolean,
    modifier: Modifier = Modifier
) {
    val d = LocalTvDimens.current
    TvFocusable(
        onClick = onClick,
        modifier = modifier,
        scaleOnFocus = 1.05f,
        cornerRadius = 8f
    ) { isFocused ->
        Box(
            modifier = Modifier
                .background(
                    color = when {
                        isPrimary -> AccentCyan
                        isFocused -> Color.White.copy(alpha = 0.2f)
                        else -> Color.White.copy(alpha = 0.1f)
                    },
                    shape = RoundedCornerShape(8.dp)
                )
                .padding(horizontal = d.buttonPaddingH, vertical = d.buttonPaddingV)
        ) {
            Text(
                text = text,
                color = if (isPrimary) Color.Black else Color.White,
                fontSize = d.buttonFontSize,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun TvWatchLinkItem(
    server: String,
    onClick: () -> Unit,
    isExtracting: Boolean = false
) {
    val d = LocalTvDimens.current
    TvFocusableSimple(
        onClick = { if (!isExtracting) onClick() }
    ) { isFocused ->
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = if (isFocused) Color.White.copy(alpha = 0.15f) else CardSurface,
                    shape = RoundedCornerShape(8.dp)
                )
                .padding(d.episodePadding),
            horizontalArrangement = Arrangement.spacedBy(d.episodePadding),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Rounded.PlayArrow,
                contentDescription = null,
                tint = AccentCyan,
                modifier = Modifier.size(d.settingsIconSize)
            )
            Text(
                text = server.uppercase(),
                color = Color.White,
                fontSize = d.episodeFontSize,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun TvEpisodesSection(
    episodes: List<dev.neostream.app.data.model.Episode>,
    selectedSeason: Int,
    onSeasonSelect: (Int) -> Unit,
    onPlayEpisode: (dev.neostream.app.data.model.Episode) -> Unit,
    isExtracting: Boolean = false,
    extractionError: String? = null
) {
    val d = LocalTvDimens.current
    Column(
        verticalArrangement = Arrangement.spacedBy(d.episodePadding)
    ) {
        Text(
            text = "Épisodes",
            color = Color.White,
            fontSize = d.titleSize,
            fontWeight = FontWeight.Bold
        )
        
        val seasons = episodes.map { it.season }.distinct().sorted()
        if (seasons.size > 1) {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(d.seasonPaddingV)
            ) {
                items(seasons) { season ->
                    TvFocusableSimple(
                        onClick = { onSeasonSelect(season) }
                    ) { isFocused ->
                        Box(
                            modifier = Modifier
                                .background(
                                    color = when {
                                        season == selectedSeason -> AccentCyan
                                        isFocused -> Color.White.copy(alpha = 0.2f)
                                        else -> Color.White.copy(alpha = 0.1f)
                                    },
                                    shape = RoundedCornerShape(8.dp)
                                )
                                .padding(horizontal = d.seasonPaddingH, vertical = d.seasonPaddingV)
                        ) {
                            Text(
                                text = "Saison $season",
                                color = if (season == selectedSeason) Color.Black else Color.White,
                                fontSize = d.episodeFontSize,
                                fontWeight = if (season == selectedSeason) FontWeight.Bold else FontWeight.Normal
                            )
                        }
                    }
                }
            }
        }
        
        if (isExtracting) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(
                    color = AccentCyan,
                    modifier = Modifier.size(d.settingsIconSize),
                    strokeWidth = 2.dp
                )
                Spacer(Modifier.width(d.seasonPaddingV))
                Text(
                    "Extraction en cours...",
                    color = TextSecondary,
                    fontSize = d.tinySize
                )
            }
        }
        
        if (extractionError != null) {
            Text(
                text = extractionError,
                color = Color(0xFFFF5252),
                fontSize = d.tinySize
            )
        }
        
        val seasonEpisodes = episodes.filter { it.season == selectedSeason }
        Column(
            verticalArrangement = Arrangement.spacedBy(d.seasonPaddingV)
        ) {
            seasonEpisodes.forEach { episode ->
                TvEpisodeItem(
                    episode = episode,
                    onClick = { onPlayEpisode(episode) },
                    isExtracting = isExtracting
                )
            }
        }
    }
}

@Composable
private fun TvEpisodeItem(
    episode: dev.neostream.app.data.model.Episode,
    onClick: () -> Unit,
    isExtracting: Boolean = false
) {
    val d = LocalTvDimens.current
    val uqloadLinks = episode.watchLinks.filter { UqloadExtractor.isUqloadLink(it.url) }
    val canPlay = uqloadLinks.isNotEmpty() && !isExtracting

    TvFocusableSimple(
        onClick = { if (canPlay) onClick() }
    ) { isFocused ->
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = if (isFocused) Color.White.copy(alpha = 0.15f) else Color.White.copy(alpha = 0.05f),
                    shape = RoundedCornerShape(8.dp)
                )
                .padding(d.episodePadding),
            horizontalArrangement = Arrangement.spacedBy(d.episodePadding),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "${episode.season}x${episode.episode.toString().padStart(2, '0')}",
                color = AccentCyan,
                fontSize = d.episodeFontSize,
                fontWeight = FontWeight.Bold
            )
            
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = episode.title.ifBlank { "Episode ${episode.episode}" },
                    color = Color.White,
                    fontSize = d.episodeFontSize
                )
                if (uqloadLinks.isNotEmpty()) {
                    Text(
                        text = "${uqloadLinks.size} lien(s) Uqload",
                        color = TextSecondary,
                        fontSize = d.tinySize
                    )
                } else if (episode.watchLinks.isNotEmpty()) {
                    Text(
                        text = "Aucun lien compatible",
                        color = TextSecondary.copy(alpha = 0.5f),
                        fontSize = d.tinySize
                    )
                }
            }
            
            if (canPlay) {
                Icon(
                    imageVector = Icons.Rounded.PlayArrow,
                    contentDescription = "Lecture",
                    tint = AccentCyan,
                    modifier = Modifier.size(d.settingsIconSize)
                )
            } else if (isExtracting) {
                CircularProgressIndicator(
                    color = AccentCyan,
                    modifier = Modifier.size(d.settingsIconSize),
                    strokeWidth = 2.dp
                )
            }
        }
    }
}
