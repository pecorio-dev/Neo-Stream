import '../models/content.dart';
import '../models/movie.dart';
import 'stream_extractor.dart';

/// Service pour résoudre les liens de visionnage
class WatchLinkResolver {
  static const List<String> _preferredServers = [
    'UQLOAD',
    'STREAMTAPE',
    'DOODSTREAM',
    'MIXDROP',
  ];

  /// Résout le meilleur lien de visionnage depuis une liste de WatchLink (focus Uqload)
  static Future<StreamInfo?> resolveBestWatchLink(List<WatchLink> watchLinks) async {
    if (watchLinks.isEmpty) {
      return null;
    }

    // Filtrer pour ne garder que les liens Uqload supportés
    final uqloadLinks = watchLinks.where((link) => 
      (link.server?.toUpperCase().contains('UQLOAD') == true) || 
      (link.url?.contains('uqload') == true)
    ).toList();
    
    if (uqloadLinks.isEmpty) {
      print('⚠️ Aucun lien Uqload trouvé dans la liste');
      return null;
    }

    // Trier les liens Uqload par préférence
    final sortedLinks = _sortWatchLinksByPreference(uqloadLinks);
    
    final extractor = FastDirectExtractor();
    
    // Essayer chaque lien Uqload dans l'ordre de préférence
    for (final watchLink in sortedLinks) {
      try {
        print('🚀 Tentative d\'extraction Uqload depuis ${watchLink.server}: ${watchLink.url}');
        
        // Utiliser l'extracteur Uqload avancé
        final streamInfo = await extractor.extractStreamInfo(watchLink.url);
        print('✅ Succès extraction ${watchLink.server}: ${streamInfo.url}');
        print('🔧 Headers: ${streamInfo.headers}');
        
        extractor.dispose();
        return streamInfo;
        
      } catch (e) {
        print('❌ Échec extraction ${watchLink.server}: $e');
        continue;
      }
    }
    
    extractor.dispose();
    print('❌ Aucun lien Uqload n\'a pu être extrait');
    return null;
  }

  /// Trie les liens par ordre de préférence
  static List<WatchLink> _sortWatchLinksByPreference(List<WatchLink> watchLinks) {
    final List<WatchLink> sorted = List.from(watchLinks);
    
    sorted.sort((a, b) {
      final aIndex = _preferredServers.indexOf(a.server?.toUpperCase() ?? '');
      final bIndex = _preferredServers.indexOf(b.server?.toUpperCase() ?? '');
      
      // Si les deux serveurs sont dans la liste de préférence
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }
      
      // Si seulement a est dans la liste de préférence
      if (aIndex != -1) {
        return -1;
      }
      
      // Si seulement b est dans la liste de préférence
      if (bIndex != -1) {
        return 1;
      }
      
      // Si aucun n'est dans la liste, garder l'ordre original
      return 0;
    });
    
    return sorted;
  }

  /// Obtient la meilleure URL directement (pour compatibilité)
  static Future<String?> getBestStreamUrl(List<WatchLink> watchLinks) async {
    final streamInfo = await resolveBestWatchLink(watchLinks);
    return streamInfo?.url;
  }

  /// Vérifie si un serveur est supporté (uniquement Uqload maintenant)
  static bool isServerSupported(String? server) {
    return server?.toUpperCase().contains('UQLOAD') == true;
  }

  /// Filtre les liens pour ne garder que les serveurs supportés (Uqload uniquement)
  static List<WatchLink> filterSupportedLinks(List<WatchLink> watchLinks) {
    final supportedLinks = watchLinks.where((link) => 
      isServerSupported(link.server) || (link.url?.contains('uqload') == true)
    ).toList();
    
    print('🔍 Liens supportés trouvés: ${supportedLinks.length}/${watchLinks.length}');
    for (final link in supportedLinks) {
      print('  - ${link.server ?? 'Unknown'}: ${link.url ?? 'No URL'}');
    }
    
    return supportedLinks;
  }
}