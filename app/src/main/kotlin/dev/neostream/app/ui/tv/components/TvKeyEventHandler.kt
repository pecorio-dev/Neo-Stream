package dev.neostream.app.ui.tv.components

import android.view.KeyEvent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalView
import dev.neostream.app.util.TvKeyHandler

/**
 * Handler global pour les événements clavier TV
 * Permet de capturer les touches avant qu'elles n'atteignent les composants
 */
@Composable
fun TvKeyEventHandler(
    onBack: (() -> Unit)? = null,
    onHome: (() -> Unit)? = null,
    onMenu: (() -> Unit)? = null,
    onSearch: (() -> Unit)? = null,
) {
    val view = LocalView.current
    
    DisposableEffect(view) {
        val listener = android.view.View.OnKeyListener { _, keyCode, event ->
            if (event.action == KeyEvent.ACTION_DOWN) {
                when {
                    // Back
                    TvKeyHandler.isBackKey(keyCode) -> {
                        onBack?.invoke()
                        true
                    }
                    
                    // Home
                    TvKeyHandler.isHomeKey(keyCode) -> {
                        onHome?.invoke()
                        true
                    }
                    
                    // Menu
                    TvKeyHandler.isMenuKey(keyCode) -> {
                        onMenu?.invoke()
                        true
                    }
                    
                    // Search
                    TvKeyHandler.isSearchKey(keyCode, event.metaState) -> {
                        onSearch?.invoke()
                        true
                    }
                    
                    else -> false
                }
            } else {
                false
            }
        }
        
        view.setOnKeyListener(listener)
        view.isFocusableInTouchMode = true
        view.requestFocus()
        
        onDispose {
            view.setOnKeyListener(null)
        }
    }
}
