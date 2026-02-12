package dev.neostream.app.ui.mobile.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Movie
import androidx.compose.material.icons.rounded.Tv
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.ui.theme.*
import dev.neostream.app.ui.mobile.util.cardPressEffect
import dev.neostream.app.ui.mobile.util.staggeredFadeIn

@Composable
fun MovieCard(
    item: MediaItem,
    isTV: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    index: Int = 0,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val isPressed by interactionSource.collectIsPressedAsState()
    val elevation by animateDpAsState(if (isFocused) 16.dp else 4.dp, label = "elevation")
    val shape = RoundedCornerShape(12.dp)
    var visible by remember { mutableStateOf(true) }

    val glowColor = AccentCyan

    val focusModifier = if (isTV) {
        Modifier
            .focusable(interactionSource = interactionSource)
            .then(
                if (isFocused) Modifier
                    .border(BorderStroke(2.dp, AccentCyan), shape)
                    .drawBehind {
                        drawRoundRect(
                            color = glowColor.copy(alpha = 0.3f),
                            topLeft = Offset(-4.dp.toPx(), -4.dp.toPx()),
                            size = Size(
                                size.width + 8.dp.toPx(),
                                size.height + 8.dp.toPx()
                            ),
                            cornerRadius = CornerRadius(16.dp.toPx()),
                            style = Stroke(width = 4.dp.toPx()),
                        )
                    }
                else Modifier
            )
    } else Modifier

    Column(
        modifier = modifier
            .staggeredFadeIn(index, visible)
            .cardPressEffect(isPressed)
            .shadow(elevation, shape)
            .clip(shape)
            .clickable(interactionSource = interactionSource, indication = null, onClick = onClick)
            .then(focusModifier)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(2f / 3f)
        ) {
            AsyncImage(
                model = item.poster,
                contentDescription = item.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                Color.Transparent,
                                Color.Black.copy(alpha = 0.4f),
                                Color.Black.copy(alpha = 0.85f),
                            ),
                            startY = 100f,
                        )
                    )
            )

            Icon(
                imageVector = if (item.isSerie) Icons.Rounded.Tv else Icons.Rounded.Movie,
                contentDescription = null,
                tint = TextPrimary,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(6.dp)
                    .background(CardSurface.copy(alpha = 0.7f), RoundedCornerShape(6.dp))
                    .border(1.dp, GlassBorder, RoundedCornerShape(6.dp))
                    .padding(4.dp)
                    .size(12.dp),
            )

            if (item.quality.isNotBlank()) {
                Text(
                    text = item.quality,
                    color = Color.White,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(6.dp)
                        .background(
                            Brush.horizontalGradient(
                                colors = listOf(
                                    AccentCyan.copy(alpha = 0.9f),
                                    AccentPurple.copy(alpha = 0.9f),
                                ),
                            ),
                            RoundedCornerShape(6.dp),
                        )
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }

            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(8.dp)
            ) {
                Text(
                    text = item.title,
                    color = Color.White,
                    fontSize = if (isTV) 16.sp else 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (item.year.isNotBlank()) {
                    Text(
                        text = item.year,
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = if (isTV) 14.sp else 11.sp,
                    )
                }
            }

            if (item.rating > 0f) {
                RatingBadge(
                    rating = item.rating,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(6.dp),
                )
            }
        }
    }
}
