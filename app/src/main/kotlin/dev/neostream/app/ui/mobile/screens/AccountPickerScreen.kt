package dev.neostream.app.ui.mobile.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ChildCare
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Face
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Movie
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Pets
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.data.local.AccountEntity
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.AccentPurple
import dev.neostream.app.ui.theme.CardSurface
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.GlassBorder
import dev.neostream.app.ui.theme.TextPrimary
import dev.neostream.app.ui.theme.TextSecondary

private fun avatarIcon(name: String): ImageVector = when (name) {
    "face" -> Icons.Rounded.Face
    "star" -> Icons.Rounded.Star
    "pets" -> Icons.Rounded.Pets
    "child" -> Icons.Rounded.ChildCare
    "gaming" -> Icons.Rounded.SportsEsports
    "music" -> Icons.Rounded.MusicNote
    "movie" -> Icons.Rounded.Movie
    else -> Icons.Rounded.Person
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AccountPickerScreen(
    accounts: List<AccountEntity>,
    onSelectAccount: (AccountEntity, String?) -> Unit,
    onCreateAccount: (username: String, password: String, avatarIcon: String, accentColor: Long) -> Unit,
    onEditAccount: (id: Long, username: String, password: String, avatarIcon: String, accentColor: Long) -> Unit,
    onDeleteAccount: (id: Long) -> Unit,
) {
    var passwordDialogAccount by remember { mutableStateOf<AccountEntity?>(null) }
    var showCreateDialog by remember { mutableStateOf(false) }
    var editingAccount by remember { mutableStateOf<AccountEntity?>(null) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 32.dp, vertical = 64.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Qui regarde ?",
                fontSize = 28.sp,
                fontWeight = FontWeight.Black,
                color = TextPrimary,
            )

            Spacer(Modifier.height(40.dp))

            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalArrangement = Arrangement.spacedBy(24.dp),
                maxItemsInEachRow = 4,
            ) {
                accounts.forEachIndexed { index, account ->
                    AccountAvatar(
                        account = account,
                        index = index,
                        onClick = {
                            if (account.passwordHash.isNotEmpty()) {
                                passwordDialogAccount = account
                            } else {
                                onSelectAccount(account, null)
                            }
                        },
                        onLongClick = {
                            editingAccount = account
                        },
                    )
                }
            }

            Spacer(Modifier.height(40.dp))

            Column(
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .clickable(onClick = { showCreateDialog = true })
                    .padding(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .border(2.dp, GlassBorder, CircleShape)
                        .clip(CircleShape)
                        .background(CardSurface),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Add,
                        contentDescription = "Ajouter un profil",
                        tint = TextSecondary,
                        modifier = Modifier.size(32.dp),
                    )
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    text = "Ajouter un profil",
                    fontSize = 13.sp,
                    color = TextSecondary,
                )
            }
        }
    }

    passwordDialogAccount?.let { account ->
        PasswordDialog(
            username = account.username,
            onConfirm = { password ->
                onSelectAccount(account, password)
                passwordDialogAccount = null
            },
            onDismiss = { passwordDialogAccount = null },
        )
    }

    if (showCreateDialog) {
        CreateAccountDialog(
            onConfirm = { username, password, avatarIcon, accentColor ->
                onCreateAccount(username, password, avatarIcon, accentColor)
                showCreateDialog = false
            },
            onDismiss = { showCreateDialog = false }
        )
    }

    editingAccount?.let { account ->
        EditAccountDialog(
            account = account,
            onConfirm = { username, password, avatarIcon, accentColor ->
                onEditAccount(account.id, username, password, avatarIcon, accentColor)
                editingAccount = null
            },
            onDelete = {
                onDeleteAccount(account.id)
                editingAccount = null
            },
            onDismiss = { editingAccount = null }
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun AccountAvatar(
    account: AccountEntity,
    index: Int,
    onClick: () -> Unit,
    onLongClick: () -> Unit = {},
) {
    val animatable = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(index * 80L)
        animatable.animateTo(
            1f,
            animationSpec = tween(400, easing = FastOutSlowInEasing),
        )
    }

    Column(
        modifier = Modifier
            .padding(horizontal = 12.dp)
            .alpha(animatable.value)
            .graphicsLayer { translationY = (1f - animatable.value) * 40f }
            .clip(RoundedCornerShape(16.dp))
            .combinedClickable(
                onClick = onClick,
                onLongClick = onLongClick
            )
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(Color(account.accentColor)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = avatarIcon(account.avatarIcon),
                contentDescription = account.username,
                tint = Color.White,
                modifier = Modifier.size(40.dp),
            )
        }

        Spacer(Modifier.height(10.dp))

        Text(
            text = account.username,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = TextPrimary,
        )

        if (account.passwordHash.isNotEmpty()) {
            Icon(
                imageVector = Icons.Rounded.Lock,
                contentDescription = null,
                tint = TextSecondary,
                modifier = Modifier
                    .size(14.dp)
                    .padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun PasswordDialog(
    username: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var password by remember { mutableStateOf("") }
    var passwordVisible by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = CardSurface,
        shape = RoundedCornerShape(20.dp),
        title = {
            Text(
                text = username,
                color = TextPrimary,
                fontWeight = FontWeight.Bold,
            )
        },
        text = {
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Mot de passe") },
                singleLine = true,
                visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                trailingIcon = {
                    IconButton(onClick = { passwordVisible = !passwordVisible }) {
                        Icon(
                            imageVector = if (passwordVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                            contentDescription = null,
                            tint = TextSecondary,
                        )
                    }
                },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary,
                    cursorColor = AccentCyan,
                    focusedBorderColor = AccentCyan,
                    unfocusedBorderColor = GlassBorder,
                    focusedLabelColor = AccentCyan,
                    unfocusedLabelColor = TextSecondary,
                    focusedContainerColor = DeepBlack,
                    unfocusedContainerColor = DeepBlack,
                ),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth(),
            )
        },
        confirmButton = {
            Button(
                onClick = { onConfirm(password) },
                colors = ButtonDefaults.buttonColors(
                    containerColor = AccentCyan,
                    contentColor = DeepBlack,
                ),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text("Confirmer", fontWeight = FontWeight.SemiBold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Annuler", color = TextSecondary)
            }
        },
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EditAccountDialog(
    account: AccountEntity,
    onConfirm: (username: String, password: String, avatarIcon: String, accentColor: Long) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit,
) {
    var username by remember { mutableStateOf(account.username) }
    var password by remember { mutableStateOf("") }
    var passwordVisible by remember { mutableStateOf(false) }
    var selectedIcon by remember { mutableStateOf(account.avatarIcon) }
    var selectedColor by remember { mutableStateOf(account.accentColor) }
    var showDeleteConfirmation by remember { mutableStateOf(false) }

    val availableIcons = listOf("face", "star", "pets", "child", "gaming", "music", "movie")
    val availableColors = listOf(
        0xFFE91E63, // Pink
        0xFF9C27B0, // Purple
        0xFF2196F3, // Blue
        0xFF00BCD4, // Cyan
        0xFF4CAF50, // Green
        0xFFFF9800, // Orange
        0xFFF44336, // Red
    )

    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            containerColor = CardSurface,
            shape = RoundedCornerShape(20.dp),
            title = {
                Text(
                    text = "Supprimer le profil",
                    color = TextPrimary,
                    fontWeight = FontWeight.Bold,
                )
            },
            text = {
                Text(
                    text = "Êtes-vous sûr de vouloir supprimer le profil \"${account.username}\" ? Cette action est irréversible.",
                    color = TextSecondary,
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        onDelete()
                        showDeleteConfirmation = false
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFFF44336),
                        contentColor = Color.White,
                    ),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Text("Supprimer", fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = false }) {
                    Text("Annuler", color = TextSecondary)
                }
            },
        )
    } else {
        AlertDialog(
            onDismissRequest = onDismiss,
            containerColor = CardSurface,
            shape = RoundedCornerShape(20.dp),
            title = {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Modifier le profil",
                        color = TextPrimary,
                        fontWeight = FontWeight.Bold,
                    )
                    IconButton(onClick = { showDeleteConfirmation = true }) {
                        Icon(
                            imageVector = Icons.Rounded.Delete,
                            contentDescription = "Supprimer",
                            tint = Color(0xFFF44336)
                        )
                    }
                }
            },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // Username field
                    OutlinedTextField(
                        value = username,
                        onValueChange = { username = it },
                        label = { Text("Nom d'utilisateur") },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = TextPrimary,
                            unfocusedTextColor = TextPrimary,
                            cursorColor = AccentCyan,
                            focusedBorderColor = AccentCyan,
                            unfocusedBorderColor = GlassBorder,
                            focusedLabelColor = AccentCyan,
                            unfocusedLabelColor = TextSecondary,
                            focusedContainerColor = DeepBlack,
                            unfocusedContainerColor = DeepBlack,
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth(),
                    )

                    // Password field (optional)
                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it },
                        label = { Text("Nouveau mot de passe (optionnel)") },
                        singleLine = true,
                        visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        trailingIcon = {
                            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                Icon(
                                    imageVector = if (passwordVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                    contentDescription = null,
                                    tint = TextSecondary,
                                )
                            }
                        },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = TextPrimary,
                            unfocusedTextColor = TextPrimary,
                            cursorColor = AccentCyan,
                            focusedBorderColor = AccentCyan,
                            unfocusedBorderColor = GlassBorder,
                            focusedLabelColor = AccentCyan,
                            unfocusedLabelColor = TextSecondary,
                            focusedContainerColor = DeepBlack,
                            unfocusedContainerColor = DeepBlack,
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth(),
                    )

                    // Avatar icon selection
                    Text(
                        text = "Icône",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextPrimary,
                    )

                    FlowRow(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        availableIcons.forEach { icon ->
                            Box(
                                modifier = Modifier
                                    .size(48.dp)
                                    .clip(CircleShape)
                                    .background(
                                        if (selectedIcon == icon) Color(selectedColor)
                                        else CardSurface
                                    )
                                    .border(
                                        width = if (selectedIcon == icon) 2.dp else 1.dp,
                                        color = if (selectedIcon == icon) Color(selectedColor).copy(alpha = 0.5f)
                                        else GlassBorder,
                                        shape = CircleShape
                                    )
                                    .clickable { selectedIcon = icon }
                                    .padding(8.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = avatarIcon(icon),
                                    contentDescription = icon,
                                    tint = if (selectedIcon == icon) Color.White else TextSecondary,
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                        }
                    }

                    // Color selection
                    Text(
                        text = "Couleur",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextPrimary,
                    )

                    FlowRow(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        availableColors.forEach { color ->
                            Box(
                                modifier = Modifier
                                    .size(48.dp)
                                    .clip(CircleShape)
                                    .background(Color(color))
                                    .border(
                                        width = if (selectedColor == color) 3.dp else 0.dp,
                                        color = Color.White,
                                        shape = CircleShape
                                    )
                                    .clickable { selectedColor = color }
                            )
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (username.isNotBlank()) {
                            onConfirm(username, password, selectedIcon, selectedColor)
                        }
                    },
                    enabled = username.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = AccentCyan,
                        contentColor = DeepBlack,
                        disabledContainerColor = GlassBorder,
                        disabledContentColor = TextSecondary,
                    ),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Text("Enregistrer", fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = onDismiss) {
                    Text("Annuler", color = TextSecondary)
                }
            },
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CreateAccountDialog(
    onConfirm: (username: String, password: String, avatarIcon: String, accentColor: Long) -> Unit,
    onDismiss: () -> Unit,
) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var passwordVisible by remember { mutableStateOf(false) }
    var selectedIcon by remember { mutableStateOf("face") }
    var selectedColor by remember { mutableStateOf(0xFFE91E63) }

    val availableIcons = listOf("face", "star", "pets", "child", "gaming", "music", "movie")
    val availableColors = listOf(
        0xFFE91E63, // Pink
        0xFF9C27B0, // Purple
        0xFF2196F3, // Blue
        0xFF00BCD4, // Cyan
        0xFF4CAF50, // Green
        0xFFFF9800, // Orange
        0xFFF44336, // Red
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = CardSurface,
        shape = RoundedCornerShape(20.dp),
        title = {
            Text(
                text = "Créer un profil",
                color = TextPrimary,
                fontWeight = FontWeight.Bold,
            )
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Username field
                OutlinedTextField(
                    value = username,
                    onValueChange = { username = it },
                    label = { Text("Nom d'utilisateur") },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = TextPrimary,
                        unfocusedTextColor = TextPrimary,
                        cursorColor = AccentCyan,
                        focusedBorderColor = AccentCyan,
                        unfocusedBorderColor = GlassBorder,
                        focusedLabelColor = AccentCyan,
                        unfocusedLabelColor = TextSecondary,
                        focusedContainerColor = DeepBlack,
                        unfocusedContainerColor = DeepBlack,
                    ),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth(),
                )

                // Password field (optional)
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Mot de passe (optionnel)") },
                    singleLine = true,
                    visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = {
                        IconButton(onClick = { passwordVisible = !passwordVisible }) {
                            Icon(
                                imageVector = if (passwordVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                contentDescription = null,
                                tint = TextSecondary,
                            )
                        }
                    },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = TextPrimary,
                        unfocusedTextColor = TextPrimary,
                        cursorColor = AccentCyan,
                        focusedBorderColor = AccentCyan,
                        unfocusedBorderColor = GlassBorder,
                        focusedLabelColor = AccentCyan,
                        unfocusedLabelColor = TextSecondary,
                        focusedContainerColor = DeepBlack,
                        unfocusedContainerColor = DeepBlack,
                    ),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth(),
                )

                // Avatar icon selection
                Text(
                    text = "Icône",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = TextPrimary,
                )

                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    availableIcons.forEach { icon ->
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(
                                    if (selectedIcon == icon) Color(selectedColor)
                                    else CardSurface
                                )
                                .border(
                                    width = if (selectedIcon == icon) 2.dp else 1.dp,
                                    color = if (selectedIcon == icon) Color(selectedColor).copy(alpha = 0.5f)
                                    else GlassBorder,
                                    shape = CircleShape
                                )
                                .clickable { selectedIcon = icon }
                                .padding(8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = avatarIcon(icon),
                                contentDescription = icon,
                                tint = if (selectedIcon == icon) Color.White else TextSecondary,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                    }
                }

                // Color selection
                Text(
                    text = "Couleur",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = TextPrimary,
                )

                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    availableColors.forEach { color ->
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(Color(color))
                                .border(
                                    width = if (selectedColor == color) 3.dp else 0.dp,
                                    color = Color.White,
                                    shape = CircleShape
                                )
                                .clickable { selectedColor = color }
                        )
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { 
                    if (username.isNotBlank()) {
                        onConfirm(username, password, selectedIcon, selectedColor)
                    }
                },
                enabled = username.isNotBlank(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AccentCyan,
                    contentColor = DeepBlack,
                    disabledContainerColor = GlassBorder,
                    disabledContentColor = TextSecondary,
                ),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text("Créer", fontWeight = FontWeight.SemiBold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Annuler", color = TextSecondary)
            }
        },
    )
}
