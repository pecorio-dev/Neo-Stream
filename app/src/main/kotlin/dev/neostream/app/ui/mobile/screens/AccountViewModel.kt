package dev.neostream.app.ui.mobile.screens

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dev.neostream.app.data.local.AccountEntity
import dev.neostream.app.data.local.NeoStreamDatabase
import dev.neostream.app.data.local.SessionManager
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class AccountViewModel(application: Application) : AndroidViewModel(application) {
    private val accountDao = NeoStreamDatabase.getInstance(application).accountDao()

    val accounts: StateFlow<List<AccountEntity>> = accountDao.getAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun createAccount(username: String, password: String, avatarIcon: String, accentColor: Long) {
        viewModelScope.launch {
            val hash = SessionManager.hashPassword(password)
            val account = AccountEntity(
                username = username,
                passwordHash = hash,
                avatarIcon = avatarIcon,
                accentColor = accentColor,
            )
            val id = accountDao.insert(account)
            SessionManager.setCurrentAccount(getApplication(), id)
        }
    }

    fun login(account: AccountEntity, password: String?): Boolean {
        if (account.passwordHash.isNotEmpty()) {
            if (password == null || !SessionManager.verifyPassword(password, account.passwordHash)) {
                return false
            }
        }
        SessionManager.setCurrentAccount(getApplication(), account.id)
        return true
    }

    fun updateAccount(id: Long, username: String, password: String, avatarIcon: String, accentColor: Long) {
        viewModelScope.launch {
            val existing = accountDao.getById(id) ?: return@launch
            val hash = if (password.isEmpty()) existing.passwordHash else SessionManager.hashPassword(password)
            accountDao.update(existing.copy(
                username = username,
                passwordHash = hash,
                avatarIcon = avatarIcon,
                accentColor = accentColor,
            ))
        }
    }

    fun deleteAccount(id: Long) {
        viewModelScope.launch {
            accountDao.delete(id)
            val db = NeoStreamDatabase.getInstance(getApplication())
            db.favoriteDao().deleteAllForAccount(id)
            SessionManager.logout(getApplication())
        }
    }

    fun logout() {
        SessionManager.logout(getApplication())
    }
}
