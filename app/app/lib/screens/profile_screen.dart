import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../config/neo.dart';
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
  ProfileScreen({super.key});

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
          backgroundColor: Neo.bgOverlay(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
          ),
          title: Text('Code affiliation', style: Neo.titleLarge(context)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Partagez ce code pour rattacher vos recommandations.',
                style: Neo.bodyMedium(context),
              ),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF16163A), Color(0xFF0A0A18)]),
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
                ).copyWith(color: Neo.textSecondary(context)),
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
                  SnackBar(
                    content: Text('Code copie.'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              icon: Icon(Icons.copy_all_rounded),
              label: Text('Copier'),
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
              decoration: BoxDecoration(
                color: Neo.bgSurface(context),
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
                            color: Neo.textDisabled(context),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: NeoTheme.prestigeGold,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Passer Premium',
                            style: NeoTheme.headlineMedium(
                              context,
                            ).copyWith(color: NeoTheme.prestigeGold),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Catalogue complet, profils famille et verification continue cote API.',
                        style: Neo.bodyMedium(context),
                      ),
                      SizedBox(height: 18),
                      _benefit(context, 'Catalogue complet films et series'),
                      SizedBox(height: 10),
                      _benefit(context, 'Jusqu a 4 profils supplementaires'),
                      SizedBox(height: 10),
                      _benefit(
                        context,
                        'Experience plus fluide sur tous les ecrans',
                      ),
                      SizedBox(height: 18),
                      SwitchListTile.adaptive(
                        value: hasAffiliateCode,
                        contentPadding: EdgeInsets.zero,
                        activeColor: NeoTheme.prestigeGold,
                        title: Text(
                          'J ai un code d affiliation',
                          style: NeoTheme.bodyMedium(
                            context,
                          ).copyWith(color: Neo.textPrimary(context)),
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
                        SizedBox(height: 12),
                        TextField(
                          controller: refController,
                          onChanged: (value) =>
                              validateCode(setSheetState, value),
                          style: NeoTheme.bodyLarge(
                            context,
                          ).copyWith(color: Neo.textPrimary(context)),
                          decoration: InputDecoration(
                            labelText: 'Code affiliation',
                            suffixIcon: isValidating
                                ? Padding(
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
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: NeoTheme.successGreen,
                                  )
                                : null,
                          ),
                        ),
                        if (validationMessage != null) ...[
                          SizedBox(height: 8),
                          Text(
                            validationMessage!,
                            style: Neo.bodySmall(context).copyWith(
                              color: isCodeValid
                                  ? NeoTheme.successGreen
                                  : NeoTheme.warningOrange,
                            ),
                          ),
                        ],
                      ],
                      SizedBox(height: 22),
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
                                : Theme.of(context).colorScheme.primary,
                            foregroundColor: hasAffiliateCode && isCodeValid
                                ? Colors.black
                                : Colors.white,
                            disabledBackgroundColor: Neo.bgElevated(context),
                            disabledForegroundColor: Neo.textDisabled(context),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: Icon(Icons.payment_rounded),
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
          decoration: BoxDecoration(
            color: Neo.bgBase(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(NeoTheme.radius2xl)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: Neo.topPanelGradient(context),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment_rounded, color: Colors.white),
                    SizedBox(width: 10),
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
                      icon: Icon(
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
                      SnackBar(
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
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  Widget _benefit(BuildContext context, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: NeoTheme.successGreen,
          size: 20,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: NeoTheme.bodyMedium(
              context,
            ).copyWith(color: Neo.textPrimary(context)),
          ),
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: Neo.labelMedium(context).copyWith(color: color),
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
    final isTV = NeoTheme.isTV(context);
    final iconSize = isTV ? 52.0 : 44.0;
    return Container(
      padding: EdgeInsets.all(isTV ? 20 : 16),
      decoration: BoxDecoration(
        gradient: Neo.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
        boxShadow: NeoTheme.shadowLevel1,
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
            ),
            child: Icon(icon, color: color, size: isTV ? 26 : 22),
          ),
          SizedBox(width: isTV ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Neo.labelMedium(context)),
                SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Neo.titleMedium(context).copyWith(color: color),
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
    final isTV = NeoTheme.isTV(context);
    final crossAxisCount = isTV ? 3 : (width >= 700 ? 2 : 1);
    final padding = NeoTheme.screenPadding(context);

    final actions = <_ActionItem>[
      _ActionItem(
        icon: Icons.favorite_outline_rounded,
        title: 'Bibliotheque',
        subtitle: 'Voir tous vos favoris',
        color: Theme.of(context).colorScheme.primary,
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
          ).push(MaterialPageRoute(builder: (_) => HistoryScreen()));
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
          ).push(MaterialPageRoute(builder: (_) => SettingsScreen()));
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
              MaterialPageRoute(builder: (_) => SubAccountsScreen()),
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
        title: Text('Profil', style: Neo.headlineMedium(context)),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadFavorites,
          color: Theme.of(context).colorScheme.primary,
          child: ListView(
            padding: EdgeInsets.fromLTRB(padding.left, 18, padding.right, 32),
            children: [
              Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: Neo.glassGradient(context),
                    borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                    border: Border.all(
                      color: (auth.isPremium ? NeoTheme.prestigeGold : Theme.of(context).colorScheme.primary).withValues(alpha: 0.15),
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
                            width: isTV ? 96 : 76,
                            height: isTV ? 96 : 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: auth.isPremium
                                  ? NeoTheme.premiumGradient
                                  : NeoTheme.heroGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: (auth.isPremium ? NeoTheme.prestigeGold : Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
                                  blurRadius: isTV ? 24 : 16,
                                  spreadRadius: isTV ? 4 : 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (user?.username.isNotEmpty ?? false)
                                    ? user!.username[0].toUpperCase()
                                    : 'U',
                                style: Neo.displayMedium(context).copyWith(
                                  color: auth.isPremium
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
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
                                      style: Neo.headlineLarge(context),
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
                                SizedBox(height: 8),
                                Text(
                                  user?.email.isNotEmpty == true
                                      ? user!.email
                                      : 'Compte Neo-Stream',
                                  style: Neo.bodyLarge(context),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  auth.isPremium
                                      ? 'Abonnement ${user?.premiumLabel ?? 'Premium'}'
                                      : 'Passez Premium pour debloquer les profils famille.',
                                  style: Neo.bodySmall(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: auth.isPremium
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SettingsScreen(),
                                    ),
                                  );
                                }
                              : _showUpgradeSheet,
                          style: FilledButton.styleFrom(
                            backgroundColor: auth.isPremium
                                ? Theme.of(context).colorScheme.primary
                                : NeoTheme.prestigeGold,
                            foregroundColor: auth.isPremium
                                ? Colors.white
                                : Colors.black,
                            minimumSize: isTV ? const Size.fromHeight(54) : null,
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
              SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 700;
                  final stats = [
                    _stat(
                      context,
                      icon: Icons.favorite_outline_rounded,
                      label: 'Favoris',
                      value: '${_favorites.length}',
                      color: Theme.of(context).colorScheme.primary,
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
                          : Neo.textSecondary(context),
                    ),
                  ];

                  return wide
                      ? Row(
                          children:
                              stats
                                  .expand(
                                    (item) => [
                                      Expanded(child: item),
                                      SizedBox(width: 12),
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
                                      SizedBox(height: 12),
                                    ],
                                  )
                                  .toList()
                                ..removeLast(),
                        );
                },
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: Neo.surfaceGradient,
                  borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), width: 0.5),
                  boxShadow: NeoTheme.shadowLevel1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mes favoris',
                            style: Neo.titleLarge(context),
                          ),
                        ),
                        if (_favorites.isNotEmpty)
                          TextButton.icon(
                            onPressed: _openFavoritesPage,
                            icon: Icon(Icons.grid_view_rounded),
                            label: Text('Voir tout'),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Votre bibliotheque personnelle reste accessible sur tous les appareils.',
                      style: Neo.bodySmall(context),
                    ),
                    SizedBox(height: 16),
                    if (_isLoadingFavorites)
                      SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    else if (_favorites.isEmpty)
                      Container(
                        height: 180,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Neo.bgElevated(context),
                          borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                          border: Border.all(color: Neo.bgBorder(context).withValues(alpha: 0.2), width: 0.5),
                        ),
                        child: Text(
                          'Aucun favori pour le moment.',
                          style: Neo.bodyMedium(context),
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
                          separatorBuilder: (_1, _2) => SizedBox(width: 12),
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
              SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: NeoTheme.gridSpacing(context),
                  mainAxisSpacing: NeoTheme.gridSpacing(context),
                  childAspectRatio: isTV ? 2.6 : (crossAxisCount == 1 ? 2.8 : 2.4),
                ),
                itemBuilder: (context, index) => _ActionCard(item: actions[index]),
              ),
            ],
          ),
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

  _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _ActionCard extends StatefulWidget {
  final _ActionItem item;
  _ActionCard({required this.item});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    final isTV = NeoTheme.isTV(context);
    final item = widget.item;
    final iconSize = isTV ? 56.0 : 48.0;

    return Focus(
      canRequestFocus: useFocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: useFocus
          ? (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                   event.logicalKey == LogicalKeyboardKey.select ||
                   event.logicalKey == LogicalKeyboardKey.space)) {
                setState(() => _pressed = true);
                item.onTap();
                return KeyEventResult.handled;
              }
              if (event is KeyUpEvent) setState(() => _pressed = false);
              return KeyEventResult.ignored;
            }
          : null,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          item.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: NeoTheme.durationFast,
            padding: EdgeInsets.all(isTV ? 22 : 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF16163A), Color(0xFF0A0A18)]),
              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
              border: Border.all(
                color: (_focused && useFocus) || _pressed
                    ? item.color
                    : item.color.withValues(alpha: 0.15),
                width: (_focused && useFocus) || _pressed ? 2 : 0.5,
              ),
              boxShadow: [
                ...NeoTheme.shadowLevel2,
                if (_focused && useFocus)
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: NeoTheme.durationFast,
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: _pressed ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: item.color.withValues(alpha: 0.2), width: 0.5),
                  ),
                  child: Icon(item.icon, color: item.color, size: isTV ? 28 : 24),
                ),
                SizedBox(width: isTV ? 16 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Neo.titleMedium(context),
                      ),
                      SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Neo.bodySmall(context),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Neo.textDisabled(context),
                  size: isTV ? 28 : 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteTile extends StatefulWidget {
  final Content content;
  final VoidCallback onTap;

  _FavoriteTile({required this.content, required this.onTap});

  @override
  State<_FavoriteTile> createState() => _FavoriteTileState();
}

class _FavoriteTileState extends State<_FavoriteTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.82 : 1.0,
          duration: Duration(milliseconds: 100),
          child: Container(
            decoration: BoxDecoration(
              gradient: Neo.surfaceGradient,
              borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
              border: Border.all(
                color: _pressed
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                    : Neo.bgBorder(context).withValues(alpha: 0.15),
                width: 0.5,
              ),
              boxShadow: NeoTheme.shadowLevel1,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: widget.content.fullPosterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.content.fullPosterUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_1, _2) => Container(color: Neo.bgElevated(context)),
                          errorWidget: (_1, _2, _3) => Container(
                            color: Neo.bgElevated(context),
                            child: Icon(Icons.movie_rounded, color: Neo.textDisabled(context)),
                          ),
                        )
                      : Container(
                          color: Neo.bgElevated(context),
                          child: Icon(Icons.movie_rounded, color: Neo.textDisabled(context)),
                        ),
                ),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.content.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Neo.labelLarge(context),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.content.typeLabel,
                        style: Neo.labelSmall(context).copyWith(color: Neo.textSecondary(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritesPage extends StatefulWidget {
  final List<Content> favorites;
  final VoidCallback onRefresh;
  final void Function(Content) onTap;

  _FavoritesPage({
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
      backgroundColor: Neo.bgBase(context),
      appBar: AppBar(
        backgroundColor: Neo.bgBase(context),
        title: Text(
          'Tous les favoris',
          style: Neo.headlineMedium(context),
        ),
      ),
      body: _localFavorites.isEmpty
          ? Center(
              child: Text('Aucun favori.', style: Neo.titleLarge(context)),
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
                        color: Neo.bgBase(context).withValues(alpha: 0.82),
                        shape: CircleBorder(),
                        child: IconButton(
                          onPressed: () => _remove(item),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Theme.of(context).colorScheme.primary,
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
