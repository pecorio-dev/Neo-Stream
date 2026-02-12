package dev.neostream.app.ui.mobile.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class SeriesState(
    val items: List<MediaItem> = emptyList(),
    val genres: List<String> = emptyList(),
    val selectedGenre: String? = null,
    val searchQuery: String = "",
    val sortOption: SortOption = SortOption.RECENT,
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val error: String? = null,
    val offset: Int = 0,
    val total: Int = 0,
    val hasMore: Boolean = true,
)

class SeriesViewModel(
    private val repository: MediaRepository = MediaRepository(),
) : ViewModel() {

    private val _state = MutableStateFlow(SeriesState())
    val state: StateFlow<SeriesState> = _state

    companion object {
        private const val PAGE_SIZE = 30
    }

    init {
        loadGenres()
        loadInitial()
    }

    private fun loadGenres() {
        viewModelScope.launch {
            repository.getGenres().onSuccess { genres ->
                _state.update { it.copy(genres = genres) }
            }
        }
    }

    private fun loadInitial() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null, offset = 0, items = emptyList()) }
            fetchItems(offset = 0)
        }
    }

    private suspend fun fetchItems(offset: Int) {
        val query = _state.value.searchQuery
        val genre = _state.value.selectedGenre
        val sort = _state.value.sortOption

        val result = when {
            query.isNotBlank() -> repository.search(query, type = "serie")
            genre != null -> repository.getGenreItems(genre, type = "serie", limit = PAGE_SIZE)
            else -> repository.getSeries(limit = PAGE_SIZE, offset = offset).map { paginated ->
                _state.update { it.copy(total = paginated.total) }
                paginated.data
            }
        }

        result.onSuccess { newItems ->
            val sorted = sortItems(newItems, sort)
            _state.update { current ->
                val allItems = if (offset == 0) sorted else current.items + sorted
                current.copy(
                    items = allItems,
                    isLoading = false,
                    isLoadingMore = false,
                    offset = offset + newItems.size,
                    hasMore = newItems.size >= PAGE_SIZE && query.isBlank() && genre == null,
                )
            }
        }.onFailure { e ->
            _state.update { it.copy(isLoading = false, isLoadingMore = false, error = e.message) }
        }
    }

    fun loadMore() {
        val current = _state.value
        if (current.isLoadingMore || !current.hasMore || current.searchQuery.isNotBlank() || current.selectedGenre != null) return
        viewModelScope.launch {
            _state.update { it.copy(isLoadingMore = true) }
            fetchItems(offset = current.offset)
        }
    }

    fun setSearchQuery(query: String) {
        _state.update { it.copy(searchQuery = query) }
        loadInitial()
    }

    fun setGenre(genre: String?) {
        _state.update { it.copy(selectedGenre = genre) }
        loadInitial()
    }

    fun setSortOption(option: SortOption) {
        _state.update { current ->
            current.copy(
                sortOption = option,
                items = sortItems(current.items, option),
            )
        }
    }

    private fun sortItems(items: List<MediaItem>, sort: SortOption): List<MediaItem> = when (sort) {
        SortOption.RECENT -> items
        SortOption.RATING -> items.sortedByDescending { it.rating }
        SortOption.TITLE -> items.sortedBy { it.title.lowercase() }
    }
}
