package dev.neostream.app.ui.mobile.screens

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dev.neostream.app.data.extractor.UqloadExtractor
import dev.neostream.app.data.local.NeoStreamDatabase
import dev.neostream.app.data.local.SessionManager
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.data.model.WatchLink
import dev.neostream.app.data.repository.MediaRepository
import dev.neostream.app.data.repository.MediaRepository.Companion.toFavoriteEntity
import dev.neostream.app.ui.player.VideoPlayerActivity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class DetailState(
    val item: MediaItem? = null,
    val recommendations: List<MediaItem> = emptyList(),
    val isFavorite: Boolean = false,
    val isLoading: Boolean = false,
    val isLoadingRecommendations: Boolean = false,
    val selectedSeason: Int = 1,
    val error: String? = null,
    val isExtracting: Boolean = false,
    val extractionError: String? = null,
)

class DetailViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = MediaRepository()
    private val favoriteDao = NeoStreamDatabase.getInstance(application).favoriteDao()

    private val _state = MutableStateFlow(DetailState())
    val state: StateFlow<DetailState> = _state

    fun loadDetail(id: String, type: String) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }

            android.util.Log.d("DetailViewModel", "Loading detail for id=$id, type=$type")
            repository.getDetail(id, type)
                .onSuccess { item ->
                    android.util.Log.d("DetailViewModel", "Item loaded: ${item.title}")
                    android.util.Log.d("DetailViewModel", "  type=${item.type}, seasonsCount=${item.seasonsCount}, episodesCount=${item.episodesCount}")
                    android.util.Log.d("DetailViewModel", "  isSerie=${item.isSerie} (computed)")
                    android.util.Log.d("DetailViewModel", "  episodes=${item.episodes.size}, watchLinks=${item.watchLinks.size}")
                    android.util.Log.d("DetailViewModel", "  episodesBySeason keys: ${item.episodesBySeason.keys}")
                    android.util.Log.d("DetailViewModel", "  watchLinks: ${item.watchLinks.take(2).map { "${it.server}: ${it.url.take(50)}" }}")
                    _state.update { it.copy(item = item, isLoading = false) }
                    loadRecommendations(item)
                    val accountId = SessionManager.currentAccountId.value ?: 0L
                    launch {
                        favoriteDao.isFavorite(item.id, accountId).collect { isFav ->
                            _state.update { it.copy(isFavorite = isFav) }
                        }
                    }
                }
                .onFailure { e ->
                    android.util.Log.e("DetailViewModel", "Failed to load detail", e)
                    _state.update { it.copy(isLoading = false, error = e.message) }
                }
        }
    }

    private fun loadRecommendations(source: MediaItem) {
        viewModelScope.launch {
            _state.update { it.copy(isLoadingRecommendations = true) }
            val recs = repository.getRecommendations(source, limit = 20)
            _state.update { it.copy(recommendations = recs, isLoadingRecommendations = false) }
        }
    }

    fun toggleFavorite() {
        val item = _state.value.item ?: return
        val accountId = SessionManager.currentAccountId.value ?: 0L
        viewModelScope.launch {
            if (_state.value.isFavorite) {
                favoriteDao.delete(item.id, accountId)
            } else {
                favoriteDao.insert(item.toFavoriteEntity().copy(accountId = accountId))
            }
        }
    }

    fun selectSeason(season: Int) {
        _state.update { it.copy(selectedSeason = season) }
    }

    fun playLink(link: WatchLink) {
        if (!UqloadExtractor.isUqloadLink(link.url)) return
        val item = _state.value.item ?: return
        
        viewModelScope.launch {
            _state.update { it.copy(isExtracting = true, extractionError = null) }
            UqloadExtractor.extract(link.url)
                .onSuccess { info ->
                    _state.update { it.copy(isExtracting = false) }
                    VideoPlayerActivity.start(
                        context = getApplication(),
                        videoUrl = info.url,
                        title = item.title,
                        headers = info.headers,
                        mediaId = item.id,
                        mediaTitle = item.title,
                        mediaType = if (item.isSerie) "serie" else "film"
                    )
                }
                .onFailure { e ->
                    _state.update { it.copy(isExtracting = false, extractionError = e.message) }
                }
        }
    }

    fun playEpisodeLink(link: WatchLink, episode: dev.neostream.app.data.model.Episode) {
        if (!UqloadExtractor.isUqloadLink(link.url)) return
        val item = _state.value.item ?: return
        
        viewModelScope.launch {
            _state.update { it.copy(isExtracting = true, extractionError = null) }
            UqloadExtractor.extract(link.url)
                .onSuccess { info ->
                    _state.update { it.copy(isExtracting = false) }
                    VideoPlayerActivity.start(
                        context = getApplication(),
                        videoUrl = info.url,
                        title = episode.title.ifBlank { "Episode ${episode.episode}" },
                        headers = info.headers,
                        mediaId = item.id,
                        mediaTitle = item.title,
                        mediaType = "serie",
                        season = episode.season,
                        episode = episode.episode
                    )
                }
                .onFailure { e ->
                    _state.update { it.copy(isExtracting = false, extractionError = e.message) }
                }
        }
    }

    fun dismissExtractionError() {
        _state.update { it.copy(extractionError = null) }
    }
}
