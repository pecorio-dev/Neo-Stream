/// Neo-Stream content model.
class Content {
  final int id;
  final String? cpasmieuxId;
  final String title;
  final String? description;
  final String contentType;
  final List<String> genres;
  final double rating;
  final int? releaseDate;
  final String? poster;
  final String? posterUrl;
  final List<WatchLink> watchLinks;
  final List<Episode> episodes;
  final Map<int, List<Episode>> seasons;
  final int seasonCount;
  final int episodeCount;
  final String? urlSite;
  final List<String> keywords;
  final String? createdAt;
  final String? updatedAt;
  final int? rank;
  final int? todayViews;
  final String? trend;
  final int? matchPercent;
  final double? progressPercent;
  final String? currentEpisodeId;
  final String? seriesBaseTitle;
  final List<int> availableSeasons;
  final List<int> missingSeasons;
  final int mergedVariantCount;
  final bool hasDetachedSeasons;
  final bool autoMerged;
  bool inLibrary;
  final bool isPremiumContent;
  final List<Content> similar;
  final Map<String, dynamic>? userProgress;
  final List<dynamic>? allProgress;

  Content({
    required this.id,
    this.cpasmieuxId,
    required this.title,
    this.description,
    required this.contentType,
    this.genres = const [],
    this.rating = 0,
    this.releaseDate,
    this.poster,
    this.posterUrl,
    this.watchLinks = const [],
    this.episodes = const [],
    this.seasons = const {},
    this.seasonCount = 0,
    this.episodeCount = 0,
    this.urlSite,
    this.keywords = const [],
    this.createdAt,
    this.updatedAt,
    this.rank,
    this.todayViews,
    this.trend,
    this.matchPercent,
    this.progressPercent,
    this.currentEpisodeId,
    this.seriesBaseTitle,
    this.availableSeasons = const [],
    this.missingSeasons = const [],
    this.mergedVariantCount = 1,
    this.hasDetachedSeasons = false,
    this.autoMerged = false,
    this.inLibrary = false,
    this.isPremiumContent = true,
    this.similar = const [],
    this.userProgress,
    this.allProgress,
  });

  bool get isFilm =>
      contentType != 'serie'; // Tout ce qui n'est pas serie est un film
  bool get isSerie => contentType == 'serie';
  String get typeLabel => isFilm ? 'Film' : 'Serie';

  String get displayTitle =>
      (seriesBaseTitle != null && seriesBaseTitle!.trim().isNotEmpty)
      ? seriesBaseTitle!
      : title;

  bool get hasSeasonGaps => missingSeasons.isNotEmpty;

  /// Whether this content has a resolvable poster image.
  bool get hasPoster => fullPosterUrl.isNotEmpty;

  String get fullPosterUrl {
    if (posterUrl != null && posterUrl!.trim().isNotEmpty) {
      final url = posterUrl!.trim();
      if (url.startsWith('http')) return url;
      return _resolveImagePath(url);
    }
    if (poster != null && poster!.trim().isNotEmpty) {
      final url = poster!.trim();
      if (url.startsWith('http')) return url;
      return _resolveImagePath(url);
    }
    return '';
  }

  static String _resolveImagePath(String path) {
    final clean = path.startsWith('/') ? path : '/$path';
    if (clean.startsWith('/app/')) {
      return 'https://neo-stream.eu$clean';
    }
    return 'https://neo-stream.eu/app$clean';
  }

  /// Resolve any poster string (used by history, library, etc.)
  static String resolvePosterUrl(String? poster) {
    if (poster == null || poster.trim().isEmpty) return '';
    final url = poster.trim();
    if (url.startsWith('http')) return url;
    return _resolveImagePath(url);
  }

  String get mainGenre => genres.isNotEmpty ? genres.first : '';
  String get genresText => genres.join(' / ');
  List<String> get availableLanguages {
    final languages = <String>{};
    if (isFilm) {
      for (final link in watchLinks) {
        if (link.languageCode != 'unknown') {
          languages.add(link.languageCode);
        }
      }
      if (languages.isEmpty && watchLinks.isNotEmpty) {
        languages.add('vf');
      }
    } else {
      for (final episode in episodes) {
        languages.addAll(episode.availableLanguages);
      }
      if (languages.isEmpty && episodes.isNotEmpty) {
        final hasPlayableLinks = episodes.any(
          (episode) => episode.watchLinks.isNotEmpty,
        );
        if (hasPlayableLinks) {
          languages.add('vf');
        }
      }
    }
    final sorted = languages.toList();
    sorted.sort((left, right) {
      const order = <String, int>{'vf': 0, 'vostfr': 1, 'unknown': 2};
      return (order[left] ?? 99).compareTo(order[right] ?? 99);
    });
    return sorted;
  }

  String get languageTag {
    if (isFilm) {
      return _resolveLanguageTag(watchLinks);
    }

    for (final episode in episodes) {
      final tag = _resolveLanguageTag(episode.watchLinks);
      if (tag.isNotEmpty) {
        return tag;
      }
    }
    return '';
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static List<int> _toIntList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    final items = value
        .map(_toInt)
        .whereType<int>()
        .where((item) => item > 0)
        .toSet()
        .toList();
    items.sort();
    return items;
  }

  factory Content.fromJson(Map<String, dynamic> json) {
    final watchLinks = (json['watch_links'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WatchLink.fromJson)
        .toList();

    final episodes = (json['episodes'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Episode.fromJson)
        .toList();

    final seasons = <int, List<Episode>>{};
    if (json['seasons'] is Map) {
      (json['seasons'] as Map).forEach((key, value) {
        final seasonNumber = int.tryParse(key.toString()) ?? 1;
        if (value is List) {
          seasons[seasonNumber] = value
              .whereType<Map<String, dynamic>>()
              .map(Episode.fromJson)
              .toList();
        }
      });
    } else {
      for (final episode in episodes) {
        seasons.putIfAbsent(episode.season, () => <Episode>[]).add(episode);
      }
    }

    final allProgress = json['all_progress'] as List?;
    if (allProgress != null) {
      for (final progress in allProgress) {
        if (progress is Map<String, dynamic>) {
          final epId = progress['episode_id']?.toString();
          final perc = _toDouble(progress['progress_percent']);
          if (epId != null && perc != null) {
            for (final epList in seasons.values) {
              for (final ep in epList) {
                if ('S${ep.season}E${ep.episode}' == epId) {
                  ep.progressPercent = perc;
                }
              }
            }
          }
        }
      }
    }

    final genres = (json['genres'] as List? ?? const [])
        .map((item) => item.toString())
        .toList();

    final keywords = (json['keywords'] as List? ?? const [])
        .map((item) => item.toString())
        .toList();

    final similar = (json['similar'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Content.fromJson)
        .where((c) => c.hasPoster)
        .toList();

    final rawId = json['id'] ?? json['content_id'];

    return Content(
      id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      cpasmieuxId: json['cpasmieux_id']?.toString(),
      title: _unescapeHtml(json['title']?.toString() ?? 'Sans titre'),
      description: json['description'] != null
          ? _unescapeHtml(json['description'].toString())
          : null,
      contentType: json['content_type']?.toString() ?? 'film',
      genres: genres,
      rating: _toDouble(json['rating']) ?? 0,
      releaseDate: _toInt(json['release_date']),
      poster: json['poster']?.toString(),
      posterUrl: json['poster_url']?.toString(),
      watchLinks: watchLinks,
      episodes: episodes,
      seasons: seasons,
      seasonCount: _toInt(json['season_count']) ?? seasons.length,
      episodeCount: _toInt(json['episode_count']) ?? episodes.length,
      urlSite: json['url_site']?.toString(),
      keywords: keywords,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      rank: _toInt(json['rank']),
      todayViews: _toInt(json['today_views']),
      trend: json['trend']?.toString(),
      matchPercent: _toInt(json['match_percent']),
      progressPercent: _toDouble(json['progress_percent']),
      currentEpisodeId: json['episode_id']?.toString(),
      seriesBaseTitle: json['series_base_title']?.toString(),
      availableSeasons: _toIntList(json['available_seasons']),
      missingSeasons: _toIntList(json['missing_seasons']),
      mergedVariantCount: _toInt(json['merged_variant_count']) ?? 1,
      hasDetachedSeasons: json['has_detached_seasons'] == true,
      autoMerged: json['auto_merged'] == true,
      inLibrary: json['in_library'] == true,
      isPremiumContent: json['is_premium_content'] != false,
      similar: similar,
      userProgress: json['user_progress'] as Map<String, dynamic>?,
      allProgress: allProgress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cpasmieux_id': cpasmieuxId,
      'title': title,
      'description': description,
      'content_type': contentType,
      'genres': genres,
      'rating': rating,
      'release_date': releaseDate,
      'poster': poster,
      'poster_url': posterUrl,
      'season_count': seasonCount,
      'episode_count': episodeCount,
      'url_site': urlSite,
      'keywords': keywords,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'rank': rank,
      'today_views': todayViews,
      'trend': trend,
      'match_percent': matchPercent,
      'progress_percent': progressPercent,
      'episode_id': currentEpisodeId,
      'series_base_title': seriesBaseTitle,
      'available_seasons': availableSeasons,
      'missing_seasons': missingSeasons,
      'merged_variant_count': mergedVariantCount,
      'has_detached_seasons': hasDetachedSeasons,
      'auto_merged': autoMerged,
      'in_library': inLibrary,
      'is_premium_content': isPremiumContent,
    };
  }
}

String _unescapeHtml(String text) {
  return text
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#x2F;', '/');
}

class WatchLink {
  final String url;
  final String server;
  final String language;
  final String domain;

  WatchLink({
    required this.url,
    required this.server,
    this.language = 'unknown',
    this.domain = '',
  });

  factory WatchLink.fromJson(Map<String, dynamic> json) {
    return WatchLink(
      url: json['url']?.toString() ?? '',
      server: json['server']?.toString() ?? 'Unknown',
      language: json['language']?.toString() ?? 'unknown',
      domain: json['domain']?.toString() ?? '',
    );
  }

  String get serverName {
    final normalized = server.toLowerCase();
    if (normalized.contains('uqload')) {
      return 'Uqload';
    }
    if (normalized.contains('voe')) {
      return 'Voe';
    }
    if (normalized.contains('vidzy')) {
      return 'Vidzy';
    }
    if (normalized.contains('netu')) {
      return 'Netu';
    }
    if (normalized.contains('dood')) {
      return 'Doodstream';
    }
    return server;
  }

  String get languageTag {
    if (languageCode == 'vostfr') {
      return 'VOSTFR';
    }
    if (languageCode == 'vf') {
      return 'VF';
    }
    return '';
  }

  String get languageCode {
    final normalized = language.toLowerCase().trim();
    if (normalized.contains('vostfr') || normalized.contains('vost')) {
      return 'vostfr';
    }
    if (normalized == 'vf' ||
        normalized == 'fr' ||
        normalized.contains('truefrench') ||
        normalized.contains('french') ||
        normalized.contains('francais') ||
        normalized.contains('français')) {
      return 'vf';
    }

    final haystack = '$language $server $domain $url'.toUpperCase();
    if (haystack.trim().isEmpty) {
      return 'unknown';
    }
    if (haystack.contains('VOSTFR') || haystack.contains('VOST')) {
      return 'vostfr';
    }
    if (RegExp(
      r'(?:^|[^A-Z])VF(?:[^A-Z]|$)|TRUEFRENCH|FRENCH|FRANCAIS|FRANÇAIS',
    ).hasMatch(haystack)) {
      return 'vf';
    }
    return 'vf';
  }

  bool matchesLanguage(String languageCode) =>
      this.languageCode == languageCode;
}

class Episode {
  final int season;
  final int episode;
  final String title;
  final String? url;
  final List<WatchLink> watchLinks;
  double? progressPercent;

  Episode({
    required this.season,
    required this.episode,
    required this.title,
    this.url,
    this.watchLinks = const [],
    this.progressPercent,
  });

  String get label => 'S$season E$episode';
  String get fullLabel => '$label - $title';
  List<String> get availableLanguages {
    final languages = <String>{};
    for (final link in watchLinks) {
      if (link.languageCode != 'unknown') {
        languages.add(link.languageCode);
      }
    }
    if (languages.isEmpty && watchLinks.isNotEmpty) {
      languages.add('vf');
    }
    final sorted = languages.toList();
    sorted.sort((left, right) {
      const order = <String, int>{'vf': 0, 'vostfr': 1, 'unknown': 2};
      return (order[left] ?? 99).compareTo(order[right] ?? 99);
    });
    return sorted;
  }

  String get languageTag {
    return _resolveLanguageTag(watchLinks);
  }

  factory Episode.fromJson(Map<String, dynamic> json) {
    final watchLinks = (json['watch_links'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WatchLink.fromJson)
        .toList();

    return Episode(
      season: Content._toInt(json['season']) ?? 1,
      episode: Content._toInt(json['episode']) ?? 1,
      title: _unescapeHtml(json['title']?.toString() ?? 'Episode inconnu'),
      url: json['url']?.toString(),
      watchLinks: watchLinks,
    );
  }
}

String _resolveLanguageTag(List<WatchLink> links) {
  if (links.isEmpty) {
    return '';
  }

  final codes = links
      .map((link) => link.languageCode)
      .where((code) => code != 'unknown')
      .toSet();

  if (codes.contains('vf')) {
    return 'VF';
  }
  if (codes.contains('vostfr')) {
    return 'VOSTFR';
  }
  return 'VF';
}
