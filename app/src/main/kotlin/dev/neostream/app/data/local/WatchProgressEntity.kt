package dev.neostream.app.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "watch_progress")
data class WatchProgressEntity(
    @PrimaryKey val id: String, // Format: "accountId_mediaId" ou "accountId_mediaId_S{season}E{episode}"
    val accountId: Long,
    val mediaId: String,
    val title: String,
    val imageUrl: String = "",
    val contentType: String, // "movie" or "episode"
    
    // Pour les épisodes
    val seriesId: String? = null,
    val seasonNumber: Int? = null,
    val episodeNumber: Int? = null,
    
    // Progression
    val currentPosition: Long, // Position actuelle en ms
    val duration: Long, // Durée totale en ms
    val lastWatched: Long, // Timestamp
    
    // Autres infos
    val year: String = "",
    val quality: String = ""
) {
    val progressPercent: Float
        get() = if (duration > 0) (currentPosition.toFloat() / duration) * 100f else 0f
    
    val isCompleted: Boolean
        get() = duration > 0 && (duration - currentPosition) < 600000 // < 10 minutes restantes (600000ms = 10min)
    
    val remainingTime: Long
        get() = duration - currentPosition
}
