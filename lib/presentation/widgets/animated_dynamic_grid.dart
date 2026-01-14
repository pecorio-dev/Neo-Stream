import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../data/models/movie.dart';
import 'dynamic_movie_card.dart';

// Nouvelle grille animée avec des cartes dynamiques
class AnimatedDynamicGrid extends StatelessWidget {
  final List<Movie> movies;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets? padding;
  final Duration animationDuration;
  final Duration delayBetweenItems;
  final DynamicCardType cardType;

  const AnimatedDynamicGrid({
    Key? key,
    required this.movies,
    this.onMovieTap,
    this.onMovieLongPress,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.animationDuration = const Duration(milliseconds: 600),
    this.delayBetweenItems = const Duration(milliseconds: 80),
    this.cardType = DynamicCardType.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = _getDynamicCrossAxisCount(constraints.maxWidth);
          
          return GridView.builder(
            padding: padding ?? const EdgeInsets.all(16),
            physics: physics,
            shrinkWrap: shrinkWrap,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: _getDynamicAspectRatio(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: animationDuration,
                delay: delayBetweenItems,
                columnCount: crossAxisCount,
                child: SlideAnimation(
                  verticalOffset: 30.0,
                  child: FadeInAnimation(
                    child: ScaleAnimation(
                      scale: 0.8,
                      child: DynamicMovieCard(
                        movie: movies[index],
                        cardType: cardType,
                        index: index,
                        onTap: () => onMovieTap?.call(movies[index]),
                        onLongPress: () => onMovieLongPress?.call(movies[index]),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  int _getDynamicCrossAxisCount(double width) {
    switch (cardType) {
      case DynamicCardType.featured:
        return width > 800 ? 2 : 1;
      case DynamicCardType.standard:
        if (width > 1200) return 4;
        if (width > 800) return 3;
        return 2;
      case DynamicCardType.compact:
        if (width > 1200) return 5;
        if (width > 800) return 4;
        if (width > 600) return 3;
        return 2;
      case DynamicCardType.mini:
        if (width > 1200) return 6;
        if (width > 800) return 5;
        if (width > 600) return 4;
        return 3;
    }
  }

  double _getDynamicAspectRatio() {
    switch (cardType) {
      case DynamicCardType.featured:
        return 0.6;
      case DynamicCardType.standard:
        return 0.55;
      case DynamicCardType.compact:
        return 0.5;
      case DynamicCardType.mini:
        return 0.45;
    }
  }
}

// Grille mosaïque animée avec différentes tailles
class AnimatedMosaicGrid extends StatelessWidget {
  final List<Movie> movies;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final Duration animationDuration;
  final Duration delayBetweenItems;

  const AnimatedMosaicGrid({
    Key? key,
    required this.movies,
    this.onMovieTap,
    this.onMovieLongPress,
    this.physics,
    this.padding,
    this.animationDuration = const Duration(milliseconds: 800),
    this.delayBetweenItems = const Duration(milliseconds: 120),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return AnimationLimiter(
      child: SingleChildScrollView(
        physics: physics,
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          children: _buildAnimatedMosaicSections(),
        ),
      ),
    );
  }

  List<Widget> _buildAnimatedMosaicSections() {
    final sections = <Widget>[];
    int index = 0;
    int animationIndex = 0;

    while (index < movies.length) {
      // Section avec une carte featured
      if (index < movies.length) {
        sections.add(_buildAnimatedFeaturedSection(index, animationIndex));
        index++;
        animationIndex++;
      }

      // Section avec des cartes standard
      if (index < movies.length) {
        final standardMovies = movies.skip(index).take(4).toList();
        sections.add(_buildAnimatedStandardSection(standardMovies, index, animationIndex));
        index += standardMovies.length;
        animationIndex += standardMovies.length;
      }

      // Section avec des cartes compactes
      if (index < movies.length) {
        final compactMovies = movies.skip(index).take(6).toList();
        sections.add(_buildAnimatedCompactSection(compactMovies, index, animationIndex));
        index += compactMovies.length;
        animationIndex += compactMovies.length;
      }

      // Espacement entre les sections
      if (index < movies.length) {
        sections.add(const SizedBox(height: 24));
      }
    }

    return sections;
  }

  Widget _buildAnimatedFeaturedSection(int movieIndex, int animationIndex) {
    if (movieIndex >= movies.length) return const SizedBox.shrink();

    return AnimationConfiguration.staggeredList(
      position: animationIndex,
      duration: animationDuration,
      delay: delayBetweenItems,
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: ScaleAnimation(
            scale: 0.9,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: DynamicMovieCard(
                  movie: movies[movieIndex],
                  cardType: DynamicCardType.featured,
                  index: movieIndex,
                  onTap: () => onMovieTap?.call(movies[movieIndex]),
                  onLongPress: () => onMovieLongPress?.call(movies[movieIndex]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedStandardSection(List<Movie> sectionMovies, int startIndex, int animationStartIndex) {
    return AnimationConfiguration.staggeredList(
      position: animationStartIndex,
      duration: animationDuration,
      delay: delayBetweenItems,
      child: SlideAnimation(
        horizontalOffset: 30.0,
        child: FadeInAnimation(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
                
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: sectionMovies.length,
                  itemBuilder: (context, index) {
                    final movie = sectionMovies[index];
                    return DynamicMovieCard(
                      movie: movie,
                      cardType: DynamicCardType.standard,
                      index: startIndex + index,
                      onTap: () => onMovieTap?.call(movie),
                      onLongPress: () => onMovieLongPress?.call(movie),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCompactSection(List<Movie> sectionMovies, int startIndex, int animationStartIndex) {
    return AnimationConfiguration.staggeredList(
      position: animationStartIndex,
      duration: animationDuration,
      delay: delayBetweenItems,
      child: SlideAnimation(
        horizontalOffset: -30.0,
        child: FadeInAnimation(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;
                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 800) {
                  crossAxisCount = 3;
                } else {
                  crossAxisCount = 2;
                }
                
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: sectionMovies.length,
                  itemBuilder: (context, index) {
                    final movie = sectionMovies[index];
                    return DynamicMovieCard(
                      movie: movie,
                      cardType: DynamicCardType.compact,
                      index: startIndex + index,
                      onTap: () => onMovieTap?.call(movie),
                      onLongPress: () => onMovieLongPress?.call(movie),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Widget pour un layout en cascade avec des tailles variables
class AnimatedWaterfallGrid extends StatelessWidget {
  final List<Movie> movies;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets? padding;
  final Duration animationDuration;
  final Duration delayBetweenItems;

  const AnimatedWaterfallGrid({
    Key? key,
    required this.movies,
    this.onMovieTap,
    this.onMovieLongPress,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.animationDuration = const Duration(milliseconds: 500),
    this.delayBetweenItems = const Duration(milliseconds: 60),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _buildWaterfallLayout(context, constraints);
        },
      ),
    );
  }

  Widget _buildWaterfallLayout(BuildContext context, BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    final columns = _getColumnCount(screenWidth);
    
    // Diviser les films en colonnes
    final columnMovies = List.generate(columns, (index) => <Movie>[]);
    
    for (int i = 0; i < movies.length; i++) {
      final columnIndex = i % columns;
      columnMovies[columnIndex].add(movies[i]);
    }

    return SingleChildScrollView(
      physics: physics,
      padding: padding ?? const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(columns, (columnIndex) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: columnIndex > 0 ? 6 : 0,
                right: columnIndex < columns - 1 ? 6 : 0,
              ),
              child: Column(
                children: _buildColumnItems(columnMovies[columnIndex], columnIndex, columns),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildColumnItems(List<Movie> columnMovies, int columnIndex, int totalColumns) {
    return columnMovies.asMap().entries.map((entry) {
      final index = entry.key;
      final movie = entry.value;
      final globalIndex = columnIndex + (index * totalColumns);
      
      // Varier les types de cartes selon la position
      DynamicCardType cardType;
      if (index == 0 && columnIndex == 0) {
        cardType = DynamicCardType.featured;
      } else if (index % 3 == 0) {
        cardType = DynamicCardType.standard;
      } else if (index % 2 == 0) {
        cardType = DynamicCardType.compact;
      } else {
        cardType = DynamicCardType.mini;
      }

      return AnimationConfiguration.staggeredList(
        position: globalIndex,
        duration: animationDuration,
        delay: delayBetweenItems,
        child: SlideAnimation(
          verticalOffset: 20.0,
          child: FadeInAnimation(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DynamicMovieCard(
                movie: movie,
                cardType: cardType,
                index: globalIndex,
                onTap: () => onMovieTap?.call(movie),
                onLongPress: () => onMovieLongPress?.call(movie),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  int _getColumnCount(double screenWidth) {
    if (screenWidth > 1200) return 4;
    if (screenWidth > 800) return 3;
    if (screenWidth > 600) return 2;
    return 1;
  }
}