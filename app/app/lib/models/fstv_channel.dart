import 'package:flutter/material.dart';

/// Une chaîne IPTV NEO-STREAM FSTV.
///
/// Format API :
///   {slug, name, category, logo, sources: [{url, label, is_free}]}
class FstvChannel {
  final String slug;
  final String name;
  final String category;
  final String? logo;
  final List<Map<String, dynamic>> sources;

  const FstvChannel({
    required this.slug,
    required this.name,
    required this.category,
    this.logo,
    this.sources = const [],
  });

  /// ID legacy (hash du slug pour compatibilité)
  int get id => slug.hashCode.abs();

  factory FstvChannel.fromJson(Map<String, dynamic> json) {
    final slug = (json['slug'] as String?)?.trim() ?? '';
    final name = (json['name'] as String?)?.trim() ?? 'Chaîne';
    final category = (json['category'] as String?)?.trim() ?? 'Autre';
    final logo = (json['logo'] as String?)?.trim();
    final rawSources = json['sources'];
    final sources = <Map<String, dynamic>>[];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is Map) {
          sources.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return FstvChannel(
      slug: slug,
      name: name,
      category: category,
      logo: logo,
      sources: sources,
    );
  }

  /// Devine la catégorie d'une chaîne à partir de son nom et slug.
  static String _guessCategory(String name, String slug) {
    final s = '${name.toLowerCase()} ${slug.toLowerCase()}';
    if (s.contains('bein') || s.contains('sport') || s.contains('canal') &&
        (s.contains('sport') || s.contains('foot') || s.contains('golf') ||
         s.contains('motogp') || s.contains('formula') || s.contains('ligue'))) {
      return 'Sport';
    }
    if (s.contains('sport') || s.contains('bein') || s.contains('rmc') ||
        s.contains('dazn') || s.contains('eurosport') || s.contains('equipe') ||
        s.contains('foot') || s.contains('golf') || s.contains('motogp') ||
        s.contains('ligue') || s.contains('formula') || s.contains('rugby')) {
      return 'Sport';
    }
    if (s.contains('ciné') || s.contains('cine') || s.contains('film') ||
        s.contains('movie') || s.contains('action') || s.contains('fx')) {
      return 'Cinéma';
    }
    if (s.contains('info') || s.contains('news') || s.contains('actu') ||
        s.contains('bfm') || s.contains('lci') || s.contains('france 24') ||
        s.contains('cnews') || s.contains('lcp')) {
      return 'Info';
    }
    if (s.contains('jeun') || s.contains('enfant') || s.contains('kids') ||
        s.contains('child') || s.contains('family') || s.contains('cartoon') ||
        s.contains('disney') || s.contains('gulli') || s.contains('boomerang') ||
        s.contains('nickelodeon') || s.contains('piwi') || s.contains('teletoon')) {
      return 'Enfants';
    }
    if (s.contains('doc') || s.contains('discov') || s.contains('nature') ||
        s.contains('science') || s.contains('planete') || s.contains('ushuaia') ||
        s.contains('animaux') || s.contains('rage') || s.contains('voyage') ||
        s.contains('trek') || s.contains('season') || s.contains('chasse')) {
      return 'Documentaire';
    }
    if (s.contains('musi') || s.contains('music') || s.contains('mtv') ||
        s.contains('mcm') || s.contains('nrj') || s.contains('melody') ||
        s.contains('mezzo')) {
      return 'Musique';
    }
    if (s.contains('tf1') || s.contains('france 2') || s.contains('france 3') ||
        s.contains('m6') || s.contains('w9') || s.contains('arte') ||
        s.contains('c8') || s.contains('cstar') || s.contains('tmc') ||
        s.contains('tf1') || s.contains('gulli') || s.contains('6ter') ||
        s.contains('rtl') || s.contains('tfx') || s.contains('ab1') ||
        s.contains('paris') || s.contains('comedie')) {
      return 'Généralistes';
    }
    return 'Généralistes';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FstvChannel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FstvChannel($id, "$name", "$category")';

  // ── Métadonnées d'affichage par catégorie ──────────────────────────────

  /// Icône Material représentant la catégorie de la chaîne.
  IconData get categoryIcon => _categoryMeta(category).icon;

  /// Couleur d'accent associée à la catégorie (utilisée pour l'icône / glow).
  Color get categoryColor => _categoryMeta(category).color;

  /// Initialise de chaîne (lettre) pour l'avatar quand aucun logo n'existe.
  String get initial {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').trim();
    return cleaned.isEmpty ? 'TV' : cleaned[0].toUpperCase();
  }

  static ({IconData icon, Color color}) _categoryMeta(String category) {
    final c = category.toLowerCase();
    if (c.contains('sport')) {
      return (icon: Icons.sports_soccer_rounded, color: const Color(0xFF22C55E));
    }
    if (c.contains('ciné') || c.contains('cine') || c.contains('film') ||
        c.contains('movie')) {
      return (icon: Icons.movie_filter_rounded, color: const Color(0xFFA855F7));
    }
    if (c.contains('jeun') || c.contains('enfant') || c.contains('kids') ||
        c.contains('child') || c.contains('family') || c.contains('anim')) {
      return (icon: Icons.abc_rounded, color: const Color(0xFF10B981));
    }
    if (c.contains('info') || c.contains('news') || c.contains('actu')) {
      return (icon: Icons.newspaper_rounded, color: const Color(0xFF3B82F6));
    }
    if (c.contains('musi') || c.contains('music')) {
      return (icon: Icons.music_note_rounded, color: const Color(0xFFF59E0B));
    }
    if (c.contains('doc') || c.contains('discov') || c.contains('nature') ||
        c.contains('science')) {
      return (icon: Icons.public_rounded, color: const Color(0xFF06B6D4));
    }
    if (c.contains('géné') || c.contains('general')) {
      return (icon: Icons.live_tv_rounded, color: const Color(0xFFE50914));
    }
    return (icon: Icons.tv_rounded, color: const Color(0xFF6B7280));
  }
}
