package dev.neostream.app.ui.tv.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Composant de base pour tous les éléments focusables TV
 * 
 * Features:
 * - Border glow quand focusé
 * - Scale animation (1.0 → 1.1)
 * - Shadow elevation
 * - Callbacks focus/unfocus
 */
@Composable
fun TvFocusable(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onFocus: () -> Unit = {},
    onLoseFocus: () -> Unit = {},
    scaleOnFocus: Float = 1.1f,
    borderColor: Color = Color(0xFF00D9FF), // AccentCyan
    borderWidth: Float = 3f,
    cornerRadius: Float = 12f,
    enabled: Boolean = true,
    content: @Composable (isFocused: Boolean) -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    
    // Animations optimisées pour TV (plus rapides et fluides)
    val scale by animateFloatAsState(
        targetValue = if (isFocused) scaleOnFocus else 1f,
        animationSpec = tween(durationMillis = 150), // Réduit de 200 à 150ms
        label = "scale"
    )
    
    val elevation by animateDpAsState(
        targetValue = if (isFocused) 20.dp else 4.dp, // Augmenté de 16 à 20 pour plus d'effet
        animationSpec = tween(durationMillis = 150),
        label = "elevation"
    )
    
    val borderWidthDp by animateDpAsState(
        targetValue = if (isFocused) borderWidth.dp else 0.dp,
        animationSpec = tween(durationMillis = 150),
        label = "borderWidth"
    )
    
    // Callbacks
    if (isFocused) {
        onFocus()
    } else {
        onLoseFocus()
    }
    
    Box(
        modifier = modifier
            .scale(scale)
            .shadow(
                elevation = elevation,
                shape = RoundedCornerShape(cornerRadius.dp),
                clip = false
            )
            .border(
                border = BorderStroke(borderWidthDp, borderColor),
                shape = RoundedCornerShape(cornerRadius.dp)
            )
            .focusable(enabled = enabled, interactionSource = interactionSource)
            .clickable(
                enabled = enabled,
                interactionSource = interactionSource,
                indication = null
            ) {
                onClick()
            }
    ) {
        content(isFocused)
    }
}

/**
 * Variant simple sans animations pour les éléments de menu/sidebar
 */
@Composable
fun TvFocusableSimple(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    requestFocus: Boolean = false,
    content: @Composable (isFocused: Boolean) -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val focusRequester = remember { FocusRequester() }
    
    // Auto-focus si demandé
    LaunchedEffect(requestFocus) {
        if (requestFocus) {
            focusRequester.requestFocus()
        }
    }
    
    Box(
        modifier = modifier
            .focusRequester(focusRequester)
            .focusable(enabled = enabled, interactionSource = interactionSource)
            .clickable(
                enabled = enabled,
                interactionSource = interactionSource,
                indication = null
            ) {
                onClick()
            }
    ) {
        content(isFocused)
    }
}

/**
 * Extension avec auto-focus pour TvFocusable
 */
@Composable
fun TvFocusableWithAutoFocus(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onFocus: () -> Unit = {},
    onLoseFocus: () -> Unit = {},
    scaleOnFocus: Float = 1.1f,
    borderColor: Color = Color(0xFF00D9FF),
    borderWidth: Float = 3f,
    cornerRadius: Float = 12f,
    enabled: Boolean = true,
    requestFocus: Boolean = false,
    content: @Composable (isFocused: Boolean) -> Unit
) {
    val focusRequester = remember { FocusRequester() }
    
    // Auto-focus si demandé
    LaunchedEffect(requestFocus) {
        if (requestFocus) {
            focusRequester.requestFocus()
        }
    }
    
    TvFocusable(
        onClick = onClick,
        modifier = modifier.focusRequester(focusRequester),
        onFocus = onFocus,
        onLoseFocus = onLoseFocus,
        scaleOnFocus = scaleOnFocus,
        borderColor = borderColor,
        borderWidth = borderWidth,
        cornerRadius = cornerRadius,
        enabled = enabled,
        content = content
    )
}
