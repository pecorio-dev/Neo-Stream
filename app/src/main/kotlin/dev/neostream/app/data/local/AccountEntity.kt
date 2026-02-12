package dev.neostream.app.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "accounts")
data class AccountEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val username: String,
    val passwordHash: String = "",
    val avatarIcon: String = "person",
    val accentColor: Long = 0xFF00D9FF,
    val createdAt: Long = System.currentTimeMillis(),
)
