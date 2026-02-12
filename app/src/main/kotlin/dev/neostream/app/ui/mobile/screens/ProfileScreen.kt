package dev.neostream.app.ui.mobile.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.ChildCare
import androidx.compose.material.icons.rounded.Face
import androidx.compose.material.icons.rounded.Movie
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Pets
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
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

private data class AvatarOption(val key: String, val icon: ImageVector)

private val avatarOptions = listOf(
    AvatarOption("person", Icons.Rounded.Person),
    AvatarOption("face", Icons.Rounded.Face),
    AvatarOption("star", Icons.Rounded.Star),
    AvatarOption("pets", Icons.Rounded.Pets),
    AvatarOption("child", Icons.Rounded.ChildCare),
    AvatarOption("gaming", Icons.Rounded.SportsEsports),
    AvatarOption("music", Icons.Rounded.MusicNote),
    AvatarOption("movie", Icons.Rounded.Movie),
)

private val colorOptions: List<Long> = listOf(
    0xFF00D9FF,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFFFFD700,
    0xFF4CAF50,
    0xFFFF5722,
    0xFFE91E63,
    0xFF2196F3,
)

@Composable
fun ProfileScreen(
    existingAccount: AccountEntity? = null,
    onSave: (username: String, password: String, avatarIcon: String, accentColor: Long) -> Unit,
    onDelete: (() -> Unit)? = null,
    onBackClick: () -> Unit,
) {
    val isEditing = existingAccount != null

    var username by remember { mutableStateOf(existingAccount?.username ?: "") }
    var password by remember { mutableStateOf("") }
    var passwordVisible by remember { mutableStateOf(false) }
    var selectedIcon by remember { mutableStateOf(existingAccount?.avatarIcon ?: "person") }
    var selectedColor by remember { mutableStateOf(existingAccount?.accentColor ?: colorOptions.first()) }

    val selectedAvatarVector = avatarOptions.firstOrNull { it.key == selectedIcon }?.icon ?: Icons.Rounded.Person

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
            .verticalScroll(rememberScrollState()),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 8.dp, end = 16.dp, top = 48.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBackClick) {
                Icon(Icons.Rounded.ArrowBack, contentDescription = "Retour", tint = Color.White)
            }
            Text(
                text = if (isEditing) "Modifier le profil" else "Nouveau profil",
                fontSize = 24.sp,
                fontWeight = FontWeight.Black,
                color = TextPrimary,
            )
        }

        Spacer(Modifier.height(32.dp))

        Box(
            modifier = Modifier
                .size(100.dp)
                .align(Alignment.CenterHorizontally)
                .clip(CircleShape)
                .background(Color(selectedColor)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = selectedAvatarVector,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(52.dp),
            )
        }

        Spacer(Modifier.height(32.dp))

        Column(modifier = Modifier.padding(horizontal = 24.dp)) {
            Text(
                text = "Nom d'utilisateur",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = AccentCyan,
                modifier = Modifier.padding(bottom = 6.dp),
            )
            OutlinedTextField(
                value = username,
                onValueChange = { username = it },
                placeholder = { Text("Entrez un nom") },
                singleLine = true,
                colors = fieldColors(),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(Modifier.height(20.dp))

            Text(
                text = "Mot de passe (optionnel)",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = AccentCyan,
                modifier = Modifier.padding(bottom = 6.dp),
            )
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                placeholder = { Text(if (isEditing) "Laisser vide pour ne pas changer" else "Entrez un mot de passe") },
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
                colors = fieldColors(),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(Modifier.height(28.dp))

            Text(
                text = "Icône",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = AccentCyan,
                modifier = Modifier.padding(bottom = 10.dp),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                avatarOptions.forEach { option ->
                    val isSelected = selectedIcon == option.key
                    Box(
                        modifier = Modifier
                            .size(52.dp)
                            .clip(CircleShape)
                            .background(if (isSelected) CardSurface else Color.Transparent)
                            .border(
                                width = if (isSelected) 2.dp else 1.dp,
                                color = if (isSelected) AccentCyan else GlassBorder,
                                shape = CircleShape,
                            )
                            .clickable { selectedIcon = option.key },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = option.icon,
                            contentDescription = option.key,
                            tint = if (isSelected) AccentCyan else TextSecondary,
                            modifier = Modifier.size(26.dp),
                        )
                    }
                }
            }

            Spacer(Modifier.height(28.dp))

            Text(
                text = "Couleur",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = AccentCyan,
                modifier = Modifier.padding(bottom = 10.dp),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                colorOptions.forEach { color ->
                    val isSelected = selectedColor == color
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color(color))
                            .then(
                                if (isSelected) Modifier.border(3.dp, Color.White, CircleShape)
                                else Modifier.border(1.dp, GlassBorder, CircleShape)
                            )
                            .clickable { selectedColor = color },
                    )
                }
            }

            Spacer(Modifier.height(36.dp))

            Button(
                onClick = { onSave(username.trim(), password, selectedIcon, selectedColor) },
                enabled = username.isNotBlank(),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            brush = Brush.horizontalGradient(listOf(AccentCyan, AccentPurple)),
                            shape = RoundedCornerShape(14.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Enregistrer",
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        color = Color.White,
                    )
                }
            }

            if (isEditing && onDelete != null) {
                Spacer(Modifier.height(16.dp))

                Button(
                    onClick = onDelete,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0x33FF4444),
                        contentColor = Color(0xFFFF4444),
                    ),
                ) {
                    Text(
                        text = "Supprimer le profil",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                }
            }

            Spacer(Modifier.height(40.dp))
        }
    }
}

@Composable
private fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = TextPrimary,
    unfocusedTextColor = TextPrimary,
    cursorColor = AccentCyan,
    focusedBorderColor = AccentCyan,
    unfocusedBorderColor = GlassBorder,
    focusedLabelColor = AccentCyan,
    unfocusedLabelColor = TextSecondary,
    focusedPlaceholderColor = TextSecondary,
    unfocusedPlaceholderColor = TextSecondary,
    focusedContainerColor = CardSurface,
    unfocusedContainerColor = CardSurface,
)
