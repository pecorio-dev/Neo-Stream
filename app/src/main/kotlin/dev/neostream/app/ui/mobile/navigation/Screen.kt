package dev.neostream.app.ui.mobile.navigation

sealed class Screen(val route: String) {
    data object AccountPicker : Screen("account_picker")
    data object Home : Screen("home")
    data object Movies : Screen("movies")
    data object Series : Screen("series")
    data object Favorites : Screen("favorites")
    data object Settings : Screen("settings")
    data object Detail : Screen("detail/{id}/{type}") {
        fun createRoute(id: String, type: String) = "detail/$id/$type"
    }
}
