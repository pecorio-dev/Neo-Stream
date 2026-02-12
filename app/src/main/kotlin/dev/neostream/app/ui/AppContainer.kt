package dev.neostream.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.ui.theme.DeepBlack

@Composable
fun AppContainer(
    isForcedContainer: Boolean,
    content: @Composable () -> Unit
) {
    if (!isForcedContainer) {
        Box(modifier = Modifier.fillMaxSize().background(DeepBlack)) {
            content()
        }
        return
    }

    val config = LocalConfiguration.current
    val screenWidthDp = config.screenWidthDp.toFloat()
    val screenHeightDp = config.screenHeightDp.toFloat()
    val screenAspect = screenWidthDp / screenHeightDp
    val targetAspect = 16f / 9f
    val isPortrait = screenAspect < 1f

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A0A)),
        contentAlignment = Alignment.Center
    ) {
        val containerModifier = if (isPortrait) {
            val maxFraction = 0.85f
            Modifier
                .fillMaxWidth(maxFraction)
                .aspectRatio(targetAspect)
        } else {
            if (screenAspect >= targetAspect) {
                Modifier
                    .fillMaxHeight(0.85f)
                    .aspectRatio(targetAspect)
            } else {
                Modifier
                    .fillMaxWidth(0.85f)
                    .aspectRatio(targetAspect)
            }
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "⬜ DEBUG — Mode TV (16:9)",
                color = Color(0xFF00D9FF),
                fontSize = 11.sp,
                modifier = Modifier.padding(bottom = 6.dp)
            )

            Box(
                modifier = containerModifier
                    .clip(RoundedCornerShape(6.dp))
                    .border(2.dp, Color(0xFF00D9FF), RoundedCornerShape(6.dp))
                    .clipToBounds()
                    .background(DeepBlack)
            ) {
                content()
            }

            Text(
                text = "${screenWidthDp.toInt()}×${screenHeightDp.toInt()} dp → TV 16:9",
                color = Color(0x9900D9FF),
                fontSize = 10.sp,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}
