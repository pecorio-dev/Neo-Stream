import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class SearchBarWidget extends StatefulWidget {
  final String? initialQuery;
  final String hintText;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onFilterTap;
  final bool showFilter;
  final bool autofocus;
  final List<String> suggestions;
  final Function(String)? onSuggestionTap;

  const SearchBarWidget({
    Key? key,
    this.initialQuery,
    this.hintText = 'Rechercher films, séries...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onFilterTap,
    this.showFilter = true,
    this.autofocus = false,
    this.suggestions = const [],
    this.onSuggestionTap,
  }) : super(key: key);

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  bool _showSuggestions = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();
    
    _animationController = AnimationController(
      duration: AppConstants.shortAnimation,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _animationController.forward();
      if (widget.suggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      }
    } else {
      _animationController.reverse();
      _removeOverlay();
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildSuggestionsOverlay(),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showSuggestions = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      _showSuggestions = false;
    }
  }

  Widget _buildSuggestionsOverlay() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return Positioned(
      left: offset.dx,
      top: offset.dy + size.height + 4,
      width: size.width,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.accentNeon.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = widget.suggestions[index];
              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.search,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                title: Text(
                  suggestion,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  _controller.text = suggestion;
                  widget.onSuggestionTap?.call(suggestion);
                  _removeOverlay();
                  _focusNode.unfocus();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _focusNode.hasFocus 
                ? AppTheme.neonShadow 
                : AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Expanded(child: _buildSearchField()),
                if (widget.showFilter) _buildFilterButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: _focusNode.hasFocus
            ? Border.all(color: AppTheme.accentNeon, width: 2)
            : null,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppTheme.textSecondary,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onClear?.call();
                    _removeOverlay();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          setState(() {}); // Pour mettre à jour le bouton clear
          widget.onChanged?.call(value);
          
          if (value.isNotEmpty && widget.suggestions.isNotEmpty) {
            _showSuggestionsOverlay();
          } else {
            _removeOverlay();
          }
        },
        onSubmitted: (value) {
          widget.onSubmitted?.call(value);
          _removeOverlay();
          _focusNode.unfocus();
        },
      ),
    );
  }

  Widget _buildFilterButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentNeon.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: const Icon(
            Icons.tune,
            color: AppTheme.accentNeon,
          ),
          onPressed: widget.onFilterTap,
          tooltip: 'Filtres avancés',
        ),
      ),
    );
  }
}

// Widget pour les filtres rapides
class QuickFilters extends StatelessWidget {
  final List<String> selectedFilters;
  final List<String> availableFilters;
  final Function(String) onFilterToggle;
  final VoidCallback? onClearAll;

  const QuickFilters({
    Key? key,
    required this.selectedFilters,
    required this.availableFilters,
    required this.onFilterToggle,
    this.onClearAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: availableFilters.length + (selectedFilters.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0 && selectedFilters.isNotEmpty) {
            return _buildClearAllChip();
          }
          
          final filterIndex = selectedFilters.isNotEmpty ? index - 1 : index;
          final filter = availableFilters[filterIndex];
          final isSelected = selectedFilters.contains(filter);
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) => onFilterToggle(filter),
              backgroundColor: AppTheme.surface,
              selectedColor: AppTheme.accentNeon,
              checkmarkColor: AppTheme.backgroundPrimary,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.backgroundPrimary : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: isSelected 
                  ? AppTheme.accentNeon 
                  : AppTheme.textSecondary.withOpacity(0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClearAllChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: const Text('Effacer tout'),
        onPressed: onClearAll,
        backgroundColor: AppTheme.errorColor,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        avatar: const Icon(
          Icons.clear_all,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}