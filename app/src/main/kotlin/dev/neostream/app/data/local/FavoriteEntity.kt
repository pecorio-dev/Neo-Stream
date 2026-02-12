package dev.neostream.app.data.local

import androidx.room.Entity

@Entity(tableName = "favorites", primaryKeys = ["id", "accountId"])
data class FavoriteEntity(
    val id: String,
    val accountId: Long = 0,
    val title: String,
    val poster: String,
    val year: String,
    val type: String,
    val rating: Float,
    val quality: String,
    val url: String,
    val addedAt: Long = System.currentTimeMillis(),
)
