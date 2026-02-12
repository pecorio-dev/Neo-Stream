package dev.neostream.app.data.local

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface FavoriteDao {
    @Query("SELECT * FROM favorites WHERE accountId = :accountId ORDER BY addedAt DESC")
    fun getAll(accountId: Long): Flow<List<FavoriteEntity>>

    @Query("SELECT * FROM favorites WHERE accountId = :accountId AND type = :type ORDER BY addedAt DESC")
    fun getByType(accountId: Long, type: String): Flow<List<FavoriteEntity>>

    @Query("SELECT EXISTS(SELECT 1 FROM favorites WHERE id = :id AND accountId = :accountId)")
    fun isFavorite(id: String, accountId: Long): Flow<Boolean>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(favorite: FavoriteEntity)

    @Query("DELETE FROM favorites WHERE id = :id AND accountId = :accountId")
    suspend fun delete(id: String, accountId: Long)

    @Query("SELECT COUNT(*) FROM favorites WHERE accountId = :accountId")
    fun count(accountId: Long): Flow<Int>

    @Query("DELETE FROM favorites WHERE accountId = :accountId")
    suspend fun deleteAllForAccount(accountId: Long)
}
