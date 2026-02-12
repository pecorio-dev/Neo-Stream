package dev.neostream.app.ui.tv.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.tv.LocalTvDimens

/**
 * Menu latéral gauche pour navigation TV
 * Style Leanback
 */
@Composable
fun TvSidebar(
    currentRoute: String,
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
    requestInitialFocus: Boolean = false
) {
    val d = LocalTvDimens.current
    Column(
        modifier = modifier
            .width(d.sidebarWidth)
            .fillMaxHeight()
            .background(DeepBlack.copy(alpha = 0.95f))
            .padding(vertical = d.contentPadding, horizontal = d.rowPadding / 2),
        verticalArrangement = Arrangement.spacedBy(d.seasonPaddingV)
    ) {
        // Logo/Titre app
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(bottom = d.rowPadding / 2)
        ) {
            Text(
                text = "NeoStream",
                color = AccentCyan,
                fontSize = d.logoFontSize,
                fontWeight = FontWeight.Bold
            )
        }
        
        // Menu items
        TvMenuItem(
            icon = Icons.Rounded.Home,
            label = "Accueil",
            isSelected = currentRoute == "home",
            onClick = { onNavigate("home") },
            requestFocus = requestInitialFocus && currentRoute == "home"
        )
        
        TvMenuItem(
            icon = Icons.Rounded.Movie,
            label = "Films",
            isSelected = currentRoute == "movies",
            onClick = { onNavigate("movies") }
        )
        
        TvMenuItem(
            icon = Icons.Rounded.Tv,
            label = "Séries",
            isSelected = currentRoute == "series",
            onClick = { onNavigate("series") }
        )
        
        TvMenuItem(
            icon = Icons.Rounded.Favorite,
            label = "Favoris",
            isSelected = currentRoute == "favorites",
            onClick = { onNavigate("favorites") }
        )
        
        Spacer(Modifier.weight(1f))
        
        TvMenuItem(
            icon = Icons.Rounded.Settings,
            label = "Paramètres",
            isSelected = currentRoute == "settings",
            onClick = { onNavigate("settings") }
        )
    }
}

/**
 * Item de menu individuel
 */
@Composable
private fun TvMenuItem(
    icon: ImageVector,
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    requestFocus: Boolean = false
) {
    val d = LocalTvDimens.current
    TvFocusableSimple(
        onClick = onClick,
        modifier = modifier,
        requestFocus = requestFocus
    ) { isFocused ->
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = when {
                        isFocused -> AccentCyan.copy(alpha = 0.3f)
                        isSelected -> AccentCyan.copy(alpha = 0.15f)
                        else -> Color.Transparent
                    },
                    shape = RoundedCornerShape(12.dp)
                )
                .padding(horizontal = d.menuItemPaddingH, vertical = d.menuItemPaddingV),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(d.menuItemPaddingH)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = when {
                    isFocused || isSelected -> AccentCyan
                    else -> Color.White.copy(alpha = 0.7f)
                },
                modifier = Modifier.size(d.menuIconSize)
            )
            
            Text(
                text = label,
                color = when {
                    isFocused || isSelected -> Color.White
                    else -> Color.White.copy(alpha = 0.7f)
                },
                fontSize = d.menuFontSize,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
            )
        }
    }
}
