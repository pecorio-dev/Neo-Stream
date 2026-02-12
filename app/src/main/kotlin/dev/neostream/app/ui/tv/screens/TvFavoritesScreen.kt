package dev.neostream.app.ui.tv.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.neostream.app.ui.mobile.screens.FavoritesViewModel
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.TextSecondary
import dev.neostream.app.ui.tv.LocalTvDimens
import dev.neostream.app.ui.tv.components.TvCard
import dev.neostream.app.ui.tv.components.TvSidebar

/**
 * Écran Favoris pour TV
 */
@Composable
fun TvFavoritesScreen(
   onNavigateToDetail: (String, String) -> Unit,
   onNavigateToHome: () -> Unit,
   onNavigateToMovies: () -> Unit,
   onNavigateToSeries: () -> Unit,
   onNavigateToSettings: () -> Unit,
   viewModel: FavoritesViewModel = viewModel()
) {
    val d = LocalTvDimens.current
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    
    val currentRoute = "favorites"
    
    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
    ) {
        // Sidebar
        TvSidebar(
            currentRoute = currentRoute,
            onNavigate = { route ->
               when (route) {
                   "home" -> onNavigateToHome()
                   "favorites" -> { /* Already here */ }
                   "movies" -> onNavigateToMovies()
                   "series" -> onNavigateToSeries()
                   "settings" -> onNavigateToSettings()
               }
           }
        )
        
        // Content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
                .padding(
                    horizontal = d.contentPadding,
                    vertical = d.gridSpacing
                ),
            verticalArrangement = Arrangement.spacedBy(d.rowSpacing) // Meilleur espacement
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Mes favoris",
                    color = Color.White,
                    fontSize = d.largeTitleSize,
                    fontWeight = FontWeight.Bold
                )
                
                if (state.items.isNotEmpty()) {
                    Text(
                        text = "${state.items.size} élément(s)",
                        color = TextSecondary,
                        fontSize = d.bodySize
                    )
                }
            }
            
            // Grille de favoris
            if (state.items.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(d.episodePadding)
                    ) {
                        Text(
                            text = "", // icon removed
                            fontSize = 64.sp
                        )
                        Text(
                            text = "Aucun favori pour le moment",
                            color = TextSecondary,
                            fontSize = d.sectionTitleSize
                        )
                        Text(
                            text = "Ajoutez des films et séries à vos favoris.",
                            color = TextSecondary,
                            fontSize = d.episodeFontSize
                        )
                    }
                }
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(d.gridMinCellSize),
                    horizontalArrangement = Arrangement.spacedBy(d.gridSpacing),
                    verticalArrangement = Arrangement.spacedBy(d.gridSpacing)
                ) {
                    items(state.items) { item ->
                        TvCard(
                            title = item.title,
                            posterUrl = item.poster,
                            onClick = {
                                onNavigateToDetail(item.id, if (item.isSerie) "serie" else "film")
                            },
                            rating = item.rating,
                            year = item.year
                        )
                    }
                }
            }
        }
    }
}
