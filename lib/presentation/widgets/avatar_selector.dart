import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/avatar.dart';
import '../../data/services/avatar_service.dart';

class AvatarSelector extends StatefulWidget {
  final Avatar? selectedAvatar;
  final Function(Avatar) onAvatarSelected;
  final bool showCategories;
  final int crossAxisCount;

  const AvatarSelector({
    Key? key,
    this.selectedAvatar,
    required this.onAvatarSelected,
    this.showCategories = true,
    this.crossAxisCount = 3,
  }) : super(key: key);

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  String _selectedCategory = 'Tous';
  List<Avatar> _filteredAvatars = [];
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  void _loadAvatars() {
    final allAvatars = AvatarService.getAllAvatars();
    final categories = AvatarService.getCategories();
    
    setState(() {
      _filteredAvatars = allAvatars;
      _categories = ['Tous', ...categories];
    });
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'Tous') {
        _filteredAvatars = AvatarService.getAllAvatars();
      } else {
        _filteredAvatars = AvatarService.getAvatarsByCategory(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showCategories) ...[
          _buildCategoryFilter(),
          const SizedBox(height: 16),
        ],
        _buildAvatarGrid(),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => _filterByCategory(category),
              backgroundColor: AppColors.cyberGray,
              selectedColor: AppColors.neonBlue,
              checkmarkColor: AppColors.cyberBlack,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.cyberBlack : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _filteredAvatars.length,
      itemBuilder: (context, index) {
        final avatar = _filteredAvatars[index];
        final isSelected = widget.selectedAvatar?.id == avatar.id;
        
        return _buildAvatarItem(avatar, isSelected);
      },
    );
  }

  Widget _buildAvatarItem(Avatar avatar, bool isSelected) {
    return GestureDetector(
      onTap: () => widget.onAvatarSelected(avatar),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.cyberGray,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.neonBlue.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Avatar Image
              Positioned.fill(
                child: Container(
                  color: AppColors.cyberGray,
                  child: Image.asset(
                    avatar.fullImagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.cyberGray,
                        child: Icon(
                          Icons.person,
                          color: AppColors.textSecondary,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              // Selection Overlay
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: AppColors.neonBlue,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              
              // Avatar Name
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Text(
                    avatar.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget pour afficher un avatar simple
class AvatarDisplay extends StatelessWidget {
  final Avatar avatar;
  final double size;
  final bool showBorder;
  final VoidCallback? onTap;

  const AvatarDisplay({
    Key? key,
    required this.avatar,
    this.size = 60,
    this.showBorder = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(
                  color: AppColors.neonBlue,
                  width: 2,
                )
              : null,
          boxShadow: showBorder
              ? [
                  BoxShadow(
                    color: AppColors.neonBlue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: Image.asset(
            avatar.fullImagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.cyberGray,
                child: Icon(
                  Icons.person,
                  color: AppColors.textSecondary,
                  size: size * 0.6,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}