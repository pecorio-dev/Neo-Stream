import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import '../widgets/section_header.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();
  bool _autoPlay = true;
  bool _autoSubtitles = false;
  bool _isRefreshingSecurity = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      appBar: AppBar(
        backgroundColor: NeoTheme.bgBase,
        title: Text('Parametres', style: NeoTheme.headlineMedium(context)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          NeoTheme.screenPadding(context).left,
          12,
          NeoTheme.screenPadding(context).right,
          48,
        ),
        children: [
          SectionHeader(
            title: 'Compte et securite',
            subtitle:
                'Preferences locales, verification API et hygiene de session.',
            icon: Icons.tune_rounded,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          _buildAccountSummary(
            context,
            username: user?.username ?? '-',
            email: user?.email ?? '-',
            isPremium: auth.isPremium,
          ),
          const SizedBox(height: 16),
          _buildPanel(
            context,
            title: 'Compte',
            subtitle: 'Informations personnelles et securite',
            children: [
              _buildInfoRow(
                context,
                Icons.person_outline_rounded,
                'Nom',
                user?.username ?? '-',
              ),
              _buildDivider(),
              _buildInfoRow(
                context,
                Icons.alternate_email_rounded,
                'Email',
                user?.email ?? '-',
              ),
              _buildDivider(),
              _buildActionRow(
                context,
                icon: Icons.lock_outline_rounded,
                title: 'Changer le mot de passe',
                subtitle: 'Mettre a jour vos identifiants',
                onTap: _showChangePasswordDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPanel(
            context,
            title: 'Lecture',
            subtitle: 'Comportement du lecteur selon l appareil',
            children: [
              _buildToggleRow(
                context,
                icon: Icons.play_circle_outline_rounded,
                title: 'Lecture automatique',
                subtitle: 'Lancer la lecture quand la source est prete',
                value: _autoPlay,
                onChanged: (value) => setState(() => _autoPlay = value),
              ),
              _buildDivider(),
              _buildToggleRow(
                context,
                icon: Icons.closed_caption_off_outlined,
                title: 'Sous-titres automatiques',
                subtitle: 'Activer si disponibles selon la source',
                value: _autoSubtitles,
                onChanged: (value) => setState(() => _autoSubtitles = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPanel(
            context,
            title: 'Securite',
            subtitle:
                'Protection continue contre bypass, session fraudee et client non verifie',
            children: [

              _buildActionRow(
                context,
                icon: Icons.refresh_rounded,
                title: _isRefreshingSecurity
                    ? 'Rotation en cours'
                    : 'Rafraichir la session de securite',
                subtitle: 'Renouvelle le jeton de verification cote API',
                onTap: _isRefreshingSecurity ? () {} : _refreshSecuritySession,
                color: NeoTheme.infoCyan,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPanel(
            context,
            title: 'Licence et abonnement',
            subtitle:
                'Activez une cle pour appliquer automatiquement l offre associee a votre compte',
            children: [
              _buildInfoRow(
                context,
                Icons.workspace_premium_outlined,
                'Offre actuelle',
                user?.premiumLabel ?? 'Gratuit',
                valueColor: auth.isPremium
                    ? NeoTheme.prestigeGold
                    : NeoTheme.textSecondary,
              ),
              _buildDivider(),
              _buildActionRow(
                context,
                icon: Icons.vpn_key_outlined,
                title: 'Activer une cle de licence',
                subtitle:
                    'Saisir une cle recue pour debloquer l offre correspondante',
                onTap: () => _showRedeemLicenseDialog(auth),
                color: NeoTheme.prestigeGold,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPanel(
            context,
            title: 'Donnees',
            subtitle: 'Nettoyage local et historique utilisateur',
            children: [
              _buildActionRow(
                context,
                icon: Icons.history_toggle_off_rounded,
                title: 'Supprimer l historique',
                subtitle: 'Effacer toutes les reprises de lecture',
                onTap: _confirmClearHistory,
                color: NeoTheme.warningOrange,
              ),
              _buildDivider(),
              _buildActionRow(
                context,
                icon: Icons.favorite_outline_rounded,
                title: 'Vider les favoris',
                subtitle: 'Retirer les contenus enregistres de votre liste',
                onTap: _confirmClearFavorites,
                color: NeoTheme.errorRed,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPanel(
            context,
            title: 'Application',
            subtitle: 'Informations de service et de build',
            children: [
              _buildInfoRow(
                context,
                Icons.info_outline_rounded,
                'Version',
                '1.0.0',
              ),
              _buildDivider(),
              _buildInfoRow(
                context,
                Icons.workspace_premium_outlined,
                'Statut',
                auth.isPremium ? 'Premium' : 'Gratuit',
                valueColor: auth.isPremium
                    ? NeoTheme.prestigeGold
                    : NeoTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded, color: NeoTheme.errorRed),
              label: Text(
                'Deconnexion',
                style: NeoTheme.titleMedium(
                  context,
                ).copyWith(color: NeoTheme.errorRed),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: NeoTheme.errorRed.withValues(alpha: 0.2),
                ),
                backgroundColor: NeoTheme.errorRed.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSummary(
    BuildContext context, {
    required String username,
    required String email,
    required bool isPremium,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: NeoTheme.glassGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: (isPremium ? NeoTheme.prestigeGold : NeoTheme.primaryRed).withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isPremium
                  ? NeoTheme.premiumGradient
                  : NeoTheme.heroGradient,
              boxShadow: [
                BoxShadow(
                  color: (isPremium ? NeoTheme.prestigeGold : NeoTheme.primaryRed).withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: NeoTheme.headlineMedium(
                  context,
                ).copyWith(color: isPremium ? Colors.black : Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username, style: NeoTheme.titleLarge(context)),
                const SizedBox(height: 4),
                Text(email, style: NeoTheme.bodySmall(context)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isPremium ? NeoTheme.prestigeGold : NeoTheme.infoCyan).withValues(alpha: isPremium ? 0.08 : 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: (isPremium ? NeoTheme.prestigeGold : NeoTheme.infoCyan).withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              isPremium ? 'Premium' : 'Secure',
              style: NeoTheme.labelMedium(context).copyWith(
                color: isPremium ? NeoTheme.prestigeGold : NeoTheme.infoCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(color: NeoTheme.bgBorder.withValues(alpha: 0.15), width: 0.5),
        boxShadow: NeoTheme.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: NeoTheme.titleLarge(context)),
          const SizedBox(height: 4),
          Text(subtitle, style: NeoTheme.bodySmall(context)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        color: NeoTheme.bgBorder.withValues(alpha: 0.12),
        height: 0.5,
        thickness: 0.5,
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        _buildLeading(icon, NeoTheme.infoCyan),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NeoTheme.labelMedium(context)),
              const SizedBox(height: 4),
              Text(
                value,
                style: NeoTheme.titleMedium(
                  context,
                ).copyWith(color: valueColor ?? NeoTheme.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final accent = color ?? NeoTheme.primaryRed;
    return InkWell(
      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _buildLeading(icon, accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: NeoTheme.titleMedium(context)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: NeoTheme.bodySmall(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        _buildLeading(
          icon,
          value ? NeoTheme.successGreen : NeoTheme.textTertiary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NeoTheme.titleMedium(context)),
              const SizedBox(height: 4),
              Text(subtitle, style: NeoTheme.bodySmall(context)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: NeoTheme.primaryRed,
          activeTrackColor: NeoTheme.primaryRed.withValues(alpha: 0.35),
        ),
      ],
    );
  }

  Widget _buildLeading(IconData icon, Color accent) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Icon(icon, size: 18, color: accent),
    );
  }

  Future<void> _refreshSecuritySession() async {
    setState(() => _isRefreshingSecurity = true);
    try {
      await _api.refreshSecuritySession();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session de securite rafraichie'),
            backgroundColor: NeoTheme.primaryRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: NeoTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingSecurity = false);
      }
    }
  }

  void _showRedeemLicenseDialog(AuthProvider auth) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeoTheme.bgOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusXl)),
        title: Text('Activer une cle', style: NeoTheme.titleLarge(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrez votre cle de licence pour appliquer automatiquement l offre associee.',
              style: NeoTheme.bodyMedium(context),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: NeoTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Cle de licence',
                hintText: 'NEO-XXXXX-XXXXX-XXXXX-XXXXX',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: TextStyle(color: NeoTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final key = controller.text.trim();
              if (key.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Entrez une cle valide'),
                    backgroundColor: NeoTheme.errorRed,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              try {
                final response = await _api.redeemLicenseKey(key);
                await auth.refreshUser();
                if (!mounted) {
                  return;
                }
                final license = response['license'] as Map<String, dynamic>?;
                final offer = license?['offer_code']?.toString() ?? 'offre';
                final until = license?['premium_until']?.toString() ?? '';
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      until.isNotEmpty
                          ? 'Cle activee: $offer jusqu au ${until.split(' ').first}'
                          : 'Cle activee: $offer',
                    ),
                    backgroundColor: NeoTheme.successGreen,
                  ),
                );
                setState(() {});
              } catch (e) {
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: NeoTheme.errorRed,
                  ),
                );
              }
            },
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
        backgroundColor: NeoTheme.bgOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusXl)),
        title: Text(
          'Changer le mot de passe',
          style: NeoTheme.titleLarge(context),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              style: const TextStyle(color: NeoTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Mot de passe actuel',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: const TextStyle(color: NeoTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              style: const TextStyle(color: NeoTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Confirmation'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: TextStyle(color: NeoTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Les mots de passe ne correspondent pas'),
                    backgroundColor: NeoTheme.errorRed,
                  ),
                );
                return;
              }
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('6 caracteres minimum'),
                    backgroundColor: NeoTheme.errorRed,
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
                      content: Text('Mot de passe modifie'),
                      backgroundColor: NeoTheme.primaryRed,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: NeoTheme.errorRed,
                    ),
                  );
                }
              }
            },
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
        backgroundColor: NeoTheme.bgOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusXl)),
        title: Text(
          'Supprimer l historique ?',
          style: NeoTheme.titleLarge(context),
        ),
        content: Text(
          'Toutes les reprises de lecture seront supprimees.',
          style: NeoTheme.bodyMedium(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: TextStyle(color: NeoTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Historique supprime'),
                      backgroundColor: NeoTheme.primaryRed,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: NeoTheme.errorRed,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Supprimer',
              style: TextStyle(color: NeoTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearFavorites() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeoTheme.bgOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusXl)),
        title: Text('Vider les favoris ?', style: NeoTheme.titleLarge(context)),
        content: Text(
          'Les contenus enregistres seront retires de votre liste.',
          style: NeoTheme.bodyMedium(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: TextStyle(color: NeoTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Favoris vides'),
                    backgroundColor: NeoTheme.primaryRed,
                  ),
                );
              }
            },
            child: Text('Vider', style: TextStyle(color: NeoTheme.errorRed)),
          ),
        ],
      ),
    );
  }
}
