package dev.neostream.app.ui.mobile.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.ui.mobile.components.CompactCard
import dev.neostream.app.ui.mobile.components.FeaturedCard
import dev.neostream.app.ui.mobile.components.MediaRow
import dev.neostream.app.ui.mobile.components.MovieCard
import dev.neostream.app.ui.mobile.components.SectionHeader
import dev.neostream.app.ui.mobile.components.ShimmerCard
import dev.neostream.app.ui.mobile.components.WideCard
import dev.neostream.app.ui.theme.LocalIsTV
import dev.neostream.app.ui.mobile.util.staggeredFadeIn

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel,
    onItemClick: (MediaItem) -> Unit,
    onSettingsClick: () -> Unit,
    onSeeAllClick: (String) -> Unit,
) {
    val state by viewModel.state.collectAsState()
    val isTV = LocalIsTV.current
    val tvPadding = if (isTV) 48.dp else 0.dp
    var sectionsVisible by remember { mutableStateOf(false) }

    LaunchedEffect(state.isLoading) {
        if (!state.isLoading) sectionsVisible = true
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = tvPadding)
    ) {
        when {
            state.isLoading && state.isEmpty -> {
                HomeShimmerContent(isTV)
            }
            state.error != null && state.isEmpty -> {
                Text(
                    text = state.error ?: "Erreur inconnue",
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.align(Alignment.Center),
                )
            }
            else -> {
                PullToRefreshBox(
                    isRefreshing = state.isRefreshing,
                    onRefresh = { viewModel.refresh() },
                    modifier = Modifier.fillMaxSize(),
                ) {
                    val listState = rememberLazyListState()

                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        item { Spacer(Modifier.height(if (isTV) 32.dp else 16.dp)) }

                        // Featured hero card
                        state.featuredItem?.let { featured ->
                            item(key = "featured") {
                                AnimatedVisibility(
                                    visible = sectionsVisible,
                                    enter = fadeIn() + slideInVertically { -it / 4 },
                                ) {
                                    FeaturedCard(
                                        item = featured,
                                        isTV = isTV,
                                        onClick = { onItemClick(featured) },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(horizontal = 16.dp),
                                    )
                                }
                                Spacer(Modifier.height(24.dp))
                            }
                        }

                        // Tendance - WideCards
                        if (state.trending.isNotEmpty()) {
                            item(key = "trending") {
                                HomeSectionAnimated(index = 0, visible = sectionsVisible) {
                                    Column {
                                        SectionHeader(
                                            title = "Tendance",
                                            isTV = isTV,
                                            onSeeAllClick = { onSeeAllClick("trending") },
                                        )
                                        LazyRow(
                                            contentPadding = PaddingValues(horizontal = 16.dp),
                                            horizontalArrangement = Arrangement.spacedBy(if (isTV) 16.dp else 12.dp),
                                        ) {
                                            itemsIndexed(state.trending, key = { _, item -> "trending_${item.url}" }) { index, item ->
                                                WideCard(
                                                    item = item,
                                                    isTV = isTV,
                                                    onClick = { onItemClick(item) },
                                                    modifier = Modifier.width(if (isTV) 280.dp else 220.dp),
                                                )
                                            }
                                        }
                                    }
                                }
                                Spacer(Modifier.height(24.dp))
                            }
                        }

                        // Films Recents - MovieCards
                        if (state.recentFilms.isNotEmpty()) {
                            item(key = "recent_films") {
                                HomeSectionAnimated(index = 1, visible = sectionsVisible) {
                                    MediaRow(
                                        title = "Films Recents",
                                        items = state.recentFilms,
                                        isTV = isTV,
                                        onItemClick = onItemClick,
                                        onSeeAllClick = { onSeeAllClick("films") },
                                    )
                                }
                                Spacer(Modifier.height(24.dp))
                            }
                        }

                        // Series du moment - CompactCards
                        if (state.recentSeries.isNotEmpty()) {
                            item(key = "recent_series") {
                                HomeSectionAnimated(index = 2, visible = sectionsVisible) {
                                    Column {
                                        SectionHeader(
                                            title = "Séries du moment",
                                            isTV = isTV,
                                            onSeeAllClick = { onSeeAllClick("series") },
                                        )
                                        LazyRow(
                                            contentPadding = PaddingValues(horizontal = 16.dp),
                                            horizontalArrangement = Arrangement.spacedBy(if (isTV) 14.dp else 10.dp),
                                        ) {
                                            itemsIndexed(state.recentSeries, key = { _, item -> "series_${item.url}" }) { index, item ->
                                                CompactCard(
                                                    item = item,
                                                    onClick = { onItemClick(item) },
                                                    modifier = Modifier.size(if (isTV) 160.dp else 120.dp),
                                                    index = index,
                                                )
                                            }
                                        }
                                    }
                                }
                                Spacer(Modifier.height(24.dp))
                            }
                        }

                        // Les Mieux Notés - MovieCards
                        if (state.topRated.isNotEmpty()) {
                            item(key = "top_rated") {
                                HomeSectionAnimated(index = 3, visible = sectionsVisible) {
                                    MediaRow(
                                        title = "Les Mieux Notés",
                                        items = state.topRated,
                                        isTV = isTV,
                                        onItemClick = onItemClick,
                                        onSeeAllClick = { onSeeAllClick("top_rated") },
                                    )
                                }
                                Spacer(Modifier.height(24.dp))
                            }
                        }

                        // Suggestions pour vous - WideCards
                        if (state.randomPicks.isNotEmpty()) {
                            item(key = "suggestions") {
                                HomeSectionAnimated(index = 4, visible = sectionsVisible) {
                                    Column {
                                        SectionHeader(
                                            title = "Suggestions pour vous",
                                            isTV = isTV,
                                            onSeeAllClick = { onSeeAllClick("suggestions") },
                                        )
                                        LazyRow(
                                            contentPadding = PaddingValues(horizontal = 16.dp),
                                            horizontalArrangement = Arrangement.spacedBy(if (isTV) 16.dp else 12.dp),
                                        ) {
                                            itemsIndexed(state.randomPicks, key = { _, item -> "random_${item.url}" }) { index, item ->
                                                WideCard(
                                                    item = item,
                                                    isTV = isTV,
                                                    onClick = { onItemClick(item) },
                                                    modifier = Modifier.width(if (isTV) 280.dp else 220.dp),
                                                )
                                            }
                                        }
                                    }
                                }
                                Spacer(Modifier.height(32.dp))
                            }
                        }
                    }
                }
            }
        }

        IconButton(
            onClick = onSettingsClick,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = if (isTV) 24.dp else 8.dp, end = 8.dp),
        ) {
            Icon(
                imageVector = Icons.Rounded.Settings,
                contentDescription = "Paramètres",
                tint = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

@Composable
private fun HomeSectionAnimated(
    index: Int,
    visible: Boolean,
    content: @Composable () -> Unit,
) {
    Box(modifier = Modifier.staggeredFadeIn(index, visible)) {
        content()
    }
}

@Composable
private fun HomeShimmerContent(isTV: Boolean) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = if (isTV) 32.dp else 16.dp),
    ) {
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(if (isTV) 280.dp else 220.dp)
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
                    ),
            )
            Spacer(Modifier.height(24.dp))
        }

        items(3) { sectionIndex ->
            Column {
                Box(
                    modifier = Modifier
                        .width(150.dp)
                        .height(20.dp)
                        .padding(bottom = 8.dp)
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant,
                            shape = androidx.compose.foundation.shape.RoundedCornerShape(4.dp),
                        ),
                )
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(if (isTV) 16.dp else 10.dp),
                ) {
                    items(6) {
                        ShimmerCard(modifier = Modifier.width(if (isTV) 180.dp else 130.dp))
                    }
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}
