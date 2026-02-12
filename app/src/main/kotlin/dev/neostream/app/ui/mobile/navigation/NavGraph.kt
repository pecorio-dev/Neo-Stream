package dev.neostream.app.ui.mobile.navigation

import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import dev.neostream.app.data.local.SessionManager
import dev.neostream.app.ui.mobile.screens.AccountPickerScreen
import dev.neostream.app.ui.mobile.screens.AccountViewModel
import dev.neostream.app.ui.mobile.screens.DetailScreen
import dev.neostream.app.ui.mobile.screens.DetailViewModel
import dev.neostream.app.ui.mobile.screens.FavoritesScreen
import dev.neostream.app.ui.mobile.screens.FavoritesViewModel
import dev.neostream.app.ui.mobile.screens.HomeScreen
import dev.neostream.app.ui.mobile.screens.HomeViewModel
import dev.neostream.app.ui.mobile.screens.MoviesScreen
import dev.neostream.app.ui.mobile.screens.MoviesViewModel
import dev.neostream.app.ui.mobile.screens.SeriesScreen
import dev.neostream.app.ui.mobile.screens.SeriesViewModel
import dev.neostream.app.ui.mobile.screens.SettingsScreen
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue

@Composable
fun NavGraph(navController: NavHostController) {
    // Déterminer l'écran de démarrage en fonction du compte actif
    val currentAccountId by SessionManager.currentAccountId.collectAsState()
    val startDestination = if (currentAccountId == null) {
        Screen.AccountPicker.route
    } else {
        Screen.Home.route
    }
    
    NavHost(
        navController = navController,
        startDestination = startDestination,
        enterTransition = { fadeIn() },
        exitTransition = { fadeOut() },
    ) {
        // Écran de sélection de compte
        composable(Screen.AccountPicker.route) {
            val vm: AccountViewModel = viewModel()
            val accounts by vm.accounts.collectAsState()
            AccountPickerScreen(
                accounts = accounts,
                onSelectAccount = { account, password ->
                    if (vm.login(account, password)) {
                        navController.navigate(Screen.Home.route) {
                            popUpTo(Screen.AccountPicker.route) { inclusive = true }
                        }
                    }
                },
                onCreateAccount = { username, password, avatarIcon, accentColor ->
                    vm.createAccount(username, password, avatarIcon, accentColor)
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.AccountPicker.route) { inclusive = true }
                    }
                },
                onEditAccount = { id, username, password, avatarIcon, accentColor ->
                    vm.updateAccount(id, username, password, avatarIcon, accentColor)
                },
                onDeleteAccount = { id ->
                    vm.deleteAccount(id)
                }
            )
        }
        
        composable(Screen.Home.route) {
            val vm: HomeViewModel = viewModel()
            HomeScreen(
                viewModel = vm,
                onItemClick = { item ->
                    navController.navigate(Screen.Detail.createRoute(item.id, item.type))
                },
                onSettingsClick = { navController.navigate(Screen.Settings.route) },
                onSeeAllClick = { category ->
                    when (category) {
                        "series", "series_recentes" -> navController.navigate(Screen.Series.route) {
                            popUpTo(Screen.Home.route) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                        else -> navController.navigate(Screen.Movies.route) {
                            popUpTo(Screen.Home.route) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                },
            )
        }

        composable(Screen.Movies.route) {
            val vm: MoviesViewModel = viewModel()
            MoviesScreen(
                viewModel = vm,
                onItemClick = { item ->
                    navController.navigate(Screen.Detail.createRoute(item.id, item.type))
                },
                onSettingsClick = { navController.navigate(Screen.Settings.route) },
            )
        }

        composable(Screen.Series.route) {
            val vm: SeriesViewModel = viewModel()
            SeriesScreen(
                viewModel = vm,
                onItemClick = { item ->
                    navController.navigate(Screen.Detail.createRoute(item.id, item.type))
                },
                onSettingsClick = { navController.navigate(Screen.Settings.route) },
            )
        }

        composable(Screen.Favorites.route) {
            val vm: FavoritesViewModel = viewModel()
            FavoritesScreen(
                viewModel = vm,
                onItemClick = { item ->
                    navController.navigate(Screen.Detail.createRoute(item.id, item.type))
                },
                onSettingsClick = { navController.navigate(Screen.Settings.route) },
            )
        }

        composable(
            route = Screen.Detail.route,
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("type") { type = NavType.StringType },
            ),
            enterTransition = { slideInHorizontally { it } + fadeIn() },
            exitTransition = { slideOutHorizontally { it } + fadeOut() },
        ) { backStackEntry ->
            val id = backStackEntry.arguments?.getString("id") ?: return@composable
            val type = backStackEntry.arguments?.getString("type") ?: "film"
            val vm: DetailViewModel = viewModel()
            DetailScreen(
                viewModel = vm,
                id = id,
                type = type,
                onBackClick = { navController.popBackStack() },
                onSettingsClick = { navController.navigate(Screen.Settings.route) },
                onItemClick = { item ->
                    navController.navigate(Screen.Detail.createRoute(item.id, item.type))
                },
            )
        }

        composable(
            route = Screen.Settings.route,
            enterTransition = { slideInHorizontally { it } + fadeIn() },
            exitTransition = { slideOutHorizontally { it } + fadeOut() },
        ) { backStackEntry ->
            val context = androidx.compose.ui.platform.LocalContext.current
            SettingsScreen(
                onBackClick = { navController.popBackStack() },
                onSwitchAccount = {
                    SessionManager.logout(context)
                    navController.navigate(Screen.AccountPicker.route) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }
    }
}
