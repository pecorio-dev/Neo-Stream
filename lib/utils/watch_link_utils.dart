import 'dart:io';

import '../models/content.dart';

class WatchLinkUtils {
  static const List<_DomainPriority> _domainPriorities = [
    _DomainPriority(patterns: ['m3u8', '.mp4'], score: 300),
    _DomainPriority(patterns: ['uqload'], score: 280),
    _DomainPriority(patterns: ['vidzy'], score: 260),
  ];

  static List<WatchLink> prioritize(
    List<WatchLink> links, {
    String? preferredLanguage,
  }) {
    // Ne garder QUE Uqload et Vidzy (et les liens directs m3u8/mp4)
    // Ces serveurs sont les SEULS supportés par l'API Python externe
    final allowedPatterns = ['m3u8', '.mp4', 'uqload', 'vidzy'];
    
    final ranked = links
        .where((link) => link.url.trim().isNotEmpty)
        .where((link) {
          final source = _normalizeSource(link);
          return allowedPatterns.any((pattern) => source.contains(pattern));
        })
        .toList(growable: true);

    ranked.sort(
      (left, right) => score(
        right,
        preferredLanguage: preferredLanguage,
      ).compareTo(score(left, preferredLanguage: preferredLanguage)),
    );

    final seen = <String>{};
    return ranked.where((link) => seen.add(sourceSignature(link))).toList();
  }

  static List<String> sortLanguages(Iterable<String> languages) {
    final normalized = languages
        .map((language) => language.trim().toLowerCase())
        .where((language) => language.isNotEmpty)
        .toSet()
        .toList(growable: true);

    const order = <String, int>{'vf': 0, 'vostfr': 1, 'unknown': 2};

    normalized.sort(
      (left, right) => (order[left] ?? 99).compareTo(order[right] ?? 99),
    );
    return normalized;
  }

  static String defaultLanguage(Iterable<String> languages) {
    final sorted = sortLanguages(
      languages.where((language) => language != 'unknown'),
    );
    if (sorted.contains('vf')) {
      return 'vf';
    }
    if (sorted.contains('vostfr')) {
      return 'vostfr';
    }
    return sorted.isNotEmpty ? sorted.first : 'vf';
  }

  static String labelForLanguage(String languageCode) {
    switch (languageCode.trim().toLowerCase()) {
      case 'vf':
        return 'VF';
      case 'vostfr':
        return 'VOSTFR';
      default:
        return 'Auto';
    }
  }

  static int recommendedParallelism() {
    final cores = Platform.numberOfProcessors;
    if (cores <= 4) {
      return 1;
    }
    if (cores <= 8) {
      return 2;
    }
    return 3;
  }

  static int score(WatchLink link, {String? preferredLanguage}) {
    final languageCode = link.languageCode;
    final normalizedPreferred = preferredLanguage?.trim().toLowerCase();
    var total = _domainScore(link) + _serverHintScore(link);

    if (normalizedPreferred != null && normalizedPreferred.isNotEmpty) {
      if (languageCode == normalizedPreferred) {
        total += 90;
      } else if (languageCode == 'unknown') {
        total += 30;
      }
    }

    if (link.url.contains('.m3u8') || link.url.contains('.mp4')) {
      total += 120;
    }

    return total;
  }

  static String sourceSignature(WatchLink link) {
    return '${_normalizeSource(link)}|${link.server.toLowerCase()}|${link.url.toLowerCase()}';
  }

  static String sourceLabel(WatchLink link) {
    final domain = _extractDomain(link);
    if (domain.isNotEmpty) {
      return domain;
    }
    return link.serverName;
  }

  static int _domainScore(WatchLink link) {
    final source = _normalizeSource(link);
    if (source.contains('https://https://')) {
      return 12;
    }
    for (final priority in _domainPriorities) {
      if (priority.matches(source)) {
        return priority.score;
      }
    }
    return 120;
  }

  static int _serverHintScore(WatchLink link) {
    final server = link.server.toLowerCase();
    if (server.contains('multi') || server.contains('embed')) {
      return 6;
    }
    return 0;
  }

  static String _normalizeSource(WatchLink link) {
    return '${_extractDomain(link)} ${link.server.toLowerCase()} ${link.url.toLowerCase()}';
  }

  static String _extractDomain(WatchLink link) {
    if (link.domain.trim().isNotEmpty) {
      return link.domain.trim().toLowerCase();
    }
    return Uri.tryParse(link.url)?.host.toLowerCase() ?? '';
  }
}

class _DomainPriority {
  final List<String> patterns;
  final int score;

  const _DomainPriority({required this.patterns, required this.score});

  bool matches(String source) {
    for (final pattern in patterns) {
      if (source.contains(pattern)) {
        return true;
      }
    }
    return false;
  }
}
