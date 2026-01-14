import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'navigation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/platform_service.dart';
import '../../core/tv/tv_navigation_service.dart';

/// Widget centralisé pour la navigation avec support TV et mobile
class GlobalNavigationWrapper extends StatelessWidget {
  final Widget child;
  final String? initialRoute;
  final Map<String, WidgetBuilder>? routes;
  final RouteFactory? onGenerateRoute;
  final RouteFactory? onUnknownRoute;

  const GlobalNavigationWrapper({
    Key? key,
    required this.child,
    this.initialRoute,
    this.routes,
    this.onGenerateRoute,
    this.onUnknownRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TVSafeNavigator(
      child: child,
    );
  }
}

/// Widget pour la navigation avec support TV
class TVSafeScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;
  final List<Widget>? persistentFooterButtons;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool primary;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final String? restorationId;
  final bool tvMode;
  final List<String> tvInstructions;
  final ScrollController? scrollController;

  const TVSafeScaffold({
    Key? key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.restorationId,
    this.tvMode = false,
    this.tvInstructions = const [],
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget scaffold = Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      persistentFooterButtons: persistentFooterButtons,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: primary,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      restorationId: restorationId,
    );

    // Si on est en mode TV, on ajoute les raccourcis et actions appropriés
    if (tvMode || PlatformService.isTVMode) {
      scaffold = Shortcuts(
        shortcuts: {
          ...TVNavigationService.getTVShortcuts(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
        },
        child: Actions(
          actions: {
            ...TVNavigationService.getTVActions(context),
          },
          child: scaffold,
        ),
      );
    }

    // Ajouter les instructions TV si fournies
    if (tvInstructions.isNotEmpty) {
      scaffold = Stack(
        children: [
          scaffold,
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundPrimary.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.accentNeon.withOpacity(0.3),
                ),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: tvInstructions.map((instruction) {
                  final parts = instruction.split(':');
                  if (parts.length == 2) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentNeon.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            parts[0].trim(),
                            style: const TextStyle(
                              color: AppTheme.accentNeon,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          parts[1].trim(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  }
                  return Text(
                    instruction,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    }

    return scaffold;
  }
}

/// Widget pour la navigation avec support de la grille pour TV
class TVSafeGridView extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final List<Widget> children;
  final Function(int)? onItemSelected;
  final EdgeInsets padding;
  final bool tvMode;

  const TVSafeGridView({
    Key? key,
    required this.crossAxisCount,
    this.childAspectRatio = 0.7,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    required this.children,
    this.onItemSelected,
    this.padding = EdgeInsets.zero,
    this.tvMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveTVMode = tvMode || PlatformService.isTVMode;
    final effectiveCrossAxisCount = effectiveTVMode ? 3 : crossAxisCount;
    final effectiveChildAspectRatio = effectiveTVMode ? 0.65 : childAspectRatio;

    if (effectiveTVMode) {
      // Pour le mode TV, on utilise une grille avec focus et navigation
      return Padding(
        padding: padding,
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: effectiveCrossAxisCount,
            childAspectRatio: effectiveChildAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) {
            return Focus(
              autofocus: index == 0,
              child: Builder(
                builder: (context) {
                  return GestureDetector(
                    onTap: () {
                      if (onItemSelected != null) {
                        onItemSelected!(index);
                      }
                    },
                    child: children[index],
                  );
                },
              ),
            );
          },
        ),
      );
    } else {
      // Pour le mode mobile, on utilise une grille standard
      return Padding(
        padding: padding,
        child: GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
          ),
          children: children,
        ),
      );
    }
  }
}

/// Widget pour la navigation avec support de la liste pour TV
class TVSafeListView extends StatelessWidget {
  final List<Widget> children;
  final Function(int)? onItemSelected;
  final EdgeInsets padding;
  final bool tvMode;
  final ScrollController? controller;

  const TVSafeListView({
    Key? key,
    required this.children,
    this.onItemSelected,
    this.padding = EdgeInsets.zero,
    this.tvMode = false,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveTVMode = tvMode || PlatformService.isTVMode;

    if (effectiveTVMode) {
      // Pour le mode TV, on utilise une liste avec focus et navigation
      return Padding(
        padding: padding,
        child: ListView.builder(
          controller: controller,
          itemCount: children.length,
          itemBuilder: (context, index) {
            return Focus(
              autofocus: index == 0,
              child: Builder(
                builder: (context) {
                  return GestureDetector(
                    onTap: () {
                      if (onItemSelected != null) {
                        onItemSelected!(index);
                      }
                    },
                    child: children[index],
                  );
                },
              ),
            );
          },
        ),
      );
    } else {
      // Pour le mode mobile, on utilise une liste standard
      return Padding(
        padding: padding,
        child: ListView(
          controller: controller,
          children: children,
        ),
      );
    }
  }
}