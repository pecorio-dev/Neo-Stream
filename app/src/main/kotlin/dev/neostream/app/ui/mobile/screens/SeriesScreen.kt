package dev.neostream.app.ui.mobile.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.ui.mobile.components.CompactCard
import dev.neostream.app.ui.mobile.components.MovieCard
import dev.neostream.app.ui.mobile.components.ShimmerCard
import dev.neostream.app.ui.theme.LocalIsTV
import dev.neostream.app.ui.theme.TextSecondary

@Composable
fun SeriesScreen(
    viewModel: SeriesViewModel,
    onItemClick: (MediaItem) -> Unit,
    onSettingsClick: () -> Unit,
) {
    val state by viewModel.state.collectAsState()
    val isTV = LocalIsTV.current
    val tvPadding = if (isTV) 48.dp else 0.dp
    val columns = if (isTV) 4 else 2
    val gridState = rememberLazyGridState()

    val shouldLoadMore by remember {
        derivedStateOf {
            val lastVisible = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            lastVisible >= gridState.layoutInfo.totalItemsCount - 6
        }
    }

    LaunchedEffect(shouldLoadMore) {
        snapshotFlow { shouldLoadMore }.collect { load ->
            if (load) viewModel.loadMore()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = tvPadding)
    ) {
        LazyVerticalGrid(
            columns = GridCells.Fixed(columns),
            state = gridState,
            contentPadding = PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = if (isTV) 32.dp else 16.dp,
                bottom = 32.dp,
            ),
            horizontalArrangement = Arrangement.spacedBy(if (isTV) 16.dp else 10.dp),
            verticalArrangement = Arrangement.spacedBy(if (isTV) 16.dp else 12.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            item(span = { GridItemSpan(columns) }) {
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        GlassSearchBar(
                            query = state.searchQuery,
                            onQueryChange = { viewModel.setSearchQuery(it) },
                            placeholder = "Rechercher une série...",
                            modifier = Modifier.weight(1f),
                        )
                        IconButton(onClick = onSettingsClick) {
                            Icon(
                                imageVector = Icons.Rounded.Settings,
                                contentDescription = "Paramètres",
                                tint = MaterialTheme.colorScheme.onSurface,
                            )
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                }
            }

            if (state.genres.isNotEmpty()) {
                item(span = { GridItemSpan(columns) }) {
                    GenreFilterRow(
                        genres = state.genres,
                        selectedGenre = state.selectedGenre,
                        onGenreSelected = { viewModel.setGenre(it) },
                    )
                }
            }

            item(span = { GridItemSpan(columns) }) {
                SortRow(
                    currentSort = state.sortOption,
                    onSortSelected = { viewModel.setSortOption(it) },
                )
            }

            if (state.isLoading) {
                items(columns * 3, key = { "shimmer_$it" }) {
                    ShimmerCard()
                }
            } else if (state.items.isEmpty() && state.error == null) {
                item(span = { GridItemSpan(columns) }) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = "Aucune série trouvée",
                            color = TextSecondary,
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }
                }
            } else if (state.error != null && state.items.isEmpty()) {
                item(span = { GridItemSpan(columns) }) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = state.error ?: "Erreur inconnue",
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                }
            } else {
                itemsIndexed(state.items, key = { _, item -> item.url }) { index, item ->
                    if (index % 3 == 0) {
                        CompactCard(
                            item = item,
                            onClick = { onItemClick(item) },
                            index = index,
                        )
                    } else {
                        MovieCard(
                            item = item,
                            isTV = isTV,
                            onClick = { onItemClick(item) },
                            index = index,
                        )
                    }
                }

                if (state.isLoadingMore) {
                    items(columns, key = { "loading_more_$it" }) {
                        ShimmerCard()
                    }
                }
            }
        }
    }
}
