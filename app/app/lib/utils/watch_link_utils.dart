import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/content.dart';

class WatchLinkUtils {
  // ── Serveurs extractables (lecture directe HLS/MP4, sans pub) ──────────────
  static const _extractablePatterns = [
    'm3u8', '.mp4',
    'vidaraa.cc',
    'vidsonic.net',
    'savefiles.com',
    'vidmoly.biz', 'vidmoly.to',
    'minochinos.com',
    'uqload.is', 'uqload.bz', 'uqload.org', 'uqload.co', 'uqload.to', 'uqload.net',
    'uqload',
    'vidzy.cc', 'vidzy.live', 'vidzy.org',
    'filemoon.to', 'filemoon.sx', 'filemoon.in', 'filmoon', 'moonmov',
    'mixdrop.co', 'mixdrop.ag', 'mixdrop.sb', 'mxdrop.',
    'streamtape.com', 'streamtape.net',
    'vidoza.net', 'vidoza.org',
    'videovard.sx', 'vido.lol', 'vido.to',
    'mp4upload.com',
    'ok.ru', 'odnoklassniki.ru',
    'vk.com', 'vk.ru',
    'dailymotion.com', 'dai.ly',
    'streamsb.', 'sbplay', 'sblanh', 'sbfast', 'sbjoy', 'sbemb', 'sbrity',
    'vidguard.', 'listeamed.', 'bembed.', 'vgfplay.', 'vgembed.',
    'smashystream.com',
    'ninjastream.to', 'ninjastream.eu',
    'yourupload',
    'uptostream.com', 'uptostream.eu',
    'hlsplay.com', 'evoload.io', 'streamdav.com',
    'chillx.to',
    'kwik.si', 'kwik.cx',
  ];

  // ── Serveurs iframe-only (lecture via WebView) ─────────────────────────────
  static const _iframeOnlyPatterns = [
    'luluvdo.com', 'luluvid.com', 'lulustream',
    'bryantenunder.com', 'vickisaveworker.com', 'rebeccacostthousand.com',
    'aprilasat.cyou', 'tipfly.xyz',
    'flemmix.upns.pro', 'serix.upns.live', 'flemmix.online',
    'hgcloud.to',
    'playmogo.com',
    'xshotcok.com',
    'up4fun.top',
    'vudeo.ws',
    'waaw.to',
  ];

  static List<WatchLink> prioritize(
    List<WatchLink> links, {
    String? preferredLanguage,
  }) {
    final ranked = links
        .where((link) => link.url.trim().isNotEmpty)
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
    final cores = kIsWeb ? 2 : Platform.numberOfProcessors;
    if (cores <= 4) {
      return 1;
    }
    if (cores <= 8) {
      return 2;
    }
    return 3;
  }

  static bool isExtractable(WatchLink link) {
    final src = _normalizeSource(link);
    return _extractablePatterns.any((p) => src.contains(p));
  }

  static bool isIframeOnly(WatchLink link) {
    final src = _normalizeSource(link);
    return _iframeOnlyPatterns.any((p) => src.contains(p));
  }

  /// Retire les liens iframe-only et les URLs vides avant extraction.
  static List<WatchLink> filterPlayable(List<WatchLink> links) {
    return links
        .where((link) => link.url.trim().isNotEmpty && !isIframeOnly(link))
        .toList();
  }

  static String serverDisplayName(WatchLink link) {
    final domain = _extractDomain(link);
    if (domain.contains('vidaraa'))   return 'Vidaraa';
    if (domain.contains('vidsonic'))  return 'Vidsonic';
    if (domain.contains('savefiles')) return 'Savefiles';
    if (domain.contains('vidmoly'))   return 'Vidmoly';
    if (domain.contains('minochinos'))return 'Minochinos';
    if (domain.contains('uqload'))    return 'Uqload';
    if (domain.contains('luluvdo') || domain.contains('luluvid')) return 'Lulu';
    if (domain.contains('bryantenunder') || domain.contains('voe')) return 'Voe';
    if (domain.contains('upns.pro') || domain.contains('upns.live')) return 'FMX';
    if (domain.contains('hgcloud'))   return 'Hxfile';
    if (domain.contains('playmogo'))  return 'DoodStream';
    if (domain.contains('vidzy'))     return 'Vidzy';
    if (domain.contains('filemoon') || domain.contains('filmoon')) return 'Filemoon';
    if (domain.contains('mixdrop') || domain.contains('mxdrop'))   return 'Mixdrop';
    if (domain.contains('streamtape'))return 'Streamtape';
    if (domain.contains('vidoza'))    return 'Vidoza';
    if (link.server.trim().isNotEmpty && link.server != 'Unknown') return link.server;
    return domain.isNotEmpty ? domain.split('.').first : 'Lecteur';
  }

  static int score(WatchLink link, {String? preferredLanguage}) {
    final languageCode = link.languageCode;
    final normalizedPreferred = preferredLanguage?.trim().toLowerCase();
    var total = _domainScore(link);

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
    final src = _normalizeSource(link);
    if (src.contains('https://https://')) return 12;

    // Direct streams — highest priority
    if (src.contains('.m3u8') || src.contains('.mp4')) return 350;

    // Extractable servers (sans pub) — high priority
    if (src.contains('vidaraa.cc'))    return 320;
    if (src.contains('vidsonic.net'))  return 310;
    if (src.contains('savefiles.com')) return 300;
    if (src.contains('vidmoly'))       return 295;
    if (src.contains('minochinos'))    return 290;
    if (src.contains('uqload'))        return 280;
    if (src.contains('vidzy'))         return 270;
    if (src.contains('filemoon') || src.contains('filmoon')) return 260;
    if (src.contains('mixdrop') || src.contains('mxdrop'))   return 250;
    if (src.contains('streamsb') || src.contains('sbplay'))  return 240;
    if (src.contains('streamtape'))    return 230;
    if (src.contains('vidoza'))        return 220;
    if (src.contains('voe.sx') || src.contains('dianaavoidthey')) return 200;

    // Iframe-only — lower priority
    if (src.contains('luluvdo') || src.contains('luluvid')) return 120;
    if (src.contains('bryantenunder') || src.contains('tipfly')) return 110;
    if (src.contains('upns.pro') || src.contains('upns.live') || src.contains('flemmix.online')) return 100;
    if (src.contains('hgcloud'))  return 90;
    if (src.contains('playmogo')) return 80;
    if (src.contains('xshotcok') || src.contains('up4fun') || src.contains('vudeo') || src.contains('waaw')) return 70;

    return 150; // default for unknown domains
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
