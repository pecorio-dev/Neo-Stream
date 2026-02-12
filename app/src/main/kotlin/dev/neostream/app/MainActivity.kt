package dev.neostream.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import dev.neostream.app.player.PlayerManager
import dev.neostream.app.ui.AppContainer
import dev.neostream.app.ui.mobile.screens.SplashScreen
import dev.neostream.app.ui.mobile.navigation.BottomNavBar
import dev.neostream.app.ui.mobile.navigation.NavGraph
import dev.neostream.app.ui.mobile.navigation.Screen
import dev.neostream.app.ui.tv.ProvideTvDimens
import dev.neostream.app.ui.tv.navigation.TvNavGraph
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.NeoStreamTheme
import dev.neostream.app.util.PlatformDetector

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val platformIsTV = PlatformDetector.isTV(this)
        val forceTv = PlatformDetector.isForceTvMode(this)
        val isTV = platformIsTV || forceTv
        val isForcedContainer = forceTv

        setContent {
            NeoStreamTheme(isTV = isTV) {
                AppContainer(isForcedContainer = isForcedContainer) {
                    var showSplash by remember { mutableStateOf(true) }
                    
                    if (showSplash) {
                        SplashScreen(onTimeout = { showSplash = false })
                    } else {
                        if (isTV) {
                            ProvideTvDimens {
                                TvMainScreen()
                            }
                        } else {
                            // Interface Mobile
                            MobileMainScreen()
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        PlayerManager.release()
    }
}

/**
 * Interface Mobile
 */
@Composable
private fun MobileMainScreen() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute by remember {
        derivedStateOf { navBackStackEntry?.destination?.route }
    }

    val showBottomBar by remember {
        derivedStateOf {
            currentRoute in listOf(
                Screen.Home.route,
                Screen.Movies.route,
                Screen.Series.route,
                Screen.Favorites.route,
            )
        }
    }

    Scaffold(
        containerColor = DeepBlack,
        bottomBar = {
            if (showBottomBar) {
                BottomNavBar(
                    currentRoute = currentRoute,
                    onNavigate = { screen ->
                        navController.navigate(screen.route) {
                            popUpTo(Screen.Home.route) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            NavGraph(navController = navController)
        }
    }
}

/**
 * Interface TV
 */
@Composable
private fun TvMainScreen() {
    val navController = rememberNavController()
    // TV fills parent; in forced-container mode, the whole app is already letterboxed by AppContainer
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
    ) {
        TvNavGraph(navController = navController)
    }
}
