import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../models/content.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import '../widgets/content_card.dart';
import '../widgets/section_header.dart';
import 'detail_screen.dart';
import 'history_screen.dart';

class PremiumHubScreen extends StatefulWidget {
  const PremiumHubScreen({super.key});

  @override
  State<PremiumHubScreen> createState() => _PremiumHubScreenState();
}

class _PremiumHubScreenState extends State<PremiumHubScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isActivating = false;
  bool _isValidating = false;

  List<Map<String, dynamic>> _historyItems = [];
  List<Map<String, dynamic>> _licenseHistory = [];

  final _licenseController = TextEditingController();
  final _affiliateController = TextEditingController();
  final _licenseFocus = FocusNode();
  final _affiliateFocus = FocusNode();

  late AnimationController _headerAnimCtrl;
  late Animation<double> _headerFadeAnim;

  @override
  void initState() {
    super.initState();
    _headerAnimCtrl = AnimationController(
      vsync: this,
      duration: NeoTheme.durationHero,
    );
    _headerFadeAnim = CurvedAnimation(
      parent: _headerAnimCtrl,
      curve: NeoTheme.cinematic,
    );
    _headerAnimCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _headerAnimCtrl.dispose();
    _licenseController.dispose();
    _affiliateController.dispose();
    _licenseFocus.dispose();
    _affiliateFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final futures = <Future>[
        _api.getHistory().then((items) {
          _historyItems = items
              .whereType<Map<String, dynamic>>()
              .where((item) {
                final poster = item['poster']?.toString() ?? '';
                return Content.resolvePosterUrl(poster).isNotEmpty;
              })
              .take(20)
              .toList();
        }),
      ];
      if (auth.isPremium) {
        futures.add(_api.getLicenseHistory().then((items) {
          _licenseHistory = items;
        }));
      }
      await Future.wait(futures);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _activateLicense() async {
    final key = _licenseController.text.trim();
    if (key.isEmpty) return;
    setState(() => _isActivating = true);
    try {
      final result = await _api.redeemLicenseKey(key);
      if (!mounted) return;
      final success = result['success'] == true;
      final message =
          result['message']?.toString() ?? (success ? 'Licence activée !' : 'Erreur');
      _showSnack(message, success: success);
      if (success) {
        _licenseController.clear();
        await context.read<AuthProvider>().refreshUser();
        await _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Erreur: $e', success: false);
    }
    if (!mounted) return;
    setState(() => _isActivating = false);
  }

  Future<void> _validateAffiliate() async {
    final code = _affiliateController.text.trim();
    if (code.isEmpty) return;
    setState(() => _isValidating = true);
    try {
      final result = await _api.validateAffiliateCode(code);
      if (!mounted) return;
      final success = result['valid'] == true || result['success'] == true;
      final message = result['message']?.toString() ??
          (success ? 'Code affilié valide !' : 'Code invalide');
      _showSnack(message, success: success);
      if (success) _affiliateController.clear();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Erreur: $e', success: false);
    }
    if (!mounted) return;
    setState(() => _isValidating = false);
  }

  void _showSnack(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: success ? NeoTheme.successGreen : NeoTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _confirmCancelSubscription() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: NeoTheme.bgOverlay,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
            ),
            title: Text(
              'Annuler l\'abonnement ?',
              style: NeoTheme.titleLarge(context),
            ),
            content: Text(
              'Votre accès Premium restera actif jusqu\'à la date d\'expiration. '
              'Vous ne serez pas remboursé.',
              style: NeoTheme.bodyMedium(context)
                  .copyWith(color: NeoTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Retour',
                  style: NeoTheme.labelLarge(context)
                      .copyWith(color: NeoTheme.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Confirmer',
                  style: NeoTheme.labelLarge(context)
                      .copyWith(color: NeoTheme.errorRed),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    _showSnack('Demande d\'annulation envoyée.', success: true);
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final date = DateTime.parse(raw).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return raw.split(' ').first;
    }
  }

  String _maskLicenseKey(String key) {
    if (key.length <= 8) return key;
    return '${key.substring(0, 4)}${'•' * (key.length - 8)}${key.substring(key.length - 4)}';
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final content = context.watch<ContentProvider>();
    final user = auth.user;
    final isPremium = auth.isPremium;
    final padding = NeoTheme.screenPadding(context);
    final scale = NeoTheme.scaleFactor(context);

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: _isLoading
          ? _buildShimmer(context)
          : RefreshIndicator(
              onRefresh: _loadData,
              color: NeoTheme.primaryRed,
              backgroundColor: NeoTheme.bgElevated,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // HEADER
                  SliverToBoxAdapter(
                    child: _buildHeader(context, user, isPremium, scale),
                  ),

                  // PREMIUM / UPGRADE SECTION
                  if (!isPremium) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: padding,
                        child: _buildBenefitsBanner(context, scale),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 20 * scale)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: padding,
                        child: _buildActivateSection(context, scale),
                      ),
                    ),
                  ],

                  if (isPremium) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: padding,
                        child: _buildSubscriptionCard(context, user!, scale),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 20 * scale)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: padding,
                        child: _buildStatsCard(context, content, user, scale),
                      ),
                    ),
                  ],

                  // CONTINUE WATCHING
                  SliverToBoxAdapter(
                      child: SizedBox(height: NeoTheme.sectionGap(context))),
                  SliverToBoxAdapter(
                    child: _buildContinueWatching(context, content),
                  ),

                  // RECENT HISTORY
                  SliverToBoxAdapter(
                      child: SizedBox(height: NeoTheme.sectionGap(context))),
                  SliverToBoxAdapter(
                    child: _buildRecentHistory(context, scale),
                  ),

                  // LICENSE HISTORY (premium only)
                  if (isPremium && _licenseHistory.isNotEmpty) ...[
                    SliverToBoxAdapter(
                        child: SizedBox(height: NeoTheme.sectionGap(context))),
                    SliverToBoxAdapter(
                      child: _buildLicenseHistory(context, padding, scale),
                    ),
                  ],

                  SliverToBoxAdapter(child: SizedBox(height: 80 * scale)),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(
      BuildContext context, user, bool isPremium, double scale) {
    return FadeTransition(
      opacity: _headerFadeAnim,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16 * scale,
          left: NeoTheme.screenPadding(context).left,
          right: NeoTheme.screenPadding(context).right,
          bottom: 28 * scale,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPremium
                ? [
                    NeoTheme.prestigeGold.withValues(alpha: 0.12),
                    NeoTheme.bgBase.withValues(alpha: 0.95),
                    NeoTheme.bgBase,
                  ]
                : [
                    NeoTheme.primaryRed.withValues(alpha: 0.08),
                    NeoTheme.purpleAccent.withValues(alpha: 0.04),
                    NeoTheme.bgBase,
                  ],
            stops: const [0, 0.5, 1],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NEO STREAM title
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => (isPremium
                          ? NeoTheme.premiumGradient
                          : NeoTheme.heroGradient)
                      .createShader(bounds),
                  child: Text(
                    'NEO',
                    style: NeoTheme.displayLarge(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'STREAM',
                  style: NeoTheme.displayLarge(context).copyWith(
                    color: NeoTheme.textPrimary,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(context, isPremium, scale),
              ],
            ),
            SizedBox(height: 6 * scale),
            Text(
              isPremium ? 'Espace Premium' : 'Passez à Premium',
              style: NeoTheme.bodyLarge(context).copyWith(
                color: NeoTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isPremium, double scale) {
    final color = isPremium ? NeoTheme.prestigeGold : NeoTheme.textDisabled;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 7 * scale,
      ),
      decoration: BoxDecoration(
        gradient: isPremium
            ? LinearGradient(
                colors: [
                  NeoTheme.prestigeGold.withValues(alpha: 0.2),
                  NeoTheme.goldDark.withValues(alpha: 0.1),
                ],
              )
            : null,
        color: isPremium ? null : NeoTheme.bgElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isPremium ? 0.5 : 0.2),
          width: 0.5,
        ),
        boxShadow: isPremium ? NeoTheme.shadowGoldGlow : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium ? Icons.workspace_premium_rounded : Icons.person_outline,
            size: 16 * scale,
            color: color,
          ),
          SizedBox(width: 6 * scale),
          Text(
            isPremium ? 'Premium' : 'Gratuit',
            style: NeoTheme.labelLarge(context).copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BENEFITS BANNER (non-premium)
  // ─────────────────────────────────────────────────────────────

  Widget _buildBenefitsBanner(BuildContext context, double scale) {
    final benefits = [
      (Icons.hd_rounded, 'HD / 4K', 'Qualité maximale'),
      (Icons.block_rounded, 'Sans Pub', 'Aucune interruption'),
      (Icons.family_restroom_rounded, 'Famille', 'Profils multiples'),
      (Icons.bolt_rounded, 'Priorité', 'Accès anticipé'),
    ];

    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        gradient: NeoTheme.glassGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(
          color: NeoTheme.prestigeGold.withValues(alpha: 0.25),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    NeoTheme.premiumGradient.createShader(bounds),
                child: Icon(
                  Icons.diamond_rounded,
                  size: 24 * scale,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Text(
                  'Avantages Premium',
                  style: NeoTheme.headlineMedium(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18 * scale),
          GridView.count(
            crossAxisCount: NeoTheme.isTV(context)
                ? 4
                : NeoTheme.isTablet(context)
                    ? 4
                    : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12 * scale,
            crossAxisSpacing: 12 * scale,
            childAspectRatio: NeoTheme.isTV(context) ? 2.2 : 2.4,
            children: benefits.map((b) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale,
                  vertical: 10 * scale,
                ),
                decoration: BoxDecoration(
                  color: NeoTheme.bgElevated.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                  border: Border.all(
                    color: NeoTheme.bgBorder.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36 * scale,
                      height: 36 * scale,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            NeoTheme.prestigeGold.withValues(alpha: 0.2),
                            NeoTheme.prestigeGold.withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(NeoTheme.radiusSm),
                      ),
                      child: Icon(
                        b.$1,
                        size: 18 * scale,
                        color: NeoTheme.prestigeGold,
                      ),
                    ),
                    SizedBox(width: 10 * scale),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.$2,
                            style: NeoTheme.labelLarge(context).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            b.$3,
                            style: NeoTheme.bodySmall(context).copyWith(
                              color: NeoTheme.textDisabled,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIVATE PREMIUM (non-premium)
  // ─────────────────────────────────────────────────────────────

  Widget _buildActivateSection(BuildContext context, double scale) {
    final useFocus = NeoTheme.needsFocusNavigation(context);

    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.22),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activer Premium',
            style: NeoTheme.headlineMedium(context).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            'Entrez votre clé de licence ou code d\'affiliation',
            style: NeoTheme.bodyMedium(context)
                .copyWith(color: NeoTheme.textSecondary),
          ),
          SizedBox(height: 20 * scale),

          // License key
          _buildInputRow(
            context,
            controller: _licenseController,
            focusNode: _licenseFocus,
            hint: 'Clé de licence',
            icon: Icons.vpn_key_rounded,
            buttonLabel: 'Activer',
            isLoading: _isActivating,
            onSubmit: _activateLicense,
            buttonColor: NeoTheme.primaryRed,
            useFocus: useFocus,
            scale: scale,
          ),
          SizedBox(height: 14 * scale),

          // Affiliate code
          _buildInputRow(
            context,
            controller: _affiliateController,
            focusNode: _affiliateFocus,
            hint: 'Code d\'affiliation',
            icon: Icons.handshake_rounded,
            buttonLabel: 'Valider',
            isLoading: _isValidating,
            onSubmit: _validateAffiliate,
            buttonColor: NeoTheme.prestigeGold,
            useFocus: useFocus,
            scale: scale,
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required String buttonLabel,
    required bool isLoading,
    required VoidCallback onSubmit,
    required Color buttonColor,
    required bool useFocus,
    required double scale,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: NeoTheme.bgElevated,
              borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
              border: Border.all(
                color: NeoTheme.bgBorder.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: NeoTheme.bodyLarge(context),
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: NeoTheme.bodyLarge(context)
                    .copyWith(color: NeoTheme.textDisabled),
                prefixIcon: Icon(icon, color: NeoTheme.textDisabled, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16 * scale,
                  vertical: 14 * scale,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 10 * scale),
        _FocusableButton(
          useFocus: useFocus,
          onTap: isLoading ? null : onSubmit,
          child: AnimatedContainer(
            duration: NeoTheme.durationFast,
            padding: EdgeInsets.symmetric(
              horizontal: 20 * scale,
              vertical: 14 * scale,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLoading
                    ? [
                        buttonColor.withValues(alpha: 0.3),
                        buttonColor.withValues(alpha: 0.2),
                      ]
                    : [buttonColor, buttonColor.withValues(alpha: 0.85)],
              ),
              borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
              boxShadow: isLoading
                  ? null
                  : [
                      BoxShadow(
                        color: buttonColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: isLoading
                ? SizedBox(
                    width: 20 * scale,
                    height: 20 * scale,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    buttonLabel,
                    style: NeoTheme.labelLarge(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SUBSCRIPTION CARD (premium)
  // ─────────────────────────────────────────────────────────────

  Widget _buildSubscriptionCard(
      BuildContext context, User user, double scale) {
    final expiry = user.premiumExpiry;
    final isLifetime = user.premiumType == 'lifetime';

    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        gradient: NeoTheme.glassGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(
          color: NeoTheme.prestigeGold.withValues(alpha: 0.3),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowGoldGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium type badge
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    NeoTheme.premiumGradient.createShader(bounds),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 28 * scale,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.premiumLabel,
                      style: NeoTheme.headlineLarge(context).copyWith(
                        fontWeight: FontWeight.w800,
                        color: NeoTheme.prestigeGold,
                      ),
                    ),
                    Text(
                      'Membre depuis ${_formatDate(user.createdAt)}',
                      style: NeoTheme.bodySmall(context).copyWith(
                        color: NeoTheme.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20 * scale),

          // Info rows
          _buildInfoRow(
            context,
            icon: Icons.calendar_today_rounded,
            label: 'Expiration',
            value: expiry.isEmpty
                ? 'Non définie'
                : expiry == 'Illimite'
                    ? '∞  Illimité'
                    : expiry,
            valueColor: isLifetime
                ? NeoTheme.prestigeGold
                : NeoTheme.textPrimary,
            scale: scale,
          ),
          SizedBox(height: 10 * scale),
          _buildInfoRow(
            context,
            icon: Icons.verified_rounded,
            label: 'Statut',
            value: 'Actif',
            valueColor: NeoTheme.successGreen,
            scale: scale,
          ),

          // Cancel button (hidden for lifetime)
          if (!isLifetime) ...[
            SizedBox(height: 20 * scale),
            Align(
              alignment: Alignment.centerRight,
              child: _FocusableButton(
                useFocus: NeoTheme.needsFocusNavigation(context),
                onTap: _confirmCancelSubscription,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 10 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: NeoTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                    border: Border.all(
                      color: NeoTheme.errorRed.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'Annuler l\'abonnement',
                    style: NeoTheme.labelLarge(context).copyWith(
                      color: NeoTheme.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required double scale,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16 * scale, color: NeoTheme.textDisabled),
        SizedBox(width: 10 * scale),
        Text(
          label,
          style: NeoTheme.bodyMedium(context)
              .copyWith(color: NeoTheme.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: NeoTheme.labelLarge(context).copyWith(
            color: valueColor ?? NeoTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATS CARD (premium)
  // ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard(
      BuildContext context, ContentProvider content, User user, double scale) {
    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.22),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 20 * scale, color: NeoTheme.infoCyan),
              SizedBox(width: 10 * scale),
              Text(
                'Vos Statistiques',
                style: NeoTheme.headlineMedium(context).copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 18 * scale),

          // Stats grid
          Row(
            children: [
              _buildStatTile(
                context,
                label: 'Total',
                value: '${content.totalAvailable}',
                icon: Icons.movie_filter_rounded,
                color: NeoTheme.infoCyan,
                scale: scale,
              ),
              SizedBox(width: 12 * scale),
              _buildStatTile(
                context,
                label: 'Films',
                value: '${content.totalFilms}',
                icon: Icons.local_movies_rounded,
                color: NeoTheme.purpleAccent,
                scale: scale,
              ),
              SizedBox(width: 12 * scale),
              _buildStatTile(
                context,
                label: 'Séries',
                value: '${content.totalSeries}',
                icon: Icons.tv_rounded,
                color: NeoTheme.warningOrange,
                scale: scale,
              ),
            ],
          ),

          // Referral code
          if (user.isAffiliatePartner &&
              user.affiliateCode != null &&
              user.affiliateCode!.isNotEmpty) ...[
            SizedBox(height: 18 * scale),
            Container(
              padding: EdgeInsets.all(14 * scale),
              decoration: BoxDecoration(
                color: NeoTheme.bgElevated.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                border: Border.all(
                  color: NeoTheme.prestigeGold.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.share_rounded,
                      size: 18 * scale, color: NeoTheme.prestigeGold),
                  SizedBox(width: 10 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code de parrainage',
                          style: NeoTheme.bodySmall(context)
                              .copyWith(color: NeoTheme.textDisabled),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.affiliateCode!,
                          style: NeoTheme.titleMedium(context).copyWith(
                            color: NeoTheme.prestigeGold,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _FocusableButton(
                    useFocus: NeoTheme.needsFocusNavigation(context),
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: user.affiliateCode!));
                      _showSnack('Code copié !', success: true);
                    },
                    child: Container(
                      padding: EdgeInsets.all(10 * scale),
                      decoration: BoxDecoration(
                        color: NeoTheme.prestigeGold.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(NeoTheme.radiusSm),
                      ),
                      child: Icon(Icons.copy_rounded,
                          size: 18 * scale, color: NeoTheme.prestigeGold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double scale,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 14 * scale,
          horizontal: 10 * scale,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22 * scale, color: color),
            SizedBox(height: 8 * scale),
            Text(
              value,
              style: NeoTheme.headlineLarge(context).copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            SizedBox(height: 2 * scale),
            Text(
              label,
              style: NeoTheme.bodySmall(context)
                  .copyWith(color: NeoTheme.textDisabled),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTINUE WATCHING
  // ─────────────────────────────────────────────────────────────

  Widget _buildContinueWatching(BuildContext context, ContentProvider content) {
    final items = content.continueWatching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Reprendre',
          subtitle: 'Continuez où vous en étiez',
          icon: Icons.play_circle_rounded,
        ),
        SizedBox(height: NeoTheme.spaceLg),
        if (items.isEmpty)
          Padding(
            padding: NeoTheme.screenPadding(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                gradient: NeoTheme.surfaceGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: NeoTheme.bgBorder.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_disabled_rounded,
                      size: 40, color: NeoTheme.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune lecture en cours',
                    style: NeoTheme.bodyLarge(context)
                        .copyWith(color: NeoTheme.textDisabled),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: NeoTheme.cardHeight(context),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: NeoTheme.screenPadding(context),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: NeoTheme.cardWidth(context),
                    child: ContentCard(
                      content: item,
                      variant: CardVariant.continueWatching,
                      index: index,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(contentId: item.id),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RECENT HISTORY
  // ─────────────────────────────────────────────────────────────

  Widget _buildRecentHistory(BuildContext context, double scale) {
    final padding = NeoTheme.screenPadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Historique',
          subtitle: 'Vos derniers visionnages',
          icon: Icons.history_rounded,
          onSeeAll: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
        ),
        SizedBox(height: NeoTheme.spaceLg),
        if (_historyItems.isEmpty)
          Padding(
            padding: padding,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                gradient: NeoTheme.surfaceGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: NeoTheme.bgBorder.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off_rounded,
                      size: 40, color: NeoTheme.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun historique',
                    style: NeoTheme.bodyLarge(context)
                        .copyWith(color: NeoTheme.textDisabled),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 130 * scale,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: padding,
              itemCount: _historyItems.length,
              itemBuilder: (context, index) {
                return _buildHistoryTile(context, _historyItems[index], scale);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTile(
      BuildContext context, Map<String, dynamic> item, double scale) {
    final title = item['title']?.toString() ?? '';
    final poster = Content.resolvePosterUrl(item['poster']?.toString() ?? '');
    final progress = _safeDouble(item['progress_percent']);
    final contentId = _safeInt(item['content_id']);
    final useFocus = NeoTheme.needsFocusNavigation(context);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: _FocusableButton(
        useFocus: useFocus,
        onTap: contentId > 0
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(contentId: contentId),
                  ),
                )
            : null,
        child: Container(
          width: 240 * scale,
          decoration: BoxDecoration(
            gradient: NeoTheme.surfaceGradient,
            borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
            border: Border.all(
              color: NeoTheme.bgBorder.withValues(alpha: 0.2),
              width: 0.5,
            ),
            boxShadow: NeoTheme.shadowLevel1,
          ),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(NeoTheme.radiusLg),
                ),
                child: SizedBox(
                  width: 80 * scale,
                  height: double.infinity,
                  child: poster.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: poster,
                          fit: BoxFit.cover,
                          placeholder: (_, url) => Container(
                            color: NeoTheme.bgElevated,
                          ),
                          errorWidget: (_, url, error) => Container(
                            color: NeoTheme.bgElevated,
                            child: const Icon(Icons.broken_image_rounded,
                                color: NeoTheme.textDisabled),
                          ),
                        )
                      : Container(
                          color: NeoTheme.bgElevated,
                          child: const Icon(Icons.movie_rounded,
                              color: NeoTheme.textDisabled),
                        ),
                ),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: NeoTheme.labelLarge(context).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6 * scale),
                      if (item['episode_label'] != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 4 * scale),
                          child: Text(
                            item['episode_label'].toString(),
                            style: NeoTheme.bodySmall(context)
                                .copyWith(color: NeoTheme.infoCyan),
                            maxLines: 1,
                          ),
                        ),
                      if (progress > 0) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress / 100,
                                  minHeight: 3,
                                  backgroundColor:
                                      NeoTheme.bgBorder.withValues(alpha: 0.3),
                                  valueColor:
                                      const AlwaysStoppedAnimation(
                                          NeoTheme.primaryRed),
                                ),
                              ),
                            ),
                            SizedBox(width: 8 * scale),
                            Text(
                              '${progress.toInt()}%',
                              style: NeoTheme.labelSmall(context).copyWith(
                                color: NeoTheme.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (item['watched_at'] != null) ...[
                        SizedBox(height: 4 * scale),
                        Text(
                          _formatDate(item['watched_at']?.toString()),
                          style: NeoTheme.bodySmall(context)
                              .copyWith(color: NeoTheme.textDisabled),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LICENSE HISTORY
  // ─────────────────────────────────────────────────────────────

  Widget _buildLicenseHistory(
      BuildContext context, EdgeInsets padding, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Licences',
          subtitle: 'Historique d\'activation',
          icon: Icons.key_rounded,
        ),
        SizedBox(height: NeoTheme.spaceLg),
        Padding(
          padding: padding,
          child: Container(
            decoration: BoxDecoration(
              gradient: NeoTheme.surfaceGradient,
              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
              border: Border.all(
                color: NeoTheme.bgBorder.withValues(alpha: 0.22),
                width: 0.5,
              ),
              boxShadow: NeoTheme.shadowLevel1,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _licenseHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final lic = entry.value;
                final key = lic['license_key']?.toString() ?? '';
                final date = _formatDate(lic['redeemed_at']?.toString());
                final type = lic['type']?.toString() ?? '';

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 14 * scale,
                  ),
                  decoration: BoxDecoration(
                    border: index < _licenseHistory.length - 1
                        ? Border(
                            bottom: BorderSide(
                              color: NeoTheme.bgBorder.withValues(alpha: 0.12),
                              width: 0.5,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36 * scale,
                        height: 36 * scale,
                        decoration: BoxDecoration(
                          color:
                              NeoTheme.prestigeGold.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(NeoTheme.radiusSm),
                        ),
                        child: Icon(Icons.vpn_key_rounded,
                            size: 16 * scale, color: NeoTheme.prestigeGold),
                      ),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _maskLicenseKey(key),
                              style: NeoTheme.labelLarge(context).copyWith(
                                fontFamily: 'monospace',
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2 * scale),
                            Text(
                              '${type.isNotEmpty ? '$type · ' : ''}$date',
                              style: NeoTheme.bodySmall(context)
                                  .copyWith(color: NeoTheme.textDisabled),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle_rounded,
                          size: 18 * scale, color: NeoTheme.successGreen),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SHIMMER LOADING
  // ─────────────────────────────────────────────────────────────

  Widget _buildShimmer(BuildContext context) {
    final scale = NeoTheme.scaleFactor(context);
    final padding = NeoTheme.screenPadding(context);
    final hPad = padding.horizontal / 2;

    return Shimmer.fromColors(
      baseColor: NeoTheme.bgElevated,
      highlightColor: NeoTheme.bgActive,
      period: const Duration(milliseconds: 1800),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header shimmer
            SizedBox(height: MediaQuery.of(context).padding.top + 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  Container(
                    width: 180 * scale,
                    height: 36 * scale,
                    decoration: BoxDecoration(
                      color: NeoTheme.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 100 * scale,
                    height: 32 * scale,
                    decoration: BoxDecoration(
                      color: NeoTheme.bgElevated,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32 * scale),

            // Card shimmers
            for (var i = 0; i < 3; i++) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Container(
                  height: (i == 0 ? 200 : 100) * scale,
                  decoration: BoxDecoration(
                    color: NeoTheme.bgElevated,
                    borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                  ),
                ),
              ),
              SizedBox(height: 16 * scale),
            ],

            // Section shimmer
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  Container(
                    width: 40 * scale,
                    height: 40 * scale,
                    decoration: BoxDecoration(
                      color: NeoTheme.bgElevated,
                      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 140 * scale,
                    height: 16 * scale,
                    decoration: BoxDecoration(
                      color: NeoTheme.bgElevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16 * scale),
            SizedBox(
              height: NeoTheme.cardHeight(context),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: hPad),
                itemCount: 5,
                itemBuilder: (ctx, idx) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: NeoTheme.cardWidth(context),
                    decoration: BoxDecoration(
                      color: NeoTheme.bgElevated,
                      borderRadius:
                          BorderRadius.circular(NeoTheme.radiusLg),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────

  int _safeInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _safeDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// ─────────────────────────────────────────────────────────────────
// FOCUSABLE BUTTON — TV/Desktop key event support
// ─────────────────────────────────────────────────────────────────

class _FocusableButton extends StatefulWidget {
  final bool useFocus;
  final VoidCallback? onTap;
  final Widget child;

  const _FocusableButton({
    required this.useFocus,
    required this.onTap,
    required this.child,
  });

  @override
  State<_FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<_FocusableButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) {
        if (_focused != f) setState(() => _focused = f);
      },
      onKeyEvent: widget.useFocus
          ? (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                   event.logicalKey == LogicalKeyboardKey.select ||
                   event.logicalKey == LogicalKeyboardKey.space)) {
                widget.onTap?.call();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
          : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NeoTheme.durationFast,
          decoration: _focused && widget.useFocus
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: NeoTheme.primaryRed.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                )
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
