package dev.neostream.app.ui.mobile.screens

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.neostream.app.data.local.WatchProgressEntity
import dev.neostream.app.data.repository.WatchProgressRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class WatchProgressViewModel : ViewModel() {
    
    private val _inProgressItems = MutableStateFlow<List<WatchProgressEntity>>(emptyList())
    val inProgressItems: StateFlow<List<WatchProgressEntity>> = _inProgressItems
    
    fun loadInProgress(context: Context) {
        viewModelScope.launch {
            val repository = WatchProgressRepository(context)
            repository.getInProgress().collect { items ->
                _inProgressItems.value = items
            }
        }
    }
    
    suspend fun saveMovieProgress(
        context: Context,
        movieId: String,
        title: String,
        currentPosition: Long,
        duration: Long,
        imageUrl: String = "",
        year: String = "",
        quality: String = ""
    ) {
        val repository = WatchProgressRepository(context)
        repository.saveMovieProgress(
            movieId = movieId,
            title = title,
            currentPosition = currentPosition,
            duration = duration,
            imageUrl = imageUrl,
            year = year,
            quality = quality
        )
    }
    
    suspend fun saveEpisodeProgress(
        context: Context,
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
        val repository = WatchProgressRepository(context)
        repository.saveEpisodeProgress(
            seriesId = seriesId,
            seasonNumber = seasonNumber,
            episodeNumber = episodeNumber,
            seriesTitle = seriesTitle,
            episodeTitle = episodeTitle,
            currentPosition = currentPosition,
            duration = duration,
            imageUrl = imageUrl,
            year = year,
            quality = quality
        )
    }
    
    suspend fun getProgress(context: Context, id: String): WatchProgressEntity? {
        val repository = WatchProgressRepository(context)
        return repository.getProgressById(id)
    }
}
