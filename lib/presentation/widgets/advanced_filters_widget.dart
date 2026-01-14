import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../../core/theme/app_theme.dart';

class AdvancedFiltersWidget extends ConsumerStatefulWidget {
  final SearchProvider provider;
  final VoidCallback? onFiltersChanged;

  const AdvancedFiltersWidget({
    Key? key,
    required this.provider,
    this.onFiltersChanged,
  }) : super(key: key);

  @override
  ConsumerState<AdvancedFiltersWidget> createState() => _AdvancedFiltersWidgetState();
}

class _AdvancedFiltersWidgetState extends ConsumerState<AdvancedFiltersWidget> {
  String _selectedSortOption = 'relevance';
  List<String> _selectedGenres = [];
  String _selectedQuality = '';
  String _selectedLanguage = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildGenreFilters(),
          const SizedBox(height: 20),
          _buildYearRangeFilter(),
          const SizedBox(height: 20),
          _buildRatingFilter(),
          const SizedBox(height: 20),
          _buildQualityFilter(),
          const SizedBox(height: 20),
          _buildLanguageFilter(),
          const SizedBox(height: 20),
          _buildSortOptions(),
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.tune,
          color: AppTheme.accentNeon,
          size: 24,
        ),
        const SizedBox(width: 12),
        const Text(
          'Filtres avancés',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.close,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildGenreFilters() {
    final popularGenres = [
      'Action', 'Comédie', 'Drame', 'Thriller', 'Science-Fiction',
      'Horreur', 'Romance', 'Animation', 'Aventure', 'Crime',
      'Documentaire', 'Fantastique', 'Guerre', 'Histoire', 'Musique',
      'Mystère', 'Western', 'Familial'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Genres',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popularGenres.map((genre) {
            final isSelected = _selectedGenres.contains(genre);
            return FilterChip(
              label: Text(genre),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedGenres.add(genre);
                  } else {
                    _selectedGenres.remove(genre);
                  }
                });
                _onFiltersChanged();
              },
              backgroundColor: AppTheme.surface,
              selectedColor: AppTheme.accentNeon,
              checkmarkColor: AppTheme.backgroundPrimary,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.backgroundPrimary : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildYearRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Année de sortie',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildYearDropdown(
                label: 'De',
                value: widget.provider.minYear,
                onChanged: (value) {
                  widget.provider.setYearFilter(value ?? 0, widget.provider.maxYear);
                  _onFiltersChanged();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildYearDropdown(
                label: 'À',
                value: widget.provider.maxYear,
                onChanged: (value) {
                  widget.provider.setYearFilter(widget.provider.minYear, value ?? DateTime.now().year);
                  _onFiltersChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYearDropdown({
    required String label,
    required int value,
    required Function(int?) onChanged,
  }) {
    final currentYear = DateTime.now().year;
    final years = <int>[];
    
    for (int year = currentYear; year >= 1950; year--) {
      years.add(year);
    }

    return DropdownButtonFormField<int>(
      value: value == 0 ? null : value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dropdownColor: AppTheme.surface,
      style: const TextStyle(color: AppTheme.textPrimary),
      items: [
        const DropdownMenuItem<int>(
          value: null,
          child: Text('Toutes', style: TextStyle(color: AppTheme.textPrimary)),
        ),
        ...years.map((year) => DropdownMenuItem<int>(
          value: year,
          child: Text(year.toString(), style: const TextStyle(color: AppTheme.textPrimary)),
        )),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Note minimum',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentNeon,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.provider.minRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppTheme.backgroundPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.accentNeon,
            inactiveTrackColor: AppTheme.textSecondary.withOpacity(0.3),
            thumbColor: AppTheme.accentNeon,
            overlayColor: AppTheme.accentNeon.withOpacity(0.3),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: widget.provider.minRating,
            min: 0.0,
            max: 10.0,
            divisions: 20,
            onChanged: (value) {
              widget.provider.setRatingFilter(value);
              _onFiltersChanged();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQualityFilter() {
    final qualities = ['Toutes', 'HD', 'Full HD', '4K', 'CAM', 'TS', 'DVDRip', 'BDRip'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Qualité',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: qualities.map((quality) {
            final isSelected = _selectedQuality == quality || (quality == 'Toutes' && _selectedQuality.isEmpty);
            return FilterChip(
              label: Text(quality),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedQuality = selected ? (quality == 'Toutes' ? '' : quality) : '';
                });
                _onFiltersChanged();
              },
              backgroundColor: AppTheme.surface,
              selectedColor: AppTheme.accentNeon,
              checkmarkColor: AppTheme.backgroundPrimary,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.backgroundPrimary : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLanguageFilter() {
    final languages = ['Toutes', 'Français', 'Anglais', 'VOSTFR', 'VF', 'VO'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langue',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: languages.map((language) {
            final isSelected = _selectedLanguage == language || (language == 'Toutes' && _selectedLanguage.isEmpty);
            return FilterChip(
              label: Text(language),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedLanguage = selected ? (language == 'Toutes' ? '' : language) : '';
                });
                _onFiltersChanged();
              },
              backgroundColor: AppTheme.surface,
              selectedColor: AppTheme.accentNeon,
              checkmarkColor: AppTheme.backgroundPrimary,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.backgroundPrimary : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSortOptions() {
    final sortOptions = {
      'relevance': 'Pertinence',
      'rating': 'Note',
      'year': 'Année',
      'title': 'Titre',
      'popularity': 'Popularité',
      'date_added': 'Récemment ajouté',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trier par',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedSortOption,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          dropdownColor: AppTheme.surface,
          style: const TextStyle(color: AppTheme.textPrimary),
          items: sortOptions.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value, style: const TextStyle(color: AppTheme.textPrimary)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSortOption = value ?? 'relevance';
            });
            _onFiltersChanged();
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _clearAllFilters,
            icon: const Icon(Icons.clear_all),
            label: const Text('Tout effacer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.textSecondary),
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
              foregroundColor: AppTheme.backgroundPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedGenres.clear();
      _selectedQuality = '';
      _selectedLanguage = '';
      _selectedSortOption = 'relevance';
    });
    widget.provider.clearFilters();
    _onFiltersChanged();
  }

  void _applyFilters() {
    // Appliquer les filtres sélectionnés
    if (_selectedGenres.isNotEmpty) {
      widget.provider.setGenreFilter(_selectedGenres.first); // Pour l'instant, un seul genre
    }
    
    // Relancer la recherche avec les nouveaux filtres
    widget.provider.instantSearch(widget.provider.currentQuery);
    
    Navigator.pop(context);
  }

  void _onFiltersChanged() {
    widget.onFiltersChanged?.call();
  }
}
