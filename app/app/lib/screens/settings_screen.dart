import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../config/constants.dart';
import '../providers/providers.dart';
import '../providers/theme_provider.dart';
import '../providers/update_provider.dart';
import '../services/api_service.dart';
import '../services/player_prefs.dart';
import '../widgets/update_dialog.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'sub_accounts_screen.dart';

class SettingsScreen extends StatefulWidget {
  SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();
  bool _isRefreshingSecurity = false;
  bool _isCheckingUpdate = false;
  bool _allowPreRelease = false;

  PlayerPrefs _playerPrefs = PlayerPrefs();

  @override
  void initState() {
    super.initState();
    PlayerPrefs.load().then((p) {
      if (mounted) setState(() => _playerPrefs = p);
    });
    _loadUpdatePrefs();
  }

  Future<void> _loadUpdatePrefs() async {
    final allow = await context.read<UpdateProvider>().allowPreRelease;
    if (mounted) setState(() => _allowPreRelease = allow);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isWide = MediaQuery.of(context).size.width >= 700;
    final isTV = NeoTheme.isTV(context);
    final hPad = NeoTheme.screenPadding(context);
    final scale = NeoTheme.scaleFactor(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.browserBack) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      backgroundColor: Neo.bgBase(context),
      appBar: AppBar(
        backgroundColor: Neo.bgBase(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 32 * scale,
              height: 32 * scale,
              decoration: BoxDecoration(
                gradient: Neo.heroGradient(context),
                borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
              ),
              child: Icon(Icons.tune_rounded, color: Neo.onHeroGradient(context), size: 16 * scale),
            ),
            SizedBox(width: 10 * scale),
            Text('Parametres', style: Neo.headlineMedium(context)),
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
          _buildUserHeader(context, auth, user),
          SizedBox(height: isTV ? 24 : 18),
          _buildQuickActions(context, auth),
          SizedBox(height: isTV ? 24 : 20),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAppearanceSection(context, themeProvider),
                      SizedBox(height: 16),
                      _buildPlayerSection(context),
                      SizedBox(height: 16),
                      _buildLicenseSection(context, auth, user),
                      SizedBox(height: 16),
                      _buildAppSection(context),
                    ],
                  ),
                ),
                SizedBox(width: isTV ? 20 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAccountSection(context, user),
                      SizedBox(height: 16),
                      _buildSecuritySection(context),
                      SizedBox(height: 16),
                      _buildDataSection(context),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _buildAppearanceSection(context, themeProvider),
            SizedBox(height: 16),
            _buildPlayerSection(context),
            SizedBox(height: 16),
            _buildAccountSection(context, user),
            SizedBox(height: 16),
            _buildSecuritySection(context),
            SizedBox(height: 16),
            _buildLicenseSection(context, auth, user),
            SizedBox(height: 16),
            _buildDataSection(context),
            SizedBox(height: 16),
            _buildAppSection(context),
          ],
          SizedBox(height: 20),
          _buildAppInfo(context, auth),
          SizedBox(height: 20),
          _buildLogoutButton(context, auth),
        ],
      ),
    ),
    );
  }

  Widget _buildUserHeader(BuildContext context, AuthProvider auth, dynamic user) {
    final scale = NeoTheme.scaleFactor(context);
    final isTV = NeoTheme.isTV(context);
    final accent = auth.isPremium ? NeoTheme.prestigeGold : NeoTheme.infoCyan;
    final avatarSize = isTV ? 64.0 : 52.0;

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        gradient: Neo.glassGradient(context),
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 0.5),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: Row(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: auth.isPremium ? NeoTheme.premiumGradient : Neo.heroGradient(context),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 1),
              ],
            ),
            child: Center(
              child: Text(
                (user?.username?.isNotEmpty ?? false) ? user!.username[0].toUpperCase() : 'U',
                style: Neo.headlineMedium(context).copyWith(
                  color: auth.isPremium ? Colors.black : Neo.onHeroGradient(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: 14 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.username ?? 'Utilisateur',
                  style: Neo.titleLarge(context).copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(user?.email ?? '', style: Neo.bodySmall(context)),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.25), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  auth.isPremium ? Icons.workspace_premium_rounded : Icons.verified_user_outlined,
                  size: 14,
                  color: accent,
                ),
                SizedBox(width: 5),
                Text(
                  auth.isPremium ? 'Premium' : 'Standard',
                  style: Neo.labelMedium(context).copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AuthProvider auth) {
    final isTV = NeoTheme.isTV(context);
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.person_rounded,
        label: 'Profil',
        color: NeoTheme.infoCyan,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
      ),
      _QuickAction(
        icon: Icons.history_rounded,
        label: 'Historique',
        color: NeoTheme.warningOrange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen())),
      ),
      if (auth.isPremium)
        _QuickAction(
          icon: Icons.people_rounded,
          label: 'Famille',
          color: NeoTheme.purpleAccent,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubAccountsScreen())),
        ),
    ];

    return SizedBox(
      height: isTV ? 90 : 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_1, _2) => SizedBox(width: 12),
        itemBuilder: (_, i) {
          final action = actions[i];
          return _QuickActionTile(action: action);
        },
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context, ThemeProvider themeProvider) {
    return _buildSection(
      context,
      title: 'Apparence',
      icon: Icons.palette_outlined,
      accent: NeoTheme.infoCyan,
      children: [
        _buildThemeSelector(context, themeProvider),
      ],
    );
  }

  Widget _buildThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    return Row(
      children: [
        Expanded(
          child: _ThemeOption(
            icon: Icons.light_mode_rounded,
            label: 'Clair',
            isSelected: themeProvider.isLight,
            onTap: () => themeProvider.setLight(),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _ThemeOption(
            icon: Icons.dark_mode_rounded,
            label: 'Sombre',
            isSelected: themeProvider.isDark,
            onTap: () => themeProvider.setDark(),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Lecteur video',
      icon: Icons.play_circle_outline_rounded,
      accent: Theme.of(context).colorScheme.primary,
      children: [
        _buildToggleRow(
          context,
          icon: Icons.memory_rounded,
          title: 'Acceleration materielle',
          subtitle: 'Utilise le GPU pour decoder (recommande)',
          value: _playerPrefs.hwdecEnabled,
          onChanged: (v) {
            setState(() => _playerPrefs.hwdecEnabled = v);
            _playerPrefs.save();
          },
        ),
        _buildDivider(context),
        _buildAudioDelayRow(context),
        _buildDivider(context),
        _buildSubScaleRow(context),
      ],
    );
  }

  Widget _buildAudioDelayRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLeadingIcon(context, Icons.av_timer_rounded, NeoTheme.warningOrange),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Decalage audio', style: Neo.titleMedium(context)),
                    SizedBox(height: 2),
                    Text(
                      '${_playerPrefs.audioDelayMs > 0 ? '+' : ''}${_playerPrefs.audioDelayMs} ms',
                      style: Neo.bodySmall(context).copyWith(color: Neo.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _playerPrefs.audioDelayMs = 0);
                  _playerPrefs.save();
                },
                child: Text('Reset', style: TextStyle(color: Neo.textTertiary(context), fontSize: 12)),
              ),
            ],
          ),
          SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _playerPrefs.audioDelayMs.toDouble(),
              min: -1000,
              max: 1000,
              divisions: 40,
              activeColor: NeoTheme.warningOrange,
              inactiveColor: NeoTheme.warningOrange.withValues(alpha: 0.15),
              onChanged: (v) => setState(() => _playerPrefs.audioDelayMs = v.round()),
              onChangeEnd: (_) => _playerPrefs.save(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubScaleRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLeadingIcon(context, Icons.closed_caption_rounded, NeoTheme.infoCyan),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Taille sous-titres', style: Neo.titleMedium(context)),
                    SizedBox(height: 2),
                    Text(
                      'x${_playerPrefs.subScale.toStringAsFixed(1)}',
                      style: Neo.bodySmall(context).copyWith(color: Neo.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _playerPrefs.subScale = 1.0);
                  _playerPrefs.save();
                },
                child: Text('Reset', style: TextStyle(color: Neo.textTertiary(context), fontSize: 12)),
              ),
            ],
          ),
          SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _playerPrefs.subScale,
              min: 0.5,
              max: 2.5,
              divisions: 20,
              activeColor: NeoTheme.infoCyan,
              inactiveColor: NeoTheme.infoCyan.withValues(alpha: 0.15),
              onChanged: (v) => setState(() => _playerPrefs.subScale = double.tryParse(v.toStringAsFixed(1)) ?? 1.0),
              onChangeEnd: (_) => _playerPrefs.save(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, dynamic user) {
    return _buildSection(
      context,
      title: 'Compte',
      icon: Icons.person_outline_rounded,
      accent: NeoTheme.infoCyan,
      children: [
        _buildInfoRow(context, Icons.person_outline_rounded, 'Nom', user?.username ?? '-'),
        _buildDivider(context),
        _buildInfoRow(context, Icons.alternate_email_rounded, 'Email', user?.email ?? '-'),
        _buildDivider(context),
        _buildActionRow(
          context,
          icon: Icons.lock_outline_rounded,
          title: 'Changer le mot de passe',
          subtitle: 'Mettre a jour vos identifiants',
          onTap: _showChangePasswordDialog,
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Securite',
      icon: Icons.shield_outlined,
      accent: NeoTheme.successGreen,
      children: [
        _buildActionRow(
          context,
          icon: Icons.refresh_rounded,
          title: _isRefreshingSecurity ? 'Rotation en cours...' : 'Rafraichir la session',
          subtitle: 'Renouvelle le jeton de verification API',
          onTap: _isRefreshingSecurity ? () {} : _refreshSecuritySession,
          color: NeoTheme.successGreen,
          trailing: _isRefreshingSecurity
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: NeoTheme.successGreen),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildLicenseSection(BuildContext context, AuthProvider auth, dynamic user) {
    return _buildSection(
      context,
      title: 'Licence',
      icon: Icons.workspace_premium_outlined,
      accent: NeoTheme.prestigeGold,
      children: [
        _buildInfoRow(
          context,
          Icons.workspace_premium_outlined,
          'Offre actuelle',
          user?.premiumLabel ?? 'Gratuit',
          valueColor: auth.isPremium ? NeoTheme.prestigeGold : Neo.textSecondary(context),
        ),
        _buildDivider(context),
        _buildActionRow(
          context,
          icon: Icons.vpn_key_outlined,
          title: 'Activer une cle de licence',
          subtitle: 'Saisir une cle pour debloquer l offre',
          onTap: () => _showRedeemLicenseDialog(auth),
          color: NeoTheme.prestigeGold,
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Donnees',
      icon: Icons.storage_outlined,
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
        _buildDivider(context),
        _buildActionRow(
          context,
          icon: Icons.favorite_outline_rounded,
          title: 'Vider les favoris',
          subtitle: 'Retirer tous les contenus enregistres',
          onTap: _confirmClearFavorites,
          color: NeoTheme.errorRed,
        ),
        _buildDivider(context),
        if (kDebugMode || NeoTheme.isDesktopPlatform)
          _buildToggleRow(
            context,
            icon: Icons.tv_rounded,
            title: 'Mode TV (debug)',
            subtitle: 'Forcer l interface TV sur PC',
            value: NeoTheme.forceTVMode,
            onChanged: (v) async {
              await NeoTheme.setForceTVMode(v);
              setState(() {});
            },
          ),
      ],
    );
  }

  Widget _buildAppInfo(BuildContext context, AuthProvider auth) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Neo.bgSurface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        border: Border.all(color: Neo.bgBorder(context).withValues(alpha: 0.1), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Neo.textTertiary(context)),
          SizedBox(width: 12),
          Text('Neo-Stream', style: Neo.labelMedium(context).copyWith(color: Neo.textTertiary(context))),
          Spacer(),
          Text('v${AppConstants.appVersion}', style: Neo.bodySmall(context).copyWith(color: Neo.textDisabled(context))),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (auth.isPremium ? NeoTheme.prestigeGold : Neo.textTertiary(context)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              auth.isPremium ? 'Premium' : 'Gratuit',
              style: Neo.labelSmall(context).copyWith(
                color: auth.isPremium ? NeoTheme.prestigeGold : Neo.textTertiary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Application',
      icon: Icons.system_update_rounded,
      accent: NeoTheme.infoCyan,
      children: [
        _buildActionRow(
          context,
          icon: Icons.system_update_rounded,
          title: _isCheckingUpdate
              ? 'Verification en cours...'
              : 'Verifier les mises a jour',
          subtitle: 'Version actuelle : v${AppConstants.appVersion}',
          onTap: _isCheckingUpdate ? () {} : _checkForUpdates,
          color: NeoTheme.infoCyan,
          trailing: _isCheckingUpdate
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: NeoTheme.infoCyan),
                )
              : null,
        ),
        _buildDivider(context),
        _buildToggleRow(
          context,
          icon: Icons.science_outlined,
          title: 'Versions beta (pre-releases)',
          subtitle: 'Inclut les versions instables dans la detection',
          value: _allowPreRelease,
          onChanged: (v) async {
            setState(() => _allowPreRelease = v);
            await context.read<UpdateProvider>().setAllowPreRelease(v);
          },
        ),
      ],
    );
  }

  Future<void> _checkForUpdates() async {
    final update = context.read<UpdateProvider>();
    setState(() => _isCheckingUpdate = true);
    await update.checkManual(includePreRelease: _allowPreRelease);
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (update.hasUpdate && update.lastResult?.release != null) {
      showUpdateDialog(context, isTV: false);
    } else if (update.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${update.error}'), backgroundColor: NeoTheme.errorRed),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vous etes a jour (v${AppConstants.appVersion})'),
          backgroundColor: NeoTheme.successGreen,
        ),
      );
    }
  }

  // ─── Section builder ──────────────────────────────────────────────

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? accent,
  }) {
    final accentColor = accent ?? NeoTheme.infoCyan;
    final scale = NeoTheme.scaleFactor(context);

    return Container(
      decoration: BoxDecoration(
        gradient: Neo.surfaceGradient(context),
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(color: Neo.bgBorder(context).withValues(alpha: 0.12), width: 0.5),
        boxShadow: NeoTheme.shadowLevel1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16 * scale, 14 * scale, 16 * scale, 12 * scale),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Neo.bgBorder(context).withValues(alpha: 0.08), width: 0.5),
                left: BorderSide(color: accentColor, width: 3),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                SizedBox(width: 10),
                Text(
                  title,
                  style: Neo.labelLarge(context).copyWith(fontWeight: FontWeight.w700),
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

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: Neo.bgBorder(context).withValues(alpha: 0.1), height: 0.5, thickness: 0.5),
    );
  }

  Widget _buildLeadingIcon(BuildContext context, IconData icon, Color accent) {
    final isTV = NeoTheme.isTV(context);
    return Container(
      width: isTV ? 42 : 36,
      height: isTV ? 42 : 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Icon(icon, size: isTV ? 18 : 16, color: accent),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String title, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildLeadingIcon(context, icon, NeoTheme.infoCyan),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Neo.labelMedium(context).copyWith(color: Neo.textTertiary(context))),
                SizedBox(height: 2),
                Text(
                  value,
                  style: Neo.titleMedium(context).copyWith(color: valueColor ?? Neo.textPrimary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return _PressableRow(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _buildLeadingIcon(context, icon, accent),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Neo.titleMedium(context)),
                  SizedBox(height: 2),
                  Text(subtitle, style: Neo.bodySmall(context)),
                ],
              ),
            ),
            SizedBox(width: 8),
            trailing ?? Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.6), size: 20),
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildLeadingIcon(context, icon, value ? NeoTheme.successGreen : Neo.textTertiary(context)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Neo.titleMedium(context)),
                SizedBox(height: 2),
                Text(subtitle, style: Neo.bodySmall(context)),
              ],
            ),
          ),
          SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
            inactiveThumbColor: Neo.textDisabled(context),
            inactiveTrackColor: Neo.bgBorder(context).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider auth) {
    final isTV = NeoTheme.isTV(context);
    return SizedBox(
      height: isTV ? 58 : 50,
      child: OutlinedButton.icon(
        onPressed: () async {
          await auth.logout();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => LoginScreen()),
              (route) => false,
            );
          }
        },
        icon: Icon(Icons.logout_rounded, color: NeoTheme.errorRed, size: 20),
        label: Text(
          'Deconnexion',
          style: Neo.titleMedium(context).copyWith(color: NeoTheme.errorRed),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: NeoTheme.errorRed.withValues(alpha: 0.2)),
          backgroundColor: NeoTheme.errorRed.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusLg)),
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
          SnackBar(content: Text('Session de securite rafraichie', style: TextStyle(color: Neo.readableOnPrimary(context))), backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: NeoTheme.errorRed),
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
        backgroundColor: Neo.bgOverlay(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusXl)),
        title: Text('Activer une cle', style: Neo.titleLarge(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrez votre cle de licence pour appliquer l offre associee.',
              style: Neo.bodyMedium(context),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: Neo.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Cle de licence',
                hintText: 'NEO-XXXXX-XXXXX-XXXXX-XXXXX',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: Neo.textSecondary(context))),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final key = controller.text.trim();
              if (key.isEmpty) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Entrez une cle valide'), backgroundColor: NeoTheme.errorRed),
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
                  SnackBar(content: Text('Erreur: $e'), backgroundColor: NeoTheme.errorRed),
                );
              }
            },
            child: Text('Activer'),
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
        backgroundColor: Neo.bgOverlay(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusXl)),
        title: Text('Changer le mot de passe', style: Neo.titleLarge(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              style: TextStyle(color: Neo.textPrimary(context)),
              decoration: InputDecoration(labelText: 'Mot de passe actuel'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: TextStyle(color: Neo.textPrimary(context)),
              decoration: InputDecoration(labelText: 'Nouveau mot de passe'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              style: TextStyle(color: Neo.textPrimary(context)),
              decoration: InputDecoration(labelText: 'Confirmation'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: Neo.textSecondary(context))),
          ),
          TextButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: NeoTheme.errorRed),
                );
                return;
              }
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('6 caracteres minimum'), backgroundColor: NeoTheme.errorRed),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _api.changePassword(oldCtrl.text, newCtrl.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Mot de passe modifie', style: TextStyle(color: Neo.readableOnPrimary(context))), backgroundColor: Theme.of(context).colorScheme.primary),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: NeoTheme.errorRed),
                  );
                }
              }
            },
            child: Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Neo.bgOverlay(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusXl)),
        title: Text('Supprimer l historique ?', style: Neo.titleLarge(context)),
        content: Text(
          'Toutes les reprises de lecture seront supprimees.',
          style: Neo.bodyMedium(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: Neo.textSecondary(context))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Historique supprime', style: TextStyle(color: Neo.readableOnPrimary(context))), backgroundColor: Theme.of(context).colorScheme.primary),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: NeoTheme.errorRed),
                  );
                }
              }
            },
            child: Text('Supprimer', style: TextStyle(color: NeoTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  void _confirmClearFavorites() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Neo.bgOverlay(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusXl)),
        title: Text('Vider les favoris ?', style: Neo.titleLarge(context)),
        content: Text(
          'Les contenus enregistres seront retires de votre liste.',
          style: Neo.bodyMedium(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: Neo.textSecondary(context))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.clearLibrary();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Favoris vides', style: TextStyle(color: Neo.readableOnPrimary(context))), backgroundColor: Theme.of(context).colorScheme.primary),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: NeoTheme.errorRed),
                  );
                }
              }
            },
            child: Text('Vider', style: TextStyle(color: NeoTheme.errorRed)),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Components ────────────────────────────────────────

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
}

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    final action = widget.action;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        action.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: Duration(milliseconds: 100),
        child: Container(
          width: isTV ? 160 : 120,
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            gradient: Neo.surfaceGradient(context),
            borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
            border: Border.all(
              color: _pressed ? action.color.withValues(alpha: 0.5) : action.color.withValues(alpha: 0.12),
              width: _pressed ? 1.5 : 0.5,
            ),
            boxShadow: NeoTheme.shadowLevel1,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isTV ? 38 : 32,
                height: isTV ? 38 : 32,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, size: isTV ? 20 : 16, color: action.color),
              ),
              SizedBox(height: 8),
              Text(
                action.label,
                style: Neo.labelMedium(context).copyWith(
                  color: Neo.textPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Theme Option ───────────────────────────────────────────────────

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  _ThemeOption({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Theme.of(context).colorScheme.primary : Neo.textTertiary(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: NeoTheme.durationFast,
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : Neo.bgSurface(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4) : Neo.bgBorder(context).withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(width: 8),
            Text(
              label,
              style: Neo.labelLarge(context).copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Pressable Row ──────────────────────────────────────────────────

class _PressableRow extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  _PressableRow({required this.onTap, required this.child});

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
