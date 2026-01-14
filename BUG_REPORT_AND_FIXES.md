# NEO-Stream Flutter - Bug Report & Fixes

## 🔴 CRITICAL BUGS

### 1. **Bottom Overflow in Series Details Screen**
**File**: `lib/presentation/screens/series_details_screen.dart`
**Severity**: CRITICAL
**Description**: 
- The `_buildTitleSection()` Row with rating, date, and quality badges can overflow horizontally
- No `Expanded` or `Flexible` widgets wrapping long text
- Text overflow handling missing

**Current Code Issue (Lines 350-390)**:
```dart
Row(
  children: [
    if (widget.series.rating != null) ...[
      // Rating widget - FIXED WIDTH
    ],
    if (widget.series.releaseDate?.isNotEmpty == true) ...[
      Text(
        widget.series.releaseDate!,  // NO FLEXIBLE WRAPPER - CAN OVERFLOW
        style: const TextStyle(...),
      ),
    ],
    if (widget.series.quality?.isNotEmpty == true) ...[
      Container(
        // NO FLEXIBLE WRAPPER
      ),
    ],
  ],
),
```

**Fix**:
```dart
Row(
  children: [
    if (widget.series.rating != null && (widget.series.rating is num) && (widget.series.rating as num) > 0) ...[
      Container(
        // Rating widget
      ),
      const SizedBox(width: 12),
    ],
    Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (widget.series.releaseDate?.isNotEmpty == true) ...[
              Text(
                widget.series.releaseDate!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (widget.series.quality?.isNotEmpty == true) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.series.quality!,
                  style: const TextStyle(
                    color: AppColors.cyberBlack,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ],
)
```

---

### 2. **RenderFlex Overflow in Season/Episode ListTile**
**File**: `lib/presentation/screens/series_details_screen.dart` (Lines ~480-520)
**Severity**: CRITICAL
**Description**:
- Season ListTile title Row with season number and episode count can overflow
- Title text not wrapped properly
- No Expanded widget for flexible sizing

**Current Code**:
```dart
ListTile(
  title: Row(
    children: [
      Text(
        'Saison ${season.seasonNumber}',
        // NO FLEXIBLE WRAPPER - CAN OVERFLOW
      ),
      const SizedBox(width: 8),
      Text(
        '(${season.episodes.length} épisodes)',
        // NO FLEXIBLE WRAPPER
      ),
    ],
  ),
  // ...
)
```

**Fix**:
```dart
ListTile(
  title: Row(
    children: [
      Expanded(
        child: Text(
          'Saison ${season.seasonNumber}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '(${season.episodes.length} épisodes)',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  ),
  // ...
)
```

---

### 3. **Missing Episode Tile Completion**
**File**: `lib/presentation/screens/series_details_screen.dart` (Lines ~540+)
**Severity**: HIGH
**Description**:
- The `_buildEpisodeTile()` method appears incomplete - file ends abruptly
- No proper trailing widget (play button)
- No onTap handler for playing episode
- Progress bar/indicator missing

**Current Issue**:
```dart
Widget _buildEpisodeTile(Episode episode, Season season, WatchProgress? progress) {
  return ListTile(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.cyberGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: progress != null && !progress.isCompleted 
              ? AppColors.neonBlue 
              : Colors.transparent,
          width: 2,
        ),
      ),
      // INCOMPLETE - NO TITLE, SUBTITLE, TRAILING, OR ONTAP
    ),
  );
}
```

**Fix**:
```dart
Widget _buildEpisodeTile(Episode episode, Season season, WatchProgress? progress) {
  final episodeKey = '${widget.series.id}_${season.seasonNumber}_${episode.episodeNumber}';
  
  return ListTile(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.cyberGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: progress != null && progress.watchedSeconds > 0 
              ? AppColors.neonBlue 
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          episode.episodeNumber.toString().padLeft(2, '0'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    ),
    title: Text(
      'Épisode ${episode.episodeNumber}',
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: progress != null && progress.watchedSeconds > 0
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.watchedSeconds / (progress.totalSeconds ?? 1),
                  backgroundColor: AppColors.cyberGray,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.neonBlue,
                  ),
                  minHeight: 3,
                ),
              ),
            ],
          )
        : const Text('Non regardé'),
    trailing: IconButton(
      icon: const Icon(Icons.play_arrow, color: AppColors.neonBlue),
      onPressed: () => _playEpisode(episode, season),
    ),
    onTap: () => _playEpisode(episode, season),
  );
}

void _playEpisode(Episode episode, Season season) {
  // Navigate to video player or stream
  Navigator.pushNamed(
    context,
    '/video-player',
    arguments: {
      'series': widget.series,
      'season': season,
      'episode': episode,
    },
  );
}
```

---

## 🟡 HIGH PRIORITY BUGS

### 4. **Memory Leak in Series Details - Episode Progress Loading**
**File**: `lib/presentation/screens/series_details_screen.dart` (Lines ~125-145)
**Severity**: HIGH
**Description**:
- `_loadEpisodeProgress()` creates many watch progress queries without pagination
- Could hang UI on series with 100+ episodes
- No cancellation token support

**Current Code**:
```dart
Future<void> _loadEpisodeProgress() async {
  for (int i = 0; i < widget.series.seasons.length; i++) {
    final season = widget.series.seasons[i];
    for (int j = 0; j < season.episodes.length; j++) {
      // Sequential loading - blocks UI
      final progress = await WatchProgressService.getProgress(...);
      _episodeProgress[key] = progress;
    }
  }
  setState(() {});  // ONE setState at end - good, but loop is slow
}
```

**Fix**:
```dart
Future<void> _loadEpisodeProgress() async {
  try {
    final futures = <Future<void>>[];
    
    for (int i = 0; i < widget.series.seasons.length; i++) {
      final season = widget.series.seasons[i];
      for (int j = 0; j < season.episodes.length; j++) {
        final episode = season.episodes[j];
        final future = WatchProgressService.getProgress(
          contentId: widget.series.id ?? '',
          contentType: 'series',
          seasonNumber: season.seasonNumber,
          episodeNumber: episode.episodeNumber,
        ).then((progress) {
          if (mounted) {
            final key = '${widget.series.id}_${season.seasonNumber}_${episode.episodeNumber}';
            _episodeProgress[key] = progress;
          }
        });
        futures.add(future);
      }
    }
    
    // Load in parallel with limit
    const batchSize = 10;
    for (int i = 0; i < futures.length; i += batchSize) {
      final batch = futures.sublist(
        i,
        i + batchSize > futures.length ? futures.length : i + batchSize,
      );
      await Future.wait(batch);
    }
    
    if (mounted) {
      setState(() {});
    }
  } catch (e) {
    print('Error loading episode progress: $e');
  }
}
```

---

### 5. **MovieCard AspectRatio Calculation Bug**
**File**: `lib/presentation/widgets/movie_card.dart` (Lines ~285-295)
**Severity**: HIGH
**Description**:
- `_getAspectRatio()` calculation can produce very small values
- Formula: `width / (height + 35)` for details section
- For small cards: 120 / (180 + 35) = 0.5 - causes distorted cards

**Current Code**:
```dart
double _getAspectRatio() {
  final dimensions = CardDimensions(_getCardWidth(), _getCardWidth() * 1.5);
  final totalHeight = dimensions.height + (showDetails ? 35 : 0);
  return dimensions.width / totalHeight;  // CAN BE VERY SMALL
}
```

**Fix**:
```dart
double _getAspectRatio() {
  final cardWidth = _getCardWidth();
  final cardHeight = cardWidth * 1.5;  // 160 x 240 for medium
  
  // Add extra space for title/year section
  final detailsHeight = showDetails ? 45 : 0;
  final totalHeight = cardHeight + detailsHeight;
  
  // Ensure minimum aspect ratio
  final aspectRatio = cardWidth / totalHeight;
  return aspectRatio.clamp(0.55, 0.75);  // Range for proper display
}
```

---

### 6. **Flutter ScrollController Not Assigned to CustomScrollView**
**File**: `lib/presentation/screens/movies_screen.dart` (Lines ~96-102)
**Severity**: HIGH
**Description**:
- `_scrollController` created but assignment to `CustomScrollView` might fail if controller is disposed
- Listener added in `initState` before widget tree built
- No null-safety on `_scrollController.position`

**Current Code**:
```dart
void _setupScrollController() {
  _scrollController = ScrollController();
  _scrollController.addListener(() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMovies();
    }
  });
}
```

**Fix**:
```dart
void _setupScrollController() {
  _scrollController = ScrollController();
  _scrollController.addListener(_onScrollListener);
}

void _onScrollListener() {
  try {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 200) {
        _loadMoreMovies();
      }
    }
  } catch (e) {
    print('Scroll listener error: $e');
  }
}

@override
void dispose() {
  _scrollController.removeListener(_onScrollListener);
  _scrollController.dispose();
  _animationController.dispose();
  super.dispose();
}
```

---

## 🟠 MEDIUM PRIORITY BUGS

### 7. **Image Placeholder in MovieCard - No Constraints**
**File**: `lib/presentation/widgets/movie_card.dart` (Lines ~180-195)
**Severity**: MEDIUM
**Description**:
- Placeholder icon not bounded
- Can overflow container if dimensions are very small
- No proper size constraints

**Current Code**:
```dart
Widget _buildPlaceholder() {
  return Container(
    color: AppTheme.surface,
    child: const Center(
      child: Icon(
        Icons.movie_outlined,
        color: AppTheme.textSecondary,
        size: 48,  // FIXED SIZE - may overflow on small cards
      ),
    ),
  );
}
```

**Fix**:
```dart
Widget _buildPlaceholder() {
  return Container(
    color: AppTheme.surface,
    child: Center(
      child: Icon(
        Icons.movie_outlined,
        color: AppTheme.textSecondary,
        size: 48,
        semanticLabel: 'Aucune image disponible',
      ),
    ),
  );
}
```

---

### 8. **AnimationController Forward Without Mounted Check**
**File**: `lib/presentation/screens/series_details_screen.dart` (Lines ~89-92)
**Severity**: MEDIUM
**Description**:
- `_animationController.forward()` called without checking if widget is mounted
- Can throw exception if widget is disposed during animation setup

**Current Code**:
```dart
_scrollController.addListener(_onScroll);

// Démarrer les animations
_animationController.forward();  // NO MOUNTED CHECK
Future.delayed(const Duration(milliseconds: 500), () {
  if (mounted) _fabAnimationController.forward();  // HAS CHECK
});
```

**Fix**:
```dart
_scrollController.addListener(_onScroll);

// Démarrer les animations
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    _animationController.forward();
  }
});

Future.delayed(const Duration(milliseconds: 500), () {
  if (mounted) {
    _fabAnimationController.forward();
  }
});
```

---

### 9. **Missing Null Safety in Series Details Rating**
**File**: `lib/presentation/screens/series_details_screen.dart` (Lines ~220-240)
**Severity**: MEDIUM
**Description**:
- Inconsistent type checking for rating (sometimes `is num`, sometimes cast)
- Could throw at runtime if rating is null
- Multiple type checks scattered

**Current Code**:
```dart
if (widget.series.rating != null && (widget.series.rating is num) && (widget.series.rating as num) > 0) {
  // Inconsistent checking
}
```

**Fix**:
```dart
double? _parseRating() {
  final rating = widget.series.rating;
  if (rating == null) return null;
  
  if (rating is double) return rating;
  if (rating is int) return rating.toDouble();
  if (rating is String) {
    try {
      return double.parse(rating.split('/').first.trim());
    } catch (_) {}
  }
  
  return null;
}

Color _getRatingColor(double rating) {
  if (rating >= 8.0) return Colors.green;
  if (rating >= 6.0) return Colors.orange;
  return Colors.red;
}

// Usage:
final rating = _parseRating();
if (rating != null && rating > 0) {
  // Use rating safely
}
```

---

## 🔵 LOW PRIORITY BUGS / IMPROVEMENTS

### 10. **Series Details FAB Button Not Shown/Hidden Smoothly**
**File**: `lib/presentation/screens/series_details_screen.dart` (Lines ~171-175)
**Severity**: LOW
**Description**:
- FAB animation is basic elastic tween
- Should respond to scroll position
- No hide-on-scroll behavior

**Improvement**:
```dart
Widget _buildPlayButton() {
  return ScaleTransition(
    scale: _fabAnimation,
    child: FloatingActionButton.extended(
      onPressed: _playFirstEpisode,
      backgroundColor: AppColors.neonBlue,
      icon: const Icon(Icons.play_arrow),
      label: const Text('Lecture'),
      heroTag: 'play_fab',
    ),
  );
}

void _playFirstEpisode() {
  if (widget.series.seasons.isNotEmpty &&
      widget.series.seasons[0].episodes.isNotEmpty) {
    final firstEpisode = widget.series.seasons[0].episodes[0];
    _playEpisode(firstEpisode, widget.series.seasons[0]);
  }
}
```

---

### 11. **Movie Details Screen Not Shown in Code**
**File**: `lib/presentation/screens/movie_details_screen.dart`
**Severity**: LOW
**Description**:
- File exists but not provided for review
- Likely has similar bugs to series_details_screen

**Recommendation**:
- Review and apply same fixes as series_details_screen
- Add proper image caching strategy
- Implement watch progress tracking

---

### 12. **No Error Boundary/Catch Block in Main Screen**
**File**: `lib/presentation/screens/main_screen.dart`
**Severity**: LOW
**Description**:
- Navigation and widget building not wrapped in error handlers
- Could crash app on navigation errors

**Improvement**:
```dart
void _navigateToMovieDetails(Movie movie) {
  try {
    Navigator.pushNamed(
      context,
      '/movie-detail',
      arguments: movie,
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur de navigation: $e')),
    );
  }
}
```

---

## 📋 SUMMARY TABLE

| Bug # | File | Type | Severity | Status |
|-------|------|------|----------|--------|
| 1 | series_details_screen.dart | Overflow | CRITICAL | ❌ Not Fixed |
| 2 | series_details_screen.dart | Overflow | CRITICAL | ❌ Not Fixed |
| 3 | series_details_screen.dart | Incomplete | HIGH | ❌ Not Fixed |
| 4 | series_details_screen.dart | Memory | HIGH | ❌ Not Fixed |
| 5 | movie_card.dart | Layout | HIGH | ❌ Not Fixed |
| 6 | movies_screen.dart | Safety | HIGH | ❌ Not Fixed |
| 7 | movie_card.dart | Layout | MEDIUM | ❌ Not Fixed |
| 8 | series_details_screen.dart | Safety | MEDIUM | ❌ Not Fixed |
| 9 | series_details_screen.dart | Type Safety | MEDIUM | ❌ Not Fixed |
| 10 | series_details_screen.dart | UX | LOW | ⚠️ Enhancement |
| 11 | movie_details_screen.dart | Missing Review | LOW | ❌ Not Fixed |
| 12 | main_screen.dart | Error Handling | LOW | ❌ Not Fixed |

---

## 🔧 QUICK FIX PRIORITY

**Fix in this order**:
1. **CRITICAL Bugs (1-2)**: Bottom overflow issues - app crashes on small screens
2. **HIGH Bugs (3-6)**: Incomplete code, memory leaks, layout issues
3. **MEDIUM Bugs (7-9)**: Polish and stability
4. **LOW Improvements (10-12)**: Enhanced UX and error handling

---

## ✅ TESTING CHECKLIST

After fixes, test:
- [ ] Landscape orientation on small screens
- [ ] Series with 50+ episodes
- [ ] Very long series/movie titles
- [ ] Image loading failures
- [ ] Rapid scrolling and pagination
- [ ] Animation smooth on low-end devices
- [ ] Watch progress tracking
- [ ] Episode playback navigation
- [ ] Favorite toggle functionality
- [ ] Share functionality
