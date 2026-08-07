import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class PaymentWallScreen extends StatefulWidget {
  const PaymentWallScreen({super.key});

  @override
  State<PaymentWallScreen> createState() => _PaymentWallScreenState();
}

class _PaymentWallScreenState extends State<PaymentWallScreen> {
  final _licenseController = TextEditingController();
  bool _isActivating = false;

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _activateLicense() async {
    final key = _licenseController.text.trim();
    if (key.isEmpty) return;
    setState(() => _isActivating = true);
    try {
      final result = await ApiService().redeemLicenseKey(key);
      if (!mounted) return;
      final success = result['success'] == true;
      final message = result['message']?.toString() ??
          (success ? 'Accès activé !' : 'Clé invalide');
      _showSnack(message, success: success);
      if (success) {
        _licenseController.clear();
        await context.read<AuthProvider>().refreshUser();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_1, _2, _3) => HomeScreen(),
            transitionDuration: NeoTheme.durationSlow,
            transitionsBuilder: (_1, animation, _2, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Erreur: $e', success: false);
    }
    if (!mounted) return;
    setState(() => _isActivating = false);
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
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: success ? NeoTheme.successGreen : NeoTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusMd)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_1, _2, _3) => LoginScreen(),
        transitionDuration: NeoTheme.durationSlow,
        transitionsBuilder: (_1, animation, _2, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  Future<void> _openPayPal(String plan) async {
    final uid = context.read<AuthProvider>().user?.id.toString();
    if (uid == null) return;
    final checkoutUrl =
        'https://neo-stream.eu/app/checkout.php?uid=$uid&plan=$plan';

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Neo.bgBase(context),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(NeoTheme.radius2xl)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border(
                  bottom: BorderSide(
                    color: Neo.bgBorder(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Le fond du sheet dispatche (clair en thème clair) :
                  // icônes/titre doivent suivre le thème.
                  Icon(Icons.payment_rounded, color: Neo.textPrimary(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Paiement PayPal',
                      style: Neo.titleMedium(context),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    icon:
                        Icon(Icons.close_rounded, color: Neo.textPrimary(context)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(checkoutUrl)),
                onLoadStop: (controller, url) async {
                  if (url == null) return;
                  if (!url.toString().contains('checkout_success')) return;
                  Navigator.of(sheetCtx).pop();
                  if (!mounted) return;
                  await context.read<AuthProvider>().refreshUser();
                  if (!mounted) return;
                  _showSnack('Paiement confirmé ! Accès activé.',
                      success: true);
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (_1, _2, _3) => HomeScreen(),
                      transitionDuration: NeoTheme.durationSlow,
                      transitionsBuilder: (_1, animation, _2, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = NeoTheme.scaleFactor(context);
    final padding = NeoTheme.screenPadding(context);
    final isMobile = NeoTheme.isMobile(context);

    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.4,
            colors: [Color(0xFF101018), Color(0xFF080810), Color(0xFF040408)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Header ───────────────────────────────────────────
              Padding(
                padding:
                    EdgeInsets.fromLTRB(padding.left, 12, padding.right, 0),
                child: Row(
                  children: [
                    Row(
                      children: [
                        Text(
                          'NEO',
                          style: Neo.titleLarge(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'STREAM',
                          style: Neo.titleLarge(context).copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w200,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Déconnexion'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Content ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      padding.left, 32 * scale, padding.right, 40 * scale),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ─── Title Section ────────────────────────
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 64 * scale,
                                  height: 64 * scale,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        Colors.white.withValues(alpha: 0.08),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.live_tv_rounded,
                                    color: Colors.white,
                                    size: 30 * scale,
                                  ),
                                ),
                                SizedBox(height: 20 * scale),
                                Text(
                                  'TV en Direct Premium',
                                  textAlign: TextAlign.center,
                                  style: Neo.displayMedium(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 10 * scale),
                                Text(
                                  'Sans engagement, résiliable à tout moment.',
                                  textAlign: TextAlign.center,
                                  style: Neo.bodyLarge(context).copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.55),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 36 * scale),

                          // ─── Pricing Plans ────────────────────────
                          isMobile
                              ? Column(
                                  children: [
                                    _buildMonthlyPlan(context, scale),
                                    SizedBox(height: 16 * scale),
                                    _buildAnnualPlan(context, scale),
                                  ],
                                )
                              : IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                          child: _buildMonthlyPlan(
                                              context, scale)),
                                      SizedBox(width: 16 * scale),
                                      Expanded(
                                          child: _buildAnnualPlan(
                                              context, scale)),
                                    ],
                                  ),
                                ),
                          SizedBox(height: 20 * scale),

                          // ─── Payment Note ─────────────────────────
                          Center(
                            child: Text(
                              'Paiement sécurisé via PayPal. Sans engagement.',
                              style: Neo.bodySmall(context).copyWith(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          SizedBox(height: 36 * scale),

                          // ─── License Key Section ──────────────────
                          _buildLicenseSection(context, scale),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Monthly Plan Card ──────────────────────────────────────────────────

  Widget _buildMonthlyPlan(BuildContext context, double scale) {
    return Container(
      padding: EdgeInsets.all(22 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan Mensuel',
            style: Neo.titleLarge(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16 * scale),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '9,99€',
                style: Neo.displayMedium(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/mois',
                style: Neo.bodyMedium(context).copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            'Facturé chaque mois',
            style: Neo.bodySmall(context).copyWith(
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 20 * scale),
          _buildFeatureItem(context, scale, 'Toutes les chaînes Premium en HD'),
          SizedBox(height: 10 * scale),
          _buildFeatureItem(context, scale, 'Zéro publicité sur tout le site'),
          SizedBox(height: 10 * scale),
          _buildFeatureItem(context, scale, 'Clé IPTV auto-générée'),
          SizedBox(height: 10 * scale),
          _buildFeatureItem(context, scale, 'Support prioritaire'),
          SizedBox(height: 24 * scale),
          SizedBox(
            width: double.infinity,
            child: _buildSubscribeButton(
              context,
              scale: scale,
              onTap: () => _openPayPal('monthly'),
              filled: false,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Annual Plan Card ───────────────────────────────────────────────────

  Widget _buildAnnualPlan(BuildContext context, double scale) {
    return Container(
      padding: EdgeInsets.all(22 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.03),
            blurRadius: 40,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Plan Annuel',
                style: Neo.titleLarge(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'Le plus populaire',
                  style: Neo.labelSmall(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '69,99€',
                style: Neo.displayMedium(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/an',
                style: Neo.bodyMedium(context).copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          Row(
            children: [
              Text(
                '119,88€',
                style: Neo.bodySmall(context).copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Soit 5,83€/mois · Économie 49,89€',
                style: Neo.bodySmall(context).copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 20 * scale),
          _buildFeatureItem(context, scale, 'Tout l\'avantage Mensuel'),
          SizedBox(height: 10 * scale),
          _buildFeatureItem(
              context, scale, '−41% sur le tarif mensuel'),
          SizedBox(height: 10 * scale),
          _buildFeatureItem(
              context, scale, 'Accès prioritaire aux nouvelles chaînes'),
          SizedBox(height: 10 * scale),
          _buildFeatureItem(context, scale, 'Support prioritaire 24/7'),
          SizedBox(height: 10 * scale),
          _buildFeatureItem(
              context, scale, 'Badge Premium sur votre profil'),
          SizedBox(height: 24 * scale),
          SizedBox(
            width: double.infinity,
            child: _buildSubscribeButton(
              context,
              scale: scale,
              onTap: () => _openPayPal('annual'),
              filled: true,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature Item ───────────────────────────────────────────────────────

  Widget _buildFeatureItem(BuildContext context, double scale, String text) {
    return Row(
      children: [
        Container(
          width: 20 * scale,
          height: 20 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Icon(
            Icons.check_rounded,
            color: Colors.white.withValues(alpha: 0.8),
            size: 13 * scale,
          ),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: Text(
            text,
            style: Neo.bodyMedium(context).copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Subscribe Button ───────────────────────────────────────────────────

  Widget _buildSubscribeButton(
    BuildContext context, {
    required double scale,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: NeoTheme.durationFast,
        padding: EdgeInsets.symmetric(vertical: 14 * scale),
        decoration: BoxDecoration(
          color: filled
              ? Colors.white
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
          border: Border.all(
            color: filled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.2),
            width: filled ? 0 : 0.5,
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            'S\'abonner',
            style: Neo.labelLarge(context).copyWith(
              color: filled ? Colors.black : Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  // ─── License Key Section ────────────────────────────────────────────────

  Widget _buildLicenseSection(BuildContext context, double scale) {
    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Déjà une clé d\'activation ?',
            style: Neo.titleMedium(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            'Entrez votre clé de licence pour activer votre accès.',
            style: Neo.bodySmall(context).copyWith(
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 14 * scale),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius:
                        BorderRadius.circular(NeoTheme.radiusMd),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: TextField(
                    controller: _licenseController,
                    style: Neo.bodyLarge(context)
                        .copyWith(color: Colors.white),
                    onSubmitted: (_) => _activateLicense(),
                    decoration: InputDecoration(
                      hintText: 'Clé de licence',
                      hintStyle: Neo.bodyLarge(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      prefixIcon: Icon(
                        Icons.vpn_key_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isActivating ? null : _activateLicense,
                child: AnimatedContainer(
                  duration: NeoTheme.durationFast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _isActivating
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(NeoTheme.radiusMd),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: _isActivating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'Activer',
                          style: Neo.labelLarge(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
