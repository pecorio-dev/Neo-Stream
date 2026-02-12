package dev.neostream.app.ui.tv.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.ui.tv.LocalTvDimens

/**
 * Rangée horizontale de cartes média pour TV
 * Style Leanback (Netflix/Prime Video)
 */
@Composable
fun TvRow(
    title: String,
    items: List<MediaItem>,
    onItemClick: (MediaItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    val d = LocalTvDimens.current
    Column(
        modifier = modifier.fillMaxWidth()
    ) {
        // Titre de la section avec hiérarchie visuelle améliorée
        Text(
            text = title,
            color = Color.White,
            fontSize = d.titleSize,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(
                start = d.rowPadding, 
                bottom = d.rowSpacing, // Augmenté de episodePadding à rowSpacing
                top = d.episodePadding // Ajout d'un padding top pour séparation
            )
        )
        
        // Row horizontale de cartes
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(d.rowSpacing),
            contentPadding = PaddingValues(horizontal = d.rowPadding)
        ) {
            items(items) { item ->
                TvCardCompact(
                    title = item.title,
                    posterUrl = item.poster,
                    onClick = { onItemClick(item) },
                    rating = item.rating,
                    year = item.year
                )
            }
        }
    }
}

/**
 * Rangée avec cartes grandes (pour featured content)
 */
@Composable
fun TvRowLarge(
    title: String,
    items: List<MediaItem>,
    onItemClick: (MediaItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    val d = LocalTvDimens.current
    Column(
        modifier = modifier.fillMaxWidth()
    ) {
        Text(
            text = title,
            color = Color.White,
            fontSize = d.largeTitleSize,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(
                start = d.rowPadding, 
                bottom = d.gridSpacing, // Augmenté pour meilleure séparation
                top = d.rowSpacing // Ajout d'un padding top
            )
        )
        
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(d.gridSpacing),
            contentPadding = PaddingValues(horizontal = d.rowPadding)
        ) {
            items(items) { item ->
                TvCard(
                    title = item.title,
                    posterUrl = item.poster,
                    onClick = { onItemClick(item) },
                    rating = item.rating,
                    year = item.year
                )
            }
        }
    }
}
