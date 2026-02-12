package dev.neostream.app.ui.mobile.util

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.graphicsLayer

// Staggered fade-in for list items
fun Modifier.staggeredFadeIn(index: Int, visible: Boolean): Modifier = composed {
    val delay = index * 50
    val animatable = remember { Animatable(0f) }
    
    LaunchedEffect(visible) {
        if (visible) {
            kotlinx.coroutines.delay(delay.toLong())
            animatable.animateTo(
                1f,
                animationSpec = tween(400, easing = FastOutSlowInEasing)
            )
        }
    }
    
    this
        .alpha(animatable.value)
        .graphicsLayer {
            translationY = (1f - animatable.value) * 60f
        }
}

// Card press animation
fun Modifier.cardPressEffect(isPressed: Boolean): Modifier = composed {
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "press"
    )
    this.scale(scale)
}

// Shimmer effect modifier
fun Modifier.shimmerEffect(): Modifier = composed {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val alpha by transition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.7f,
        animationSpec = infiniteRepeatable(
            animation = tween(800),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "shimmer_alpha"
    )
    this.alpha(alpha)
}

// Enter transition specs for navigation
object NavTransitions {
    val enterTransition: AnimatedContentTransitionScope<*>.() -> EnterTransition = {
        fadeIn(tween(300)) + slideInVertically(tween(300)) { it / 6 }
    }
    val exitTransition: AnimatedContentTransitionScope<*>.() -> ExitTransition = {
        fadeOut(tween(200))
    }
}
