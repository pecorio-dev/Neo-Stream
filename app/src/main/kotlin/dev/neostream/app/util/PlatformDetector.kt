package dev.neostream.app.util

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration

object PlatformDetector {

    enum class Platform { MOBILE, TV }

    private const val PREF_NAME = "neostream_prefs"
    private const val KEY_FORCE_TV_MODE = "force_tv_mode"
    
    private var cached: Platform? = null

    fun detect(context: Context): Platform {
        // Vérifier d'abord si le mode TV est forcé dans les paramètres
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val forceTvMode = prefs.getBoolean(KEY_FORCE_TV_MODE, false)
        
        if (forceTvMode) {
            return Platform.TV
        }
        
        // Utiliser le cache si disponible
        cached?.let { return it }

        // Détection automatique
        val uiModeManager = context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        val platform = if (uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            Platform.TV
        } else {
            Platform.MOBILE
        }
        cached = platform
        return platform
    }

    fun isTV(context: Context): Boolean = detect(context) == Platform.TV
    
    /**
     * Active/désactive le mode TV forcé
     * ATTENTION: Nécessite un redémarrage de l'app pour prendre effet
     */
    fun setForceTvMode(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_FORCE_TV_MODE, enabled).apply()
        // Vider le cache pour forcer une nouvelle détection
        cached = null
    }
    
    /**
     * Vérifie si le mode TV est forcé
     */
    fun isForceTvMode(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_FORCE_TV_MODE, false)
    }
}
