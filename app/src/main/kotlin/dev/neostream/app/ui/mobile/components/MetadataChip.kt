package dev.neostream.app.ui.mobile.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.ui.theme.*

enum class ChipVariant { GLASS, ACCENT, RATING }

@Composable
fun MetadataChip(
    text: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    variant: ChipVariant = ChipVariant.GLASS,
) {
    val shape = RoundedCornerShape(8.dp)

    val backgroundColor = when (variant) {
        ChipVariant.GLASS -> CardSurface.copy(alpha = 0.6f)
        ChipVariant.ACCENT -> AccentCyan.copy(alpha = 0.2f)
        ChipVariant.RATING -> AccentGold.copy(alpha = 0.2f)
    }

    val borderColor = when (variant) {
        ChipVariant.GLASS -> GlassBorder
        ChipVariant.ACCENT -> AccentCyan.copy(alpha = 0.4f)
        ChipVariant.RATING -> AccentGold.copy(alpha = 0.4f)
    }

    val textColor = when (variant) {
        ChipVariant.GLASS -> TextPrimary
        ChipVariant.ACCENT -> AccentCyan
        ChipVariant.RATING -> AccentGold
    }

    Row(
        modifier = modifier
            .clip(shape)
            .background(backgroundColor)
            .border(1.dp, borderColor, shape)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = textColor,
                modifier = Modifier.size(12.dp),
            )
        }
        Text(
            text = text,
            color = textColor,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}
