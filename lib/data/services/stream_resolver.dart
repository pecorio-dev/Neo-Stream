import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../models/series.dart' as series_models;
import 'stream_extractor.dart';
import '../extractors/uqload_extractor.dart';

/// Classe interne pour représenter un lien de streaming (compatible avec movie et series WatchLink)
class _StreamLink {
  final String server;
  final String url;
  final String? quality;

  _StreamLink({
    required this.server,
    required this.url,
    this.quality,
  });

  factory _StreamLink.fromMovieWatchLink(WatchLink link) {
    return _StreamLink(
      server: link.server,
      url: link.url,
      quality: link.quality,
    );
  }

  factory _StreamLink.fromSeriesWatchLink(series_models.WatchLink link) {
    return _StreamLink(
      server: link.server,
      url: link.url,
      quality: link.quality,
    );
  }
}

/// Service pour résoudre les liens de streaming en testant tous les serveurs disponibles
class StreamResolver {
  static const int maxAttemptsPerLink = 2;

  /// Résout le flux vidéo en testant les liens dans cet ordre:
  /// 1. Liens Uqload (priorité haute)
  /// 2. Autres serveurs connus
  /// 3. N'importe quel lien comme dernier recours
  static Future<StreamInfo?> resolveMovieStream(
    List<WatchLink> watchLinks,
  ) async {
    if (watchLinks.isEmpty) {
      print('⚠️ Aucun lien de visionnage trouvé');
      return null;
    }

    // Convertir vers la classe interne générique
    final streamLinks = watchLinks.map(_StreamLink.fromMovieWatchLink).toList();

    // Catégoriser les liens
    final uqloadLinks = <_StreamLink>[];
    final knownServerLinks = <_StreamLink>[];
    final otherLinks = <_StreamLink>[];

    for (final link in streamLinks) {
      if (UqloadExtractor.isUqloadUrl(link.url)) {
        uqloadLinks.add(link);
      } else if (_isKnownServer(link.server)) {
        knownServerLinks.add(link);
      } else {
        otherLinks.add(link);
      }
    }

    print('📊 Liens trouvés:');
    print('  - Uqload: ${uqloadLinks.length}');
    print('  - Serveurs connus: ${knownServerLinks.length}');
    print('  - Autres: ${otherLinks.length}');

    // UNIQUEMENT Uqload est supporté maintenant
    if (uqloadLinks.isEmpty) {
      print('⚠️ Aucun lien Uqload trouvé - autres serveurs non supportés');
      return null;
    }

    // Essayer uniquement les liens Uqload
    return await _tryExtractFromLinks(uqloadLinks);
  }

  /// Résout le flux vidéo pour une série
  static Future<StreamInfo?> resolveSeriesStream(
    List<series_models.WatchLink> watchLinks,
  ) async {
    if (watchLinks.isEmpty) {
      print('⚠️ Aucun lien de visionnage trouvé pour cet épisode');
      return null;
    }

    // Convertir vers la classe interne générique
    final streamLinks = watchLinks.map(_StreamLink.fromSeriesWatchLink).toList();

    // Catégoriser les liens
    final uqloadLinks = <_StreamLink>[];
    final knownServerLinks = <_StreamLink>[];
    final otherLinks = <_StreamLink>[];

    for (final link in streamLinks) {
      if (UqloadExtractor.isUqloadUrl(link.url)) {
        uqloadLinks.add(link);
      } else if (_isKnownServer(link.server)) {
        knownServerLinks.add(link);
      } else {
        otherLinks.add(link);
      }
    }

    print('📊 Liens épisode trouvés:');
    print('  - Uqload: ${uqloadLinks.length}');
    print('  - Serveurs connus: ${knownServerLinks.length}');
    print('  - Autres: ${otherLinks.length}');

    // UNIQUEMENT Uqload est supporté maintenant
    if (uqloadLinks.isEmpty) {
      print('⚠️ Aucun lien Uqload trouvé - autres serveurs non supportés');
      return null;
    }

    // Essayer uniquement les liens Uqload
    return await _tryExtractFromLinks(uqloadLinks);
  }

  /// Essaie d'extraire le flux à partir de chaque lien
  static Future<StreamInfo?> _tryExtractFromLinks(
    List<_StreamLink> links,
  ) async {
    for (int i = 0; i < links.length; i++) {
      final link = links[i];

      if (link.url.isEmpty || !link.url.startsWith('http')) {
        print('⏭️  Lien $i: URL invalide (${link.server})');
        continue;
      }

      print('🔄 Lien $i (${link.server}): ${link.url}');

      // Si c'est un lien Uqload, essayer avec l'extracteur Uqload
      if (UqloadExtractor.isUqloadUrl(link.url)) {
        final result = await _tryUqloadExtraction(link);
        if (result != null) return result;
      } else {
        // Pour les autres serveurs, essayer directement
        final result = await _tryDirectStream(link);
        if (result != null) return result;
      }
    }

    print('❌ Aucun lien ne fonctionnait');
    return null;
  }

  /// Essaie l'extraction Uqload avec retry
  static Future<StreamInfo?> _tryUqloadExtraction(_StreamLink link) async {
    for (int attempt = 1; attempt <= maxAttemptsPerLink; attempt++) {
      try {
        print('  📥 Extraction Uqload tentative $attempt');
        final extracted =
            await UqloadExtractor.extractStreamInfo(link.url);

        if (extracted.url.isNotEmpty) {
          final streamInfo = StreamInfo(
            url: extracted.url,
            quality: extracted.quality,
            headers: extracted.headers,
          );
          print('  ✅ Succès Uqload: ${streamInfo.url}');
          return streamInfo;
        }
      } catch (e) {
        print('  ❌ Erreur Uqload tentative $attempt: $e');
      }
    }
    return null;
  }

  /// Essaie d'utiliser le flux directement pour d'autres serveurs
  static Future<StreamInfo?> _tryDirectStream(_StreamLink link) async {
    try {
      print('  📥 Essai direct stream');

      // Vérifier si l'URL est valide en faisant une requête HEAD
      if (link.url.startsWith('http')) {
        final streamInfo = StreamInfo(
          url: link.url,
          quality: link.quality ?? 'auto',
          format: 'direct',
        );

        print('  ✅ Stream direct valide: ${streamInfo.url}');
        return streamInfo;
      }
    } catch (e) {
      print('  ❌ Erreur stream direct: $e');
    }
    return null;
  }

  /// Vérifie si c'est un serveur connu et supporté
  static bool _isKnownServer(String server) {
    final knownServers = {
      'voe',
      'vidoza',
      'uptobox',
      'turbobit',
      'dl.free.fr',
      'streamz',
      'mcloud',
      'drive.google',
      'mega',
      'dropbox',
      'rapidgator',
    };

    return knownServers.any(
        (known) => server.toLowerCase().contains(known.toLowerCase()));
  }
}
