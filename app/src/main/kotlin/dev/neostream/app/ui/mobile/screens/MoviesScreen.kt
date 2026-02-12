package dev.neostream.app.ui.mobile.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Search
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.ui.mobile.components.ChipVariant
import dev.neostream.app.ui.mobile.components.MetadataChip
import dev.neostream.app.ui.mobile.components.MovieCard
import dev.neostream.app.ui.mobile.components.ShimmerCard
import dev.neostream.app.ui.theme.CardSurface
import dev.neostream.app.ui.theme.GlassBorder
import dev.neostream.app.ui.theme.LocalIsTV
import dev.neostream.app.ui.theme.TextPrimary
import dev.neostream.app.ui.theme.TextSecondary

@Composable
fun MoviesScreen(
    viewModel: MoviesViewModel,
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
                            placeholder = "Rechercher un film...",
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
                            text = "Aucun film trouvé",
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
                    MovieCard(
                        item = item,
                        isTV = isTV,
                        onClick = { onItemClick(item) },
                        index = index,
                    )
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

@Composable
internal fun GlassSearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(12.dp)

    Row(
        modifier = modifier
            .clip(shape)
            .background(CardSurface.copy(alpha = 0.6f))
            .border(1.dp, GlassBorder, shape)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Rounded.Search,
            contentDescription = null,
            tint = TextSecondary,
            modifier = Modifier.padding(end = 4.dp),
        )

        Box(modifier = Modifier.weight(1f)) {
            if (query.isEmpty()) {
                Text(
                    text = placeholder,
                    color = TextSecondary,
                    fontSize = 14.sp,
                )
            }
            BasicTextField(
                value = query,
                onValueChange = onQueryChange,
                textStyle = TextStyle(
                    color = TextPrimary,
                    fontSize = 14.sp,
                ),
                singleLine = true,
                cursorBrush = SolidColor(TextPrimary),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        if (query.isNotEmpty()) {
            Icon(
                imageVector = Icons.Rounded.Close,
                contentDescription = "Effacer",
                tint = TextSecondary,
                modifier = Modifier.clickable { onQueryChange("") },
            )
        }
    }
}

@Composable
internal fun GenreFilterRow(
    genres: List<String>,
    selectedGenre: String?,
    onGenreSelected: (String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Spacer(Modifier.width(8.dp))
        MetadataChip(
            text = "Tous",
            variant = if (selectedGenre == null) ChipVariant.ACCENT else ChipVariant.GLASS,
            modifier = Modifier.clickable { onGenreSelected(null) },
        )
        genres.forEach { genre ->
            MetadataChip(
                text = genre,
                variant = if (selectedGenre == genre) ChipVariant.ACCENT else ChipVariant.GLASS,
                modifier = Modifier.clickable { onGenreSelected(genre) },
            )
        }
        Spacer(Modifier.width(8.dp))
    }
}

@Composable
internal fun SortRow(
    currentSort: SortOption,
    onSortSelected: (SortOption) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SortOption.entries.forEach { option ->
            val label = when (option) {
                SortOption.RECENT -> "Récent"
                SortOption.RATING -> "Note"
                SortOption.TITLE -> "Titre"
            }
            Text(
                text = label,
                color = if (currentSort == option) MaterialTheme.colorScheme.primary else TextSecondary,
                fontSize = 13.sp,
                fontWeight = if (currentSort == option) FontWeight.Bold else FontWeight.Normal,
                modifier = Modifier
                    .clickable { onSortSelected(option) }
                    .padding(horizontal = 4.dp, vertical = 4.dp),
            )
        }
    }
}
