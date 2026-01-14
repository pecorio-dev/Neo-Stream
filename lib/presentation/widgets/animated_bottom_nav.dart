import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

class AnimatedBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const AnimatedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<AnimatedBottomNav>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late List<AnimationController> _itemControllers;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _itemControllers = List.generate(
      widget.items.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    // Animate current item
    _itemControllers[widget.currentIndex].forward();
  }

  @override
  void didUpdateWidget(AnimatedBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // Animate out old item
      _itemControllers[oldWidget.currentIndex].reverse();
      // Animate in new item
      _itemControllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: _buildBackgroundDecoration(),
      child: SafeArea(
        child: Row(
          children: widget.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = index == widget.currentIndex;

            return Expanded(
              child: _buildNavItem(item, index, isSelected),
            );
          }).toList(),
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.cyberDark.withOpacity(0.95),
          AppColors.cyberBlack,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.neonBlue.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, -5),
        ),
        BoxShadow(
          color: AppColors.cyberBlack.withOpacity(0.8),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  Widget _buildNavItem(BottomNavItem item, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => widget.onTap(index),
      child: AnimatedBuilder(
        animation: _itemControllers[index],
        builder: (context, child) {
          final animationValue = _itemControllers[index].value;
          
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container with glow effect
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? item.color.withOpacity(0.1 + (animationValue * 0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(
                            color: item.color.withOpacity(0.3 + (animationValue * 0.4)),
                            width: 1 + animationValue,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: item.color.withOpacity(0.2 + (animationValue * 0.3)),
                              blurRadius: 8 + (animationValue * 12),
                              spreadRadius: animationValue * 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        key: ValueKey(isSelected),
                        color: isSelected 
                            ? item.color
                            : AppColors.textTertiary,
                        size: 24 + (animationValue * 4),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Label
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isSelected 
                        ? item.color
                        : AppColors.textTertiary,
                    fontSize: 11 + (animationValue * 1),
                    fontWeight: isSelected 
                        ? FontWeight.bold 
                        : FontWeight.normal,
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Active indicator
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 20 + (animationValue * 10),
                    height: 2,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withOpacity(0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ).animate(
                    effects: [
                      const ScaleEffect(
                        duration: Duration(milliseconds: 300),
                        begin: Offset(0.5, 1.0),
                        end: Offset(1.0, 1.0),
                      ),
                      const FadeEffect(
                        duration: Duration(milliseconds: 300),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

// Predefined nav items for NEO STREAM
class NeoStreamNavItems {
  static const List<BottomNavItem> items = [
    BottomNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Accueil',
      color: AppColors.neonBlue,
    ),
    BottomNavItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: 'Recherche',
      color: AppColors.neonPurple,
    ),
    BottomNavItem(
      icon: Icons.favorite_border,
      activeIcon: Icons.favorite,
      label: 'Favoris',
      color: AppColors.neonPink,
    ),
    BottomNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profil',
      color: AppColors.neonGreen,
    ),
  ];
}