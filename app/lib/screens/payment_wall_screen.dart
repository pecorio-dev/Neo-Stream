import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
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
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: NeoTheme.durationSlow,
            transitionsBuilder: (_, animation, __, child) =>
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
                child: Text(message, style: const TextStyle(color: Colors.white))),
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
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: NeoTheme.durationSlow,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  Future<void> _openPayPal() async {
    final uid = context.read<AuthProvider>().user?.id.toString();
    if (uid == null) return;
    final checkoutUrl = 'https://neo-stream.eu/app/checkout.php?uid=$uid';

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: NeoTheme.bgBase,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(NeoTheme.radius2xl)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(gradient: NeoTheme.topPanelGradient),
              child: Row(
                children: [
                  const Icon(Icons.payment_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Paiement PayPal — 10€',
                      style: NeoTheme.titleMedium(context)
                          .copyWith(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
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
                  _showSnack('Paiement confirmé ! Accès activé.', success: true);
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const HomeScreen(),
                      transitionDuration: NeoTheme.durationSlow,
                      transitionsBuilder: (_, animation, __, child) =>
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

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.3,
            colors: [Color(0xFF12122A), Color(0xFF0A0A18), Color(0xFF06060C)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    padding.left, 12, padding.right, 0),
                child: Row(
                  children: [
                    Row(
                      children: [
                        Text(
                          'NEO',
                          style: NeoTheme.titleLarge(context).copyWith(
                            color: NeoTheme.primaryRed,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'STREAM',
                          style: NeoTheme.titleLarge(context).copyWith(
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
                        foregroundColor: NeoTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      padding.left, 28 * scale, padding.right, 32 * scale),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 76 * scale,
                              height: 76 * scale,
                              decoration: BoxDecoration(
                                gradient: NeoTheme.heroGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: NeoTheme.primaryRed
                                        .withValues(alpha: 0.4),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white,
                                size: 34 * scale,
                              ),
                            ),
                          ),
                          SizedBox(height: 22 * scale),

                          Text(
                            'Accès restreint',
                            textAlign: TextAlign.center,
                            style: NeoTheme.displayMedium(context)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 10 * scale),
                          Text(
                            'Pour regarder des films, séries et animes, activez votre accès Neo-Stream une seule fois.',
                            textAlign: TextAlign.center,
                            style: NeoTheme.bodyMedium(context).copyWith(
                              color: NeoTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 24 * scale),
                          Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24 * scale,
                                vertical: 12 * scale,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    NeoTheme.prestigeGold
                                        .withValues(alpha: 0.2),
                                    NeoTheme.goldDark.withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                    NeoTheme.radiusXl),
                                border: Border.all(
                                  color: NeoTheme.prestigeGold
                                      .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                                boxShadow: NeoTheme.shadowGoldGlow,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    color: NeoTheme.prestigeGold,
                                    size: 22 * scale,
                                  ),
                                  SizedBox(width: 10 * scale),
                                  Text(
                                    '10€',
                                    style: NeoTheme.displayMedium(context)
                                        .copyWith(
                                      color: NeoTheme.prestigeGold,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(width: 6 * scale),
                                  Text(
                                    'à vie',
                                    style: NeoTheme.bodyLarge(context).copyWith(
                                      color: NeoTheme.prestigeGold
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 24 * scale),

                          Container(
                            padding: EdgeInsets.all(18 * scale),
                            decoration: BoxDecoration(
                              gradient: NeoTheme.surfaceGradient,
                              borderRadius:
                                  BorderRadius.circular(NeoTheme.radiusLg),
                              border: Border.all(
                                color:
                                    NeoTheme.bgBorder.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                              boxShadow: NeoTheme.shadowLevel2,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Comment payer',
                                  style: NeoTheme.titleMedium(context)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 14 * scale),
                                _buildPaymentOption(
                                  context,
                                  scale: scale,
                                  icon: Icons.chat_bubble_outline_rounded,
                                  title: 'Via Discord',
                                  subtitle:
                                      'Contactez p3cori0 — il vous enverra votre clé d\'activation',
                                  color: const Color(0xFF5865F2),
                                  buttonLabel: 'Copier p3cori0',
                                  onTap: () {
                                    Clipboard.setData(
                                        const ClipboardData(text: 'p3cori0'));
                                    _showSnack('Pseudo copié : p3cori0',
                                        success: true);
                                  },
                                ),
                                SizedBox(height: 10 * scale),
                                _buildPaymentOption(
                                  context,
                                  scale: scale,
                                  icon: Icons.payment_rounded,
                                  title: 'Via PayPal',
                                  subtitle:
                                      'Paiement sécurisé — accès activé automatiquement',
                                  color: const Color(0xFF009CDE),
                                  buttonLabel: 'Ouvrir PayPal',
                                  onTap: _openPayPal,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20 * scale),

                          Container(
                            padding: EdgeInsets.all(18 * scale),
                            decoration: BoxDecoration(
                              gradient: NeoTheme.glassGradient,
                              borderRadius:
                                  BorderRadius.circular(NeoTheme.radiusLg),
                              border: Border.all(
                                color: NeoTheme.primaryRed
                                    .withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                              boxShadow: NeoTheme.shadowLevel2,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Déjà une clé d\'activation ?',
                                  style: NeoTheme.titleMedium(context)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 12 * scale),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: NeoTheme.bgElevated,
                                          borderRadius: BorderRadius.circular(
                                              NeoTheme.radiusMd),
                                          border: Border.all(
                                            color: NeoTheme.bgBorder
                                                .withValues(alpha: 0.3),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _licenseController,
                                          style: NeoTheme.bodyLarge(context),
                                          onSubmitted: (_) =>
                                              _activateLicense(),
                                          decoration: InputDecoration(
                                            hintText: 'Clé de licence',
                                            hintStyle: NeoTheme.bodyLarge(
                                                    context)
                                                .copyWith(
                                                    color:
                                                        NeoTheme.textDisabled),
                                            prefixIcon: const Icon(
                                              Icons.vpn_key_rounded,
                                              color: NeoTheme.textDisabled,
                                              size: 20,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: _isActivating
                                          ? null
                                          : _activateLicense,
                                      child: AnimatedContainer(
                                        duration: NeoTheme.durationFast,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: _isActivating
                                                ? [
                                                    NeoTheme.primaryRed
                                                        .withValues(alpha: 0.3),
                                                    NeoTheme.primaryRed
                                                        .withValues(alpha: 0.2),
                                                  ]
                                                : [
                                                    NeoTheme.primaryRed,
                                                    NeoTheme.primaryRed
                                                        .withValues(alpha: 0.85),
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                              NeoTheme.radiusMd),
                                          boxShadow: _isActivating
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: NeoTheme.primaryRed
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 12,
                                                    offset:
                                                        const Offset(0, 4),
                                                  ),
                                                ],
                                        ),
                                        child: _isActivating
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                          Colors.white),
                                                ),
                                              )
                                            : Text(
                                                'Activer',
                                                style: NeoTheme.labelLarge(
                                                        context)
                                                    .copyWith(
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
                          ),
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

  Widget _buildPaymentOption(
    BuildContext context, {
    required double scale,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40 * scale,
            height: 40 * scale,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20 * scale),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
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
                      .copyWith(color: NeoTheme.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * scale),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 8 * scale,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
                border: Border.all(
                    color: color.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text(
                buttonLabel,
                style: NeoTheme.labelMedium(context).copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
