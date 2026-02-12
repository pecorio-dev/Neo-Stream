package dev.neostream.app.ui.mobile.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Cached
import androidx.compose.material.icons.rounded.Cloud
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Tv
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.neostream.app.BuildConfig
import dev.neostream.app.ui.theme.AccentCyan
import dev.neostream.app.ui.theme.AccentPurple
import dev.neostream.app.ui.theme.CardSurface
import dev.neostream.app.ui.theme.DeepBlack
import dev.neostream.app.ui.theme.GlassBorder
import dev.neostream.app.ui.theme.LocalIsTV
import dev.neostream.app.ui.theme.TextSecondary
import dev.neostream.app.data.repository.ViewingStatsCalculator
import dev.neostream.app.util.PlatformDetector
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen(
    onBackClick: () -> Unit,
    onSwitchAccount: () -> Unit = {},
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val isTV = LocalIsTV.current
    val tvPad = if (isTV) 48.dp else 0.dp
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var forceTv by remember { mutableStateOf(false) }
    var visible by remember { mutableStateOf(false) }
    var stats by remember { mutableStateOf<ViewingStatsCalculator.ViewingStats?>(null) }
    var isLoadingStats by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) { 
        visible = true
        // Charger l'état actuel du mode TV forcé
        forceTv = PlatformDetector.isForceTvMode(context)
        
        scope.launch {
            isLoadingStats = true
            try {
                stats = ViewingStatsCalculator.calculateStats(context)
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                isLoadingStats = false
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepBlack)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = tvPad)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 8.dp, end = 16.dp, top = if (isTV) 24.dp else 48.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBackClick) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Retour", tint = Color.White)
            }
            Text(
                "Parametres",
                fontSize = if (isTV) 28.sp else 24.sp,
                fontWeight = FontWeight.Black,
                color = Color.White,
            )
        }

        Spacer(Modifier.height(20.dp))

        AnimatedVisibility(
            visible = visible,
            enter = fadeIn() + slideInVertically { it / 4 },
        ) {
            SettingsSection(title = "Compte", icon = Icons.Rounded.AccountCircle) {
                SettingsItem(
                    title = "Changer de compte",
                    subtitle = "Sélectionner un autre compte",
                    onClick = onSwitchAccount
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        // Statistiques de visionnage
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn() + slideInVertically { it / 4 },
        ) {
            if (isLoadingStats) {
                SettingsSection(title = "💰 Vos économies avec NeoStream", icon = Icons.Rounded.BarChart) {
                    SettingsItem(
                        title = "Chargement des statistiques...",
                        subtitle = "Calcul de vos économies en cours"
                    )
                }
            } else {
                val viewingStats = stats ?: ViewingStatsCalculator.ViewingStats(
                    totalFilmsWatched = 0,
                    totalEpisodesWatched = 0,
                    totalContentWatched = 0,
                    estimatedCostStreaming = 0.0,
                    estimatedCostCinema = 0.0,
                    savedAmount = 0.0,
                    savedPercentage = 0.0
                )
                
                SettingsSection(title = "💰 Vos économies avec NeoStream", icon = Icons.Rounded.BarChart) {
                    SettingsItem(
                        title = "📊 Contenus regardés gratuitement",
                        subtitle = "${viewingStats.totalFilmsWatched} films • ${viewingStats.totalEpisodesWatched} épisodes • ${viewingStats.totalContentWatched} au total"
                    )
                    SettingsItem(
                        title = "💸 Économies réalisées",
                        subtitle = if (viewingStats.savedAmount > 0) {
                            "${viewingStats.formatSaved()} économisés vs abonnements streaming (${viewingStats.formatCostStreaming()} gratuits !)"
                        } else {
                            "Commencez à regarder des contenus pour voir vos économies !"
                        }
                    )
                    if (viewingStats.savedAmount > 0 && viewingStats.totalFilmsWatched > 0) {
                        SettingsItem(
                            title = "🎬 Comparaison cinéma",
                            subtitle = "Ces ${viewingStats.totalFilmsWatched} films au cinéma = ${viewingStats.formatCostCinema()}"
                        )
                    }
                    SettingsItem(
                        title = "☕ Équivalent en donations Ko-fi",
                        subtitle = if (viewingStats.savedAmount > 0) {
                            "${ViewingStatsCalculator.getCoffeeEquivalent(viewingStats)} cafés de 3€ que vous auriez pu donner pour soutenir le projet"
                        } else {
                            "Vos économies apparaîtront ici après avoir regardé des contenus"
                        }
                    )
                    if (viewingStats.savedAmount > 0) {
                        SettingsItem(
                            title = "${ViewingStatsCalculator.getEncouragementMessage(viewingStats)}",
                            subtitle = ViewingStatsCalculator.getResponsibilityMessage(viewingStats)
                        )
                    }
                }
            }
        }
        
        Spacer(Modifier.height(8.dp))
        
        // Bouton Ko-fi stratégiquement placé après les stats
        AnimatedVisibility(
            visible = visible && !isLoadingStats,
            enter = fadeIn() + slideInVertically { it },
        ) {
            SettingsSection(title = "☕ Soutenir le projet", icon = Icons.Rounded.Favorite) {
                SettingsItem(
                    title = "💝 Offrir un café au développeur",
                    subtitle = "Un don de 3€ = Des heures de développement • Merci infiniment ! 🙏",
                    trailing = {
                        Icon(
                            Icons.Rounded.Favorite,
                            contentDescription = null,
                            tint = Color(0xFFFF5E5B),
                            modifier = Modifier.size(28.dp),
                        )
                    },
                    onClick = {
                        val intent = android.content.Intent(
                            android.content.Intent.ACTION_VIEW,
                            android.net.Uri.parse("https://ko-fi.com/pecorio")
                        )
                        context.startActivity(intent)
                    }
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        AnimatedVisibility(
            visible = visible,
            enter = fadeIn() + slideInVertically { it / 4 },
        ) {
            SettingsSection(title = "Serveur API", icon = Icons.Rounded.Cloud) {
                SettingsItem(
                    title = "URL du serveur",
                    subtitle = BuildConfig.API_BASE_URL,
                    trailing = {
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .background(Color(0xFF4CAF50), CircleShape)
                        )
                    },
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(initialAlpha = 0f) + slideInVertically { it / 3 },
        ) {
            SettingsSection(title = "Affichage", icon = Icons.Rounded.Tv) {
                SettingsItem(
                    title = "📺 Mode TV forcé",
                    subtitle = if (forceTv) "Activé • Redémarrez l'app pour appliquer" else "Désactivé • Interface mobile",
                    trailing = {
                        Switch(
                            checked = forceTv,
                            onCheckedChange = { enabled ->
                                forceTv = enabled
                                PlatformDetector.setForceTvMode(context, enabled)
                                // Appliquer immédiatement en recréant l'activité
                                (context as? android.app.Activity)?.recreate()
                            },
                            colors = SwitchDefaults.colors(
                                checkedTrackColor = AccentCyan,
                                checkedThumbColor = Color.White,
                            ),
                        )
                    },
                )
                
                if (forceTv) {
                    SettingsItem(
                        title = "🎮 Navigation clavier",
                        subtitle = "WASD ou flèches = Navigation • Enter/Space = Sélectionner • Backspace = Retour"
                    )
                }
            }
        }

        Spacer(Modifier.height(12.dp))

        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(initialAlpha = 0f) + slideInVertically { it / 2 },
        ) {
            SettingsSection(title = "Cache", icon = Icons.Rounded.Cached) {
                SettingsItem(
                    title = "Vider le cache images",
                    subtitle = "Libere l'espace de stockage",
                    trailing = {
                        Icon(
                            Icons.Rounded.Delete,
                            contentDescription = null,
                            tint = TextSecondary,
                            modifier = Modifier.size(20.dp),
                        )
                    },
                    onClick = { /* TODO: clear Coil cache */ },
                )
            }
        }


        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(initialAlpha = 0f) + slideInVertically { it },
        ) {
            SettingsSection(title = "⚠️ Avertissement légal", icon = Icons.Rounded.Info) {
                SettingsItem(
                    title = "Responsabilité",
                    subtitle = "NeoStream est un lecteur média. Utilisez uniquement du contenu légal. Le développeur n'est pas responsable de l'utilisation qui en est faite."
                )
                SettingsItem(
                    title = "⭐ Soutenez les créateurs",
                    subtitle = "Pour un contenu légal et de qualité, utilisez les plateformes officielles (Netflix, Disney+, etc.)"
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(initialAlpha = 0f) + slideInVertically { it },
        ) {
            SettingsSection(title = "A propos", icon = Icons.Rounded.Info) {
                SettingsItem(
                    title = "NeoStream",
                    subtitle = "Version ${BuildConfig.VERSION_NAME}",
                )
                SettingsItem(
                    title = "Architecture",
                    subtitle = "Kotlin + Compose + Ktor + Media3",
                )
            }
        }

        Spacer(Modifier.height(40.dp))
    }
}

@Composable
private fun SettingsSection(
    title: String,
    icon: ImageVector,
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(bottom = 8.dp),
        ) {
            Icon(icon, contentDescription = null, tint = AccentCyan, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(title, color = AccentCyan, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(CardSurface)
                .border(1.dp, GlassBorder, RoundedCornerShape(16.dp)),
        ) {
            content()
        }
    }
}

@Composable
private fun SettingsItem(
    title: String,
    subtitle: String,
    trailing: @Composable (() -> Unit)? = null,
    onClick: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = Color.White, fontWeight = FontWeight.Medium, fontSize = 15.sp)
            Text(subtitle, color = TextSecondary, fontSize = 12.sp)
        }
        trailing?.invoke()
    }
}
