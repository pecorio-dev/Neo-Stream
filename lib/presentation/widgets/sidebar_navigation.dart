import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/platform_service.dart';

class SidebarNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final bool isVisible;

  const SidebarNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTabTapped,
    this.isVisible = true,
  }) : super(key: key);

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> with TickerProviderStateMixin {
  final List<FocusNode> _navFocusNodes = List.generate(5, (index) => FocusNode());

  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.movie, 'label': 'Films', 'index': 0},
    {'icon': Icons.search, 'label': 'Recherche', 'index': 1},
    {'icon': Icons.tv, 'label': 'Séries', 'index': 2},
    {'icon': Icons.favorite, 'label': 'Favoris', 'index': 3},
    {'icon': Icons.person, 'label': 'Profil', 'index': 4},
  ];

  @override
  void initState() {
    super.initState();
    
    // Request focus on the current item after a delay to ensure it's rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PlatformService.isTVMode && _navFocusNodes.length > widget.currentIndex) {
        _navFocusNodes[widget.currentIndex].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final node in _navFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformService.isTVMode) {
      return const SizedBox.shrink(); // Only show on TV mode
    }

    return AnimatedOpacity(
      opacity: widget.isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppTheme.backgroundSecondary.withOpacity(0.95),
              AppTheme.backgroundPrimary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentNeon.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(3, 0),
            ),
          ],
          border: Border(
            right: BorderSide(
              color: AppTheme.accentNeon.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                // App logo/title placeholder
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Icon(
                    Icons.live_tv,
                    color: AppTheme.accentNeon,
                    size: 32,
                  ),
                ),

                // Navigation items and additional TV controls in a scrollable view
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Navigation items
                        ...List.generate(_navItems.length, (index) {
                          return _buildNavItem(
                            icon: _navItems[index]['icon'] as IconData,
                            label: _navItems[index]['label'] as String,
                            index: _navItems[index]['index'] as int,
                            isSelected: widget.currentIndex == index,
                          );
                        }),

                        // Additional TV controls
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.settings,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => Navigator.pushNamed(context, '/settings'),
                              ),
                              const SizedBox(height: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.info,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return Focus(
      focusNode: _navFocusNodes[index],
      onKeyEvent: (node, event) {
        if (PlatformService.isTVMode && event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTabTapped(index);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: _SidebarNavItem(
        focusNode: _navFocusNodes[index],
        isSelected: isSelected,
        onTabTapped: widget.onTabTapped,
        icon: icon,
        label: label,
        index: index,
      ),
    );
  }
}

// Widget interne pour gérer l'état de focus du sidebar navigation sans accéder directement à Focus.of(context).hasFocus
class _SidebarNavItem extends StatefulWidget {
  final FocusNode focusNode;
  final bool isSelected;
  final Function(int) onTabTapped;
  final IconData icon;
  final String label;
  final int index; // Add index to pass to the callback

  const _SidebarNavItem({
    Key? key,
    required this.focusNode,
    required this.isSelected,
    required this.onTabTapped,
    required this.icon,
    required this.label,
    required this.index,
  }) : super(key: key);

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
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
    final effectiveSelected = widget.isSelected || _isFocused;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: effectiveSelected
            ? AppTheme.accentNeon.withOpacity(0.2)
            : (_isFocused ? AppTheme.accentNeon.withOpacity(0.1) : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: _isFocused
            ? Border.all(
                color: AppTheme.accentNeon,
                width: 2,
              )
            : effectiveSelected
                ? Border.all(
                    color: AppTheme.accentNeon.withOpacity(0.5),
                    width: 1,
                  )
                : null,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppTheme.accentNeon.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTabTapped(widget.index), // Pass the index correctly
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _isFocused ? 1.1 : (effectiveSelected ? 1.05 : 1.0),
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.icon,
                    size: 24,
                    color: effectiveSelected
                        ? AppTheme.accentNeon
                        : (_isFocused ? AppTheme.accentNeon : AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label.substring(0, 1), // Show only first letter for compact sidebar
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: effectiveSelected ? FontWeight.w600 : FontWeight.w400,
                    color: effectiveSelected
                        ? AppTheme.accentNeon
                        : (_isFocused ? AppTheme.accentNeon : AppTheme.textSecondary),
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