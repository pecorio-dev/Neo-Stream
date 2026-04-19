import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/tv_config.dart';
import 'tv_remote_navigator.dart';
import 'tv_focusable_card.dart' show TVScrollPhysics;

class TVWrapper extends StatefulWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final VoidCallback? onBack;
  final TVDpadCallback? onDpad;
  final VoidCallback? onSelect;
  final bool enableDpad;

  const TVWrapper({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = false,
    this.onBack,
    this.onDpad,
    this.onSelect,
    this.enableDpad = true,
  });

  @override
  State<TVWrapper> createState() => _TVWrapperState();
}

class _TVWrapperState extends State<TVWrapper> {
  final FocusNode _screenFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _screenFocusNode.dispose();
    super.dispose();
  }

  void _defaultBackHandler() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TVRemoteNavigator(
      enableDpad: widget.enableDpad,
      onDpad: widget.onDpad,
      onSelect: widget.onSelect,
      onBack: widget.onBack ?? _defaultBackHandler,
      child: Scaffold(
        backgroundColor: TVTheme.backgroundDark,
        body: Container(
          decoration: TVTheme.screenDecoration,
          child: Column(
            children: [
              if (widget.title != null || widget.showBackButton || widget.actions != null)
                _buildHeader(),
              Expanded(child: widget.child),
            ],
          ),
        ),
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TVTheme.backgroundDark,
            TVTheme.backgroundDark.withValues(alpha: 0.9),
            TVTheme.backgroundDark.withValues(alpha: 0.7),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (widget.showBackButton)
              TVHeaderButton(
                icon: Icons.arrow_back,
                label: 'Retour',
                onTap: widget.onBack ?? _defaultBackHandler,
              )
            else if (widget.title == null)
              const SizedBox.shrink(),
            if (widget.title != null) ...[
              if (widget.showBackButton) const SizedBox(width: 16),
              Text(
                widget.title!,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: TVTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            if (widget.actions != null) ...widget.actions!,
          ],
        ),
      ),
    );
  }
}

class TVHeaderButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool isDestructive;

  const TVHeaderButton({
    super.key,
    required this.icon,
    this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<TVHeaderButton> createState() => _TVHeaderButtonState();
}

class _TVHeaderButtonState extends State<TVHeaderButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? TVTheme.errorRed : TVTheme.accentRed;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: TVConfig.focusAnimationDuration,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isFocused ? color.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isFocused ? color : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: _isFocused ? color : TVTheme.textSecondary,
                  size: 18,
                ),
                if (widget.label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.label!,
                    style: TextStyle(
                      color: _isFocused ? color : TVTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TVScreen extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool showHeader;
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? headerActions;

  const TVScreen({
    super.key,
    required this.child,
    this.padding = TVConfig.screenPadding,
    this.showHeader = false,
    this.title,
    this.showBackButton = false,
    this.onBack,
    this.headerActions,
  });

  @override
  Widget build(BuildContext context) {
    return TVWrapper(
      title: showHeader ? title : null,
      showBackButton: showBackButton,
      onBack: onBack,
      actions: headerActions,
      child: SingleChildScrollView(
        padding: padding,
        physics: TVScrollPhysics(),
        child: child,
      ),
    );
  }
}

class TVGridView extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets padding;
  final double childAspectRatio;

  const TVGridView({
    super.key,
    required this.children,
    this.crossAxisCount = 4,
    this.mainAxisSpacing = 24,
    this.crossAxisSpacing = 24,
    this.padding = TVConfig.screenPadding,
    this.childAspectRatio = TVConfig.cardAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: TVScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

class TVDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;

  const TVDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TVTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: TVTheme.defaultBorderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: TVTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              content,
              if (actions != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!
                      .map((action) => Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: action,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
