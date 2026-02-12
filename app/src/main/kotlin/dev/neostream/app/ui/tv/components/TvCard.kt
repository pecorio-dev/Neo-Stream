package dev.neostream.app.ui.tv.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.TextSecondary
import dev.neostream.app.ui.tv.LocalTvDimens

/**
 * Carte média optimisée pour TV
 * Taille: 280x420dp (ratio 2:3 comme poster)
 */
@Composable
fun TvCard(
    title: String,
    posterUrl: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    rating: Float? = null,
    year: String? = null,
) {
    val d = LocalTvDimens.current
    TvFocusable(
        onClick = onClick,
        modifier = modifier
            .width(d.cardWidthLarge)
            .height(d.cardHeightLarge),
        cornerRadius = 12f,
        scaleOnFocus = 1.08f // Réduit de 1.1 à 1.08 pour éviter les débordements
    ) { isFocused ->
        Box {
            // Poster image
            AsyncImage(
                model = posterUrl,
                contentDescription = title,
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(12.dp)),
                contentScale = ContentScale.Crop
            )
            
            // Gradient overlay en bas pour le texte
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(d.gradientHeight)
                    .align(Alignment.BottomCenter)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                Color.Black.copy(alpha = 0.9f)
                            )
                        )
                    )
            )
            
            // Informations texte
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .padding(d.episodePadding)
            ) {
                // Titre
                Text(
                    text = title,
                    color = Color.White,
                    fontSize = if (isFocused) d.bodySize else d.episodeFontSize,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                
                Spacer(Modifier.height(4.dp))
                
                // Métadonnées (rating, année)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    rating?.let {
                        Text(
                            text = "%.1f/10".format(it),
                            color = AccentCyan,
                            fontSize = d.tinySize,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    
                    year?.let {
                        Text(
                            text = it,
                            color = TextSecondary,
                            fontSize = d.tinySize
                        )
                    }
                }
                
                // Subtitle optionnel
                subtitle?.let {
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = it,
                        color = TextSecondary,
                        fontSize = d.tinySize,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            
            // Indicateur de focus (optionnel - déjà géré par TvFocusable)
            if (isFocused) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .align(Alignment.TopEnd)
                        .padding(12.dp)
                        .background(AccentCyan, shape = RoundedCornerShape(4.dp))
                )
            }
        }
    }
}

/**
 * Carte compacte pour les rows de contenu
 * Taille: 200x300dp
 */
@Composable
fun TvCardCompact(
    title: String,
    posterUrl: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    rating: Float? = null,
    year: String? = null,
) {
    val d = LocalTvDimens.current
    TvFocusable(
        onClick = onClick,
        modifier = modifier
            .width(d.cardWidth)
            .height(d.cardHeight),
        scaleOnFocus = 1.12f, // Réduit de 1.15 à 1.12 pour meilleure performance
        cornerRadius = 8f
    ) { isFocused ->
        Box {
            AsyncImage(
                model = posterUrl,
                contentDescription = title,
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(8.dp)),
                contentScale = ContentScale.Crop
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                Color.Black.copy(alpha = 0.85f)
                            )
                        )
                    )
                    .padding(d.seasonPaddingV)
            ) {
                Column {
                    Text(
                        text = title,
                        color = Color.White,
                        fontSize = d.tinySize,
                        fontWeight = FontWeight.Bold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        rating?.takeIf { it > 0 }?.let {
                            Text(
                                text = "%.1f".format(it),
                                color = AccentCyan,
                                fontSize = d.tinySize,
                                fontWeight = FontWeight.Medium
                            )
                        }
                        year?.takeIf { it.isNotBlank() }?.let {
                            Text(
                                text = it,
                                color = TextSecondary,
                                fontSize = d.tinySize
                            )
                        }
                    }
                }
            }
        }
    }
}
