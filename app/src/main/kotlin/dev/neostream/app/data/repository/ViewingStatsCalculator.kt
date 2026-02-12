package dev.neostream.app.data.repository

import android.content.Context
import kotlin.math.roundToInt

/**
 * Calcule les coûts de visionnage basés sur les prix moyens du marché
 * 
 * CALCUL RÉALISTE basé sur l'usage réel:
 * 
 * Prix de référence (France, 2024):
 * - Netflix Standard: 13.49€/mois
 * - Amazon Prime Video: 6.99€/mois
 * - Disney+: 8.99€/mois
 * - Canal+: 21€/mois
 * → Moyenne streaming: ~12.60€/mois
 * 
 * Consommation moyenne: ~30 contenus/mois (1 par jour)
 * → Prix de base par contenu: 12.60 / 30 = 0.42€
 * 
 * Ajustement selon durée:
 * - Film (2h en moyenne): 0.42€ × 1.5 = 0.63€
 * - Épisode série (40min): 0.42€ × 0.7 = 0.29€
 * 
 * Cinéma (comparaison uniquement):
 * - Prix réel: ~11€ mais personne ne va au cinéma pour tout
 * - Prix ajusté: 11 / 2 = 5.50€ (plus réaliste)
 */
object ViewingStatsCalculator {
    
    // Prix moyens du marché
    private const val CINEMA_PRICE = 5.50 // Prix cinéma ajusté (divisé par 2 car irréaliste pour tous les films)
    private const val AVERAGE_STREAMING_PRICE_PER_MONTH = 12.60 // Moyenne des plateformes
    private const val AVERAGE_CONTENT_PER_MONTH = 30.0 // ~1 contenu par jour
    
    // Prix calculé par contenu (basé sur durée moyenne)
    const val COST_PER_FILM = 0.63 // Film de 2h: prix de base × 1.5
    const val COST_PER_EPISODE = 0.29 // Épisode de 40min: prix de base × 0.7
    
    data class ViewingStats(
        val totalFilmsWatched: Int,
        val totalEpisodesWatched: Int,
        val totalContentWatched: Int,
        val estimatedCostStreaming: Double, // Coût si payé en streaming
        val estimatedCostCinema: Double,   // Coût si vu au cinéma
        val savedAmount: Double,            // Économies réalisées
        val savedPercentage: Double,        // Pourcentage d'économie
    ) {
        fun formatCostStreaming(): String = "%.2f €".format(estimatedCostStreaming)
        fun formatCostCinema(): String = "%.0f €".format(estimatedCostCinema)
        fun formatSaved(): String = "%.2f €".format(savedAmount)
        fun formatSavedPercentage(): String = "${savedPercentage.roundToInt()}%"
    }
    
    suspend fun calculateStats(context: Context): ViewingStats {
        val repository = WatchProgressRepository(context)
        
        val totalFilms = repository.getCompletedMoviesCount()
        val totalEpisodes = repository.getCompletedEpisodesCount()
        val totalContent = totalFilms + totalEpisodes
        
        // Coût RÉALISTE si payé en streaming (Netflix, etc.)
        val streamingCost = (totalFilms * COST_PER_FILM) + (totalEpisodes * COST_PER_EPISODE)
        
        // Coût si vu au cinéma (seulement films, séries pas disponibles au cinéma)
        val cinemaCost = totalFilms * CINEMA_PRICE
        
        // ÉCONOMIES = coût streaming qu'on aurait payé (car NeoStream est gratuit)
        val saved = streamingCost
        
        // Pourcentage d'économie = 100% car on paie 0€ au lieu du coût streaming
        val savedPercentage = 100.0
        
        return ViewingStats(
            totalFilmsWatched = totalFilms,
            totalEpisodesWatched = totalEpisodes,
            totalContentWatched = totalContent,
            estimatedCostStreaming = streamingCost,
            estimatedCostCinema = cinemaCost,
            savedAmount = saved,  // Économies basées sur le coût streaming réaliste
            savedPercentage = savedPercentage
        )
    }
    
    /**
     * Génère un message encourageant basé sur les économies
     */
    fun getEncouragementMessage(stats: ViewingStats): String {
        return when {
            stats.savedAmount < 10 -> "Vous avez déjà économisé ${stats.formatSaved()} !"
            stats.savedAmount < 50 -> "Vous avez économisé ${stats.formatSaved()} grâce à NeoStream"
            stats.savedAmount < 100 -> "WOW ! ${stats.formatSaved()} d'économies réalisées !"
            stats.savedAmount < 500 -> "INCROYABLE ! Vous avez économisé ${stats.formatSaved()} !"
            else -> "EXCEPTIONNEL ! ${stats.formatSaved()} économisés grâce à NeoStream !"
        }
    }
    
    /**
     * Message de responsabilité et encouragement au don
     */
    fun getResponsibilityMessage(stats: ViewingStats): String {
        val coffeeCount = getCoffeeEquivalent(stats)
        return when {
            coffeeCount < 3 -> "⚠️ NeoStream est gratuit. Utilisez les sites officiels pour soutenir les créateurs."
            coffeeCount < 10 -> "💡 Soutenez le développement : un café = plusieurs heures de code !"
            coffeeCount < 30 -> "🙏 Avec ${coffeeCount} cafés économisés, un don soutiendrait énormément le projet !"
            else -> "❤️ ${coffeeCount} cafés économisés ! Même un petit don fait une ÉNORME différence !"
        }
    }
    
    /**
     * Équivalence en nombre de cafés Ko-fi (3€ par café)
     */
    fun getCoffeeEquivalent(stats: ViewingStats): Int {
        return (stats.savedAmount / 3.0).toInt()
    }
}
