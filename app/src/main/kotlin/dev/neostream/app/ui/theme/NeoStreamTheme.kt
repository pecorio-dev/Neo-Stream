package dev.neostream.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// Colors
val DeepBlack = Color(0xFF0A0A12)
val DarkSurface = Color(0xFF141422)
val CardSurface = Color(0xFF1A1A2E)
val CardSurfaceLight = Color(0xFF222240)
val GlassBorder = Color(0x33FFFFFF)
val AccentCyan = Color(0xFF00D9FF)
val AccentPurple = Color(0xFF8B5CF6)
val AccentPink = Color(0xFFEC4899)
val AccentGold = Color(0xFFFFD700)
val TextPrimary = Color(0xFFEEEEEE)
val TextSecondary = Color(0xFF9CA3AF)
val RatingYellow = Color(0xFFFFB800)

private val NeoStreamColors = darkColorScheme(
    primary = AccentCyan,
    secondary = AccentPurple,
    tertiary = AccentPink,
    background = DeepBlack,
    surface = DarkSurface,
    surfaceVariant = CardSurface,
    onPrimary = DeepBlack,
    onSecondary = Color.White,
    onBackground = TextPrimary,
    onSurface = TextPrimary,
    onSurfaceVariant = TextSecondary,
    outline = GlassBorder,
)

private val NeoStreamTypography = Typography(
    displayLarge = TextStyle(fontWeight = FontWeight.Black, fontSize = 32.sp, color = TextPrimary),
    headlineLarge = TextStyle(fontWeight = FontWeight.Bold, fontSize = 24.sp, color = TextPrimary),
    headlineMedium = TextStyle(fontWeight = FontWeight.Bold, fontSize = 20.sp, color = TextPrimary),
    titleLarge = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 18.sp, color = TextPrimary),
    titleMedium = TextStyle(fontWeight = FontWeight.Medium, fontSize = 16.sp, color = TextPrimary),
    bodyLarge = TextStyle(fontWeight = FontWeight.Normal, fontSize = 14.sp, color = TextSecondary),
    bodyMedium = TextStyle(fontWeight = FontWeight.Normal, fontSize = 13.sp, color = TextSecondary),
    labelLarge = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 12.sp, color = TextSecondary),
    labelMedium = TextStyle(fontWeight = FontWeight.Medium, fontSize = 11.sp, color = TextSecondary),
)

val LocalIsTV = compositionLocalOf { false }

@Composable
fun NeoStreamTheme(isTV: Boolean = false, content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalIsTV provides isTV) {
        MaterialTheme(
            colorScheme = NeoStreamColors,
            typography = NeoStreamTypography,
            content = content,
        )
    }
}
