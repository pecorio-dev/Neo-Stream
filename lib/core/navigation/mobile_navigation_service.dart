import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Service pour la navigation mobile avec gestes tactiles
class MobileNavigationService {
  /// Geste de glissement depuis le bord pour naviguer en arrière
  static bool isSwipeToPopEnabled = true;

  /// Geste de glissement vertical pour fermer un écran modal
  static bool isVerticalSwipeToDismissEnabled = true;

  /// Geste de double tap pour rafraîchir
  static bool isDoubleTapToRefreshEnabled = true;

  /// Gestion des raccourcis clavier pour mobile (si nécessaire)
  static Map<LogicalKeySet, Intent> getMobileShortcuts() {
    return {
      // Raccourcis pour les tests ou les utilisateurs avancés
      LogicalKeySet(LogicalKeyboardKey.escape): const MobileBackIntent(),
      LogicalKeySet(LogicalKeyboardKey.backspace): const MobileBackIntent(),
    };
  }

  /// Actions pour les raccourcis mobile
  static Map<Type, Action<Intent>> getMobileActions(BuildContext context) {
    return {
      MobileBackIntent: MobileBackAction(context),
    };
  }
}

/// Intent personnalisé pour la navigation mobile
class MobileBackIntent extends Intent {
  const MobileBackIntent();
}

/// Action pour la navigation mobile
class MobileBackAction extends Action<MobileBackIntent> {
  final BuildContext context;

  MobileBackAction(this.context);

  @override
  Object? invoke(MobileBackIntent intent) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return null;
  }
}

/// Widget pour la navigation mobile avec gestes
class MobileGesturesWrapper extends StatelessWidget {
  final Widget child;
  final bool enableSwipeToPop;
  final bool enableVerticalSwipeToDismiss;
  final bool enableDoubleTapToRefresh;
  final VoidCallback? onSwipeToPop;
  final VoidCallback? onVerticalSwipeToDismiss;
  final VoidCallback? onDoubleTapToRefresh;

  const MobileGesturesWrapper({
    Key? key,
    required this.child,
    this.enableSwipeToPop = true,
    this.enableVerticalSwipeToDismiss = true,
    this.enableDoubleTapToRefresh = true,
    this.onSwipeToPop,
    this.onVerticalSwipeToDismiss,
    this.onDoubleTapToRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget result = child;

    if (enableSwipeToPop) {
      result = _buildSwipeToPopWrapper(context, result);
    }

    if (enableVerticalSwipeToDismiss) {
      result = _buildVerticalSwipeToDismissWrapper(context, result);
    }

    return result;
  }

  Widget _buildSwipeToPopWrapper(BuildContext context, Widget child) {
    return WillPopScope(
      onWillPop: () async {
        // Gérer le comportement de retour personnalisé
        return true;
      },
      child: child,
    );
  }

  Widget _buildVerticalSwipeToDismissWrapper(BuildContext context, Widget child) {
    return child; // Pour l'instant, on ne met pas en place le swipe vertical car cela nécessite une logique complexe
  }
}

/// Widget pour le swipe à gauche pour revenir en arrière (iOS-style)
class SwipeBackGestureDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSwipeBack;
  final bool enabled;

  const SwipeBackGestureDetector({
    Key? key,
    required this.child,
    this.onSwipeBack,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return GestureDetector(
      onPanUpdate: (details) {
        if (details.delta.dx > 10) { // Seuil de détection du swipe
          if (onSwipeBack != null) {
            onSwipeBack!();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
      child: child,
    );
  }
}

/// Widget pour la navigation avec des transitions améliorées pour mobile
class MobileAnimatedNavigation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const MobileAnimatedNavigation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  }) : super(key: key);

  @override
  State<MobileAnimatedNavigation> createState() => _MobileAnimatedNavigationState();
}

class _MobileAnimatedNavigationState extends State<MobileAnimatedNavigation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.curve,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.curve,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Widget pour une page mobile avec gestes tactiles améliorés
class MobilePageScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? persistentFooterButtons;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool primary;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final String? restorationId;
  final ScrollController? scrollController;
  final bool enablePullToRefresh;
  final Future<void> Function()? onRefresh;
  final bool enableSwipeBack;

  const MobilePageScaffold({
    Key? key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.primary = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.restorationId,
    this.scrollController,
    this.enablePullToRefresh = false,
    this.onRefresh,
    this.enableSwipeBack = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget content = Scaffold(
      appBar: appBar,
      body: enablePullToRefresh && onRefresh != null
          ? RefreshIndicator(
              onRefresh: () async => await onRefresh!(),
              child: body!,
            )
          : body ?? Container(),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      persistentFooterButtons: persistentFooterButtons,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      primary: primary,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      restorationId: restorationId,
    );

    // Ajouter le swipe pour revenir en arrière si activé
    if (enableSwipeBack) {
      content = SwipeBackGestureDetector(
        onSwipeBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        child: content,
      );
    }

    return content;
  }
}

/// Widget pour une grille mobile avec gestes améliorés
class MobileGridView extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final List<Widget> children;
  final Function(int)? onItemSelected;
  final EdgeInsets padding;
  final bool enablePullToRefresh;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;

  const MobileGridView({
    Key? key,
    required this.crossAxisCount,
    this.childAspectRatio = 0.7,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    required this.children,
    this.onItemSelected,
    this.padding = EdgeInsets.zero,
    this.enablePullToRefresh = false,
    this.onRefresh,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget grid = GridView(
      controller: controller,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      children: children
          .asMap()
          .entries
          .map((entry) => GestureDetector(
                onTap: () {
                  if (onItemSelected != null) {
                    onItemSelected!(entry.key);
                  }
                },
                child: entry.value,
              ))
          .toList(),
    );

    if (enablePullToRefresh && onRefresh != null) {
      grid = RefreshIndicator(
        onRefresh: onRefresh!,
        child: grid,
      );
    }

    return Padding(
      padding: padding,
      child: grid,
    );
  }
}