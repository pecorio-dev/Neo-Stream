package dev.neostream.app.ui.tv.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import dev.neostream.app.ui.tv.LocalTvDimens

/**
 * Shimmer effect pour les cartes en chargement
 * Style TV optimisé
 */
@Composable
fun TvShimmerCard(
    modifier: Modifier = Modifier,
    isCompact: Boolean = false
) {
    val d = LocalTvDimens.current
    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmer"
    )

    val shimmerColors = listOf(
        Color.White.copy(alpha = 0.05f),
        Color.White.copy(alpha = 0.15f),
        Color.White.copy(alpha = 0.05f),
    )

    val brush = Brush.horizontalGradient(
        colors = shimmerColors,
        startX = translateAnim - 500f,
        endX = translateAnim
    )

    Box(
        modifier = modifier
            .size(
                width = if (isCompact) d.cardWidth else d.cardWidthLarge,
                height = if (isCompact) d.cardHeight else d.cardHeightLarge
            )
            .clip(RoundedCornerShape(if (isCompact) 8.dp else 12.dp))
            .background(brush)
    )
}

/**
 * Shimmer pour row horizontale
 */
@Composable
fun TvShimmerRow(
    title: String = "Chargement...",
    modifier: Modifier = Modifier,
    itemCount: Int = 6,
    isCompact: Boolean = true
) {
    val d = LocalTvDimens.current
    
    Column(
        modifier = modifier.fillMaxWidth()
    ) {
        // Titre shimmer
        Box(
            modifier = Modifier
                .padding(start = d.rowPadding, bottom = d.episodePadding)
                .width(200.dp)
                .height(d.titleSize.value.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(Color.White.copy(alpha = 0.1f))
        )
        
        // Row de cartes shimmer
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(d.rowSpacing)
        ) {
            Spacer(Modifier.width(d.rowPadding))
            repeat(itemCount) {
                TvShimmerCard(isCompact = isCompact)
            }
            Spacer(Modifier.width(d.rowPadding))
        }
    }
}

/**
 * Shimmer pour hero banner
 */
@Composable
fun TvShimmerHeroBanner(
    modifier: Modifier = Modifier
) {
    val d = LocalTvDimens.current
    val transition = rememberInfiniteTransition(label = "hero-shimmer")
    val translateAnim by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1500f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1500, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "hero-shimmer"
    )

    val shimmerColors = listOf(
        Color.White.copy(alpha = 0.05f),
        Color.White.copy(alpha = 0.12f),
        Color.White.copy(alpha = 0.05f),
    )

    val brush = Brush.horizontalGradient(
        colors = shimmerColors,
        startX = translateAnim - 750f,
        endX = translateAnim
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(540.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(brush)
    )
}

/**
 * Shimmer pour grille de contenus
 */
@Composable
fun TvShimmerGrid(
    modifier: Modifier = Modifier,
    itemCount: Int = 12
) {
    val d = LocalTvDimens.current
    
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(d.contentPadding),
        verticalArrangement = Arrangement.spacedBy(d.gridSpacing)
    ) {
        // Simule une grille avec FlowRow
        for (row in 0 until (itemCount / 4)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(d.gridSpacing)
            ) {
                repeat(4) {
                    TvShimmerCard(
                        modifier = Modifier.weight(1f),
                        isCompact = false
                    )
                }
            }
        }
    }
}
