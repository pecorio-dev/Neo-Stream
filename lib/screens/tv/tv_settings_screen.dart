import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/tv_config.dart';
import '../../providers/providers.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';

class TVSettingsScreen extends StatefulWidget {
  const TVSettingsScreen({super.key});

  @override
  State<TVSettingsScreen> createState() => _TVSettingsScreenState();
}

class _TVSettingsScreenState extends State<TVSettingsScreen> {
  final ApiService _api = ApiService();
  bool _autoPlay = true;
  bool _autoSubtitles = false;
  bool _isRefreshingSecurity = false;
  int _focusedIndex = 0;

  final List<_SettingsItem> _items = [];

  @override
  void initState() {
    super.initState();
    _buildItems();
  }

  void _buildItems() {
    _items.clear();
    _items.addAll([
      _SettingsItem(
        icon: Icons.person_outline,
        title: 'Changer le mot de passe',
        subtitle: 'Mettre a jour vos identifiants',
        onTap: _showChangePasswordDialog,
      ),
      _SettingsItem(
        icon: Icons.refresh,
        title: 'Rafraichir la session',
        subtitle: 'Renouvelle le jeton de securite',
        onTap: _refreshSecuritySession,
        isLoading: _isRefreshingSecurity,
      ),
      _SettingsItem(
        icon: Icons.vpn_key_outlined,
        title: 'Activer une cle',
        subtitle: 'Saisir une cle recue',
        onTap: () => _showRedeemLicenseDialog(context.read<AuthProvider>()),
      ),
      _SettingsItem(
        icon: Icons.history_toggle_off,
        title: 'Supprimer historique',
        subtitle: 'Effacer toutes les reprises',
        onTap: _confirmClearHistory,
        isDestructive: true,
      ),
      _SettingsItem(
        icon: Icons.favorite_outline,
        title: 'Vider les favoris',
        subtitle: 'Retirer tous les contenus',
        onTap: _confirmClearFavorites,
        isDestructive: true,
      ),
      _SettingsItem(
        icon: Icons.logout,
        title: 'Deconnexion',
        subtitle: 'Fermer cette session',
        onTap: _logout,
        isDestructive: true,
      ),
    ]);
  }

  Future<void> _refreshSecuritySession() async {
    setState(() => _isRefreshingSecurity = true);
    try {
      await _api.refreshSecuritySession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session de securite rafraichie'),
            backgroundColor: TVTheme.accentRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: TVTheme.errorRed),
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
        title: const Text('Activer une cle', style: TextStyle(color: TVTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: TVTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Cle de licence',
            labelStyle: TextStyle(color: TVTheme.textSecondary),
          ),
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
                    const SnackBar(content: Text('Cle activee'), backgroundColor: TVTheme.successGreen),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: TVTheme.errorRed),
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
        title: const Text('Changer le mot de passe', style: TextStyle(color: TVTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              style: const TextStyle(color: TVTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Actuel', labelStyle: TextStyle(color: TVTheme.textSecondary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: const TextStyle(color: TVTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Nouveau', labelStyle: TextStyle(color: TVTheme.textSecondary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              style: const TextStyle(color: TVTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Confirmation', labelStyle: TextStyle(color: TVTheme.textSecondary)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: TVTheme.errorRed),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _api.changePassword(oldCtrl.text, newCtrl.text);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mot de passe modifie'), backgroundColor: TVTheme.accentRed),
                );
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e'), backgroundColor: TVTheme.errorRed),
                );
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
        title: const Text('Supprimer historique ?', style: TextStyle(color: TVTheme.textPrimary)),
        content: const Text('Toutes les reprises seront supprimees.', style: TextStyle(color: TVTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteHistory();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historique supprime'), backgroundColor: TVTheme.accentRed),
                );
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
        title: const Text('Vider les favoris ?', style: TextStyle(color: TVTheme.textPrimary)),
        content: const Text('Les contenus seront retires de votre liste.', style: TextStyle(color: TVTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Favoris vidés'), backgroundColor: TVTheme.accentRed),
              );
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return TVWrapper(
      title: 'Parametres',
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountCard(user?.username ?? '-', user?.email ?? '-', auth.isPremium),
            const SizedBox(height: 24),
            Text('COMPTE ET SECURITE', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: TVTheme.textSecondary, letterSpacing: 2)),
            const SizedBox(height: 16),
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              final isFocused = _focusedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TVFocusableCard(
                  autoFocus: isFocused,
                  onTap: item.onTap,
                  onFocus: () => setState(() => _focusedIndex = index),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (item.isDestructive ? TVTheme.errorRed : TVTheme.accentRed).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.isDestructive ? TVTheme.errorRed : TVTheme.accentRed),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(item.subtitle, style: const TextStyle(color: TVTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (item.isLoading)
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: TVTheme.accentRed))
                      else
                        Icon(Icons.chevron_right, color: item.isDestructive ? TVTheme.errorRed : TVTheme.textSecondary),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(String username, String email, bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: TVTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isPremium ? TVTheme.accentGold : TVTheme.accentRed).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: isPremium ? const LinearGradient(colors: [Color(0xFFB8952F), Color(0xFFD4AF37)]) : TVTheme.heroGradient,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: TVTheme.textSecondary, fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isPremium ? TVTheme.accentGold : TVTheme.infoCyan).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: (isPremium ? TVTheme.accentGold : TVTheme.infoCyan).withValues(alpha: 0.3)),
            ),
            child: Text(isPremium ? 'Premium' : 'Compte', style: TextStyle(color: isPremium ? TVTheme.accentGold : TVTheme.infoCyan, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isLoading;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.isLoading = false,
  });
}
