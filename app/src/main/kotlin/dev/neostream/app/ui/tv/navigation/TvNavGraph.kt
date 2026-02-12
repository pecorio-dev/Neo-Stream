package dev.neostream.app.ui.tv.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalView
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import dev.neostream.app.ui.tv.components.TvKeyEventHandler
import dev.neostream.app.ui.tv.screens.*

/**
 * Navigation graph pour interface TV
 */
@Composable
fun TvNavGraph(
    navController: NavHostController,
    startDestination: String = "tv_home"
) {
    // Gestion globale des touches de télécommande
    TvKeyEventHandler(
        onBack = {
            if (!navController.popBackStack()) {
                // Si on est déjà sur l'écran principal, ne rien faire
                // L'utilisateur peut quitter l'app avec la touche Home de la télécommande
            }
        },
        onHome = {
            // Retour à l'écran d'accueil
            navController.navigate("tv_home") {
                popUpTo("tv_home") { inclusive = false }
            }
        },
        onMenu = {
            // Ouvrir les paramètres avec la touche Menu
            navController.navigate("tv_settings")
        },
        onSearch = {
            // Ouvrir la recherche avec la touche Search
            navController.navigate("tv_search")
        }
    )
    
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // Account Picker (sélection de profil)
        composable("tv_account_picker") {
            TvAccountPickerScreen(
                onAccountSelected = {
                    navController.navigate("tv_home") {
                        popUpTo("tv_account_picker") { inclusive = true }
                    }
                }
            )
        }
        
        // Home
        composable("tv_home") {
            TvHomeScreen(
                onNavigateToDetail = { id, type ->
                    navController.navigate("tv_detail/$id/$type")
                },
                onNavigateToMovies = {
                    navController.navigate("tv_movies")
                },
                onNavigateToSeries = {
                    navController.navigate("tv_series")
                },
                onNavigateToFavorites = {
                    navController.navigate("tv_favorites")
                },
                onNavigateToSettings = {
                    navController.navigate("tv_settings")
                }
            )
        }
        
        // Movies
        composable("tv_movies") {
            TvMoviesScreen(
               onNavigateToDetail = { id ->
                   navController.navigate("tv_detail/$id/film")
               },
               onNavigateToSearch = {
                   navController.navigate("tv_search_films")
               },
               onNavigateToHome = {
                   navController.navigate("tv_home") { popUpTo("tv_home") { inclusive = false } }
               },
               onNavigateToSeries = { navController.navigate("tv_series") },
               onNavigateToFavorites = { navController.navigate("tv_favorites") },
               onNavigateToSettings = { navController.navigate("tv_settings") }
           )
        }
        
        // Series
        composable("tv_series") {
            TvSeriesScreen(
               onNavigateToDetail = { id ->
                   navController.navigate("tv_detail/$id/serie")
               },
               onNavigateToSearch = {
                   navController.navigate("tv_search_series")
               },
               onNavigateToHome = { navController.navigate("tv_home") { popUpTo("tv_home") { inclusive = false } } },
               onNavigateToMovies = { navController.navigate("tv_movies") },
               onNavigateToFavorites = { navController.navigate("tv_favorites") },
               onNavigateToSettings = { navController.navigate("tv_settings") }
           )
        }
        
        // Detail
        composable(
            route = "tv_detail/{id}/{type}",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("type") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val id = backStackEntry.arguments?.getString("id") ?: return@composable
            val type = backStackEntry.arguments?.getString("type") ?: "film"
            
            TvDetailScreen(
               mediaId = id,
               mediaType = type,
               onBack = { navController.popBackStack() },
               onNavigateToDetail = { newId, newType ->
                   navController.navigate("tv_detail/$newId/$newType")
               }
           )
        }
        
        // Search Films
        composable("tv_search_films") {
            TvSearchFilmsScreen(
                onNavigateToDetail = { id ->
                    navController.navigate("tv_detail/$id/film")
                },
                onNavigateToHome = { navController.navigate("tv_home") { popUpTo("tv_home") { inclusive = false } } },
                onNavigateToMovies = { navController.navigate("tv_movies") },
                onNavigateToSeries = { navController.navigate("tv_series") },
                onNavigateToFavorites = { navController.navigate("tv_favorites") },
                onNavigateToSettings = { navController.navigate("tv_settings") }
            )
        }
        
        // Search Series
        composable("tv_search_series") {
            TvSearchSeriesScreen(
                onNavigateToDetail = { id ->
                    navController.navigate("tv_detail/$id/serie")
                },
                onNavigateToHome = { navController.navigate("tv_home") { popUpTo("tv_home") { inclusive = false } } },
                onNavigateToMovies = { navController.navigate("tv_movies") },
                onNavigateToSeries = { navController.navigate("tv_series") },
                onNavigateToFavorites = { navController.navigate("tv_favorites") },
                onNavigateToSettings = { navController.navigate("tv_settings") }
            )
        }
        
        // Search (générique - redirige vers films)
        composable("tv_search") {
            TvSearchScreen(
                onNavigateToDetail = { id, type ->
                    navController.navigate("tv_detail/$id/$type")
                },
                onBack = { navController.popBackStack() }
            )
        }
        
        // Favorites
        composable("tv_favorites") {
           TvFavoritesScreen(
               onNavigateToDetail = { id, type ->
                   navController.navigate("tv_detail/$id/$type")
               },
               onNavigateToHome = { navController.navigate("tv_home") { popUpTo("tv_home") { inclusive = false } } },
               onNavigateToMovies = { navController.navigate("tv_movies") },
               onNavigateToSeries = { navController.navigate("tv_series") },
               onNavigateToSettings = { navController.navigate("tv_settings") }
           )
       }
        
        // Settings
        composable("tv_settings") {
           TvSettingsScreen(
               onNavigateToHome = { navController.navigate("tv_home") { popUpTo("tv_home") { inclusive = false } } },
               onNavigateToMovies = { navController.navigate("tv_movies") },
               onNavigateToSeries = { navController.navigate("tv_series") },
               onNavigateToFavorites = { navController.navigate("tv_favorites") }
           )
       }
    }
}
