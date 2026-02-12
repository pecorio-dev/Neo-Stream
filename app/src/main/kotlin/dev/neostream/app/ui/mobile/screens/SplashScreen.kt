package dev.neostream.app.ui.mobile.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.AccentPurple
import dev.neostream.app.ui.theme.DeepBlack
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun SplashScreen(onTimeout: () -> Unit) {
    var startAnimation by remember { mutableStateOf(false) }
    
    // États d'animation pour chaque lettre
    val letterAnimations = remember {
        List(10) { Animatable(0f) }
    }
    
    // Animation de pulsation du gradient
    val infiniteTransition = rememberInfiniteTransition(label = "gradient")
    val gradientOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "gradientOffset"
    )
    
    // Animation globale de scale
    val globalScale by animateFloatAsState(
        targetValue = if (startAnimation) 1f else 0.3f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "globalScale"
    )
    
    LaunchedEffect(Unit) {
        startAnimation = true
        
        // Lancer toutes les animations de lettres en parallèle
        letterAnimations.forEachIndexed { index, animatable ->
            launch {
                delay(index * 80L)
                animatable.animateTo(
                    targetValue = 1f,
                    animationSpec = spring(
                        dampingRatio = Spring.DampingRatioMediumBouncy,
                        stiffness = Spring.StiffnessLow
                    )
                )
            }
        }
        
        // Attendre la fin des animations puis callback
        delay(2500)
        onTimeout()
    }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.radialGradient(
                    colors = listOf(
                        DeepBlack,
                        Color(0xFF0A0A12),
                        Color(0xFF000000)
                    ),
                    center = androidx.compose.ui.geometry.Offset(
                        x = 0.5f + gradientOffset * 0.1f,
                        y = 0.5f - gradientOffset * 0.1f
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        // Effet de lueur d'arrière-plan
        Box(
            modifier = Modifier
                .size(300.dp)
                .scale(globalScale * 1.2f)
                .alpha(0.3f * globalScale)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            AccentCyan.copy(alpha = 0.4f),
                            AccentPurple.copy(alpha = 0.3f),
                            Color.Transparent
                        )
                    )
                )
        )
        
        Row(
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.scale(globalScale)
        ) {
            val text = "NEO-STREAM"
            text.forEachIndexed { index, char ->
                // Calculer la couleur du gradient pour chaque lettre
                val progress = (index.toFloat() / text.length + gradientOffset) % 1f
                val color = lerp(AccentCyan, AccentPurple, progress)
                
                val letterScale = letterAnimations.getOrNull(index)?.value ?: 0f
                
                Text(
                    text = char.toString(),
                    fontSize = 48.sp,
                    fontWeight = FontWeight.Black,
                    color = color,
                    modifier = Modifier
                        .scale(letterScale)
                        .alpha(letterScale)
                        .offset(y = ((-20f * (1f - letterScale))).dp)
                )
                
                if (char == '-') {
                    Spacer(Modifier.width(8.dp))
                } else if (index < text.length - 1 && text[index + 1] != '-') {
                    Spacer(Modifier.width(2.dp))
                }
            }
        }
        
        // Sous-titre animé
        val subtitleAlpha by animateFloatAsState(
            targetValue = if (letterAnimations.lastOrNull()?.value ?: 0f > 0.8f) 1f else 0f,
            animationSpec = tween(600),
            label = "subtitleAlpha"
        )
        
        Text(
            text = "Votre streaming sans limites",
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = Color.White.copy(alpha = 0.6f),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 80.dp)
                .alpha(subtitleAlpha)
        )
    }
}

// Fonction helper pour interpoler entre deux couleurs
private fun lerp(start: Color, end: Color, fraction: Float): Color {
    return Color(
        red = start.red + (end.red - start.red) * fraction,
        green = start.green + (end.green - start.green) * fraction,
        blue = start.blue + (end.blue - start.blue) * fraction,
        alpha = start.alpha + (end.alpha - start.alpha) * fraction
    )
}
