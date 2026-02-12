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
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay

/**
 * Écran de recherche TV avec clavier virtuel
 */
@Composable
fun TvSearchScreen(
    onNavigateToDetail: (String, String) -> Unit,
    onBack: () -> Unit
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
    
    // Fonction de recherche avec debounce
    fun performSearch(query: String) {
        // Annuler la recherche précédente
        searchJob?.cancel()
        
        if (query.length < 2) {
            searchResults = emptyList()
            searchError = null
            return
        }
        
        searchJob = scope.launch {
            // Debounce de 500ms
            delay(500)
            
            isSearching = true
            searchError = null
            
            repository.search(query, type = null)
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
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
            .padding(d.contentPadding),
        verticalArrangement = Arrangement.spacedBy(d.gridSpacing)
    ) {
        // Titre
        Text(
            text = "Rechercher",
            color = Color.White,
            fontSize = d.largeTitleSize,
            fontWeight = FontWeight.Bold
        )
        
        // Champ de recherche (affichage)
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
                text = if (searchQuery.isEmpty()) "Tapez votre recherche..." else searchQuery,
                color = if (searchQuery.isEmpty()) TextSecondary else Color.White,
                fontSize = d.searchFontSize
            )
        }
        
        // Clavier virtuel
        TvVirtualKeyboard(
            onKeyPress = { key ->
                when (key) {
                    "⌫" -> {
                        if (searchQuery.isNotEmpty()) {
                            searchQuery = searchQuery.dropLast(1)
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
                    }
                }
            }
        )
        
        // Résultats
        if (isSearching) {
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
                    Text(
                        text = "Recherche en cours...",
                        color = TextSecondary,
                        fontSize = d.bodySize
                    )
                }
            }
        } else if (searchError != null) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(d.contentPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(d.episodePadding)
                ) {
                    Text(
                        text = "❌ Erreur",
                        fontSize = 48.sp
                    )
                    Text(
                        text = searchError ?: "Une erreur est survenue",
                        color = Color(0xFFFF5252),
                        fontSize = d.bodySize
                    )
                }
            }
        } else if (searchResults.isNotEmpty()) {
            Column(
                verticalArrangement = Arrangement.spacedBy(d.rowSpacing)
            ) {
                Text(
                    text = "${searchResults.size} résultat(s)",
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
                            onClick = {
                                onNavigateToDetail(item.id, if (item.isSerie) "serie" else "film")
                            },
                            rating = item.rating,
                            year = item.year
                        )
                    }
                }
            }
        } else if (searchQuery.isNotEmpty() && searchQuery.length >= 2) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(d.contentPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(d.episodePadding)
                ) {
                    Text(
                        text = "🔍",
                        fontSize = 64.sp
                    )
                    Text(
                        text = "Aucun résultat pour \"$searchQuery\"",
                        color = TextSecondary,
                        fontSize = d.bodySize
                    )
                    Text(
                        text = "Essayez avec d'autres mots-clés",
                        color = TextSecondary.copy(alpha = 0.7f),
                        fontSize = d.smallSize
                    )
                }
            }
        } else if (searchQuery.isNotEmpty() && searchQuery.length < 2) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(d.contentPadding),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Tapez au moins 2 caractères pour rechercher",
                    color = TextSecondary,
                    fontSize = d.bodySize
                )
            }
        }
    }
}

/**
 * Clavier virtuel pour TV
 */
@Composable
private fun TvVirtualKeyboard(
    onKeyPress: (String) -> Unit
) {
    val d = LocalTvDimens.current
    val rows = listOf(
        listOf("A", "B", "C", "D", "E", "F", "G", "H", "I", "J"),
        listOf("K", "L", "M", "N", "O", "P", "Q", "R", "S", "T"),
        listOf("U", "V", "W", "X", "Y", "Z", "0-9", "⌫", "SPC", "✓")
    )
    
    Column(
        verticalArrangement = Arrangement.spacedBy(d.seasonPaddingV)
    ) {
        rows.forEach { row ->
            Row(
                horizontalArrangement = Arrangement.spacedBy(d.seasonPaddingV)
            ) {
                row.forEach { key ->
                    TvKeyboardKey(
                        key = key,
                        onClick = { onKeyPress(key) }
                    )
                }
            }
        }
    }
}

/**
 * Touche du clavier virtuel
 */
@Composable
private fun TvKeyboardKey(
    key: String,
    onClick: () -> Unit
) {
    val d = LocalTvDimens.current
    TvFocusableSimple(
        onClick = onClick
    ) { isFocused ->
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
                    else -> key
                },
                color = if (key == "✓") Color.Black else Color.White,
                fontSize = d.keyFontSize,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
