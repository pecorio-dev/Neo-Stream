package dev.neostream.app.data.local

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface WatchProgressDao {
    
    @Query("SELECT * FROM watch_progress WHERE accountId = :accountId ORDER BY lastWatched DESC")
    fun getAllForAccount(accountId: Long): Flow<List<WatchProgressEntity>>
    
    @Query("SELECT COUNT(*) FROM watch_progress WHERE accountId = :accountId AND contentType = 'movie' AND (duration - currentPosition) < 600000")
    suspend fun getCompletedMoviesCount(accountId: Long): Int
    
    @Query("SELECT COUNT(*) FROM watch_progress WHERE accountId = :accountId AND contentType = 'episode' AND (duration - currentPosition) < 600000")
    suspend fun getCompletedEpisodesCount(accountId: Long): Int
    
    @Query("SELECT * FROM watch_progress WHERE accountId = :accountId AND (duration - currentPosition) >= 600000 ORDER BY lastWatched DESC")
    fun getInProgressForAccount(accountId: Long): Flow<List<WatchProgressEntity>>
    
    @Query("SELECT * FROM watch_progress WHERE id = :id")
    suspend fun getById(id: String): WatchProgressEntity?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(progress: WatchProgressEntity)
    
    @Update
    suspend fun update(progress: WatchProgressEntity)
    
    @Delete
    suspend fun delete(progress: WatchProgressEntity)
    
    @Query("DELETE FROM watch_progress WHERE accountId = :accountId")
    suspend fun deleteAllForAccount(accountId: Long)
}
