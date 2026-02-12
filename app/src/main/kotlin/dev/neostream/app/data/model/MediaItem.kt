package dev.neostream.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class MediaItem(
    val id: String = "",
    val title: String = "",
    @SerialName("original_title") val originalTitle: String = "",
    val url: String = "",
    val poster: String = "",
    val year: String = "",
    @SerialName("type") val type: String = "film",
    val quality: String = "",
    val version: String = "",
    val language: String = "",
    val synopsis: String = "",
    val rating: Float = 0f,
    val genres: List<String> = emptyList(),
    val directors: List<String> = emptyList(),
    val actors: List<String> = emptyList(),
    @SerialName("watch_links") val watchLinks: List<WatchLink> = emptyList(),
    @SerialName("episodes_by_season") val episodesBySeason: Map<String, List<Episode>> = emptyMap(),
    @SerialName("seasons_count") val seasonsCount: Int = 0,
    @SerialName("episodes_count") val episodesCount: Int = 0,
) {
    // L'API retourne toujours "type": "serie", donc on utilise seasons_count et episodes_count
    // pour détecter les vrais films (1 saison, 1 épisode) vs les vraies séries
    val isSerie: Boolean get() = seasonsCount > 1 || episodesCount > 1
    
    val episodes: List<Episode> get() = episodesBySeason.values.flatten().sortedWith(
        compareBy({ it.season }, { it.episode })
    )
}

@Serializable
data class WatchLink(
    val url: String = "",
    val server: String = "",
)

@Serializable
data class Episode(
    val title: String = "",
    val url: String = "",
    val season: Int = 0,
    val episode: Int = 0,
    @SerialName("watch_links") val watchLinks: List<WatchLink> = emptyList(),
)
