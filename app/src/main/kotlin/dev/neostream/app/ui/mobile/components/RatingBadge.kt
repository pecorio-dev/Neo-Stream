package dev.neostream.app.ui.mobile.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.ui.theme.*

@Composable
fun RatingBadge(
    rating: Float,
    modifier: Modifier = Modifier,
) {
    val animatedRating = remember { Animatable(0f) }

    LaunchedEffect(rating) {
        animatedRating.animateTo(
            targetValue = rating,
            animationSpec = tween(durationMillis = 800),
        )
    }

    val displayValue by remember {
        derivedStateOf { String.format("%.1f", animatedRating.value) }
    }

    val ratingColor = when {
        rating >= 7f -> RatingYellow
        rating >= 5f -> TextPrimary
        else -> Color(0xFFEF4444)
    }

    val shape = RoundedCornerShape(6.dp)

    Row(
        modifier = modifier
            .clip(shape)
            .background(CardSurface.copy(alpha = 0.8f))
            .border(1.dp, ratingColor.copy(alpha = 0.3f), shape)
            .padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Icon(
            imageVector = Icons.Rounded.Star,
            contentDescription = null,
            tint = ratingColor,
            modifier = Modifier.size(12.dp),
        )
        Text(
            text = displayValue,
            color = ratingColor,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}
