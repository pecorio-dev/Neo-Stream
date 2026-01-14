import 'package:flutter/material.dart';
import '../providers/search_provider.dart';
import '../../core/theme/app_theme.dart';

class ModernFiltersWidget extends StatefulWidget {
  final SearchProvider provider;
  final VoidCallback? onFiltersChanged;

  const ModernFiltersWidget({
    Key? key,
    required this.provider,
    this.onFiltersChanged,
  }) : super(key: key);

  @override
  State<ModernFiltersWidget> createState() => _ModernFiltersWidgetState();
}

class _ModernFiltersWidgetState extends State<ModernFiltersWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  String _selectedSortOption = 'relevance';
  List<String> _selectedGenres = [];
  String _selectedQuality = '';
  String _selectedLanguage = '';
  RangeValues _yearRange = RangeValues(2000, DateTime.now().year.toDouble());
  double _minRating = 0.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(_slideAnimation),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppTheme.backgroundPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernGenreFilters(),
                          const SizedBox(height: 24),
                          _buildModernYearFilter(),
                          const SizedBox(height: 24),
                          _buildModernRatingFilter(),
                          const SizedBox(height: 24),
                          _buildModernQualityFilter(),
                          const SizedBox(height: 24),
                          _buildModernLanguageFilter(),
                          const SizedBox(height: 24),
                          _buildModernSortOptions(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.neonGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tune,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Filtres avancés',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernGenreFilters() {
    final popularGenres = [
      {'name': 'Action', 'icon': Icons.local_fire_department},
      {'name': 'Comédie', 'icon': Icons.sentiment_very_satisfied},
      {'name': 'Drame', 'icon': Icons.theater_comedy},
      {'name': 'Thriller', 'icon': Icons.flash_on},
      {'name': 'Science-Fiction', 'icon': Icons.rocket_launch},
      {'name': 'Horreur', 'icon': Icons.nightlight},
      {'name': 'Romance', 'icon': Icons.favorite},
      {'name': 'Animation', 'icon': Icons.animation},
      {'name': 'Aventure', 'icon': Icons.explore},
      {'name': 'Crime', 'icon': Icons.gavel},
      {'name': 'Documentaire', 'icon': Icons.video_library},
      {'name': 'Fantastique', 'icon': Icons.auto_awesome},
    ];

    return _buildFilterSection(
      title: 'Genres',
      icon: Icons.category,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: popularGenres.map((genre) {
          final isSelected = _selectedGenres.contains(genre['name']);
          return _buildModernChip(
            label: genre['name'] as String,
            icon: genre['icon'] as IconData,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedGenres.remove(genre['name']);
                } else {
                  _selectedGenres.add(genre['name'] as String);
                }
              });
              _onFiltersChanged();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModernYearFilter() {
    return _buildFilterSection(
      title: 'Année de sortie',
      icon: Icons.calendar_today,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_yearRange.start.toInt()}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_yearRange.end.toInt()}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.accentNeon,
              inactiveTrackColor: AppTheme.surface,
              thumbColor: AppTheme.accentNeon,
              overlayColor: AppTheme.accentNeon.withOpacity(0.2),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 12,
              ),
              rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
              trackHeight: 6,
            ),
            child: RangeSlider(
              values: _yearRange,
              min: 1950,
              max: DateTime.now().year.toDouble(),
              divisions: DateTime.now().year - 1950,
              onChanged: (values) {
                setState(() {
                  _yearRange = values;
                });
                widget.provider.setYearFilter(
                  values.start.toInt(),
                  values.end.toInt(),
                );
                _onFiltersChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernRatingFilter() {
    return _buildFilterSection(
      title: 'Note minimum',
      icon: Icons.star,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '0.0',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.neonGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _minRating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '10.0',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.accentNeon,
              inactiveTrackColor: AppTheme.surface,
              thumbColor: AppTheme.accentNeon,
              overlayColor: AppTheme.accentNeon.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 6,
            ),
            child: Slider(
              value: _minRating,
              min: 0.0,
              max: 10.0,
              divisions: 20,
              onChanged: (value) {
                setState(() {
                  _minRating = value;
                });
                widget.provider.setRatingFilter(value);
                _onFiltersChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernQualityFilter() {
    final qualities = [
      {'name': 'HD', 'icon': Icons.hd},
      {'name': 'Full HD', 'icon': Icons.high_quality},
      {'name': '4K', 'icon': Icons.four_k},
      {'name': 'CAM', 'icon': Icons.videocam},
      {'name': 'DVDRip', 'icon': Icons.album},
      {'name': 'BDRip', 'icon': Icons.disc_full},
    ];

    return _buildFilterSection(
      title: 'Qualité',
      icon: Icons.high_quality,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: qualities.map((quality) {
          final isSelected = _selectedQuality == quality['name'];
          return _buildModernChip(
            label: quality['name'] as String,
            icon: quality['icon'] as IconData,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedQuality = isSelected ? '' : quality['name'] as String;
              });
              _onFiltersChanged();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModernLanguageFilter() {
    final languages = [
      {'name': 'Français', 'icon': Icons.language},
      {'name': 'Anglais', 'icon': Icons.language},
      {'name': 'VOSTFR', 'icon': Icons.subtitles},
      {'name': 'VF', 'icon': Icons.record_voice_over},
      {'name': 'VO', 'icon': Icons.hearing},
    ];

    return _buildFilterSection(
      title: 'Langue',
      icon: Icons.translate,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: languages.map((language) {
          final isSelected = _selectedLanguage == language['name'];
          return _buildModernChip(
            label: language['name'] as String,
            icon: language['icon'] as IconData,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedLanguage = isSelected ? '' : language['name'] as String;
              });
              _onFiltersChanged();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModernSortOptions() {
    final sortOptions = [
      {'key': 'relevance', 'name': 'Pertinence', 'icon': Icons.search},
      {'key': 'rating', 'name': 'Note', 'icon': Icons.star},
      {'key': 'year', 'name': 'Année', 'icon': Icons.calendar_today},
      {'key': 'title', 'name': 'Titre', 'icon': Icons.sort_by_alpha},
      {'key': 'popularity', 'name': 'Popularité', 'icon': Icons.trending_up},
      {'key': 'date_added', 'name': 'Récemment ajouté', 'icon': Icons.new_releases},
    ];

    return _buildFilterSection(
      title: 'Trier par',
      icon: Icons.sort,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: sortOptions.map((option) {
          final isSelected = _selectedSortOption == option['key'];
          return _buildModernChip(
            label: option['name'] as String,
            icon: option['icon'] as IconData,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedSortOption = option['key'] as String;
              });
              _onFiltersChanged();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentNeon.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentNeon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.accentNeon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildModernChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.neonGradient : null,
          color: isSelected ? null : AppTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppTheme.accentNeon.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentNeon.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        border: Border(
          top: BorderSide(
            color: AppTheme.accentNeon.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Réinitialiser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(
                  color: AppTheme.textSecondary.withOpacity(0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _applyFilters,
              icon: const Icon(Icons.check),
              label: const Text('Appliquer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentNeon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedGenres.clear();
      _selectedQuality = '';
      _selectedLanguage = '';
      _selectedSortOption = 'relevance';
      _yearRange = RangeValues(2000, DateTime.now().year.toDouble());
      _minRating = 0.0;
    });
    widget.provider.clearFilters();
    _onFiltersChanged();
  }

  void _applyFilters() {
    // Appliquer les filtres sélectionnés
    if (_selectedGenres.isNotEmpty) {
      widget.provider.setGenreFilter(_selectedGenres.first);
    }

    // Relancer la recherche avec les nouveaux filtres
    widget.provider.instantSearch(widget.provider.currentQuery);

    Navigator.pop(context);
  }

  void _onFiltersChanged() {
    widget.onFiltersChanged?.call();
  }
}