import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/tv_config.dart';

typedef TVDpadCallback = void Function(TVDirection direction);

enum TVDirection { up, down, left, right, select, back }

class TVRemoteNavigator extends StatefulWidget {
  final Widget child;
  final TVDpadCallback? onDpad;
  final VoidCallback? onSelect;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final bool enableDpad;
  // Quand false, le nœud racine ne capte pas le focus à l'ouverture : utile
  // pour les écrans dont un champ texte doit garder le focus (ex: recherche),
  // sinon le clavier ne s'ouvre jamais. Les événements D-pad continuent de
  // remonter jusqu'à ce Focus puisqu'il reste ancêtre de l'élément focalisé.
  final bool autofocus;

  const TVRemoteNavigator({
    super.key,
    required this.child,
    this.onDpad,
    this.onSelect,
    this.onBack,
    this.onMenu,
    this.enableDpad = true,
    this.autofocus = true,
  });

  @override
  State<TVRemoteNavigator> createState() => TVRemoteNavigatorState();
}

class TVRemoteNavigatorState extends State<TVRemoteNavigator> {
  final FocusNode _rootFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.autofocus && mounted) {
      _rootFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!widget.enableDpad) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Select/Enter — only handle if callback is set
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (widget.onSelect != null) {
        widget.onSelect!();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Back
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.gameButtonB) {
      if (widget.onBack != null) {
        widget.onBack!();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Menu
    if (key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.gameButtonStart) {
      widget.onMenu?.call();
      return KeyEventResult.handled;
    }

    // Directions
    final direction = _getDirectionFromKey(key);
    if (direction != null) {
      widget.onDpad?.call(direction);
      return KeyEventResult.ignored; // Laisser Flutter gérer la traversal
    }

    return KeyEventResult.ignored;
  }

  TVDirection? _getDirectionFromKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return TVDirection.up;
    if (key == LogicalKeyboardKey.arrowDown) return TVDirection.down;
    if (key == LogicalKeyboardKey.arrowLeft) return TVDirection.left;
    if (key == LogicalKeyboardKey.arrowRight) return TVDirection.right;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Focus(
        focusNode: _rootFocusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: widget.autofocus,
        child: widget.child,
      ),
    );
  }
}

class TVGridNavigator extends StatefulWidget {
  final int crossAxisCount;
  final int itemCount;
  final int focusedIndex;
  final ValueChanged<int>? onIndexChanged;
  final Widget Function(BuildContext context, int index, bool isFocused) itemBuilder;
  final EdgeInsets padding;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const TVGridNavigator({
    super.key,
    required this.crossAxisCount,
    required this.itemCount,
    required this.focusedIndex,
    this.onIndexChanged,
    required this.itemBuilder,
    this.padding = TVConfig.screenPadding,
    this.mainAxisSpacing = TVConfig.gridSpacing,
    this.crossAxisSpacing = TVConfig.gridSpacing,
  });

  @override
  State<TVGridNavigator> createState() => TVGridNavigatorState();
}

class TVGridNavigatorState extends State<TVGridNavigator> {
  late int _currentIndex;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.focusedIndex;
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleDpad(TVDirection direction) {
    int newIndex = _currentIndex;

    switch (direction) {
      case TVDirection.up:
        newIndex = _currentIndex - widget.crossAxisCount;
        break;
      case TVDirection.down:
        newIndex = _currentIndex + widget.crossAxisCount;
        break;
      case TVDirection.left:
        newIndex = _currentIndex - 1;
        break;
      case TVDirection.right:
        newIndex = _currentIndex + 1;
        break;
      default:
        break;
    }

    if (newIndex >= 0 && newIndex < widget.itemCount) {
      setState(() => _currentIndex = newIndex);
      widget.onIndexChanged?.call(newIndex);
      _ensureVisible(newIndex);
    }
  }

  void _ensureVisible(int index) {
    if (!_scrollController.hasClients) return;
    final row = index ~/ widget.crossAxisCount;
    final position = row * (180 + widget.mainAxisSpacing);
    _scrollController.animateTo(
      position.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TVRemoteNavigator(
      onDpad: _handleDpad,
      child: ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        itemCount: widget.itemCount,
        itemBuilder: (context, index) {
          final isFocused = index == _currentIndex;
          return widget.itemBuilder(context, index, isFocused);
        },
      ),
    );
  }
}