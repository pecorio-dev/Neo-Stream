package dev.neostream.app.data.local

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

object SessionManager {
    private const val PREFS_NAME = "neostream_session"
    private const val KEY_ACCOUNT_ID = "current_account_id"

    private val _currentAccountId = MutableStateFlow<Long?>(null)
    val currentAccountId: StateFlow<Long?> = _currentAccountId

    fun init(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val id = prefs.getLong(KEY_ACCOUNT_ID, -1L)
        _currentAccountId.value = if (id == -1L) null else id
    }

    fun setCurrentAccount(context: Context, accountId: Long) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putLong(KEY_ACCOUNT_ID, accountId).apply()
        _currentAccountId.value = accountId
    }

    fun logout(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().remove(KEY_ACCOUNT_ID).apply()
        _currentAccountId.value = null
    }

    fun hashPassword(password: String): String {
        if (password.isEmpty()) return ""
        val bytes = java.security.MessageDigest.getInstance("SHA-256").digest(password.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }

    fun verifyPassword(input: String, hash: String): Boolean {
        if (hash.isEmpty()) return true
        return hashPassword(input) == hash
    }
}
