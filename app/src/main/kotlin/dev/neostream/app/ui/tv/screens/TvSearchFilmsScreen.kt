package dev.neostream.app.ui.tv.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.data.repository.MediaRepository
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.TextSecondary
import dev.neostream.app.ui.tv.LocalTvDimens
import dev.neostream.app.ui.tv.components.TvCardCompact
import dev.neostream.app.ui.tv.components.TvFocusableSimple
import dev.neostream.app.ui.tv.components.TvSidebar
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay

@Composable
fun TvSearchFilmsScreen(
    onNavigateToDetail: (String) -> Unit,
    onNavigateToHome: () -> Unit,
    onNavigateToMovies: () -> Unit,
    onNavigateToSeries: () -> Unit,
    onNavigateToFavorites: () -> Unit,
    onNavigateToSettings: () -> Unit
) {
    val d = LocalTvDimens.current
    val context = LocalContext.current
    val repository = remember { MediaRepository() }
    
    var searchQuery by remember { mutableStateOf("") }
    var searchResults by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }
    var searchError by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    var searchJob by remember { mutableStateOf<Job?>(null) }
    
    val currentRoute = "movies"
    
    fun performSearch(query: String) {
        searchJob?.cancel()
        
        if (query.length < 2) {
            searchResults = emptyList()
            searchError = null
            return
        }
        
        searchJob = scope.launch {
            delay(500)
            isSearching = true
            searchError = null
            
            repository.search(query, type = "film")
                .onSuccess { results ->
                    searchResults = results
                    isSearching = false
                }
                .onFailure { error ->
                    searchError = error.message ?: "Erreur de recherche"
                    searchResults = emptyList()
                    isSearching = false
                }
        }
    }
    
    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
    ) {
        TvSidebar(
            currentRoute = currentRoute,
            onNavigate = { route ->
                when (route) {
                    "home" -> onNavigateToHome()
                    "movies" -> onNavigateToMovies()
                    "series" -> onNavigateToSeries()
                    "favorites" -> onNavigateToFavorites()
                    "settings" -> onNavigateToSettings()
                }
            }
        )
        
        Column(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
                .padding(d.contentPadding),
            verticalArrangement = Arrangement.spacedBy(d.gridSpacing)
        ) {
            Text(
                text = "Rechercher des Films",
                color = Color.White,
                fontSize = d.largeTitleSize,
                fontWeight = FontWeight.Bold
            )
            
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        color = Color.White.copy(alpha = 0.1f),
                        shape = RoundedCornerShape(12.dp)
                    )
                    .padding(d.searchFieldPadding)
            ) {
                Text(
                    text = if (searchQuery.isEmpty()) "Tapez le nom d'un film..." else searchQuery,
                    color = if (searchQuery.isEmpty()) TextSecondary else Color.White,
                    fontSize = d.searchFontSize
                )
            }
            
            TvVirtualKeyboard(
                onKeyPress = { key ->
                    when (key) {
                        "⌫" -> {
                            if (searchQuery.isNotEmpty()) {
                                searchQuery = searchQuery.dropLast(1)
                                performSearch(searchQuery)
                            }
                        }
                        "SPC" -> {
                            searchQuery += " "
                        }
                        "✓" -> {
                            performSearch(searchQuery)
                        }
                        else -> {
                            searchQuery += key
                            performSearch(searchQuery)
                        }
                    }
                }
            )
            
            when {
                isSearching -> {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(d.contentPadding),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(d.episodePadding),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            CircularProgressIndicator(
                                color = AccentCyan,
                                modifier = Modifier.size(d.settingsIconSize)
                            )
                            Text("Recherche...", color = TextSecondary, fontSize = d.bodySize)
                        }
                    }
                }
                searchError != null -> {
                    Box(
                        modifier = Modifier.fillMaxWidth().padding(d.contentPadding),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(d.episodePadding)
                        ) {
                            Text("❌", fontSize = 48.sp)
                            Text(searchError ?: "Erreur", color = Color.Red, fontSize = d.bodySize)
                        }
                    }
                }
                searchResults.isNotEmpty() -> {
                    Column(verticalArrangement = Arrangement.spacedBy(d.rowSpacing)) {
                        Text(
                            text = "${searchResults.size} film(s) trouvé(s)",
                            color = Color.White,
                            fontSize = d.titleSize,
                            fontWeight = FontWeight.Bold
                        )
                        
                        LazyVerticalGrid(
                            columns = GridCells.Adaptive(d.cardWidth),
                            horizontalArrangement = Arrangement.spacedBy(d.rowSpacing),
                            verticalArrangement = Arrangement.spacedBy(d.rowSpacing),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            items(searchResults) { item ->
                                TvCardCompact(
                                    title = item.title,
                                    posterUrl = item.poster,
                                    onClick = { onNavigateToDetail(item.id) },
                                    rating = item.rating,
                                    year = item.year
                                )
                            }
                        }
                    }
                }
                searchQuery.isNotEmpty() && searchQuery.length >= 2 -> {
                    Box(
                        modifier = Modifier.fillMaxWidth().padding(d.contentPadding),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(d.episodePadding)
                        ) {
                            Text("🔍", fontSize = 64.sp)
                            Text("Aucun film trouvé", color = TextSecondary, fontSize = d.bodySize)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TvVirtualKeyboard(onKeyPress: (String) -> Unit) {
    val d = LocalTvDimens.current
    // Clavier AZERTY
    val rows = listOf(
        listOf("A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P"),
        listOf("Q", "S", "D", "F", "G", "H", "J", "K", "L", "M"),
        listOf("W", "X", "C", "V", "B", "N", "0-9", "⌫", "SPC", "✓")
    )
    
    Column(verticalArrangement = Arrangement.spacedBy(d.seasonPaddingV)) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(d.seasonPaddingV)) {
                row.forEach { key ->
                    TvKeyboardKey(key = key, onClick = { onKeyPress(key) })
                }
            }
        }
    }
}

@Composable
private fun TvKeyboardKey(key: String, onClick: () -> Unit) {
    val d = LocalTvDimens.current
    var showSpecialChars by remember { mutableStateOf(false) }
    
    // Caractères spéciaux pour chaque touche (clic long)
    val specialCharsMap = mapOf(
        "A" to "À Á Â Ä Å Æ",
        "E" to "È É Ê Ë",
        "I" to "Ì Í Î Ï",
        "O" to "Ò Ó Ô Ö Ø Œ",
        "U" to "Ù Ú Û Ü",
        "C" to "Ç",
        "N" to "Ñ",
        "Y" to "Ý Ÿ",
        "0-9" to "0 1 2 3 4 5 6 7 8 9 . , ! ? - ' \" ( )"
    )
    
    TvFocusableSimple(onClick = onClick) { isFocused ->
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .size(if (key in listOf("0-9", "SPC", "✓")) d.keyWideSize else d.keySize, d.keySize)
                    .background(
                        color = when {
                            key == "✓" && isFocused -> AccentCyan
                            isFocused -> Color.White.copy(alpha = 0.3f)
                            key == "✓" -> AccentCyan.copy(alpha = 0.5f)
                            else -> Color.White.copy(alpha = 0.1f)
                        },
                        shape = RoundedCornerShape(12.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = when (key) {
                        "SPC" -> "Espace"
                        "0-9" -> "123"
                        else -> key.lowercase()
                    },
                    color = if (key == "✓") Color.Black else Color.White,
                    fontSize = d.keyFontSize,
                    fontWeight = FontWeight.Bold
                )
            }
            
            // Afficher caractères spéciaux disponibles en petit
            if (specialCharsMap.containsKey(key) && isFocused) {
                Text(
                    text = "Clic long: ${specialCharsMap[key]?.take(10) ?: ""}",
                    color = AccentCyan,
                    fontSize = d.tinySize,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }
    }
}
