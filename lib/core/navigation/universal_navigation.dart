import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/platform_service.dart';
import 'navigation_service.dart';
import 'tv_safe_navigation.dart';
import 'mobile_navigation_service.dart';
import 'animation_service.dart';

/// Widget universel pour les cartes de contenu qui supporte les deux modes de navigation
class UniversalContentCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final bool autoFocus;
  final EdgeInsets margin;
  final bool enableTVFocus;
  final Color? focusColor;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;

  const UniversalContentCard({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.autoFocus = false,
    this.margin = const EdgeInsets.all(8.0),
    this.enableTVFocus = true,
    this.focusColor,
    this.borderColor,
    this.borderWidth = 2.0,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isTVMode = PlatformService.isTVMode;

    if (isTVMode && enableTVFocus) {
      // Pour le mode TV, on utilise le Focus wrapper avec bordure animée
      return _UniversalFocusAwareCard(
        autoFocus: autoFocus,
        margin: margin,
        focusColor: focusColor,
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      );
    } else {
      // Pour le mode mobile, on utilise un simple GestureDetector avec animation
      return Container(
        margin: margin,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedScale(
            scale: onTap != null ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                borderRadius: borderRadius ?? BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor ?? AppTheme.accentNeon.withOpacity(0.3),
                  width: 1.0,
                ),
              ),
              child: child,
            ),
          ),
        ),
      );
    }
  }
}

/// Widget universel pour la navigation avec support des deux modes
class UniversalNavigationWrapper extends StatelessWidget {
  final Widget child;
  final bool enableTVNavigation;
  final bool enableMobileGestures;
  final List<String> tvInstructions;

  const UniversalNavigationWrapper({
    Key? key,
    required this.child,
    this.enableTVNavigation = true,
    this.enableMobileGestures = true,
    this.tvInstructions = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget result = child;

    if (enableTVNavigation && PlatformService.isTVMode) {
      // Pour le mode TV, on ajoute les raccourcis et actions
      result = Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const _BackIntent(),
          LogicalKeySet(LogicalKeyboardKey.goBack): const _BackIntent(),
        },
        child: Actions(
          actions: {
            // On omet cette action pour l'instant pour éviter l'erreur
            _BackIntent: CallbackAction<_BackIntent>(
              onInvoke: (intent) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                return null;
              },
            ),
          },
          child: result,
        ),
      );
    }

    if (enableMobileGestures && !PlatformService.isTVMode) {
      // Pour le mode mobile, on peut ajouter des gestes ici si nécessaire
      // Pour l'instant, on retourne simplement le widget
    }

    // Ajouter les instructions TV si spécifiées et en mode TV
    if (tvInstructions.isNotEmpty && PlatformService.isTVMode) {
      result = Stack(
        children: [
          result,
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

    return result;
  }
}

/// Widget pour une liste universelle qui supporte les deux modes
class UniversalListView extends StatelessWidget {
  final List<Widget> children;
  final Function(int)? onItemSelected;
  final EdgeInsets padding;
  final bool tvMode;
  final ScrollController? controller;
  final bool enablePullToRefresh;
  final Future<void> Function()? onRefresh;

  const UniversalListView({
    Key? key,
    required this.children,
    this.onItemSelected,
    this.padding = EdgeInsets.zero,
    this.tvMode = false,
    this.controller,
    this.enablePullToRefresh = false,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveTVMode = tvMode || PlatformService.isTVMode;

    // Pour le mode TV et mobile, on utilise une liste standard avec gestion du focus
    Widget listView = ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (context, index) {
        Widget item = children[index];

        if (effectiveTVMode) {
          // Pour le mode TV, on ajoute le support de focus
          item = Focus(
            autofocus: index == 0,
            child: Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () {
                    if (onItemSelected != null) {
                      onItemSelected!(index);
                    }
                  },
                  child: item,
                );
              },
            ),
          );
        } else {
          // Pour le mode mobile, on ajoute simplement le gesture detector
          item = GestureDetector(
            onTap: () {
              if (onItemSelected != null) {
                onItemSelected!(index);
              }
            },
            child: item,
          );
        }

        return item;
      },
    );

    // Ajouter le pull to refresh pour le mode mobile s'il est activé
    if (!effectiveTVMode && enablePullToRefresh && onRefresh != null) {
      listView = RefreshIndicator(
        onRefresh: onRefresh!,
        child: listView,
      );
    }

    return listView;
  }
}

/// Widget pour une grille universelle qui supporte les deux modes
class UniversalGridView extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final List<Widget> children;
  final Function(int)? onItemSelected;
  final EdgeInsets padding;
  final bool tvMode;
  final bool enablePullToRefresh;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;

  const UniversalGridView({
    Key? key,
    required this.crossAxisCount,
    this.childAspectRatio = 0.7,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    required this.children,
    this.onItemSelected,
    this.padding = EdgeInsets.zero,
    this.tvMode = false,
    this.enablePullToRefresh = false,
    this.onRefresh,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveTVMode = tvMode || PlatformService.isTVMode;
    final effectiveCrossAxisCount = effectiveTVMode ? 3 : crossAxisCount;
    final effectiveChildAspectRatio = effectiveTVMode ? 0.65 : childAspectRatio;

    // Pour le mode TV et mobile, on utilise une grille standard avec gestion du focus
    Widget gridView = GridView.builder(
      controller: controller,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: effectiveCrossAxisCount,
        childAspectRatio: effectiveChildAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        Widget item = children[index];

        if (effectiveTVMode) {
          // Pour le mode TV, on ajoute le support de focus
          item = Focus(
            autofocus: index == 0,
            child: Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () {
                    if (onItemSelected != null) {
                      onItemSelected!(index);
                    }
                  },
                  child: item,
                );
              },
            ),
          );
        } else {
          // Pour le mode mobile, on ajoute simplement le gesture detector
          item = GestureDetector(
            onTap: () {
              if (onItemSelected != null) {
                onItemSelected!(index);
              }
            },
            child: item,
          );
        }

        return item;
      },
    );

    // Ajouter le pull to refresh pour le mode mobile s'il est activé
    if (!effectiveTVMode && enablePullToRefresh && onRefresh != null) {
      gridView = RefreshIndicator(
        onRefresh: onRefresh!,
        child: gridView,
      );
    }

    return gridView;
  }
}

// Intent et Actions personnalisés
class _BackIntent extends Intent {
  const _BackIntent();
}

// Widget interne pour gérer l'état de focus du content card universel sans accéder directement à Focus.of(context).hasFocus
class _UniversalFocusAwareCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool autoFocus;
  final EdgeInsets margin;
  final Color? focusColor;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;

  const _UniversalFocusAwareCard({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.autoFocus = false,
    this.margin = const EdgeInsets.all(8.0),
    this.focusColor,
    this.borderColor,
    this.borderWidth = 2.0,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<_UniversalFocusAwareCard> createState() => _UniversalFocusAwareCardState();
}

class _UniversalFocusAwareCardState extends State<_UniversalFocusAwareCard> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _hasFocus = widget.autoFocus;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_hasFocus != _focusNode.hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autoFocus,
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          border: _hasFocus
              ? Border.all(
                  color: widget.borderColor ?? AppTheme.accentNeon,
                  width: widget.borderWidth,
                )
              : null,
          boxShadow: _hasFocus
              ? [
                  BoxShadow(
                    color: (widget.focusColor ?? AppTheme.accentNeon)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
              color: _hasFocus
                  ? AppTheme.accentNeon.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}