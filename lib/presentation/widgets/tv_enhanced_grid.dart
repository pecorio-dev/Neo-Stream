import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/platform_service.dart';
import '../../core/theme/app_theme.dart';

/// Grille avancée optimisée pour la navigation TV
class TVEnhancedGrid extends StatefulWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsets? padding;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Function(int)? onItemFocused;
  final Function(int)? onItemSelected;

  const TVEnhancedGrid({
    Key? key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.childAspectRatio = 0.7,
    this.padding,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.onItemFocused,
    this.onItemSelected,
  }) : super(key: key);

  @override
  State<TVEnhancedGrid> createState() => _TVEnhancedGridState();
}

class _TVEnhancedGridState extends State<TVEnhancedGrid> {
  late ScrollController _scrollController;
  final List<FocusNode> _focusNodes = [];
  int _currentFocusIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _createFocusNodes();
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _createFocusNodes() {
    _focusNodes.clear();
    for (int i = 0; i < widget.children.length; i++) {
      final focusNode = FocusNode();
      focusNode.addListener(() => _onFocusChanged(i, focusNode));
      _focusNodes.add(focusNode);
    }
  }

  void _onFocusChanged(int index, FocusNode focusNode) {
    if (focusNode.hasFocus) {
      setState(() {
        _currentFocusIndex = index;
      });
      _ensureVisible(index);
      widget.onItemFocused?.call(index);
      
      // Feedback haptique pour la navigation TV
      HapticFeedback.selectionClick();
    }
  }

  void _ensureVisible(int index) {
    if (!_scrollController.hasClients) return;

    final row = index ~/ widget.crossAxisCount;
    final screenHeight = MediaQuery.of(context).size.height;
    final itemHeight = (screenHeight * 0.3); // Estimation basée sur l'aspect ratio
    final targetOffset = row * (itemHeight + widget.mainAxisSpacing);
    
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;
    
    // Scroll avec animation fluide
    if (targetOffset < currentOffset) {
      // Scroll vers le haut
      _scrollController.animateTo(
        targetOffset - 50, // Petit offset pour voir l'élément précédent
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      // Scroll vers le bas
      _scrollController.animateTo(
        targetOffset + itemHeight - viewportHeight + 50,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.length != _focusNodes.length) {
      _createFocusNodes();
    }

    // Mode TV : Grille avec navigation focalisée
    if (PlatformService.isTVMode) {
      return _buildTVGrid();
    }

    // Mode Mobile : Grille classique
    return GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        childAspectRatio: widget.childAspectRatio,
      ),
      itemCount: widget.children.length,
      itemBuilder: (context, index) => widget.children[index],
    );
  }

  Widget _buildTVGrid() {
    return Shortcuts(
      shortcuts: _getTVGridShortcuts(),
      child: Actions(
        actions: _getTVGridActions(),
        child: GridView.builder(
          controller: _scrollController,
          padding: widget.padding ?? const EdgeInsets.all(16),
          shrinkWrap: widget.shrinkWrap,
          physics: widget.physics,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            mainAxisSpacing: widget.mainAxisSpacing,
            crossAxisSpacing: widget.crossAxisSpacing,
            childAspectRatio: widget.childAspectRatio,
          ),
          itemCount: widget.children.length,
          itemBuilder: (context, index) {
            return _buildTVGridItem(index);
          },
        ),
      ),
    );
  }

  Widget _buildTVGridItem(int index) {
    return Focus(
      focusNode: _focusNodes[index],
      autofocus: index == 0,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onItemSelected?.call(index);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: _TVFocusAwareItem(
        focusNode: _focusNodes[index],
        child: widget.children[index],
      ),
    );
  }

  Map<LogicalKeySet, Intent> _getTVGridShortcuts() {
    return {
      LogicalKeySet(LogicalKeyboardKey.arrowUp): _GridNavigateIntent(GridDirection.up),
      LogicalKeySet(LogicalKeyboardKey.arrowDown): _GridNavigateIntent(GridDirection.down),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft): _GridNavigateIntent(GridDirection.left),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): _GridNavigateIntent(GridDirection.right),
    };
  }

  Map<Type, Action<Intent>> _getTVGridActions() {
    return {
      _GridNavigateIntent: CallbackAction<_GridNavigateIntent>(
        onInvoke: (intent) {
          _navigateGrid(intent.direction);
          return null;
        },
      ),
    };
  }

  void _navigateGrid(GridDirection direction) {
    int newIndex = _currentFocusIndex;
    
    switch (direction) {
      case GridDirection.up:
        newIndex = _currentFocusIndex - widget.crossAxisCount;
        break;
      case GridDirection.down:
        newIndex = _currentFocusIndex + widget.crossAxisCount;
        break;
      case GridDirection.left:
        if (_currentFocusIndex % widget.crossAxisCount > 0) {
          newIndex = _currentFocusIndex - 1;
        }
        break;
      case GridDirection.right:
        if (_currentFocusIndex % widget.crossAxisCount < widget.crossAxisCount - 1) {
          newIndex = _currentFocusIndex + 1;
        }
        break;
    }

    // Vérifier les limites
    if (newIndex >= 0 && newIndex < widget.children.length) {
      _focusNodes[newIndex].requestFocus();
    }
  }
}

/// Widget de grille TV pour les Slivers
class TVEnhancedSliverGrid extends StatefulWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final Function(int)? onItemFocused;
  final Function(int)? onItemSelected;

  const TVEnhancedSliverGrid({
    Key? key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.childAspectRatio = 0.7,
    this.onItemFocused,
    this.onItemSelected,
  }) : super(key: key);

  @override
  State<TVEnhancedSliverGrid> createState() => _TVEnhancedSliverGridState();
}

class _TVEnhancedSliverGridState extends State<TVEnhancedSliverGrid> {
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _createFocusNodes();
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _createFocusNodes() {
    _focusNodes.clear();
    for (int i = 0; i < widget.children.length; i++) {
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          widget.onItemFocused?.call(i);
          HapticFeedback.selectionClick();
        }
      });
      _focusNodes.add(focusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.length != _focusNodes.length) {
      _createFocusNodes();
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        childAspectRatio: widget.childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (PlatformService.isTVMode) {
            return _buildTVSliverItem(index);
          }
          return widget.children[index];
        },
        childCount: widget.children.length,
      ),
    );
  }

  Widget _buildTVSliverItem(int index) {
    return Focus(
      focusNode: _focusNodes[index],
      autofocus: index == 0,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onItemSelected?.call(index);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: _TVFocusAwareItem(
        focusNode: _focusNodes[index],
        child: widget.children[index],
      ),
    );
  }
}

// Intents et enums pour la navigation
enum GridDirection { up, down, left, right }

class _GridNavigateIntent extends Intent {
  final GridDirection direction;

  const _GridNavigateIntent(this.direction);
}

// Widget interne pour gérer l'état de focus sans accéder directement à Focus.of(context).hasFocus
class _TVFocusAwareItem extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;

  const _TVFocusAwareItem({
    Key? key,
    required this.focusNode,
    required this.child,
  }) : super(key: key);

  @override
  State<_TVFocusAwareItem> createState() => _TVFocusAwareItemState();
}

class _TVFocusAwareItemState extends State<_TVFocusAwareItem> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused != widget.focusNode.hasFocus) {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      transform: Matrix4.identity()
        ..scale(_isFocused ? 1.05 : 1.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: _isFocused
            ? Border.all(
                color: AppTheme.accentNeon,
                width: 3,
              )
            : null,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppTheme.accentNeon.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppTheme.accentNeon.withOpacity(0.2),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: widget.child,
      ),
    );
  }
}