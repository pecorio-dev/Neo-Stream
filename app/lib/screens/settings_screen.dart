import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
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
    final isWide = MediaQuery.of(context).size.width >= 700;
    final isTV = NeoTheme.isTV(context);
    final hPad = NeoTheme.screenPadding(context);
    final scale = NeoTheme.scaleFactor(context);

    final accountCard = _buildAccountSummary(
      context,
      username: user?.username ?? '-',
      email: user?.email ?? '-',
      isPremium: auth.isPremium,
    );

    final panelCompte = _buildPanel(
      context,
      title: 'Compte',
      subtitle: 'Informations personnelles et securite',
      accent: NeoTheme.infoCyan,
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
    );

    final panelLecture = _buildPanel(
      context,
      title: 'Lecture',
      subtitle: 'Comportement du lecteur selon l appareil',
      accent: NeoTheme.successGreen,
      children: [
        _buildToggleRow(
          context,
          icon: Icons.play_circle_outline_rounded,
          title: 'Lecture automatique',
          subtitle: 'Lancer la lecture quand la source est prete',
          value: _autoPlay,
          onChanged: (v) => setState(() => _autoPlay = v),
        ),
        _buildDivider(),
        _buildToggleRow(
          context,
          icon: Icons.closed_caption_off_outlined,
          title: 'Sous-titres automatiques',
          subtitle: 'Activer si disponibles selon la source',
          value: _autoSubtitles,
          onChanged: (v) => setState(() => _autoSubtitles = v),
        ),
      ],
    );

    final panelSecurite = _buildPanel(
      context,
      title: 'Securite',
      subtitle: 'Protection continue contre bypass et session fraudee',
      accent: NeoTheme.infoCyan,
      children: [
        _buildActionRow(
          context,
          icon: Icons.refresh_rounded,
          title: _isRefreshingSecurity
              ? 'Rotation en cours...'
              : 'Rafraichir la session',
          subtitle: 'Renouvelle le jeton de verification cote API',
          onTap: _isRefreshingSecurity ? () {} : _refreshSecuritySession,
          color: NeoTheme.infoCyan,
          trailing: _isRefreshingSecurity
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NeoTheme.infoCyan,
                  ),
                )
              : null,
        ),
      ],
    );

    final panelLicence = _buildPanel(
      context,
      title: 'Licence et abonnement',
      subtitle: 'Activez une cle pour appliquer l offre associee',
      accent: NeoTheme.prestigeGold,
      children: [
        _buildInfoRow(
          context,
          Icons.workspace_premium_outlined,
          'Offre actuelle',
          user?.premiumLabel ?? 'Gratuit',
          valueColor:
              auth.isPremium ? NeoTheme.prestigeGold : NeoTheme.textSecondary,
        ),
        _buildDivider(),
        _buildActionRow(
          context,
          icon: Icons.vpn_key_outlined,
          title: 'Activer une cle de licence',
          subtitle: 'Saisir une cle recue pour debloquer l offre',
          onTap: () => _showRedeemLicenseDialog(auth),
          color: NeoTheme.prestigeGold,
        ),
      ],
    );

    final panelDonnees = _buildPanel(
      context,
      title: 'Donnees',
      subtitle: 'Nettoyage local et historique utilisateur',
      accent: NeoTheme.errorRed,
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
          subtitle: 'Retirer les contenus enregistres',
          onTap: _confirmClearFavorites,
          color: NeoTheme.errorRed,
        ),
      ],
    );

    final panelApp = _buildPanel(
      context,
      title: 'Application',
      subtitle: 'Informations de service et de build',
      accent: NeoTheme.textTertiary,
      children: [
        _buildInfoRow(context, Icons.info_outline_rounded, 'Version', '1.0.0'),
        _buildDivider(),
        _buildInfoRow(
          context,
          Icons.workspace_premium_outlined,
          'Statut',
          auth.isPremium ? 'Premium' : 'Gratuit',
          valueColor:
              auth.isPremium ? NeoTheme.prestigeGold : NeoTheme.textSecondary,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      appBar: AppBar(
        backgroundColor: NeoTheme.bgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 32 * scale,
              height: 32 * scale,
              decoration: BoxDecoration(
                gradient: NeoTheme.heroGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 16 * scale,
              ),
            ),
            SizedBox(width: 10 * scale),
            Text('Parametres', style: NeoTheme.headlineMedium(context)),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          hPad.left,
          isTV ? 24 : 12,
          hPad.right,
          48 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          accountCard,
          SizedBox(height: isTV ? 24 : 20),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      panelCompte,
                      const SizedBox(height: 16),
                      panelSecurite,
                      const SizedBox(height: 16),
                      panelLicence,
                    ],
                  ),
                ),
                SizedBox(width: isTV ? 20 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      panelLecture,
                      const SizedBox(height: 16),
                      panelDonnees,
                      const SizedBox(height: 16),
                      panelApp,
                    ],
                  ),
                ),
              ],
            )
          else ...[
            panelCompte,
            const SizedBox(height: 16),
            panelLecture,
            const SizedBox(height: 16),
            panelSecurite,
            const SizedBox(height: 16),
            panelLicence,
            const SizedBox(height: 16),
            panelDonnees,
            const SizedBox(height: 16),
            panelApp,
          ],
          const SizedBox(height: 24),
          _buildLogoutButton(context, auth),
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
    final scale = NeoTheme.scaleFactor(context);
    final avatarSize = NeoTheme.isTV(context) ? 72.0 : 58.0;
    final accent = isPremium ? NeoTheme.prestigeGold : NeoTheme.infoCyan;

    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        gradient: NeoTheme.glassGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(
          color: accent.withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: Row(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isPremium ? NeoTheme.premiumGradient : NeoTheme.heroGradient,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: NeoTheme.headlineMedium(context).copyWith(
                  color: isPremium ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: NeoTheme.titleLarge(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(email, style: NeoTheme.bodySmall(context)),
              ],
            ),
          ),
          SizedBox(width: 12 * scale),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: accent.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.verified_user_outlined,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  isPremium ? 'Premium' : 'Verifie',
                  style: NeoTheme.labelMedium(context)
                      .copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
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
    Color? accent,
  }) {
    final accentColor = accent ?? NeoTheme.infoCyan;
    final scale = NeoTheme.scaleFactor(context);

    return Container(
      decoration: BoxDecoration(
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              16 * scale,
              12 * scale,
              16 * scale,
              10 * scale,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: NeoTheme.bgBorder.withValues(alpha: 0.1),
                  width: 0.5,
                ),
                left: BorderSide(color: accentColor, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NeoTheme.labelLarge(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: NeoTheme.bodySmall(context)
                      .copyWith(color: NeoTheme.textTertiary),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
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
              Text(
                title,
                style: NeoTheme.labelMedium(context)
                    .copyWith(color: NeoTheme.textTertiary),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: NeoTheme.titleMedium(context).copyWith(
                  color: valueColor ?? NeoTheme.textPrimary,
                ),
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
    Widget? trailing,
  }) {
    final accent = color ?? NeoTheme.primaryRed;
    return _PressableRow(
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
                  const SizedBox(height: 3),
                  Text(subtitle, style: NeoTheme.bodySmall(context)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: accent.withValues(alpha: 0.7),
                  size: 20,
                ),
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
              const SizedBox(height: 3),
              Text(subtitle, style: NeoTheme.bodySmall(context)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: NeoTheme.primaryRed,
          activeTrackColor: NeoTheme.primaryRed.withValues(alpha: 0.35),
          inactiveThumbColor: NeoTheme.textDisabled,
          inactiveTrackColor: NeoTheme.bgBorder.withValues(alpha: 0.4),
        ),
      ],
    );
  }

  Widget _buildLeading(IconData icon, Color accent) {
    final isTV = NeoTheme.isTV(context);
    return AnimatedContainer(
      duration: NeoTheme.durationFast,
      width: isTV ? 46 : 40,
      height: isTV ? 46 : 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Icon(icon, size: isTV ? 20 : 17, color: accent),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider auth) {
    final isTV = NeoTheme.isTV(context);
    return SizedBox(
      height: isTV ? 62 : 54,
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
          style: NeoTheme.titleMedium(context).copyWith(
            color: NeoTheme.errorRed,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: NeoTheme.errorRed.withValues(alpha: 0.25)),
          backgroundColor: NeoTheme.errorRed.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
          ),
        ),
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────

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
      if (mounted) setState(() => _isRefreshingSecurity = false);
    }
  }

  void _showRedeemLicenseDialog(AuthProvider auth) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeoTheme.bgOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        ),
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
                if (!mounted) return;
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
                if (!mounted) return;
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        ),
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
              decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: const TextStyle(color: NeoTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        ),
        title: Text(
          'Vider les favoris ?',
          style: NeoTheme.titleLarge(context),
        ),
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

class _PressableRow extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PressableRow({required this.onTap, required this.child});

  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: NeoTheme.durationFast,
        curve: NeoTheme.smoothOut,
        child: AnimatedOpacity(
          opacity: _isPressed ? 0.85 : 1.0,
          duration: NeoTheme.durationFast,
          child: widget.child,
        ),
      ),
    );
  }
}
