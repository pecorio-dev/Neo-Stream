package dev.neostream.app.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [FavoriteEntity::class, AccountEntity::class, WatchProgressEntity::class], version = 3, exportSchema = false)
abstract class NeoStreamDatabase : RoomDatabase() {
    abstract fun favoriteDao(): FavoriteDao
    abstract fun accountDao(): AccountDao
    abstract fun watchProgressDao(): WatchProgressDao

    companion object {
        @Volatile private var instance: NeoStreamDatabase? = null

        fun getInstance(context: Context): NeoStreamDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    NeoStreamDatabase::class.java,
                    "neostream.db"
                ).fallbackToDestructiveMigration().build().also { instance = it }
            }
    }
}
