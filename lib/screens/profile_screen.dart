import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/content.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import 'anime_detail_screen.dart';
import 'detail_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'sub_accounts_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  List<Content> _favorites = <Content>[];
  bool _isLoadingFavorites = false;

  @override
  void initState() {
    super.initState();
    _api.libraryRevision.addListener(_loadFavorites);
    _loadFavorites();
  }

  @override
  void dispose() {
    _api.libraryRevision.removeListener(_loadFavorites);
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoadingFavorites = true);
    try {
      final data = await _api.getLibrary();
      if (!mounted) {
        return;
      }
      setState(() {
        _favorites = data.map(Content.fromJson).where((c) => c.hasPoster).toList();
        _isLoadingFavorites = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingFavorites = false);
    }
  }

  void _openDetail(Content content) {
    if (content.contentType == 'anime') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AnimeDetailScreen(animeId: content.id)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(contentId: content.id)),
      );
    }
  }

  void _openFavoritesPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FavoritesPage(
          favorites: _favorites,
          onRefresh: _loadFavorites,
          onTap: _openDetail,
        ),
      ),
    );
  }

  void _showAffiliateDialog(String code) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: NeoTheme.bgOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
          ),
          title: Text('Code affiliation', style: NeoTheme.titleLarge(context)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Partagez ce code pour rattacher vos recommandations.',
                style: NeoTheme.bodyMedium(context),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF16163A), Color(0xFF0A0A18)]),
                  borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                  border: Border.all(color: NeoTheme.prestigeGold.withValues(alpha: 0.15), width: 0.5),
                  boxShadow: NeoTheme.shadowLevel2,
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: NeoTheme.headlineMedium(
                    context,
                  ).copyWith(color: NeoTheme.prestigeGold, letterSpacing: 2),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Fermer',
                style: NeoTheme.labelLarge(
                  context,
                ).copyWith(color: NeoTheme.textSecondary),
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copie.'),
                    backgroundColor: NeoTheme.primaryRed,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: NeoTheme.primaryRed,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('Copier'),
            ),
          ],
        );
      },
    );
  }

  void _showUpgradeSheet() {
    final currentUser = context.read<AuthProvider>().user;
    final refController = TextEditingController();
    bool hasAffiliateCode = false;
    bool isCodeValid = false;
    bool isValidating = false;
    String? validationMessage;

    Future<void> validateCode(StateSetter setSheetState, String code) async {
      final normalizedCode = code.trim().toUpperCase();
      final ownCode = currentUser?.affiliateCode?.trim().toUpperCase() ?? '';

      if (normalizedCode.isEmpty) {
        setSheetState(() {
          isCodeValid = false;
          validationMessage = null;
        });
        return;
      }

      if (currentUser?.isAffiliatePartner == true &&
          ownCode == normalizedCode) {
        setSheetState(() {
          isCodeValid = false;
          isValidating = false;
          validationMessage = 'Vous ne pouvez pas utiliser votre propre code.';
        });
        return;
      }

      setSheetState(() => isValidating = true);
      try {
        final response = await _api.validateAffiliateCode(normalizedCode);
        if (!mounted) {
          return;
        }
        setSheetState(() {
          isCodeValid = response['valid'] == true;
          validationMessage = response['message']?.toString();
          isValidating = false;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }
        setSheetState(() {
          isCodeValid = false;
          isValidating = false;
          validationMessage = humanizeApiError(error);
        });
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                top: 16,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              decoration: const BoxDecoration(
                color: NeoTheme.bgSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(NeoTheme.radius2xl)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: NeoTheme.textDisabled,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: NeoTheme.prestigeGold,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Passer Premium',
                            style: NeoTheme.headlineMedium(
                              context,
                            ).copyWith(color: NeoTheme.prestigeGold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Catalogue complet, profils famille et verification continue cote API.',
                        style: NeoTheme.bodyMedium(context),
                      ),
                      const SizedBox(height: 18),
                      _benefit(context, 'Catalogue complet films et series'),
                      const SizedBox(height: 10),
                      _benefit(context, 'Jusqu a 4 profils supplementaires'),
                      const SizedBox(height: 10),
                      _benefit(
                        context,
                        'Experience plus fluide sur tous les ecrans',
                      ),
                      const SizedBox(height: 18),
                      SwitchListTile.adaptive(
                        value: hasAffiliateCode,
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: NeoTheme.prestigeGold,
                        title: Text(
                          'J ai un code d affiliation',
                          style: NeoTheme.bodyMedium(
                            context,
                          ).copyWith(color: NeoTheme.textPrimary),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            hasAffiliateCode = value;
                            if (!value) {
                              refController.clear();
                              isCodeValid = false;
                              validationMessage = null;
                            }
                          });
                        },
                      ),
                      if (hasAffiliateCode) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: refController,
                          onChanged: (value) =>
                              validateCode(setSheetState, value),
                          style: NeoTheme.bodyLarge(
                            context,
                          ).copyWith(color: NeoTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Code affiliation',
                            suffixIcon: isValidating
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: NeoTheme.prestigeGold,
                                      ),
                                    ),
                                  )
                                : isCodeValid
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: NeoTheme.successGreen,
                                  )
                                : null,
                          ),
                        ),
                        if (validationMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            validationMessage!,
                            style: NeoTheme.bodySmall(context).copyWith(
                              color: isCodeValid
                                  ? NeoTheme.successGreen
                                  : NeoTheme.warningOrange,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              isValidating ||
                                  (hasAffiliateCode &&
                                      (!isCodeValid ||
                                          refController.text.trim().isEmpty))
                              ? null
                              : () {
                                  final referralCode =
                                      hasAffiliateCode && isCodeValid
                                      ? refController.text.trim().toUpperCase()
                                      : '';
                                  Navigator.of(sheetContext).pop();
                                  _openPayPalCheckout(referralCode);
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: hasAffiliateCode && isCodeValid
                                ? NeoTheme.prestigeGold
                                : NeoTheme.primaryRed,
                            foregroundColor: hasAffiliateCode && isCodeValid
                                ? Colors.black
                                : Colors.white,
                            disabledBackgroundColor: NeoTheme.bgElevated,
                            disabledForegroundColor: NeoTheme.textDisabled,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.payment_rounded),
                          label: Text(
                            hasAffiliateCode
                                ? (isCodeValid
                                      ? 'Continuer avec avantage affiliation'
                                      : 'Entrez un code valide')
                                : 'Continuer vers le paiement',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openPayPalCheckout(String ref) {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.id.toString();
    if (uid == null) {
      return;
    }

    final baseUrl = AppConstants.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final checkoutUrl = '$baseUrl/checkout.php?uid=$uid&ref=$ref';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: NeoTheme.bgBase,
            borderRadius: BorderRadius.vertical(top: Radius.circular(NeoTheme.radius2xl)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: NeoTheme.topPanelGradient,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payment_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Paiement securise PayPal',
                        style: NeoTheme.titleMedium(
                          context,
                        ).copyWith(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(checkoutUrl)),
                  onLoadStop: (controller, url) async {
                    if (url == null) {
                      return;
                    }
                    final current = url.toString();
                    if (!current.contains('checkout_success.php')) {
                      return;
                    }
                    if (!mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    await auth.refreshUser();
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Paiement valide. Compte Premium active.',
                        ),
                        backgroundColor: NeoTheme.successGreen,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _benefit(BuildContext context, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: NeoTheme.successGreen,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: NeoTheme.bodyMedium(
              context,
            ).copyWith(color: NeoTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: NeoTheme.labelMedium(context).copyWith(color: color),
      ),
    );
  }

  Widget _stat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
        boxShadow: NeoTheme.shadowLevel1,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: NeoTheme.labelMedium(context)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NeoTheme.titleMedium(context).copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);
    final padding = NeoTheme.screenPadding(context);

    final actions = <_ActionItem>[
      _ActionItem(
        icon: Icons.favorite_outline_rounded,
        title: 'Bibliotheque',
        subtitle: 'Voir tous vos favoris',
        color: NeoTheme.primaryRed,
        onTap: _openFavoritesPage,
      ),
      _ActionItem(
        icon: Icons.history_rounded,
        title: 'Historique',
        subtitle: 'Reprises et contenus recents',
        color: NeoTheme.infoCyan,
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
        },
      ),
      _ActionItem(
        icon: Icons.settings_outlined,
        title: 'Parametres',
        subtitle: 'Compte, lecture et securite',
        color: NeoTheme.warningOrange,
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        },
      ),
      if (auth.isPremium)
        _ActionItem(
          icon: Icons.people_outline_rounded,
          title: 'Profils famille',
          subtitle: 'Creer et gerer les sous-comptes',
          color: NeoTheme.purpleAccent,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubAccountsScreen()),
            );
          },
        ),
      if (user?.isAffiliatePartner == true &&
          user?.affiliateCode != null &&
          user!.affiliateCode!.isNotEmpty)
        _ActionItem(
          icon: Icons.share_outlined,
          title: 'Affiliation',
          subtitle: 'Afficher et copier votre code',
          color: NeoTheme.prestigeGold,
          onTap: () => _showAffiliateDialog(user.affiliateCode!),
        ),
      _ActionItem(
        icon: Icons.logout_rounded,
        title: 'Deconnexion',
        subtitle: 'Fermer cette session',
        color: NeoTheme.errorRed,
        onTap: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: SafeArea(
        top: !NeoTheme.isTV(context),
        child: RefreshIndicator(
          onRefresh: _loadFavorites,
          color: NeoTheme.primaryRed,
          child: ListView(
            padding: EdgeInsets.fromLTRB(padding.left, 18, padding.right, 32),
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: NeoTheme.glassGradient,
                    borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                    border: Border.all(
                      color: (auth.isPremium ? NeoTheme.prestigeGold : NeoTheme.primaryRed).withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                    boxShadow: NeoTheme.shadowLevel2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: auth.isPremium
                                  ? NeoTheme.premiumGradient
                                  : NeoTheme.heroGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: (auth.isPremium ? NeoTheme.prestigeGold : NeoTheme.primaryRed).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (user?.username.isNotEmpty ?? false)
                                    ? user!.username[0].toUpperCase()
                                    : 'U',
                                style: NeoTheme.displayMedium(context).copyWith(
                                  color: auth.isPremium
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    Text(
                                      user?.username ?? 'Utilisateur',
                                      style: NeoTheme.headlineLarge(context),
                                    ),
                                    _pill(
                                      context,
                                      auth.isPremium ? 'Premium' : 'Standard',
                                      auth.isPremium
                                          ? NeoTheme.prestigeGold
                                          : NeoTheme.infoCyan,
                                    ),
                                    if (user?.isSubAccount == true)
                                      _pill(
                                        context,
                                        'Sous-compte',
                                        NeoTheme.purpleAccent,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user?.email.isNotEmpty == true
                                      ? user!.email
                                      : 'Compte Neo-Stream',
                                  style: NeoTheme.bodyLarge(context),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  auth.isPremium
                                      ? 'Abonnement ${user?.premiumLabel ?? 'Premium'}'
                                      : 'Passez Premium pour debloquer les profils famille.',
                                  style: NeoTheme.bodySmall(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: auth.isPremium
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  );
                                }
                              : _showUpgradeSheet,
                          style: FilledButton.styleFrom(
                            backgroundColor: auth.isPremium
                                ? NeoTheme.primaryRed
                                : NeoTheme.prestigeGold,
                            foregroundColor: auth.isPremium
                                ? Colors.white
                                : Colors.black,
                          ),
                          icon: Icon(
                            auth.isPremium
                                ? Icons.shield_outlined
                                : Icons.workspace_premium_rounded,
                          ),
                          label: Text(
                            auth.isPremium ? 'Voir securite' : 'Passer Premium',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 700;
                  final stats = [
                    _stat(
                      context,
                      icon: Icons.favorite_outline_rounded,
                      label: 'Favoris',
                      value: '${_favorites.length}',
                      color: NeoTheme.primaryRed,
                    ),
                    _stat(
                      context,
                      icon: Icons.verified_user_outlined,
                      label: 'Statut', // Changed from 'Session API'
                      value: _api.hasIntegritySession
                          ? 'Connectee'
                          : 'En attente', // Changed to 'Connectée'
                      color: _api.hasIntegritySession
                          ? NeoTheme.successGreen
                          : NeoTheme.warningOrange,
                    ),
                    _stat(
                      context,
                      icon: Icons.workspace_premium_outlined,
                      label: 'Expiration',
                      value: auth.isPremium
                          ? ((user?.premiumExpiry.isNotEmpty ?? false)
                                ? user!.premiumExpiry
                                : 'Illimite')
                          : 'Gratuit',
                      color: auth.isPremium
                          ? NeoTheme.prestigeGold
                          : NeoTheme.textSecondary,
                    ),
                  ];

                  return wide
                      ? Row(
                          children:
                              stats
                                  .expand(
                                    (item) => [
                                      Expanded(child: item),
                                      const SizedBox(width: 12),
                                    ],
                                  )
                                  .toList()
                                ..removeLast(),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              stats
                                  .expand(
                                    (item) => [
                                      item,
                                      const SizedBox(height: 12),
                                    ],
                                  )
                                  .toList()
                                ..removeLast(),
                        );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: NeoTheme.surfaceGradient,
                  borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                  border: Border.all(color: NeoTheme.primaryRed.withValues(alpha: 0.15), width: 0.5),
                  boxShadow: NeoTheme.shadowLevel1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: NeoTheme.primaryRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mes favoris',
                            style: NeoTheme.titleLarge(context),
                          ),
                        ),
                        if (_favorites.isNotEmpty)
                          TextButton.icon(
                            onPressed: _openFavoritesPage,
                            icon: const Icon(Icons.grid_view_rounded),
                            label: const Text('Voir tout'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Votre bibliotheque personnelle reste accessible sur tous les appareils.',
                      style: NeoTheme.bodySmall(context),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingFavorites)
                      const SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: NeoTheme.primaryRed,
                          ),
                        ),
                      )
                    else if (_favorites.isEmpty)
                      Container(
                        height: 180,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: NeoTheme.bgElevated,
                          borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                          border: Border.all(color: NeoTheme.bgBorder.withValues(alpha: 0.2), width: 0.5),
                        ),
                        child: Text(
                          'Aucun favori pour le moment.',
                          style: NeoTheme.bodyMedium(context),
                        ),
                      )
                    else
                      SizedBox(
                        height: width >= 1100 ? 280 : width >= 700 ? 250 : 210,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _favorites.length > 8
                              ? 8
                              : _favorites.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final item = _favorites[index];
                            return SizedBox(
                              width: width >= 1100 ? 168 : width >= 700 ? 152 : 128,
                              child: _FavoriteTile(
                                content: item,
                                onTap: () => _openDetail(item),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: NeoTheme.gridSpacing(context),
                  mainAxisSpacing: NeoTheme.gridSpacing(context),
                  childAspectRatio: crossAxisCount == 1 ? 2.8 : 2.4,
                ),
                itemBuilder: (context, index) {
                  final item = actions[index];
                  final useFocus = NeoTheme.needsFocusNavigation(context);
                  return Focus(
                    canRequestFocus: useFocus,
                    onKeyEvent: useFocus
                        ? (node, event) {
                            if (event is KeyDownEvent &&
                                (event.logicalKey == LogicalKeyboardKey.enter ||
                                 event.logicalKey == LogicalKeyboardKey.select ||
                                 event.logicalKey == LogicalKeyboardKey.space)) {
                              item.onTap();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          }
                        : null,
                    child: Builder(
                      builder: (ctx) {
                        final isFocused = Focus.of(ctx).hasFocus;
                        return InkWell(
                          borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                          onTap: item.onTap,
                          child: AnimatedContainer(
                            duration: NeoTheme.durationFast,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF16163A), Color(0xFF0A0A18)]),
                              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                              border: Border.all(
                                color: (isFocused && useFocus)
                                    ? item.color
                                    : item.color.withValues(alpha: 0.15),
                                width: (isFocused && useFocus) ? 2 : 0.5,
                              ),
                              boxShadow: [
                                ...NeoTheme.shadowLevel2,
                                if (isFocused && useFocus)
                                  BoxShadow(
                                    color: item.color.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: item.color.withValues(alpha: 0.2), width: 0.5),
                            ),
                            child: Icon(item.icon, color: item.color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: NeoTheme.titleMedium(context),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: NeoTheme.bodySmall(context),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: NeoTheme.textDisabled,
                          ),
                        ],
                      ),
                    ),
                    );
                  },
                  ),
                );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _FavoriteTile extends StatelessWidget {
  final Content content;
  final VoidCallback onTap;

  const _FavoriteTile({required this.content, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: NeoTheme.surfaceGradient,
          borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
          border: Border.all(color: NeoTheme.bgBorder.withValues(alpha: 0.15), width: 0.5),
          boxShadow: NeoTheme.shadowLevel1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: content.fullPosterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: content.fullPosterUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: NeoTheme.bgElevated),
                      errorWidget: (_, _, _) => Container(
                        color: NeoTheme.bgElevated,
                        child: const Icon(
                          Icons.movie_rounded,
                          color: NeoTheme.textDisabled,
                        ),
                      ),
                    )
                  : Container(
                      color: NeoTheme.bgElevated,
                      child: const Icon(
                        Icons.movie_rounded,
                        color: NeoTheme.textDisabled,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NeoTheme.labelLarge(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content.typeLabel,
                    style: NeoTheme.labelSmall(
                      context,
                    ).copyWith(color: NeoTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesPage extends StatefulWidget {
  final List<Content> favorites;
  final VoidCallback onRefresh;
  final void Function(Content) onTap;

  const _FavoritesPage({
    required this.favorites,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  State<_FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<_FavoritesPage> {
  final ApiService _api = ApiService();
  late List<Content> _localFavorites;

  @override
  void initState() {
    super.initState();
    _localFavorites = List<Content>.from(widget.favorites);
  }

  Future<void> _remove(Content content) async {
    try {
      if (content.contentType == 'anime') {
        await _api.removeAnimeFromLibrary(content.id);
      } else {
        await _api.removeFromLibrary(content.id);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _localFavorites.removeWhere((item) => item.id == content.id);
      });
      widget.onRefresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1400
        ? 6
        : width >= 1100
        ? 5
        : width >= 700
        ? 4
        : 2;

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      appBar: AppBar(
        backgroundColor: NeoTheme.bgBase,
        title: Text(
          'Tous les favoris',
          style: NeoTheme.headlineMedium(context),
        ),
      ),
      body: _localFavorites.isEmpty
          ? Center(
              child: Text('Aucun favori.', style: NeoTheme.titleLarge(context)),
            )
          : GridView.builder(
              padding: EdgeInsets.fromLTRB(
                NeoTheme.screenPadding(context).left,
                14,
                NeoTheme.screenPadding(context).right,
                28,
              ),
              itemCount: _localFavorites.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: NeoTheme.gridSpacing(context),
                mainAxisSpacing: NeoTheme.gridSpacing(context),
                childAspectRatio: 0.58,
              ),
              itemBuilder: (context, index) {
                final item = _localFavorites[index];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: _FavoriteTile(
                        content: item,
                        onTap: () => widget.onTap(item),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: NeoTheme.bgBase.withValues(alpha: 0.82),
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () => _remove(item),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: NeoTheme.primaryRed,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
