package dev.neostream.app.ui.mobile.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.ui.theme.*

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FeaturedCard(
    item: MediaItem,
    isTV: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    scrollOffset: Float = 0f,
) {
    val cardHeight = if (isTV) 280.dp else 220.dp
    val shape = RoundedCornerShape(16.dp)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(cardHeight)
            .clip(shape)
            .clickable(onClick = onClick)
    ) {
        AsyncImage(
            model = item.poster,
            contentDescription = item.title,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    translationY = scrollOffset * 0.3f
                    alpha = (1f - (scrollOffset / 1000f)).coerceIn(0.6f, 1f)
                },
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(
                            DeepBlack.copy(alpha = 0.85f),
                            Color.Transparent,
                        ),
                    )
                )
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            DeepBlack.copy(alpha = 0.9f),
                        ),
                        startY = 100f,
                    )
                )
        )

        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            CardSurface.copy(alpha = 0.6f),
                        )
                    )
                )
                .border(
                    width = 1.dp,
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            GlassBorder,
                            Color.Transparent,
                        )
                    ),
                    shape = RoundedCornerShape(topStart = 0.dp, topEnd = 0.dp, bottomStart = 16.dp, bottomEnd = 16.dp),
                )
                .padding(16.dp)
        ) {
            Column {
                Text(
                    text = item.title,
                    color = TextPrimary,
                    fontSize = if (isTV) 24.sp else 20.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )

                Spacer(modifier = Modifier.height(4.dp))

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    if (item.year.isNotBlank()) {
                        Text(
                            text = item.year,
                            color = TextSecondary,
                            fontSize = if (isTV) 14.sp else 12.sp,
                        )
                    }

                    if (item.rating > 0f) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(3.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.Star,
                                contentDescription = null,
                                tint = RatingYellow,
                                modifier = Modifier.size(14.dp),
                            )
                            Text(
                                text = String.format("%.1f", item.rating),
                                color = RatingYellow,
                                fontSize = if (isTV) 14.sp else 12.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }

                if (item.genres.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(6.dp))
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        item.genres.take(3).forEach { genre ->
                            MetadataChip(text = genre)
                        }
                    }
                }
            }
        }
    }
}
