package dev.neostream.app.ui.tv.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Search
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.neostream.app.ui.mobile.screens.MoviesViewModel
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.tv.components.TvButton
import dev.neostream.app.ui.tv.components.TvRow
import dev.neostream.app.ui.tv.LocalTvDimens
import dev.neostream.app.ui.tv.components.TvSidebar

/**
 * Écran Films pour TV
 */
@Composable
fun TvMoviesScreen(
   onNavigateToDetail: (String) -> Unit,
   onNavigateToSearch: () -> Unit = {},
   onNavigateToHome: () -> Unit,
   onNavigateToSeries: () -> Unit,
   onNavigateToFavorites: () -> Unit,
   onNavigateToSettings: () -> Unit,
   viewModel: MoviesViewModel = viewModel()
) {
    val d = LocalTvDimens.current
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    
    val currentRoute = "movies"
    
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
                   "movies" -> { /* Already here */ }
                   "series" -> onNavigateToSeries()
                   "favorites" -> onNavigateToFavorites()
                   "settings" -> onNavigateToSettings()
               }
           }
        )
        
        // Content - Grille de films
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f),
            verticalArrangement = Arrangement.spacedBy(d.sectionSpacing),
            contentPadding = PaddingValues(vertical = d.contentPadding)
        ) {
            // Bouton Recherche en haut
            item {
                TvButton(
                    text = "🔍 Rechercher des Films",
                    onClick = onNavigateToSearch,
                    icon = Icons.Rounded.Search,
                    isPrimary = true,
                    modifier = Modifier.padding(horizontal = d.rowPadding)
                )
            }
            // Nouveautés
            if (state.items.isNotEmpty()) {
                item {
                    TvRow(
                        title = "Nouveautés",
                        items = state.items.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Action
            item {
                val actionMovies = state.items.filter { "Action" in it.genres }
                if (actionMovies.isNotEmpty()) {
                    TvRow(
                        title = "Action",
                        items = actionMovies.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Comédie
            item {
                val comedyMovies = state.items.filter { "Comédie" in it.genres || "Comedy" in it.genres }
                if (comedyMovies.isNotEmpty()) {
                    TvRow(
                        title = "Comédie",
                        items = comedyMovies.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Drame
            item {
                val dramaMovies = state.items.filter { "Drame" in it.genres || "Drama" in it.genres }
                if (dramaMovies.isNotEmpty()) {
                    TvRow(
                        title = "Drame",
                        items = dramaMovies.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Science-Fiction
            item {
                val scifiMovies = state.items.filter { 
                    "Science-Fiction" in it.genres || "Sci-Fi" in it.genres 
                }
                if (scifiMovies.isNotEmpty()) {
                    TvRow(
                        title = "Science-Fiction",
                        items = scifiMovies.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Tous les films
            if (state.items.size > 10) {
                item {
                    TvRow(
                        title = "Tous les films",
                        items = state.items,
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
        }
    }
}
