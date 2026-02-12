package dev.neostream.app.util

import android.view.KeyEvent
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.focus.FocusManager

/**
 * Gestionnaire de touches pour interface TV
 * 
 * Mapping télécommande/clavier:
 * - D-pad (Up/Down/Left/Right) → Arrow keys ou WASD
 * - SELECT/OK → Enter ou Space
 * - BACK → Backspace ou Esc
 * - HOME → H
 * - SEARCH → Ctrl+F
 * - MENU → M
 */
object TvKeyHandler {
    
    /**
     * Gère les événements clavier pour navigation D-pad
     * @return true si la touche a été gérée, false sinon
     */
    fun handleDpadNavigation(
        keyCode: Int,
        focusManager: FocusManager
    ): Boolean {
        return when (keyCode) {
            // UP - W ou Arrow Up
            KeyEvent.KEYCODE_W,
            KeyEvent.KEYCODE_DPAD_UP -> {
                focusManager.moveFocus(FocusDirection.Up)
                true
            }
            
            // DOWN - S ou Arrow Down
            KeyEvent.KEYCODE_S,
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                focusManager.moveFocus(FocusDirection.Down)
                true
            }
            
            // LEFT - A ou Arrow Left
            KeyEvent.KEYCODE_A,
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                focusManager.moveFocus(FocusDirection.Left)
                true
            }
            
            // RIGHT - D ou Arrow Right
            KeyEvent.KEYCODE_D,
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                focusManager.moveFocus(FocusDirection.Right)
                true
            }
            
            else -> false
        }
    }
    
    /**
     * Vérifie si c'est une touche de sélection (Enter/Space)
     */
    fun isSelectKey(keyCode: Int): Boolean {
        return keyCode == KeyEvent.KEYCODE_ENTER ||
               keyCode == KeyEvent.KEYCODE_SPACE ||
               keyCode == KeyEvent.KEYCODE_DPAD_CENTER
    }
    
    /**
     * Vérifie si c'est une touche de retour (Back/Esc)
     */
    fun isBackKey(keyCode: Int): Boolean {
        return keyCode == KeyEvent.KEYCODE_BACK ||
               keyCode == KeyEvent.KEYCODE_ESCAPE ||
               keyCode == KeyEvent.KEYCODE_DEL
    }
    
    /**
     * Vérifie si c'est une touche Home (H)
     */
    fun isHomeKey(keyCode: Int): Boolean {
        return keyCode == KeyEvent.KEYCODE_H
    }
    
    /**
     * Vérifie si c'est une touche Menu (M)
     */
    fun isMenuKey(keyCode: Int): Boolean {
        return keyCode == KeyEvent.KEYCODE_M ||
               keyCode == KeyEvent.KEYCODE_MENU
    }
    
    /**
     * Vérifie si c'est une touche Search (Ctrl+F)
     */
    fun isSearchKey(keyCode: Int, metaState: Int): Boolean {
        return (keyCode == KeyEvent.KEYCODE_F && (metaState and KeyEvent.META_CTRL_ON) != 0) ||
               keyCode == KeyEvent.KEYCODE_SEARCH
    }
}
