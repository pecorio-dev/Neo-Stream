package dev.neostream.app.ui.tv.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.tv.LocalTvDimens

/**
 * Bouton TV standard
 */
@Composable
fun TvButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    isPrimary: Boolean = false,
    enabled: Boolean = true
) {
    TvFocusable(
        onClick = onClick,
        modifier = modifier,
        scaleOnFocus = 1.05f,
        cornerRadius = 8f,
        enabled = enabled
    ) { isFocused ->
        val d = LocalTvDimens.current
        Row(
            modifier = Modifier
                .background(
                    color = when {
                        !enabled -> Color.White.copy(alpha = 0.05f)
                        isPrimary -> AccentCyan
                        isFocused -> Color.White.copy(alpha = 0.2f)
                        else -> Color.White.copy(alpha = 0.1f)
                    },
                    shape = RoundedCornerShape(8.dp)
                )
                .padding(horizontal = d.buttonPaddingH, vertical = d.buttonPaddingV),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            icon?.let {
                Icon(
                    imageVector = it,
                    contentDescription = null,
                    tint = if (isPrimary) Color.Black else Color.White,
                    modifier = Modifier.size(d.rowSpacing)
                )
            }
            
            Text(
                text = text,
                color = if (isPrimary) Color.Black else Color.White,
                fontSize = d.buttonFontSize,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

/**
 * Bouton TV compact pour les actions secondaires
 */
@Composable
fun TvButtonCompact(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null
) {
    TvFocusableSimple(
        onClick = onClick,
        modifier = modifier
    ) { isFocused ->
        val d = LocalTvDimens.current
        Row(
            modifier = Modifier
                .background(
                    color = if (isFocused) Color.White.copy(alpha = 0.2f) else Color.White.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(6.dp)
                )
                .padding(horizontal = d.menuItemPaddingH, vertical = d.seasonPaddingV),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            icon?.let {
                Icon(
                    imageVector = it,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(d.episodePadding)
                )
            }
            
            Text(
                text = text,
                color = Color.White,
                fontSize = d.smallSize,
                fontWeight = FontWeight.Medium
            )
        }
    }
}
