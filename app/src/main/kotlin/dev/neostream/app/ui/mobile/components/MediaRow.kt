package dev.neostream.app.ui.mobile.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.neostream.app.data.model.MediaItem

@Composable
fun MediaRow(
    title: String,
    items: List<MediaItem>,
    isTV: Boolean,
    onItemClick: (MediaItem) -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    isLoading: Boolean = false,
    onSeeAllClick: (() -> Unit)? = null,
) {
    val cardWidth = if (isTV) 180.dp else 130.dp
    val listState = rememberLazyListState()

    Column(modifier = modifier) {
        SectionHeader(
            title = title,
            subtitle = subtitle,
            isTV = isTV,
            onSeeAllClick = onSeeAllClick,
        )

        LazyRow(
            state = listState,
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(if (isTV) 16.dp else 10.dp),
        ) {
            if (isLoading) {
                items(6) {
                    ShimmerCard(modifier = Modifier.width(cardWidth))
                }
            } else {
                itemsIndexed(items, key = { _, item -> item.url }) { index, item ->
                    MovieCard(
                        item = item,
                        isTV = isTV,
                        onClick = { onItemClick(item) },
                        modifier = Modifier.width(cardWidth),
                        index = index,
                    )
                }
            }
        }
    }
}
