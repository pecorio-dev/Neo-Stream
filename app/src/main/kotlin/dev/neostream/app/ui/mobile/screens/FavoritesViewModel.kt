package dev.neostream.app.ui.mobile.screens

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dev.neostream.app.data.local.NeoStreamDatabase
import dev.neostream.app.data.local.SessionManager
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.data.repository.MediaRepository.Companion.toMediaItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class FavoritesState(
    val items: List<MediaItem> = emptyList(),
    val filter: String = "all",
    val count: Int = 0,
)

class FavoritesViewModel(application: Application) : AndroidViewModel(application) {
    private val favoriteDao = NeoStreamDatabase.getInstance(application).favoriteDao()

    private val _filter = MutableStateFlow("all")

    private val accountId: Long get() = SessionManager.currentAccountId.value ?: 0L

    val state: StateFlow<FavoritesState> = _filter.flatMapLatest { filter ->
        val id = accountId
        val flow = if (filter == "all") {
            favoriteDao.getAll(id)
        } else {
            favoriteDao.getByType(id, filter)
        }
        flow.map { entities ->
            FavoritesState(
                items = entities.map { it.toMediaItem() },
                filter = filter,
                count = entities.size,
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FavoritesState())

    fun setFilter(filter: String) {
        _filter.value = filter
    }

    fun removeFavorite(id: String) {
        viewModelScope.launch { favoriteDao.delete(id, accountId) }
    }
}
