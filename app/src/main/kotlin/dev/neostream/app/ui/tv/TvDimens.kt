package dev.neostream.app.ui.tv

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.min

data class TvDimens(
    // Sidebar & Layout
    val sidebarWidth: Dp = 300.dp, // Augmenté pour meilleure lisibilité
    
    // Cards - Optimisé pour 10-foot experience
    val cardWidth: Dp = 220.dp, // Augmenté de 200 à 220
    val cardHeight: Dp = 330.dp, // Augmenté de 300 à 330
    val cardWidthLarge: Dp = 300.dp, // Augmenté de 280 à 300
    val cardHeightLarge: Dp = 450.dp, // Augmenté de 420 à 450
    
    // Spacing - Plus généreux pour TV
    val rowSpacing: Dp = 28.dp, // Augmenté de 24 à 28
    val rowPadding: Dp = 56.dp, // Augmenté de 48 à 56
    val sectionSpacing: Dp = 56.dp, // Augmenté de 48 à 56
    val contentPadding: Dp = 56.dp, // Augmenté de 48 à 56
    val gridSpacing: Dp = 36.dp, // Augmenté de 32 à 36
    
    // Typography - Plus large pour lecture à distance
    val titleSize: TextUnit = 32.sp, // Augmenté de 28 à 32
    val largeTitleSize: TextUnit = 42.sp, // Augmenté de 36 à 42
    val bodySize: TextUnit = 22.sp, // Augmenté de 20 à 22
    val smallSize: TextUnit = 18.sp, // Augmenté de 16 à 18
    val tinySize: TextUnit = 16.sp, // Augmenté de 14 à 16
    
    // Menu/Sidebar
    val menuItemPaddingH: Dp = 20.dp, // Augmenté de 16 à 20
    val menuItemPaddingV: Dp = 16.dp, // Augmenté de 14 à 16
    val menuIconSize: Dp = 32.dp, // Augmenté de 28 à 32
    val menuFontSize: TextUnit = 22.sp, // Augmenté de 20 à 22
    val logoFontSize: TextUnit = 32.sp, // Augmenté de 28 à 32
    
    // Buttons - Plus larges pour meilleure clickabilité
    val buttonPaddingH: Dp = 40.dp, // Augmenté de 32 à 40
    val buttonPaddingV: Dp = 20.dp, // Augmenté de 16 à 20
    val buttonFontSize: TextUnit = 22.sp, // Augmenté de 20 à 22
    
    // Detail Screen
    val detailPosterWidth: Dp = 340.dp, // Augmenté de 300 à 340
    val detailPosterHeight: Dp = 510.dp, // Augmenté de 450 à 510
    val detailTitleSize: TextUnit = 54.sp, // Augmenté de 48 à 54
    val detailMetaSize: TextUnit = 22.sp, // Augmenté de 20 à 22
    val detailSynopsisSize: TextUnit = 20.sp, // Augmenté de 18 à 20
    val detailLineHeight: TextUnit = 32.sp, // Augmenté de 28 à 32
    
    // Grid
    val gridMinCellSize: Dp = 300.dp, // Augmenté de 280 à 300
    
    // Search
    val searchFieldPadding: Dp = 28.dp, // Augmenté de 24 à 28
    val searchFontSize: TextUnit = 28.sp, // Augmenté de 24 à 28
    val keySize: Dp = 90.dp, // Augmenté de 80 à 90
    val keyWideSize: Dp = 140.dp, // Augmenté de 120 à 140
    val keyFontSize: TextUnit = 22.sp, // Augmenté de 20 à 22
    
    // Episodes
    val episodePadding: Dp = 20.dp, // Augmenté de 16 à 20
    val episodeFontSize: TextUnit = 20.sp, // Augmenté de 18 à 20
    val seasonPaddingH: Dp = 28.dp, // Augmenté de 24 à 28
    val seasonPaddingV: Dp = 14.dp, // Augmenté de 12 à 14
    
    // Settings
    val settingsItemPadding: Dp = 28.dp, // Augmenté de 24 à 28
    val settingsIconSize: Dp = 36.dp, // Augmenté de 32 à 36
    val settingsTitleSize: TextUnit = 22.sp, // Augmenté de 20 à 22
    val settingsSubtitleSize: TextUnit = 18.sp, // Augmenté de 16 à 18
    val settingsChevronSize: Dp = 32.dp, // Augmenté de 28 à 32
    
    // Visual Effects
    val sectionTitleSize: TextUnit = 28.sp, // Augmenté de 24 à 28
    val gradientHeight: Dp = 140.dp, // Augmenté de 120 à 140
    val focusBorderWidth: Dp = 4.dp, // Augmenté de 3 à 4 pour meilleure visibilité
)

val LocalTvDimens = compositionLocalOf { TvDimens() }

@Composable
fun ProvideTvDimens(content: @Composable () -> Unit) {
    BoxWithConstraints {
        // Utiliser 1920x1080 comme base pour HD (au lieu de 960x540)
        val scale = min(maxWidth.value / 1920f, maxHeight.value / 1080f)
        val dimens = TvDimens(
            sidebarWidth = (300 * scale).dp,
            cardWidth = (220 * scale).dp,
            cardHeight = (330 * scale).dp,
            cardWidthLarge = (300 * scale).dp,
            cardHeightLarge = (450 * scale).dp,
            rowSpacing = (28 * scale).dp,
            rowPadding = (56 * scale).dp,
            sectionSpacing = (56 * scale).dp,
            titleSize = (32 * scale).sp,
            largeTitleSize = (42 * scale).sp,
            bodySize = (22 * scale).sp,
            smallSize = (18 * scale).sp,
            tinySize = (16 * scale).sp,
            menuItemPaddingH = (20 * scale).dp,
            menuItemPaddingV = (16 * scale).dp,
            menuIconSize = (32 * scale).dp,
            menuFontSize = (22 * scale).sp,
            logoFontSize = (32 * scale).sp,
            contentPadding = (56 * scale).dp,
            buttonPaddingH = (40 * scale).dp,
            buttonPaddingV = (20 * scale).dp,
            buttonFontSize = (22 * scale).sp,
            detailPosterWidth = (340 * scale).dp,
            detailPosterHeight = (510 * scale).dp,
            detailTitleSize = (54 * scale).sp,
            detailMetaSize = (22 * scale).sp,
            detailSynopsisSize = (20 * scale).sp,
            detailLineHeight = (32 * scale).sp,
            gridMinCellSize = (300 * scale).dp,
            gridSpacing = (36 * scale).dp,
            searchFieldPadding = (28 * scale).dp,
            searchFontSize = (28 * scale).sp,
            keySize = (90 * scale).dp,
            keyWideSize = (140 * scale).dp,
            keyFontSize = (22 * scale).sp,
            episodePadding = (20 * scale).dp,
            episodeFontSize = (20 * scale).sp,
            seasonPaddingH = (28 * scale).dp,
            seasonPaddingV = (14 * scale).dp,
            settingsItemPadding = (28 * scale).dp,
            settingsIconSize = (36 * scale).dp,
            settingsTitleSize = (22 * scale).sp,
            settingsSubtitleSize = (18 * scale).sp,
            settingsChevronSize = (32 * scale).dp,
            sectionTitleSize = (28 * scale).sp,
            gradientHeight = (140 * scale).dp,
            focusBorderWidth = (4 * scale).dp,
        )
        CompositionLocalProvider(LocalTvDimens provides dimens) {
            content()
        }
    }
}
