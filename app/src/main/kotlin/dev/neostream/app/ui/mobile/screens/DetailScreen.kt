package dev.neostream.app.ui.mobile.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import dev.neostream.app.data.extractor.UqloadExtractor
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.data.model.WatchLink
import dev.neostream.app.ui.mobile.components.MediaRow
import dev.neostream.app.ui.mobile.components.MetadataChip
import dev.neostream.app.ui.mobile.components.ChipVariant
import dev.neostream.app.ui.mobile.components.MovieCard
import dev.neostream.app.ui.mobile.components.RatingBadge
import dev.neostream.app.ui.mobile.components.SectionHeader
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.AccentPurple
import dev.neostream.app.ui.theme.CardSurface
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.GlassBorder
import dev.neostream.app.ui.theme.LocalIsTV
import dev.neostream.app.ui.theme.TextSecondary

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DetailScreen(
    viewModel: DetailViewModel,
    id: String,
    type: String,
    onBackClick: () -> Unit,
    onSettingsClick: () -> Unit,
    onItemClick: (MediaItem) -> Unit,
) {
    val state by viewModel.state.collectAsState()
    val isTV = LocalIsTV.current

    LaunchedEffect(id, type) {
        viewModel.loadDetail(id, type)
    }

    val item = state.item

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
    ) {
        when {
            state.isLoading -> {
                CircularProgressIndicator(
                    color = AccentCyan,
                    modifier = Modifier.align(Alignment.Center)
                )
            }

            state.error != null -> {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(state.error ?: "", color = MaterialTheme.colorScheme.error)
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Retour",
                        color = AccentCyan,
                        modifier = Modifier.clickable { onBackClick() }
                    )
                }
            }

            item != null -> {
                DetailContent(
                    item = item,
                    state = state,
                    isTV = isTV,
                    onBackClick = onBackClick,
                    onSettingsClick = onSettingsClick,
                    onToggleFavorite = { viewModel.toggleFavorite() },
                    onSeasonSelect = { viewModel.selectSeason(it) },
                    onItemClick = onItemClick,
                    onPlayLink = { viewModel.playLink(it) },
                    onPlayEpisodeLink = { link, episode -> viewModel.playEpisodeLink(link, episode) },
                )
            }
        }
    }
}

@ExperimentalLayoutApi
@Composable
private fun DetailContent(
    item: MediaItem,
    state: DetailState,
    isTV: Boolean,
    onBackClick: () -> Unit,
    onSettingsClick: () -> Unit,
    onToggleFavorite: () -> Unit,
    onSeasonSelect: (Int) -> Unit,
    onItemClick: (MediaItem) -> Unit,
    onPlayLink: (WatchLink) -> Unit,
    onPlayEpisodeLink: (WatchLink, dev.neostream.app.data.model.Episode) -> Unit,
) {
    val scrollState = rememberScrollState()
    var synopsisExpanded by remember { mutableStateOf(false) }
    val tvPad = if (isTV) 48.dp else 0.dp

    Box(modifier = Modifier.fillMaxSize()) {
        AsyncImage(
            model = item.poster,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            error = androidx.compose.ui.graphics.painter.ColorPainter(CardSurface),
            placeholder = androidx.compose.ui.graphics.painter.ColorPainter(CardSurface),
            modifier = Modifier
                .fillMaxWidth()
                .height(400.dp)
                .blur(20.dp)
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(400.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            DeepBlack.copy(alpha = 0.3f),
                            DeepBlack.copy(alpha = 0.7f),
                            DeepBlack,
                        )
                    )
                )
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(horizontal = tvPad)
        ) {
            Spacer(Modifier.height(if (isTV) 40.dp else 60.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.Center,
            ) {
                AsyncImage(
                    model = item.poster,
                    contentDescription = item.title,
                    contentScale = ContentScale.Crop,
                    error = androidx.compose.ui.graphics.painter.ColorPainter(CardSurface),
                    placeholder = androidx.compose.ui.graphics.painter.ColorPainter(CardSurface),
                    modifier = Modifier
                        .width(if (isTV) 220.dp else 180.dp)
                        .height(if (isTV) 330.dp else 270.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(CardSurface)
                )
            }

            Spacer(Modifier.height(20.dp))

            Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                Text(
                    text = item.title,
                    fontSize = if (isTV) 28.sp else 24.sp,
                    fontWeight = FontWeight.Black,
                    color = Color.White,
                )

                if (item.originalTitle.isNotBlank() && item.originalTitle != item.title) {
                    Text(
                        text = item.originalTitle,
                        fontSize = 14.sp,
                        color = TextSecondary,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }

                Spacer(Modifier.height(12.dp))

                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    if (item.year.isNotBlank()) MetadataChip(text = item.year)
                    if (item.quality.isNotBlank()) MetadataChip(text = item.quality, variant = ChipVariant.ACCENT)
                    if (item.version.isNotBlank()) MetadataChip(text = item.version)
                    if (item.language.isNotBlank()) MetadataChip(text = item.language)
                    if (item.isSerie) MetadataChip(text = "Serie")
                }

                if (item.rating > 0f) {
                    Spacer(Modifier.height(12.dp))
                    RatingBadge(rating = item.rating)
                }

                if (item.genres.isNotEmpty()) {
                    Spacer(Modifier.height(12.dp))
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        item.genres.forEach { genre ->
                            MetadataChip(text = genre, variant = ChipVariant.ACCENT)
                        }
                    }
                }

                if (item.synopsis.isNotBlank()) {
                    Spacer(Modifier.height(16.dp))
                    Text(
                        text = "Synopsis",
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        color = Color.White,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        text = item.synopsis,
                        color = TextSecondary,
                        fontSize = 14.sp,
                        maxLines = if (synopsisExpanded) Int.MAX_VALUE else 4,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.animateContentSize(
                            animationSpec = spring(stiffness = Spring.StiffnessLow)
                        ),
                    )
                    if (item.synopsis.length > 200) {
                        Text(
                            text = if (synopsisExpanded) "Voir moins" else "Lire plus",
                            color = AccentCyan,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .padding(top = 4.dp)
                                .clickable { synopsisExpanded = !synopsisExpanded },
                        )
                    }
                }

                if (item.directors.isNotEmpty()) {
                    Spacer(Modifier.height(14.dp))
                    Text("Realisateur", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color.White)
                    Text(
                        text = item.directors.joinToString(", "),
                        color = TextSecondary,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }

                if (item.actors.isNotEmpty()) {
                    Spacer(Modifier.height(14.dp))
                    Text("Acteurs", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color.White)
                    Spacer(Modifier.height(4.dp))
                    Row(
                        modifier = Modifier.horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        item.actors.forEach { actor ->
                            MetadataChip(text = actor)
                        }
                    }
                }

                // Afficher les saisons/épisodes UNIQUEMENT pour les vraies séries (plusieurs saisons ou épisodes)
                if (item.isSerie && item.episodes.isNotEmpty()) {
                    Spacer(Modifier.height(20.dp))
                    SeasonsSection(
                        episodes = item.episodes,
                        selectedSeason = state.selectedSeason,
                        onSeasonSelect = onSeasonSelect,
                        onPlayEpisode = onPlayEpisodeLink,
                        isTV = isTV,
                        isExtracting = state.isExtracting,
                        extractionError = state.extractionError,
                    )
                }

                // Afficher les liens de lecture directs pour les films (1 saison, 1 épisode)
                // ou si watch_links est fourni au niveau root
                val uqloadLinks = item.watchLinks.filter { UqloadExtractor.isUqloadLink(it.url) }
                if (!item.isSerie && uqloadLinks.isNotEmpty()) {
                    Spacer(Modifier.height(20.dp))
                    Text("Liens de lecture", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color.White)
                    Spacer(Modifier.height(8.dp))
                    if (state.isExtracting) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(color = AccentCyan, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Extraction en cours...", color = TextSecondary, fontSize = 13.sp)
                        }
                        Spacer(Modifier.height(8.dp))
                    }
                    if (state.extractionError != null) {
                        Text(state.extractionError, color = Color(0xFFFF5252), fontSize = 12.sp)
                        Spacer(Modifier.height(8.dp))
                    }
                    uqloadLinks.forEachIndexed { idx, link ->
                        WatchLinkItem(
                            server = link.server.ifBlank { "Uqload ${idx + 1}" },
                            onClick = { onPlayLink(link) },
                            isExtracting = state.isExtracting,
                        )
                        if (idx < uqloadLinks.lastIndex) Spacer(Modifier.height(6.dp))
                    }
                }
            }

            if (state.recommendations.isNotEmpty()) {
                Spacer(Modifier.height(24.dp))
                MediaRow(
                    title = "Vous aimerez aussi",
                    items = state.recommendations,
                    isTV = isTV,
                    onItemClick = onItemClick,
                    isLoading = state.isLoadingRecommendations,
                )
            } else if (state.isLoadingRecommendations) {
                Spacer(Modifier.height(24.dp))
                MediaRow(
                    title = "Vous aimerez aussi",
                    items = emptyList(),
                    isTV = isTV,
                    onItemClick = {},
                    isLoading = true,
                )
            }

            Spacer(Modifier.height(40.dp))
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp + tvPad, vertical = if (isTV) 16.dp else 36.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            IconButton(onClick = onBackClick) {
                Icon(
                    Icons.Rounded.ArrowBack,
                    contentDescription = "Retour",
                    tint = Color.White,
                    modifier = Modifier
                        .size(32.dp)
                        .background(DeepBlack.copy(alpha = 0.5f), CircleShape)
                        .padding(4.dp),
                )
            }
            Row {
                FavoriteButton(
                    isFavorite = state.isFavorite,
                    onClick = onToggleFavorite,
                )
                IconButton(onClick = onSettingsClick) {
                    Icon(
                        Icons.Rounded.Settings,
                        contentDescription = "Parametres",
                        tint = Color.White,
                        modifier = Modifier
                            .size(32.dp)
                            .background(DeepBlack.copy(alpha = 0.5f), CircleShape)
                            .padding(4.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun FavoriteButton(isFavorite: Boolean, onClick: () -> Unit) {
    val scale by animateFloatAsState(
        targetValue = if (isFavorite) 1.2f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow,
        ),
        label = "fav_scale",
    )

    IconButton(onClick = onClick) {
        Icon(
            if (isFavorite) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
            contentDescription = "Favori",
            tint = if (isFavorite) Color(0xFFFF4081) else Color.White,
            modifier = Modifier
                .size(32.dp)
                .scale(scale)
                .background(DeepBlack.copy(alpha = 0.5f), CircleShape)
                .padding(4.dp),
        )
    }
}

@Composable
private fun SeasonsSection(
    episodes: List<dev.neostream.app.data.model.Episode>,
    selectedSeason: Int,
    onSeasonSelect: (Int) -> Unit,
    onPlayEpisode: (WatchLink, dev.neostream.app.data.model.Episode) -> Unit,
    isTV: Boolean,
    isExtracting: Boolean = false,
    extractionError: String? = null,
) {
    val seasons = episodes.map { it.season }.distinct().sorted()
    val selectedEpisodes = episodes.filter { it.season == selectedSeason }

    Text("Saisons & Episodes", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color.White)
    Spacer(Modifier.height(8.dp))

    Row(
        modifier = Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        seasons.forEach { season ->
            val selected = season == selectedSeason
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (selected) AccentCyan else CardSurface)
                    .border(1.dp, if (selected) AccentCyan else GlassBorder, RoundedCornerShape(8.dp))
                    .clickable { onSeasonSelect(season) }
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Text(
                    "S$season",
                    color = if (selected) DeepBlack else Color.White,
                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                    fontSize = 14.sp,
                )
            }
        }
    }

    Spacer(Modifier.height(12.dp))

    if (isExtracting) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CircularProgressIndicator(color = AccentCyan, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text("Extraction en cours...", color = TextSecondary, fontSize = 13.sp)
        }
        Spacer(Modifier.height(8.dp))
    }
    if (extractionError != null) {
        Text(extractionError, color = Color(0xFFFF5252), fontSize = 12.sp)
        Spacer(Modifier.height(8.dp))
    }

    selectedEpisodes.forEach { ep ->
        EpisodeItem(
            episode = ep,
            isTV = isTV,
            onPlay = onPlayEpisode,
            isExtracting = isExtracting,
        )
        Spacer(Modifier.height(4.dp))
    }
}

@Composable
private fun EpisodeItem(
    episode: dev.neostream.app.data.model.Episode,
    isTV: Boolean,
    onPlay: (WatchLink, dev.neostream.app.data.model.Episode) -> Unit = { _, _ -> },
    isExtracting: Boolean = false,
) {
    // Filtrer pour n'avoir que les liens Uqload
    val uqloadLinks = episode.watchLinks.filter { UqloadExtractor.isUqloadLink(it.url) }
    val canPlay = uqloadLinks.isNotEmpty() && !isExtracting
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(CardSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(10.dp))
            .then(
                if (canPlay) Modifier.clickable { onPlay(uqloadLinks.first(), episode) }
                else Modifier
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(AccentPurple.copy(alpha = 0.2f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                "${episode.episode}",
                color = AccentPurple,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                episode.title.ifBlank { "Episode ${episode.episode}" },
                color = Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            val uqloadLinks = episode.watchLinks.filter { UqloadExtractor.isUqloadLink(it.url) }
            if (uqloadLinks.isNotEmpty()) {
                Text(
                    "${uqloadLinks.size} lien(s) Uqload",
                    color = TextSecondary,
                    fontSize = 12.sp,
                )
            } else if (episode.watchLinks.isNotEmpty()) {
                Text(
                    "Aucun lien compatible",
                    color = TextSecondary.copy(alpha = 0.5f),
                    fontSize = 12.sp,
                )
            }
        }
        val uqloadLinks = episode.watchLinks.filter { UqloadExtractor.isUqloadLink(it.url) }
        if (uqloadLinks.isNotEmpty() && !isExtracting) {
            Icon(
                Icons.Rounded.PlayArrow,
                contentDescription = "Lire",
                tint = AccentCyan,
                modifier = Modifier.size(24.dp),
            )
        } else if (isExtracting) {
            CircularProgressIndicator(
                color = AccentCyan,
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp,
            )
        }
    }
}

@Composable
private fun WatchLinkItem(server: String, onClick: () -> Unit, isExtracting: Boolean = false) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(CardSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(10.dp))
            .clickable(enabled = !isExtracting) { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Rounded.PlayArrow,
            contentDescription = null,
            tint = AccentCyan,
            modifier = Modifier
                .size(32.dp)
                .background(AccentCyan.copy(alpha = 0.15f), CircleShape)
                .padding(4.dp),
        )
        Spacer(Modifier.width(12.dp))
        Column {
            Text(
                server.uppercase(),
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
            )
        }
    }
}
