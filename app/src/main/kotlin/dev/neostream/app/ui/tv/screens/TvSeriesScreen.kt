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
import dev.neostream.app.ui.mobile.screens.SeriesViewModel
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.tv.components.TvButton
import dev.neostream.app.ui.tv.components.TvRow
import dev.neostream.app.ui.tv.LocalTvDimens
import dev.neostream.app.ui.tv.components.TvSidebar

/**
 * Écran Séries pour TV
 */
@Composable
fun TvSeriesScreen(
   onNavigateToDetail: (String) -> Unit,
   onNavigateToSearch: () -> Unit = {},
   onNavigateToHome: () -> Unit,
   onNavigateToMovies: () -> Unit,
   onNavigateToFavorites: () -> Unit,
   onNavigateToSettings: () -> Unit,
   viewModel: SeriesViewModel = viewModel()
) {
    val d = LocalTvDimens.current
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    
    val currentRoute = "series"
    
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
                   "series" -> { /* Already here */ }
                   "movies" -> onNavigateToMovies()
                   "favorites" -> onNavigateToFavorites()
                   "settings" -> onNavigateToSettings()
               }
           }
        )
        
        // Content
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
                    text = "🔍 Rechercher des Séries",
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
                        title = "Nouvelles séries",
                        items = state.items.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Action
            item {
                val actionSeries = state.items.filter { "Action" in it.genres }
                if (actionSeries.isNotEmpty()) {
                    TvRow(
                        title = "Action & Aventure",
                        items = actionSeries.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Drame
            item {
                val dramaSeries = state.items.filter { "Drame" in it.genres || "Drama" in it.genres }
                if (dramaSeries.isNotEmpty()) {
                    TvRow(
                        title = "Drames",
                        items = dramaSeries.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Thriller
            item {
                val thrillerSeries = state.items.filter { "Thriller" in it.genres }
                if (thrillerSeries.isNotEmpty()) {
                    TvRow(
                        title = "Thriller",
                        items = thrillerSeries.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Comédie
            item {
                val comedySeries = state.items.filter { "Comédie" in it.genres || "Comedy" in it.genres }
                if (comedySeries.isNotEmpty()) {
                    TvRow(
                        title = "Comédies",
                        items = comedySeries.take(10),
                        onItemClick = { item ->
                            onNavigateToDetail(item.id)
                        }
                    )
                }
            }
            
            // Toutes les séries
            if (state.items.size > 10) {
                item {
                    TvRow(
                        title = "Toutes les séries",
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
