package dev.neostream.app.ui.mobile.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.data.repository.MediaRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class HomeState(
    val featuredItem: MediaItem? = null,
    val trending: List<MediaItem> = emptyList(),
    val recentFilms: List<MediaItem> = emptyList(),
    val recentSeries: List<MediaItem> = emptyList(),
    val topRated: List<MediaItem> = emptyList(),
    val randomPicks: List<MediaItem> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val error: String? = null,
) {
    val isEmpty: Boolean
        get() = featuredItem == null &&
                trending.isEmpty() &&
                recentFilms.isEmpty() &&
                recentSeries.isEmpty() &&
                topRated.isEmpty() &&
                randomPicks.isEmpty()
}

class HomeViewModel(
    private val repository: MediaRepository = MediaRepository(),
) : ViewModel() {

    private val _state = MutableStateFlow(HomeState())
    val state: StateFlow<HomeState> = _state

    init {
        loadHome()
    }

    private fun loadHome() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }

            val trending = async { repository.getRecent(limit = 20) }
            val films = async { repository.getRecent(type = "film", limit = 30) }
            val series = async { repository.getRecent(type = "serie", limit = 30) }
            val top = async { repository.getTopRated(limit = 30) }
            val random = async { repository.getRandom(count = 20) }

            val trendingResult = trending.await()
            val filmsResult = films.await()
            val seriesResult = series.await()
            val topResult = top.await()
            val randomResult = random.await()

            val topList = topResult.getOrDefault(emptyList())
            val featured = topList.filter { it.poster.isNotBlank() }.randomOrNull()

            _state.update {
                it.copy(
                    featuredItem = featured,
                    trending = trendingResult.getOrDefault(emptyList()),
                    recentFilms = filmsResult.getOrDefault(emptyList()),
                    recentSeries = seriesResult.getOrDefault(emptyList()),
                    topRated = topList,
                    randomPicks = randomResult.getOrDefault(emptyList()),
                    isLoading = false,
                    isRefreshing = false,
                    error = if (filmsResult.isFailure && seriesResult.isFailure && topResult.isFailure) {
                        filmsResult.exceptionOrNull()?.message ?: "Erreur de connexion"
                    } else null,
                )
            }
        }
    }

    fun refresh() {
        _state.update { it.copy(isRefreshing = true) }
        loadHome()
    }
}
