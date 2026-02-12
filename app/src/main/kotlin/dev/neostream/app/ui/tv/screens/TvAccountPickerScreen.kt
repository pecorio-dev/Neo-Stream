package dev.neostream.app.ui.tv.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.neostream.app.data.local.AccountEntity
import dev.neostream.app.ui.mobile.screens.AccountViewModel
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.TextSecondary
import dev.neostream.app.ui.tv.LocalTvDimens
import dev.neostream.app.ui.tv.components.TvButton
import dev.neostream.app.ui.tv.components.TvFocusableSimple

/**
 * Écran de sélection de profil pour TV
 * Inspiré de Netflix profile picker
 */
@Composable
fun TvAccountPickerScreen(
    onAccountSelected: () -> Unit,
    viewModel: AccountViewModel = viewModel()
) {
    val d = LocalTvDimens.current
    val context = LocalContext.current
    val accounts by viewModel.accounts.collectAsState()
    
    var selectedAccount by remember { mutableStateOf<AccountEntity?>(null) }
    var showPasswordDialog by remember { mutableStateOf(false) }
    var passwordInput by remember { mutableStateOf("") }
    var passwordError by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(d.sectionSpacing)
        ) {
            // Logo et titre
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(d.rowSpacing)
            ) {
                Text(
                    text = "NeoStream",
                    color = AccentCyan,
                    fontSize = d.detailTitleSize,
                    fontWeight = FontWeight.Bold
                )
                
                Text(
                    text = "Qui regarde ?",
                    color = Color.White,
                    fontSize = d.largeTitleSize,
                    fontWeight = FontWeight.Medium
                )
            }

            // Grille de profils
            LazyVerticalGrid(
                columns = GridCells.Fixed(4),
                horizontalArrangement = Arrangement.spacedBy(d.gridSpacing),
                verticalArrangement = Arrangement.spacedBy(d.gridSpacing),
                modifier = Modifier.widthIn(max = 1200.dp)
            ) {
                items(accounts) { account ->
                    TvAccountCard(
                        account = account,
                        onClick = {
                            if (account.passwordHash.isNotEmpty()) {
                                selectedAccount = account
                                showPasswordDialog = true
                                passwordInput = ""
                                passwordError = false
                            } else {
                                viewModel.login(account, null)
                                onAccountSelected()
                            }
                        }
                    )
                }
                
                // Bouton Ajouter un profil
                item {
                    TvAddAccountCard(
                        onClick = {
                            // TODO: Navigation vers création de compte
                            // Pour l'instant, créer un compte par défaut
                            val randomColor = listOf(
                                0xFFE50914, 0xFF0080FF, 0xFF00D9FF, 
                                0xFFFFA000, 0xFF00E676, 0xFFD500F9
                            ).random()
                            viewModel.createAccount(
                                username = "Profil ${accounts.size + 1}",
                                password = "",
                                avatarIcon = "Person",
                                accentColor = randomColor
                            )
                        }
                    )
                }
            }
        }

        // Dialog mot de passe
        AnimatedVisibility(visible = showPasswordDialog) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.7f)),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    modifier = Modifier
                        .width(500.dp)
                        .background(
                            color = DeepBlack.copy(alpha = 0.95f),
                            shape = RoundedCornerShape(16.dp)
                        )
                        .padding(d.contentPadding),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(d.rowSpacing)
                ) {
                    Text(
                        text = "Entrez le code PIN",
                        color = Color.White,
                        fontSize = d.titleSize,
                        fontWeight = FontWeight.Bold
                    )
                    
                    Text(
                        text = selectedAccount?.username ?: "",
                        color = TextSecondary,
                        fontSize = d.bodySize
                    )

                    TextField(
                        value = passwordInput,
                        onValueChange = { 
                            passwordInput = it
                            passwordError = false
                        },
                        visualTransformation = PasswordVisualTransformation(),
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = Color.White.copy(alpha = 0.1f),
                            unfocusedContainerColor = Color.White.copy(alpha = 0.05f),
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White,
                            cursorColor = AccentCyan,
                            focusedIndicatorColor = if (passwordError) Color.Red else AccentCyan,
                            unfocusedIndicatorColor = Color.Transparent
                        ),
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        isError = passwordError
                    )

                    if (passwordError) {
                        Text(
                            text = "Code PIN incorrect",
                            color = Color.Red,
                            fontSize = d.smallSize
                        )
                    }

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(d.rowSpacing)
                    ) {
                        TvButton(
                            text = "Annuler",
                            onClick = {
                                showPasswordDialog = false
                                selectedAccount = null
                                passwordInput = ""
                            },
                            isPrimary = false
                        )
                        
                        TvButton(
                            text = "Valider",
                            onClick = {
                                selectedAccount?.let { account ->
                                    if (viewModel.login(account, passwordInput)) {
                                        showPasswordDialog = false
                                        onAccountSelected()
                                    } else {
                                        passwordError = true
                                    }
                                }
                            },
                            isPrimary = true
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TvAccountCard(
    account: AccountEntity,
    onClick: () -> Unit
) {
    val d = LocalTvDimens.current
    
    TvFocusableSimple(
        onClick = onClick
    ) { isFocused ->
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(d.rowSpacing),
            modifier = Modifier.padding(d.episodePadding)
        ) {
            // Avatar
            Box(
                modifier = Modifier
                    .size(d.detailPosterWidth)
                    .clip(CircleShape)
                    .background(
                        color = if (isFocused) 
                            Color(account.accentColor)
                        else 
                            Color(account.accentColor).copy(alpha = 0.7f)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = avatarIcon(account.avatarIcon),
                    contentDescription = account.username,
                    modifier = Modifier.size(d.detailPosterWidth * 0.5f),
                    tint = Color.White
                )
                
                // Indicateur de protection
                if (account.passwordHash.isNotEmpty()) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(d.episodePadding)
                            .size(d.settingsIconSize)
                            .clip(CircleShape)
                            .background(DeepBlack.copy(alpha = 0.8f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Lock,
                            contentDescription = "Protégé",
                            tint = AccentCyan,
                            modifier = Modifier.size(d.menuIconSize)
                        )
                    }
                }
            }

            // Nom
            Text(
                text = account.username,
                color = if (isFocused) Color.White else TextSecondary,
                fontSize = d.sectionTitleSize,
                fontWeight = if (isFocused) FontWeight.Bold else FontWeight.Normal
            )
        }
    }
}

@Composable
private fun TvAddAccountCard(
    onClick: () -> Unit
) {
    val d = LocalTvDimens.current
    
    TvFocusableSimple(
        onClick = onClick
    ) { isFocused ->
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(d.rowSpacing),
            modifier = Modifier.padding(d.episodePadding)
        ) {
            // Avatar avec +
            Box(
                modifier = Modifier
                    .size(d.detailPosterWidth)
                    .clip(CircleShape)
                    .background(
                        color = if (isFocused) 
                            Color.White.copy(alpha = 0.2f)
                        else 
                            Color.White.copy(alpha = 0.1f)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Rounded.Add,
                    contentDescription = "Ajouter profil",
                    modifier = Modifier.size(d.detailPosterWidth * 0.5f),
                    tint = if (isFocused) AccentCyan else TextSecondary
                )
            }

            Text(
                text = "Ajouter",
                color = if (isFocused) Color.White else TextSecondary,
                fontSize = d.sectionTitleSize,
                fontWeight = if (isFocused) FontWeight.Bold else FontWeight.Normal
            )
        }
    }
}

private fun avatarIcon(name: String): ImageVector = when (name) {
    "Person" -> Icons.Rounded.Person
    "Face" -> Icons.Rounded.Face
    "Child" -> Icons.Rounded.ChildCare
    "Star" -> Icons.Rounded.Star
    "Favorite" -> Icons.Rounded.Favorite
    "Movie" -> Icons.Rounded.Movie
    "Tv" -> Icons.Rounded.Tv
    "Games" -> Icons.Rounded.SportsEsports
    else -> Icons.Rounded.Person
}
