import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/settings/settings_provider.dart';

class GenreSelectionScreen extends ConsumerStatefulWidget {
  final bool isPreferred;
  
  const GenreSelectionScreen({
    Key? key,
    required this.isPreferred,
  }) : super(key: key);

  @override
  ConsumerState<GenreSelectionScreen> createState() => _GenreSelectionScreenState();
}

class _GenreSelectionScreenState extends ConsumerState<GenreSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final List<String> _allGenres = [
    'Action',
    'Aventure',
    'Animation',
    'Comédie',
    'Crime',
    'Documentaire',
    'Drame',
    'Famille',
    'Fantastique',
    'Histoire',
    'Horreur',
    'Musique',
    'Mystère',
    'Romance',
    'Science-Fiction',
    'Thriller',
    'Guerre',
    'Western',
    'Biographie',
    'Sport',
  ];
  
  Set<String> _selectedGenres = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Load current selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(settingsProvider);
      setState(() {
        _selectedGenres = widget.isPreferred 
            ? Set.from(provider.preferredGenres)
            : Set.from(provider.blockedGenres);
      });
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            _buildSearchBar(),
            _buildGenreGrid(),
          ],
        ),
      ),
      floatingActionButton: _buildSaveButton(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.isPreferred ? 'Genres préférés' : 'Genres bloqués',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isPreferred 
                  ? [AppTheme.accentNeon, AppTheme.accentSecondary]
                  : [AppTheme.errorColor, AppTheme.warningColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.backgroundPrimary.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all, color: AppTheme.textPrimary),
          onPressed: _selectAll,
          tooltip: 'Tout sélectionner',
        ),
        IconButton(
          icon: const Icon(Icons.clear_all, color: AppTheme.textPrimary),
          onPressed: _clearAll,
          tooltip: 'Tout désélectionner',
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Rechercher un genre...',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            prefixIcon: const Icon(Icons.search, color: AppTheme.accentNeon),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accentNeon),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreGrid() {
    final filteredGenres = _allGenres
        .where((genre) => genre.toLowerCase().contains(_searchQuery))
        .toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final genre = filteredGenres[index];
            final isSelected = _selectedGenres.contains(genre);
            
            return _buildGenreChip(genre, isSelected, index);
          },
          childCount: filteredGenres.length,
        ),
      ),
    );
  }

  Widget _buildGenreChip(String genre, bool isSelected, int index) {
    final color = widget.isPreferred ? AppTheme.accentNeon : AppTheme.errorColor;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _toggleGenre(genre),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected 
                  ? color.withOpacity(0.2)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : AppTheme.textSecondary.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected) ...[
                    Icon(
                      widget.isPreferred ? Icons.favorite : Icons.block,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      genre,
                      style: TextStyle(
                        color: isSelected ? color : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      );
  }

  Widget _buildSaveButton() {
    return FloatingActionButton.extended(
      onPressed: _saveSelection,
      backgroundColor: widget.isPreferred ? AppTheme.accentNeon : AppTheme.errorColor,
      icon: const Icon(Icons.save, color: AppTheme.backgroundPrimary),
      label: Text(
        'Sauvegarder (${_selectedGenres.length})',
        style: const TextStyle(
          color: AppTheme.backgroundPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _toggleGenre(String genre) {
    setState(() {
      if (_selectedGenres.contains(genre)) {
        _selectedGenres.remove(genre);
      } else {
        _selectedGenres.add(genre);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedGenres = Set.from(_allGenres);
    });
  }

  void _clearAll() {
    setState(() {
      _selectedGenres.clear();
    });
  }

  void _saveSelection() {
    final provider = ref.read(settingsProvider);
    
    if (widget.isPreferred) {
      provider.setPreferredGenres(_selectedGenres.toList());
    } else {
      provider.setBlockedGenres(_selectedGenres.toList());
    }
    
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isPreferred 
              ? 'Genres préférés sauvegardés'
              : 'Genres bloqués sauvegardés',
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
