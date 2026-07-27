import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/tv_config.dart';
import '../../providers/providers.dart';
import '../../providers/update_provider.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../widgets/update_dialog.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';

class TVSettingsScreen extends StatefulWidget {
  final bool embedded;
  const TVSettingsScreen({super.key, this.embedded = false});

  @override
  State<TVSettingsScreen> createState() => _TVSettingsScreenState();
}

class _TVSettingsScreenState extends State<TVSettingsScreen> {
  final ApiService _api = ApiService();
  bool _autoPlay = true;
  bool _autoSubtitles = false;
  bool _isRefreshingSecurity = false;
  bool _isCheckingUpdate = false;
  bool _allowPreRelease = false;
  int _focusedSection = 0;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUpdatePrefs();
  }

  Future<void> _loadUpdatePrefs() async {
    final update = context.read<UpdateProvider>();
    final allow = await update.allowPreRelease;
    if (mounted) setState(() => _allowPreRelease = allow);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAccountCard(
                  user?.username ?? '-',
                  user?.email ?? '-',
                  auth.isPremium,
                ),
                const SizedBox(height: 28),
                _buildSectionHeader('Lecture'),
                const SizedBox(height: 12),
                _buildToggleCard(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Lecture automatique',
                  subtitle: 'Lance la lecture dès que la source est prête',
                  value: _autoPlay,
                  onChanged: (v) => setState(() => _autoPlay = v),
                  sectionIndex: 1,
                  itemIndex: 0,
                ),
                const SizedBox(height: 10),
                _buildToggleCard(
                  icon: Icons.closed_caption_off_outlined,
                  title: 'Sous-titres automatiques',
                  subtitle: 'Active si disponibles selon la source',
                  value: _autoSubtitles,
                  onChanged: (v) => setState(() => _autoSubtitles = v),
                  sectionIndex: 1,
                  itemIndex: 1,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 32, 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('Compte et sécurité'),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.lock_outline_rounded,
                  title: 'Changer le mot de passe',
                  subtitle: 'Mettre a jour vos identifiants',
                  onTap: _showChangePasswordDialog,
                  accent: TVTheme.infoCyan,
                  sectionIndex: 0,
                  itemIndex: 0,
                ),
                const SizedBox(height: 10),
                _buildActionCard(
                  icon: Icons.refresh_rounded,
                  title: _isRefreshingSecurity
                      ? 'Rotation en cours...'
                      : 'Rafraîchir la session',
                  subtitle: 'Renouvelle le jeton de vérification côté API',
                  onTap: _isRefreshingSecurity
                      ? () {}
                      : _refreshSecuritySession,
                  accent: TVTheme.infoCyan,
                  isLoading: _isRefreshingSecurity,
                  sectionIndex: 0,
                  itemIndex: 1,
                ),
                const SizedBox(height: 10),
                _buildActionCard(
                  icon: Icons.vpn_key_outlined,
                  title: 'Activer une clé de licence',
                  subtitle: 'Saisir une clé reçue pour débloquer l\'offre',
                  onTap: () =>
                      _showRedeemLicenseDialog(context.read<AuthProvider>()),
                  accent: TVTheme.accentGold,
                  sectionIndex: 0,
                  itemIndex: 2,
                ),
                const SizedBox(height: 28),
                _buildSectionHeader('Données'),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'Supprimer l\'historique',
                  subtitle: 'Effacer toutes les reprises de lecture',
                  onTap: _confirmClearHistory,
                  accent: TVTheme.warningOrange,
                  isDestructive: true,
                  sectionIndex: 2,
                  itemIndex: 0,
                ),
                const SizedBox(height: 10),
                _buildActionCard(
                  icon: Icons.favorite_outline_rounded,
                  title: 'Vider les favoris',
                  subtitle: 'Retirer tous les contenus enregistrés',
                  onTap: _confirmClearFavorites,
                  accent: TVTheme.errorRed,
                  isDestructive: true,
                  sectionIndex: 2,
                  itemIndex: 1,
                ),
                const SizedBox(height: 28),
                _buildSectionHeader('Application'),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.system_update_rounded,
                  title: _isCheckingUpdate
                      ? 'Vérification en cours...'
                      : 'Vérifier les mises à jour',
                  subtitle: 'Version actuelle : v${AppConstants.appVersion}',
                  onTap: _isCheckingUpdate ? () {} : _checkForUpdates,
                  accent: TVTheme.successGreen,
                  isLoading: _isCheckingUpdate,
                  sectionIndex: 4,
                  itemIndex: 0,
                ),
                const SizedBox(height: 10),
                _buildToggleCard(
                  icon: Icons.science_outlined,
                  title: 'Versions bêta (pré-releases)',
                  subtitle: 'Inclut les versions instables dans la détection',
                  value: _allowPreRelease,
                  onChanged: (v) async {
                    setState(() => _allowPreRelease = v);
                    await context.read<UpdateProvider>().setAllowPreRelease(v);
                  },
                  sectionIndex: 4,
                  itemIndex: 1,
                ),
                const SizedBox(height: 28),
                _buildSectionHeader('Session'),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.logout_rounded,
                  title: 'Déconnexion',
                  subtitle: 'Fermer cette session et retourner à l\'accueil',
                  onTap: _logout,
                  accent: TVTheme.errorRed,
                  isDestructive: true,
                  sectionIndex: 3,
                  itemIndex: 0,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: TVTheme.backgroundDark,
        body: Container(
          decoration: TVTheme.screenDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 24, 32, 0),
                child: Text('Paramètres', style: TextStyle(color: TVTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w600)),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return TVWrapper(
      title: 'Paramètres',
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      child: body,
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              gradient: TVTheme.heroGradient,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: TVTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(String username, String email, bool isPremium) {
    final accent = isPremium ? TVTheme.accentGold : TVTheme.accentRed;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: TVTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: isPremium
                  ? const LinearGradient(
                      colors: [Color(0xFFB8952F), Color(0xFFD4AF37)],
                    )
                  : TVTheme.heroGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: TVTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: TVTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.verified_user_outlined,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Text(
                  isPremium ? 'Premium' : 'Compte',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required int sectionIndex,
    required int itemIndex,
    Color accent = TVTheme.accentRed,
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    final isFocused =
        _focusedSection == sectionIndex && _focusedIndex == itemIndex;
    final color = isDestructive ? TVTheme.errorRed : accent;

    return TVFocusableCard(
      autoFocus: isFocused,
      onTap: onTap,
      onFocus: () {
        if (mounted) setState(() {
          _focusedSection = sectionIndex;
          _focusedIndex = itemIndex;
        });
      },
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: TVTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: TVTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent,
              ),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.6),
              size: 22,
            ),
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required int sectionIndex,
    required int itemIndex,
  }) {
    final isFocused =
        _focusedSection == sectionIndex && _focusedIndex == itemIndex;
    final accent = value ? TVTheme.successGreen : TVTheme.textSecondary;

    return TVFocusableCard(
      autoFocus: isFocused,
      onTap: () => onChanged(!value),
      onFocus: () {
        if (mounted) setState(() {
          _focusedSection = sectionIndex;
          _focusedIndex = itemIndex;
        });
      },
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: TVTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: TVTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: TVTheme.accentRed.withValues(alpha: 0.35),
            inactiveThumbColor: TVTheme.textDisabled,
            inactiveTrackColor: const Color(0xFF2A2A4A).withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────

  Future<void> _checkForUpdates() async {
    final update = context.read<UpdateProvider>();
    setState(() => _isCheckingUpdate = true);
    await update.checkManual(includePreRelease: _allowPreRelease);
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (update.hasUpdate && update.lastResult?.release != null) {
      showUpdateDialog(context, isTV: true);
    } else if (update.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${update.error}'),
          backgroundColor: TVTheme.errorRed,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous êtes à jour (v${AppConstants.appVersion})'),
          backgroundColor: TVTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _refreshSecuritySession() async {
    setState(() => _isRefreshingSecurity = true);
    try {
      await _api.refreshSecuritySession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session de sécurité rafraîchie'),
            backgroundColor: TVTheme.accentRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: TVTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingSecurity = false);
    }
  }

  void _showRedeemLicenseDialog(AuthProvider auth) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TVTheme.surfaceColor,
        title: const Text(
          'Activer une clé',
          style: TextStyle(color: TVTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entrez votre clé de licence pour appliquer l\'offre correspondante.',
              style: TextStyle(color: TVTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: TVTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Clé de licence',
                labelStyle: TextStyle(color: TVTheme.textSecondary),
                hintText: 'NEO-XXXXX-XXXXX-XXXXX-XXXXX',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.redeemLicenseKey(controller.text.trim());
                await auth.refreshUser();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Clé activée avec succès'),
                      backgroundColor: TVTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: TVTheme.errorRed,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: TVTheme.accentRed),
            child: const Text('Activer'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TVTheme.surfaceColor,
        title: const Text(
          'Changer le mot de passe',
          style: TextStyle(color: TVTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              style: const TextStyle(color: TVTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Mot de passe actuel',
                labelStyle: TextStyle(color: TVTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: const TextStyle(color: TVTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
                labelStyle: TextStyle(color: TVTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              style: const TextStyle(color: TVTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Confirmation',
                labelStyle: TextStyle(color: TVTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Les mots de passe ne correspondent pas'),
                    backgroundColor: TVTheme.errorRed,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _api.changePassword(oldCtrl.text, newCtrl.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mot de passe modifié'),
                      backgroundColor: TVTheme.accentRed,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: TVTheme.errorRed,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: TVTheme.accentRed),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TVTheme.surfaceColor,
        title: const Text(
          'Supprimer l\'historique ?',
          style: TextStyle(color: TVTheme.textPrimary),
        ),
        content: const Text(
          'Toutes les reprises de lecture seront supprimées.',
          style: TextStyle(color: TVTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Historique supprimé'),
                      backgroundColor: TVTheme.accentRed,
                    ),
                  );
                }
              } catch (_) {}
            },
            style: FilledButton.styleFrom(backgroundColor: TVTheme.errorRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmClearFavorites() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TVTheme.surfaceColor,
        title: const Text(
          'Vider les favoris ?',
          style: TextStyle(color: TVTheme.textPrimary),
        ),
        content: const Text(
          'Les contenus enregistrés seront retirés de votre liste.',
          style: TextStyle(color: TVTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Favoris vides'),
                    backgroundColor: TVTheme.accentRed,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: TVTheme.errorRed),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
