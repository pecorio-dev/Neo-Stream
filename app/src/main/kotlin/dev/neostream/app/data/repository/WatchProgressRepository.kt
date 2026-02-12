package dev.neostream.app.data.repository

import android.content.Context
import dev.neostream.app.data.local.NeoStreamDatabase
import dev.neostream.app.data.local.SessionManager
import dev.neostream.app.data.local.WatchProgressEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.firstOrNull

class WatchProgressRepository(private val context: Context) {
    private val dao = NeoStreamDatabase.getInstance(context).watchProgressDao()
    
    suspend fun saveMovieProgress(
        movieId: String,
        title: String,
        currentPosition: Long,
        duration: Long,
        imageUrl: String = "",
        year: String = "",
        quality: String = ""
    ) {
        val accountId = SessionManager.currentAccountId.firstOrNull() ?: return
        val id = "${accountId}_${movieId}"
        
        val progress = WatchProgressEntity(
            id = id,
            accountId = accountId,
            mediaId = movieId,
            title = title,
            imageUrl = imageUrl,
            contentType = "movie",
            currentPosition = currentPosition,
            duration = duration,
            lastWatched = System.currentTimeMillis(),
            year = year,
            quality = quality
        )
        
        dao.insert(progress)
    }
    
    suspend fun saveEpisodeProgress(
        seriesId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        seriesTitle: String,
        episodeTitle: String,
        currentPosition: Long,
        duration: Long,
        imageUrl: String = "",
        year: String = "",
        quality: String = ""
    ) {
        val accountId = SessionManager.currentAccountId.firstOrNull() ?: return
        val id = "${accountId}_${seriesId}_S${seasonNumber}E${episodeNumber}"
        
        val progress = WatchProgressEntity(
            id = id,
            accountId = accountId,
            mediaId = seriesId,
            title = episodeTitle,
            imageUrl = imageUrl,
            contentType = "episode",
            seriesId = seriesId,
            seasonNumber = seasonNumber,
            episodeNumber = episodeNumber,
            currentPosition = currentPosition,
            duration = duration,
            lastWatched = System.currentTimeMillis(),
            year = year,
            quality = quality
        )
        
        dao.insert(progress)
    }
    
    suspend fun getProgressById(id: String): WatchProgressEntity? {
        return dao.getById(id)
    }
    
    suspend fun getCompletedMoviesCount(): Int {
        val accountId = SessionManager.currentAccountId.firstOrNull() ?: return 0
        return dao.getCompletedMoviesCount(accountId)
    }
    
    suspend fun getCompletedEpisodesCount(): Int {
        val accountId = SessionManager.currentAccountId.firstOrNull() ?: return 0
        return dao.getCompletedEpisodesCount(accountId)
    }
    
    fun getAllProgress(): Flow<List<WatchProgressEntity>> {
        val accountId = SessionManager.currentAccountId.value ?: return kotlinx.coroutines.flow.flowOf(emptyList())
        return dao.getAllForAccount(accountId)
    }
    
    fun getInProgress(): Flow<List<WatchProgressEntity>> {
        val accountId = SessionManager.currentAccountId.value ?: return kotlinx.coroutines.flow.flowOf(emptyList())
        return dao.getInProgressForAccount(accountId)
    }
}
