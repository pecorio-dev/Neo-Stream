import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Neo-Stream Video Extractor — v2
/// Couverture ~90% des hébergeurs francophones
class VideoExtractor {
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> _headers({String? referer}) => {
        'User-Agent': _ua,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8',
        'Connection': 'keep-alive',
        if (referer != null) 'Referer': referer,
      };

  // ─────────────────────────────────────────────────────────────────
  // POINT D'ENTRÉE
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> extract(String url) async {
    final server = detectServer(url);
    try {
      final result = await _dispatch(server, url);
      if (result['success'] == true) return result;
      // Si l'extracteur dédié échoue → fallback générique
      if (server != 'unknown') return await _extractGeneric(url);
      return result;
    } catch (e) {
      return {'error': 'Extraction failed: $e', 'server': server};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DÉTECTION
  // ─────────────────────────────────────────────────────────────────

  static String detectServer(String url) {
    final u = url.toLowerCase();
    // PROXY: kakaflix / kokoflix / sequoia — proxy domains that redirect to real players
    if (RegExp(r'kakaflix\.lol|kokoflix\.lol|sequoia\.lol').hasMatch(u)) return 'proxy';
    // UQLOAD — exact PHP domains
    if (RegExp(r'uqload\.(bz|is|org|co|to)').hasMatch(u)) return 'uqload';
    // VOE — voe.sx + all its JS-redirect alias domains (from PHP)
    if (RegExp(r'voe\.sx|dianaavoidthey\.com|lancewhosedifficult\.com|sandratableother\.com|maxfinishseveral\.com|alejandrocenturyoil\.com|voe\.monster|voe\.bar|voe\.click|voe\.ninja|voe\.lol|voe\.pm|voe\.wtf|voe\.earth|voe\.xyz|voe\.wiki|voe\.party|voe\.bond').hasMatch(u)) return 'voe';
    // DOODSTREAM — exact PHP domains (do7go added, kokoflix/kakaflix removed)
    if (RegExp(r'do7go\.com|dood\.(li|wf|pm|ws|re|to)|myvidplay\.com|dsvplay\.com|doodstream|d0o0d|d000d|do0od|ds2play|doods|dooood|vvide0|playmogo|doo\.cx|d0000d|vidveto').hasMatch(u)) return 'doodstream';
    // FILEMOON — exact PHP domains (luluvid/lulustream/luluvdo added, bysebuho moved to netu)
    if (RegExp(r'filemoon\.(to|sx|in)|luluvid\.com|lulustream|luluvdo\.com|filmoon|f75s|moonmov|kerapxy').hasMatch(u)) return 'filemoon';
    // NETU — exact PHP domains: bysebuho / younetu / bysewihe
    if (RegExp(r'bysebuho\.com|younetu\.com|bysewihe\.com').hasMatch(u)) return 'netu';
    // VIDZY — exact PHP domains
    if (RegExp(r'vidzy\.(live|org)').hasMatch(u)) return 'vidzy';
    // MIXDROP — exact PHP domains (mxdrop added)
    if (RegExp(r'mixdrop\.(co|ag|sb|to)|mxdrop\.(co|ag|sb|to)').hasMatch(u)) return 'mixdrop';
    // STREAMTAPE — exact PHP domains
    if (RegExp(r'streamtape\.(com|net)|shavetape|tapecontent').hasMatch(u)) return 'streamtape';
    // VIDOZA — exact PHP domain
    if (RegExp(r'vidoza\.net|vidoza\.org').hasMatch(u)) return 'vidoza';
    // MULTIUP — exact PHP domain
    if (RegExp(r'multiup\.us').hasMatch(u)) return 'multiup';
    // GENERIC HLS — hlsplay, evoload, streamdav, videovard, vido.lol (from PHP)
    if (RegExp(r'hlsplay\.com|evoload\.io|streamdav\.com|videovard\.sx|vido\.lol').hasMatch(u)) return 'genericHLS';
    // UPTOSTREAM — exact PHP domains
    if (RegExp(r'uptostream\.(com|eu|link)').hasMatch(u)) return 'uptostream';
    // Others not in PHP but kept for wider coverage
    if (RegExp(r'mp4upload\.com').hasMatch(u)) return 'mp4upload';
    if (RegExp(r'ok\.ru|odnoklassniki\.ru').hasMatch(u)) return 'okru';
    if (RegExp(r'vk\.com|vk\.ru').hasMatch(u)) return 'vk';
    if (RegExp(r'dailymotion\.com|dai\.ly').hasMatch(u)) return 'dailymotion';
    if (RegExp(r'streamsb\.|sb(?:plays|lanh|fast|joy|emb|rity|lona|net|chill|brisk|clip)').hasMatch(u)) return 'streamsb';
    if (RegExp(r'vidguard\.|listeamed\.|bembed\.|vgfplay\.|vgembed\.').hasMatch(u)) return 'vidguard';
    if (RegExp(r'smashystream\.com').hasMatch(u)) return 'smashystream';
    if (RegExp(r'ninjastream\.(to|eu)').hasMatch(u)) return 'ninjastream';
    if (RegExp(r'yourupload').hasMatch(u)) return 'yourupload';
    if (RegExp(r'vido\.(to|live)').hasMatch(u)) return 'vido';
    if (RegExp(r'chillx\.to').hasMatch(u)) return 'chillx';
    if (RegExp(r'kwik\.(si|cx)').hasMatch(u)) return 'kwik';
    return 'unknown';
  }

  static Future<Map<String, dynamic>> _dispatch(String server, String url) async {
    switch (server) {
      case 'proxy':       return _extractProxy(url);
      case 'doodstream':  return _extractDoodstream(url);
      case 'filemoon':    return _extractFilemoon(url);
      case 'streamtape':  return _extractStreamtape(url);
      case 'voe':         return _extractVoe(url);
      case 'mixdrop':     return _extractMixdrop(url);
      case 'mp4upload':   return _extractMp4upload(url);
      case 'okru':        return _extractOkru(url);
      case 'vk':          return _extractVK(url);
      case 'dailymotion': return _extractDailymotion(url);
      case 'streamsb':    return _extractStreamSB(url);
      case 'vidguard':    return _extractVidguard(url);
      case 'vidoza':      return _extractVidoza(url);
      case 'smashystream':return _extractSmashystream(url);
      case 'ninjastream': return _extractNinjastream(url);
      case 'vidzy':       return _extractVidzy(url);
      case 'uqload':      return _extractUqload(url);
      case 'netu':        return _extractNetu(url);
      case 'multiup':     return _extractMultiup(url);
      case 'genericHLS':  return _extractGenericHLS(url);
      case 'uptostream':  return _extractYourupload(url);
      case 'yourupload':  return _extractYourupload(url);
      case 'vido':        return _extractVido(url);
      case 'chillx':      return _extractChillx(url);
      case 'kwik':        return _extractKwik(url);
      default:            return _extractGeneric(url);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DOODSTREAM
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractDoodstream(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers()).timeout(_timeout);
      if (resp.statusCode != 200) return {'error': 'Dood: HTTP ${resp.statusCode}'};

      final html = resp.body;
      final finalUrl = resp.request?.url.toString() ?? url;
      final base = _base(finalUrl);

      final passMatch = RegExp(r'(/pass_md5[^"' + "'" + r']+)["' + "'").firstMatch(html);
      if (passMatch == null) return {'error': 'Dood: pass_md5 absent'};
      final passPath = passMatch.group(1)!;

      final tokenMatch = RegExp(r'[?&]token=([a-z0-9]+)', caseSensitive: false).firstMatch(html);
      final token = tokenMatch?.group(1) ?? passPath.split('/').last;
      if (token.isEmpty) return {'error': 'Dood: token absent'};

      final passResp = await http.get(
        Uri.parse('$base$passPath'),
        headers: {
          ..._headers(referer: finalUrl),
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': '*/*',
        },
      ).timeout(_timeout);

      final prefix = passResp.body.trim();
      if (prefix == 'RELOAD' || !prefix.startsWith('http')) {
        return {'error': 'Dood: préfixe invalide'};
      }

      final expiry = DateTime.now().millisecondsSinceEpoch;
      final videoUrl = '${prefix}${_randomString(10)}?token=$token&expiry=$expiry';

      return {
        'success': true,
        'video_url': videoUrl,
        'server': 'doodstream',
        'type': 'mp4',
        'headers': {'Referer': '$base/', 'User-Agent': _ua},
      };
    } catch (e) {
      return {'error': 'Dood: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // FILEMOON / FILMOON
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractFilemoon(String url) async {
    try {
      // Normaliser vers /e/ si nécessaire
      final normUrl = url.contains('/v/') ? url.replaceFirst('/v/', '/e/') : url;
      final uri = Uri.parse(normUrl);
      final base = '${uri.scheme}://${uri.host}';

      final resp = await http.get(
        Uri.parse(normUrl),
        headers: _headers(referer: '$base/'),
      ).timeout(_timeout);

      final html = resp.body;
      if (html.isEmpty) return {'error': 'Filemoon: page vide'};

      // 1. Unpack JS eval (Filemoon utilise du JS packagé)
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      // 2. Chercher m3u8
      final m3u8 = _findM3u8(src);
      if (m3u8 != null) {
        final qualities = await _parseHLSMaster(m3u8, {'Referer': '$base/', 'User-Agent': _ua});
        return {
          'success': true,
          'video_url': m3u8,
          'server': 'filemoon',
          'type': 'hls',
          'is_hls': true,
          'qualities': qualities,
          'headers': {'Referer': '$base/', 'User-Agent': _ua, 'Origin': base},
        };
      }

      // 3. Chercher mp4
      final mp4 = _findMp4(src);
      if (mp4 != null) {
        return {
          'success': true,
          'video_url': mp4,
          'server': 'filemoon',
          'type': 'mp4',
          'headers': {'Referer': '$base/', 'User-Agent': _ua},
        };
      }

      return {'error': 'Filemoon: source non trouvée'};
    } catch (e) {
      return {'error': 'Filemoon: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // STREAMTAPE
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractStreamtape(String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: _headers(referer: 'https://streamtape.com/'),
      ).timeout(_timeout);

      final html = resp.body;

      // Pattern 1 : URL directe dans le HTML
      final directPat = RegExp(
        r'''https?://[a-z0-9.-]*streamtape\.[a-z]+/get/[A-Za-z0-9]+/[A-Za-z0-9]+\?[^"'\s<>]{10,}''',
      );
      var m = directPat.firstMatch(html);
      if (m != null) {
        return _stResult(m.group(0)!);
      }

      // Pattern 2 : url split en deux variables JS concaténées
      // ex: 'xxxxxAAA' + 'BBByyyyyy' → on les cherche séparément
      final part1 = RegExp(r'''/get/[A-Za-z0-9/]+\?[^"']+''').firstMatch(html)?.group(0);
      final token = RegExp(r'''token=([A-Za-z0-9]+)''').firstMatch(html)?.group(1);

      if (part1 != null && token != null) {
        final videoUrl = 'https://streamtape.com$part1';
        return _stResult(videoUrl);
      }

      // Pattern 3 : href dans le norobotlink
      final hrefPat = RegExp(r'''href=['"]?(//[^"'>\s]+streamtape[^"'>\s]+)''');
      m = hrefPat.firstMatch(html);
      if (m != null) {
        final videoUrl = 'https:${m.group(1)!}';
        return _stResult(videoUrl);
      }

      return {'error': 'Streamtape: URL non trouvée'};
    } catch (e) {
      return {'error': 'Streamtape: $e'};
    }
  }

  static Map<String, dynamic> _stResult(String url) => {
        'success': true,
        'video_url': url,
        'server': 'streamtape',
        'type': 'mp4',
        'headers': {'Referer': 'https://streamtape.com/', 'User-Agent': _ua},
      };

  // ─────────────────────────────────────────────────────────────────
  // VOE
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractVoe(String url) async {
    try {
      final uri = Uri.parse(url);
      final base = '${uri.scheme}://${uri.host}';
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: '$base/')).timeout(_timeout);
      var html = resp.body;

      // VOE step 1: follow window.location.href JS redirect (voe.sx → dianaavoidthey.com etc.)
      final jsRedirect = RegExp(r'''window\.location\.href\s*=\s*['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
      if (jsRedirect != null) {
        final redirectUrl = jsRedirect.group(1)!;
        if (redirectUrl.startsWith('http')) {
          final resp2 = await http.get(Uri.parse(redirectUrl), headers: _headers(referer: '$base/')).timeout(_timeout);
          html = resp2.body;
        }
      }

      // 2. Clé 'hls' avec valeur base64
      final b64Match = RegExp(r"""['"]hls['"]\s*:\s*['"]([A-Za-z0-9+/=]{20,})['"]""").firstMatch(html);
      if (b64Match != null) {
        try {
          final decoded = utf8.decode(base64.decode(b64Match.group(1)!));
          if (decoded.startsWith('http') && decoded.contains('.m3u8')) {
            return await _voeResult(decoded, base);
          }
        } catch (_) {}
      }

      // 3. atob(...)
      final atobMatch = RegExp(r'''atob\(['"]([A-Za-z0-9+/=]{20,})['"]\)''').firstMatch(html);
      if (atobMatch != null) {
        try {
          final decoded = utf8.decode(base64.decode(atobMatch.group(1)!));
          if (decoded.startsWith('http')) {
            final type = decoded.contains('.m3u8') ? 'hls' : 'mp4';
            return await _voeResult(decoded, base, type: type);
          }
        } catch (_) {}
      }

      // 4. m3u8 direct
      final m3u8 = _findM3u8(html);
      if (m3u8 != null) return await _voeResult(m3u8, base);

      // 5. wurl / source direct
      final wurlMatch = RegExp(r"""wurl\s*=\s*['"]([^'"]+)['"]""").firstMatch(html);
      if (wurlMatch != null) {
        final u = wurlMatch.group(1)!;
        if (u.startsWith('http')) return await _voeResult(u, base, type: u.contains('.m3u8') ? 'hls' : 'mp4');
      }

      return {'error': 'Voe: URL non trouvée'};
    } catch (e) {
      return {'error': 'Voe: $e'};
    }
  }

  static Future<Map<String, dynamic>> _voeResult(String videoUrl, String base, {String type = 'hls'}) async {
    final qualities = type == 'hls' ? await _parseHLSMaster(videoUrl, {'Referer': '$base/', 'User-Agent': _ua}) : <Map<String, String>>[];
    return {
      'success': true,
      'video_url': videoUrl,
      'server': 'voe',
      'type': type,
      'is_hls': type == 'hls',
      'qualities': qualities,
      'headers': {'Referer': '$base/', 'User-Agent': _ua, 'Origin': base},
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // MIXDROP
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractMixdrop(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: 'https://mixdrop.ag/')).timeout(_timeout);
      final html = resp.body;

      // Mixdrop encode l'URL dans MDCore.wurl après eval()
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      // MDCore.wurl
      final wurlMatch = RegExp(r'''MDCore\.wurl\s*=\s*["']([^"']+)["']''').firstMatch(src);
      if (wurlMatch != null) {
        var videoUrl = wurlMatch.group(1)!;
        if (videoUrl.startsWith('//')) videoUrl = 'https:$videoUrl';
        return {
          'success': true,
          'video_url': videoUrl,
          'server': 'mixdrop',
          'type': videoUrl.contains('.m3u8') ? 'hls' : 'mp4',
          'headers': {'Referer': 'https://mixdrop.ag/', 'User-Agent': _ua},
        };
      }

      // Chercher directement mp4/m3u8 après unpack
      final m3u8 = _findM3u8(src);
      if (m3u8 != null) {
        return {'success': true, 'video_url': m3u8, 'server': 'mixdrop', 'type': 'hls', 'headers': {'Referer': 'https://mixdrop.ag/', 'User-Agent': _ua}};
      }

      return {'error': 'Mixdrop: URL non trouvée'};
    } catch (e) {
      return {'error': 'Mixdrop: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // MP4UPLOAD
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractMp4upload(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: 'https://mp4upload.com/')).timeout(_timeout);
      final html = resp.body;

      // jwplayer setup
      final fileMatch = RegExp(r'''file\s*:\s*["']([^"']+\.mp4[^"']*)["']''', caseSensitive: false).firstMatch(html);
      if (fileMatch != null) {
        return {
          'success': true,
          'video_url': fileMatch.group(1)!,
          'server': 'mp4upload',
          'type': 'mp4',
          'headers': {'Referer': 'https://mp4upload.com/', 'User-Agent': _ua},
        };
      }

      // source tag
      final sourceMatch = RegExp(r'''<source[^>]+src=["']([^"']+\.mp4[^"']*)["']''', caseSensitive: false).firstMatch(html);
      if (sourceMatch != null) {
        return {
          'success': true,
          'video_url': sourceMatch.group(1)!,
          'server': 'mp4upload',
          'type': 'mp4',
          'headers': {'Referer': 'https://mp4upload.com/', 'User-Agent': _ua},
        };
      }

      return {'error': 'Mp4upload: source non trouvée'};
    } catch (e) {
      return {'error': 'Mp4upload: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // OK.RU
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractOkru(String url) async {
    try {
      // Extraire l'ID
      final midMatch = RegExp(r'ok\.ru/video(?:embed)?/(\d+)').firstMatch(url) ??
          RegExp(r'mid=(\d+)').firstMatch(url);
      if (midMatch == null) return {'error': 'OkRu: ID non trouvé'};

      final mid = midMatch.group(1)!;
      final apiUrl = 'https://ok.ru/dk?cmd=videoPlayerMetadata&mid=$mid';

      final resp = await http.get(
        Uri.parse(apiUrl),
        headers: {
          ..._headers(referer: 'https://ok.ru/'),
          'Accept': 'application/json, */*',
        },
      ).timeout(_timeout);

      if (resp.statusCode != 200) return {'error': 'OkRu: API HTTP ${resp.statusCode}'};

      final data = json.decode(resp.body);
      final videos = data['videos'] as List?;
      if (videos == null || videos.isEmpty) return {'error': 'OkRu: pas de vidéos'};

      // Priorité qualité: 1080 > 720 > 480 > 360 > 240
      const priority = ['full', 'hd', 'sd', 'low', 'lowest', 'mobile'];
      Map<String, dynamic>? best;
      int bestPrio = 999;

      for (final v in videos) {
        final name = (v['name'] as String? ?? '').toLowerCase();
        final idx = priority.indexWhere((p) => name.contains(p));
        if (idx != -1 && idx < bestPrio) {
          bestPrio = idx;
          best = v as Map<String, dynamic>;
        }
      }

      best ??= videos.first as Map<String, dynamic>;
      final videoUrl = best['url'] as String? ?? '';
      if (videoUrl.isEmpty) return {'error': 'OkRu: URL vide'};

      return {
        'success': true,
        'video_url': videoUrl,
        'server': 'okru',
        'type': 'mp4',
        'qualities': (videos as List<dynamic>).map((v) => {
          'label': (v as Map)['name']?.toString() ?? 'Auto',
          'url': v['url']?.toString() ?? '',
        }).where((q) => q['url']!.isNotEmpty).toList(),
        'headers': {'Referer': 'https://ok.ru/', 'User-Agent': _ua},
      };
    } catch (e) {
      return {'error': 'OkRu: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // VK
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractVK(String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: _headers(referer: 'https://vk.com/'),
      ).timeout(_timeout);

      final html = resp.body;

      // VK encode les URLs video dans un JSON embeds
      final qualities = <Map<String, String>>[];
      final urlPat = RegExp(r'''"url(\d+)"\s*:\s*"([^"]+\.mp4[^"]*)"''', caseSensitive: false);
      for (final m in urlPat.allMatches(html)) {
        final res = m.group(1)!;
        final u = m.group(2)!.replaceAll(r'\/', '/');
        qualities.add({'label': '${res}p', 'url': u});
      }

      if (qualities.isEmpty) {
        // Fallback: chercher mp4 générique
        final mp4 = _findMp4(html);
        if (mp4 != null) {
          return {'success': true, 'video_url': mp4, 'server': 'vk', 'type': 'mp4', 'headers': {'Referer': 'https://vk.com/', 'User-Agent': _ua}};
        }
        return {'error': 'VK: source non trouvée'};
      }

      // Trier par résolution décroissante
      qualities.sort((a, b) {
        final ra = int.tryParse(a['label']?.replaceAll('p', '') ?? '0') ?? 0;
        final rb = int.tryParse(b['label']?.replaceAll('p', '') ?? '0') ?? 0;
        return rb.compareTo(ra);
      });

      return {
        'success': true,
        'video_url': qualities.first['url']!,
        'server': 'vk',
        'type': 'mp4',
        'qualities': qualities,
        'headers': {'Referer': 'https://vk.com/', 'User-Agent': _ua},
      };
    } catch (e) {
      return {'error': 'VK: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DAILYMOTION
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractDailymotion(String url) async {
    try {
      final idMatch = RegExp(r'(?:video|dai\.ly)/([a-zA-Z0-9]+)').firstMatch(url);
      if (idMatch == null) return {'error': 'DailyMotion: ID non trouvé'};
      final id = idMatch.group(1)!;

      final apiUrl = Uri.parse(
        'https://www.dailymotion.com/player/metadata/video/$id?embedder=https://www.dailymotion.com&locale=fr_FR&dmV1st=&dmTs=',
      );

      final resp = await http.get(
        apiUrl,
        headers: {
          ..._headers(referer: 'https://www.dailymotion.com/'),
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (resp.statusCode != 200) return {'error': 'DailyMotion: API HTTP ${resp.statusCode}'};

      final data = json.decode(resp.body);
      final qualities = <Map<String, String>>[];

      // qualities map: '1080', '720', '480', '380', '240', '144'
      final qMap = data['qualities'] as Map<String, dynamic>?;
      if (qMap != null) {
        for (final entry in qMap.entries) {
          final label = entry.key;
          if (label == 'auto') continue;
          final streams = entry.value as List?;
          if (streams == null || streams.isEmpty) continue;
          final streamUrl = (streams.first as Map?)?['url'] as String?;
          if (streamUrl != null && streamUrl.isNotEmpty) {
            qualities.add({'label': '${label}p', 'url': streamUrl});
          }
        }
      }

      if (qualities.isEmpty) return {'error': 'DailyMotion: aucune qualité trouvée'};

      qualities.sort((a, b) {
        final ra = int.tryParse(a['label']?.replaceAll('p', '') ?? '0') ?? 0;
        final rb = int.tryParse(b['label']?.replaceAll('p', '') ?? '0') ?? 0;
        return rb.compareTo(ra);
      });

      final best = qualities.first['url']!;
      final type = best.contains('.m3u8') ? 'hls' : 'mp4';

      return {
        'success': true,
        'video_url': best,
        'server': 'dailymotion',
        'type': type,
        'is_hls': type == 'hls',
        'qualities': qualities,
        'headers': {'Referer': 'https://www.dailymotion.com/', 'User-Agent': _ua},
      };
    } catch (e) {
      return {'error': 'DailyMotion: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // STREAMSB / SBBRIDGES
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractStreamSB(String url) async {
    try {
      // StreamSB encode l'ID en hexadécimal double
      final idMatch = RegExp(r'(?:e/|embed[-/])([a-zA-Z0-9]+)').firstMatch(url);
      if (idMatch == null) return {'error': 'StreamSB: ID non trouvé'};

      final id = idMatch.group(1)!;
      final host = Uri.parse(url).host;
      // L'API utilise l'ID encodé en hex×2
      final hexId = id.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join();
      final hexHex = hexId.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join();

      final apiUrl = 'https://$host/sources48/$hexHex/';
      final resp = await http.get(
        Uri.parse(apiUrl),
        headers: {
          ..._headers(referer: 'https://$host/'),
          'watchsb': 'sbstream',
          'HL-token': id,
        },
      ).timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final streamData = data['stream_data'] as Map<String, dynamic>?;
        if (streamData != null) {
          final m3u8Url = streamData['file'] as String? ?? streamData['backup'] as String?;
          if (m3u8Url != null) {
            final qualities = await _parseHLSMaster(m3u8Url, {'Referer': 'https://$host/', 'User-Agent': _ua});
            return {
              'success': true,
              'video_url': m3u8Url,
              'server': 'streamsb',
              'type': 'hls',
              'is_hls': true,
              'qualities': qualities,
              'headers': {'Referer': 'https://$host/', 'User-Agent': _ua},
            };
          }
        }
      }

      // Fallback: scraping HTML
      return await _extractGeneric(url);
    } catch (e) {
      return {'error': 'StreamSB: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // VIDGUARD / VIDHIDE
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractVidguard(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: url)).timeout(_timeout);
      final html = resp.body;
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      // Vidguard utilise une fonction _x() de déobfuscation
      // Chercher d'abord le m3u8 après unpack
      final m3u8 = _findM3u8(src);
      if (m3u8 != null) {
        final base = _base(url);
        final qualities = await _parseHLSMaster(m3u8, {'Referer': '$base/', 'User-Agent': _ua});
        return {
          'success': true,
          'video_url': m3u8,
          'server': 'vidguard',
          'type': 'hls',
          'is_hls': true,
          'qualities': qualities,
          'headers': {'Referer': '$base/', 'User-Agent': _ua},
        };
      }

      // Chercher l'URL dans stream_url ou source
      final streamMatch = RegExp(r'''stream_url\s*[=:]\s*['"]([^'"]+)['"]''').firstMatch(src);
      if (streamMatch != null) {
        final u = streamMatch.group(1)!;
        return {'success': true, 'video_url': u, 'server': 'vidguard', 'type': 'hls', 'headers': {'Referer': url, 'User-Agent': _ua}};
      }

      return {'error': 'Vidguard: source non trouvée'};
    } catch (e) {
      return {'error': 'Vidguard: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // VIDOZA
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractVidoza(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: url)).timeout(_timeout);
      final html = resp.body;

      // sourcesCode:
      final srcMatch = RegExp(r'''sourcesCode\s*:\s*\[\s*\{.*?file\s*:\s*["']([^"']+)["']''', dotAll: true).firstMatch(html);
      if (srcMatch != null) {
        return {'success': true, 'video_url': srcMatch.group(1)!, 'server': 'vidoza', 'type': 'mp4', 'headers': {'Referer': url, 'User-Agent': _ua}};
      }

      final m3u8 = _findM3u8(html);
      if (m3u8 != null) return {'success': true, 'video_url': m3u8, 'server': 'vidoza', 'type': 'hls', 'headers': {'Referer': url, 'User-Agent': _ua}};

      final mp4 = _findMp4(html);
      if (mp4 != null) return {'success': true, 'video_url': mp4, 'server': 'vidoza', 'type': 'mp4', 'headers': {'Referer': url, 'User-Agent': _ua}};

      return {'error': 'Vidoza: source non trouvée'};
    } catch (e) {
      return {'error': 'Vidoza: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // SMASHYSTREAM
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractSmashystream(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: url)).timeout(_timeout);
      final html = resp.body;
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      final m3u8 = _findM3u8(src);
      if (m3u8 != null) {
        final qualities = await _parseHLSMaster(m3u8, {'Referer': url, 'User-Agent': _ua});
        return {'success': true, 'video_url': m3u8, 'server': 'smashystream', 'type': 'hls', 'is_hls': true, 'qualities': qualities, 'headers': {'Referer': url, 'User-Agent': _ua}};
      }

      return {'error': 'Smashystream: source non trouvée'};
    } catch (e) {
      return {'error': 'Smashystream: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // UQLOAD
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractUqload(String url) async {
    try {
      // Normalize all uqload domains to uqload.is (bz/org/co/to are dead)
      url = url.replaceAll(RegExp(r'uqload\.\w+'), 'uqload.is');
      // Normalize to /embed-XXXX.html format if not already
      if (!url.contains('/embed-')) {
        url = url.replaceAllMapped(RegExp(r'/([a-z0-9]+)\.html', caseSensitive: false), (m) => '/embed-${m.group(1)}.html');
      }
      final resp = await http.get(
        Uri.parse(url),
        headers: _headers(referer: 'https://uqload.is/'),
      ).timeout(_timeout);

      final html = resp.body;
      final patterns = [
        RegExp(r"""sources\s*:\s*\[\s*['"](https?://[^'"]+\.mp4[^'"]*)['"]"""),
        RegExp(r"""file\s*:\s*['"](https?://[^'"]+\.mp4[^'"]*)['"]"""),
        RegExp(r"""<source[^>]+src=['"](https?://[^'"]+\.mp4[^'"]*)['"]"""),
        RegExp(r"""(https?://[^\s"'<>]+\.mp4[^\s"'<>]*)"""),
      ];

      for (final pat in patterns) {
        final m = pat.firstMatch(html);
        if (m != null) {
          final u = (m.group(1) ?? m.group(0)!).replaceAll(r'\/', '/');
          return {'success': true, 'video_url': u, 'server': 'uqload', 'type': 'mp4', 'headers': {'Referer': 'https://uqload.is/', 'User-Agent': _ua}};
        }
      }

      return {'error': 'Uqload: source non trouvée'};
    } catch (e) {
      return {'error': 'Uqload: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // NINJASTREAM
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractNinjastream(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: url)).timeout(_timeout);
      final html = resp.body;
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      final m3u8 = _findM3u8(src);
      if (m3u8 != null) return {'success': true, 'video_url': m3u8, 'server': 'ninjastream', 'type': 'hls', 'headers': {'Referer': url, 'User-Agent': _ua}};

      final mp4 = _findMp4(src);
      if (mp4 != null) return {'success': true, 'video_url': mp4, 'server': 'ninjastream', 'type': 'mp4', 'headers': {'Referer': url, 'User-Agent': _ua}};

      return {'error': 'Ninjastream: source non trouvée'};
    } catch (e) {
      return {'error': 'Ninjastream: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // VIDZY
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractVidzy(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: url)).timeout(_timeout);
      final html = resp.body;
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      final m3u8 = _findM3u8(src);
      if (m3u8 != null) {
        return {'success': true, 'video_url': m3u8, 'server': 'vidzy', 'type': 'hls', 'is_hls': true, 'headers': {'Referer': 'https://vidzy.live/', 'User-Agent': _ua}};
      }
      final mp4 = _findMp4(src);
      if (mp4 != null) {
        return {'success': true, 'video_url': mp4, 'server': 'vidzy', 'type': 'mp4', 'headers': {'Referer': 'https://vidzy.live/', 'User-Agent': _ua}};
      }

      return {'error': 'Vidzy: source non trouvée'};
    } catch (e) {
      return {'error': 'Vidzy: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // YOURUPLOAD / UPTOSTREAM
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractYourupload(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: url)).timeout(_timeout);
      final html = resp.body;
      final m3u8 = _findM3u8(html);
      if (m3u8 != null) return {'success': true, 'video_url': m3u8, 'server': 'yourupload', 'type': 'hls', 'headers': {'Referer': url, 'User-Agent': _ua}};
      final mp4 = _findMp4(html);
      if (mp4 != null) return {'success': true, 'video_url': mp4, 'server': 'yourupload', 'type': 'mp4', 'headers': {'Referer': url, 'User-Agent': _ua}};
      return {'error': 'Yourupload: source non trouvée'};
    } catch (e) {
      return {'error': 'Yourupload: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // VIDO.TO
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractVido(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: url)).timeout(_timeout);
      final html = resp.body;
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      final m3u8 = _findM3u8(src);
      if (m3u8 != null) {
        final qualities = await _parseHLSMaster(m3u8, {'Referer': url, 'User-Agent': _ua});
        return {'success': true, 'video_url': m3u8, 'server': 'vido', 'type': 'hls', 'is_hls': true, 'qualities': qualities, 'headers': {'Referer': url, 'User-Agent': _ua}};
      }
      return {'error': 'Vido: source non trouvée'};
    } catch (e) {
      return {'error': 'Vido: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // CHILLX
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractChillx(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: url)).timeout(_timeout);
      final html = resp.body;
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      final m3u8 = _findM3u8(src);
      if (m3u8 != null) {
        final base = _base(url);
        final qualities = await _parseHLSMaster(m3u8, {'Referer': '$base/', 'User-Agent': _ua});
        return {'success': true, 'video_url': m3u8, 'server': 'chillx', 'type': 'hls', 'is_hls': true, 'qualities': qualities, 'headers': {'Referer': '$base/', 'User-Agent': _ua}};
      }

      return {'error': 'Chillx: source non trouvée'};
    } catch (e) {
      return {'error': 'Chillx: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // KWIK (lien direct de téléchargement)
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractKwik(String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: _headers(referer: 'https://animepahe.ru/'),
      ).timeout(_timeout);
      final html = resp.body;

      // Kwik utilise un form POST avec un token
      final tokenMatch = RegExp(r'''<input[^>]+name="_token"[^>]+value="([^"]+)"''').firstMatch(html);
      final postUrl = RegExp(r'''action="([^"]+kwik[^"]+)"''').firstMatch(html)?.group(1);

      if (tokenMatch != null && postUrl != null) {
        final postResp = await http.post(
          Uri.parse(postUrl),
          headers: {
            ..._headers(referer: url),
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'_token': tokenMatch.group(1)!},
        ).timeout(_timeout);

        if (postResp.statusCode == 302) {
          final location = postResp.headers['location'];
          if (location != null) {
            return {'success': true, 'video_url': location, 'server': 'kwik', 'type': 'mp4', 'headers': {'Referer': url, 'User-Agent': _ua}};
          }
        }

        final mp4 = _findMp4(postResp.body);
        if (mp4 != null) return {'success': true, 'video_url': mp4, 'server': 'kwik', 'type': 'mp4', 'headers': {'Referer': url, 'User-Agent': _ua}};
      }

      // Fallback direct
      final mp4 = _findMp4(html);
      if (mp4 != null) return {'success': true, 'video_url': mp4, 'server': 'kwik', 'type': 'mp4', 'headers': {'Referer': url, 'User-Agent': _ua}};

      return {'error': 'Kwik: source non trouvée'};
    } catch (e) {
      return {'error': 'Kwik: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PROXY (kakaflix.lol / kokoflix.lol / sequoia.lol)
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractProxy(String url) async {
    try {
      final uri = Uri.parse(url);
      final base = '${uri.scheme}://${uri.host}';
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: '$base/')).timeout(_timeout);
      final html = resp.body;
      final finalUrl = resp.request?.url.toString() ?? url;
      final finalHost = Uri.tryParse(finalUrl)?.host ?? '';

      // If redirected to a different real domain, extract from there
      if (finalHost.isNotEmpty && finalHost != uri.host &&
          !RegExp(r'kakaflix|kokoflix|sequoia').hasMatch(finalHost)) {
        return await extract(finalUrl);
      }

      // JS window.location redirect
      final jsRedirect = RegExp(r'''window\.location\.(?:href|replace)\s*[=(]\s*['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
      if (jsRedirect != null) {
        final redirectUrl = jsRedirect.group(1)!;
        if (redirectUrl.startsWith('http')) return await extract(redirectUrl);
      }

      // atob base64 redirect
      final atobMatch = RegExp(r'''atob\s*\(\s*['"]([A-Za-z0-9+/=]{10,})['"]\s*\)''').firstMatch(html);
      if (atobMatch != null) {
        try {
          final decoded = utf8.decode(base64.decode(atobMatch.group(1)!));
          if (decoded.startsWith('http')) return await extract(decoded);
        } catch (_) {}
      }

      // iframe
      final iframeMatch = RegExp(r'''<iframe[^>]+src=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
      if (iframeMatch != null) {
        var iframeUrl = iframeMatch.group(1)!;
        if (!iframeUrl.startsWith('http')) iframeUrl = '$base/${iframeUrl.replaceFirst(RegExp(r'^/'), '')}';
        return await extract(iframeUrl);
      }

      return await _extractGeneric(url);
    } catch (e) {
      return {'error': 'Proxy: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // NETU (bysebuho.com / younetu.com / bysewihe.com)
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractNetu(String url) async {
    try {
      final uri = Uri.parse(url);
      final base = '${uri.scheme}://${uri.host}';
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: '$base/')).timeout(_timeout);
      final html = resp.body;
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      final m3u8 = _findM3u8(src);
      if (m3u8 != null) {
        final qualities = await _parseHLSMaster(m3u8, {'Referer': '$base/', 'User-Agent': _ua});
        return {
          'success': true,
          'video_url': m3u8,
          'server': 'netu',
          'type': 'hls',
          'is_hls': true,
          'qualities': qualities,
          'headers': {'Referer': '$base/', 'User-Agent': _ua, 'Origin': base},
        };
      }

      // window.location redirect to another player
      final jsRedirect = RegExp(r'''window\.location\.(?:href|replace)\s*[=(]\s*['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
      if (jsRedirect != null) {
        final redirectUrl = jsRedirect.group(1)!;
        if (redirectUrl.startsWith('http')) return await extract(redirectUrl);
      }

      return {'error': 'Netu: source non trouvée'};
    } catch (e) {
      return {'error': 'Netu: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // MULTIUP (aggregator → redirects to real hosts)
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractMultiup(String url) async {
    try {
      final uri = Uri.parse(url);
      final base = '${uri.scheme}://${uri.host}';
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: '$base/')).timeout(_timeout);
      final html = resp.body;

      // window.location.replace redirect
      final replaceMatch = RegExp(r'''window\.location\.replace\s*\(\s*['"]([^'"]+)['"]''').firstMatch(html);
      if (replaceMatch != null) {
        final redirectUrl = replaceMatch.group(1)!;
        if (redirectUrl.startsWith('http')) {
          final result = await extract(redirectUrl);
          if (result['success'] == true) return result;
        }
      }

      // file: pattern
      final fileMatch = RegExp(r'''file\s*:\s*['"]([^'"]+)['"]''').firstMatch(html);
      if (fileMatch != null) {
        final u = fileMatch.group(1)!;
        final type = u.contains('.m3u8') ? 'hls' : 'mp4';
        return {'success': true, 'video_url': u, 'server': 'multiup', 'type': type, 'headers': {'Referer': '$base/', 'User-Agent': _ua}};
      }

      // vid= parameter → try uqload directly
      final vidMatch = RegExp(r'[?&]vid=([a-zA-Z0-9]+)').firstMatch(url);
      if (vidMatch != null) {
        final uqloadUrl = 'https://uqload.is/embed-${vidMatch.group(1)!}.html';
        final result = await _extractUqload(uqloadUrl);
        if (result['success'] == true) return result;
      }

      return await _extractGeneric(url);
    } catch (e) {
      return {'error': 'Multiup: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // GENERIC HLS (hlsplay.com / evoload.io / streamdav.com / videovard.sx / vido.lol)
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractGenericHLS(String url) async {
    try {
      final uri = Uri.parse(url);
      final base = '${uri.scheme}://${uri.host}';
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: '$base/')).timeout(_timeout);
      final html = resp.body;
      final finalUrl = resp.request?.url.toString() ?? url;

      // JS redirect
      final jsRedirect = RegExp(r'''window\.location\.(?:href|replace)\s*[=(]\s*['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
      if (jsRedirect != null) {
        final redirectUrl = jsRedirect.group(1)!;
        if (redirectUrl.startsWith('http')) return await extract(redirectUrl);
      }

      return await _extractGeneric(finalUrl.isNotEmpty ? finalUrl : url);
    } catch (e) {
      return {'error': 'GenericHLS: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // GÉNÉRIQUE AMÉLIORÉ
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractGeneric(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers(referer: url)).timeout(_timeout);
      final html = resp.body;

      // 1. Unpack eval JS
      final unpacked = _unpackJs(html);
      final src = unpacked.isNotEmpty ? unpacked : html;

      // 2. m3u8
      final m3u8 = _findM3u8(src);
      if (m3u8 != null) {
        final base = _base(url);
        final qualities = await _parseHLSMaster(m3u8, {'Referer': '$base/', 'User-Agent': _ua});
        return {
          'success': true,
          'video_url': m3u8,
          'server': 'generic',
          'type': 'hls',
          'is_hls': true,
          'qualities': qualities,
          'headers': {'Referer': '$base/', 'User-Agent': _ua},
        };
      }

      // 3. mp4
      final mp4 = _findMp4(src);
      if (mp4 != null) {
        return {
          'success': true,
          'video_url': mp4,
          'server': 'generic',
          'type': 'mp4',
          'headers': {'Referer': url, 'User-Agent': _ua},
        };
      }

      // 4. "file":"..." pattern
      final fileMatch = RegExp(r'''"file"\s*:\s*"(https?://[^"]{10,})"''', caseSensitive: false).firstMatch(src);
      if (fileMatch != null) {
        final u = fileMatch.group(1)!.replaceAll(r'\/', '/');
        if (u.startsWith('http')) {
          return {'success': true, 'video_url': u, 'server': 'generic', 'type': u.contains('.m3u8') ? 'hls' : 'mp4', 'headers': {'Referer': url, 'User-Agent': _ua}};
        }
      }

      // 5. og:video
      final ogMatch = RegExp(r'''<meta[^>]+property="og:video"[^>]+content="([^"]+)"''', caseSensitive: false).firstMatch(html);
      if (ogMatch != null) {
        final u = ogMatch.group(1)!;
        return {'success': true, 'video_url': u, 'server': 'generic', 'type': u.contains('.m3u8') ? 'hls' : 'mp4', 'headers': {'Referer': url, 'User-Agent': _ua}};
      }

      return {'error': 'Generic: aucune source trouvée pour $url'};
    } catch (e) {
      return {'error': 'Generic: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // SÉLECTION DE QUALITÉ HLS MASTER
  // ─────────────────────────────────────────────────────────────────

  static Future<List<Map<String, String>>> _parseHLSMaster(
    String masterUrl,
    Map<String, String> headers,
  ) async {
    try {
      final resp = await http.get(Uri.parse(masterUrl), headers: headers).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return [];
      if (!resp.body.contains('#EXTM3U')) return [];

      final lines = resp.body.split('\n');
      final qualities = <Map<String, String>>[];
      String? bandwidth;
      String? resolution;

      final baseUri = Uri.parse(masterUrl);

      for (final raw in lines) {
        final line = raw.trim();
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          final bwM = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
          final resM = RegExp(r'RESOLUTION=(\d+x\d+)').firstMatch(line);
          bandwidth = bwM?.group(1);
          resolution = resM?.group(1);
        } else if (line.isNotEmpty && !line.startsWith('#')) {
          final segUrl = line.startsWith('http') ? line : baseUri.resolve(line).toString();
          final height = resolution != null ? int.tryParse(resolution.split('x').last) ?? 0 : 0;
          final label = height > 0 ? '${height}p' : (bandwidth != null ? '${(int.parse(bandwidth) / 1000).toStringAsFixed(0)}k' : 'Auto');
          qualities.add({'label': label, 'url': segUrl, 'bandwidth': bandwidth ?? '0'});
          bandwidth = null;
          resolution = null;
        }
      }

      qualities.sort((a, b) {
        return int.parse(b['bandwidth'] ?? '0').compareTo(int.parse(a['bandwidth'] ?? '0'));
      });

      return qualities;
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

  static String? _findM3u8(String src) {
    final m = RegExp('https?://[^\\s"\'<>]+\\.m3u8(?:[^\\s"\'<>]*)?', caseSensitive: false).firstMatch(src);
    return m?.group(0);
  }

  static String? _findMp4(String src) {
    final patterns = [
      RegExp(r'''["']file["']\s*:\s*["'](https?://[^"']+\.mp4[^"']*)["']''', caseSensitive: false),
      RegExp(r'''<source[^>]+src=["'](https?://[^"']+\.mp4[^"']*)["']''', caseSensitive: false),
      RegExp('https?://[^\\s"\'<>]+\\.mp4(?:\\?[^\\s"\'<>]*)?', caseSensitive: false),
    ];
    for (final pat in patterns) {
      final m = pat.firstMatch(src);
      if (m != null) return (m.group(1) ?? m.group(0)!).replaceAll(r'\/', '/');
    }
    return null;
  }

  static String _base(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return '${uri.scheme}://${uri.host}';
  }

  /// Unpack eval(function(p,a,c,k,e,d){...}) JavaScript
  static String _unpackJs(String html) {
    final match = RegExp(
      r"eval\(function\(p,a,c,k,e,d?\)\{.*?\}\('(.*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'(.*?)'\.split\s*\(\s*'([^']*)'\s*\)",
      dotAll: true,
    ).firstMatch(html);

    if (match == null) return '';

    try {
      final p = match.group(1)!;
      final a = int.parse(match.group(2)!);
      final c = int.parse(match.group(3)!);
      final kStr = match.group(4)!;
      final delimiter = match.group(5)!;
      final k = delimiter.isNotEmpty ? kStr.split(delimiter) : <String>[];
      var result = p;

      for (var i = c - 1; i >= 0; i--) {
        if (i < k.length && k[i].isNotEmpty) {
          String word;
          if (a == 36) {
            const digits = '0123456789abcdefghijklmnopqrstuvwxyz';
            var n = i;
            word = '';
            while (n > 0) {
              word = digits[n % 36] + word;
              n = n ~/ 36;
            }
            if (word.isEmpty) word = '0';
          } else {
            word = i.toRadixString(a == 16 ? 16 : (a == 2 ? 2 : 10));
          }
          result = result.replaceAll(RegExp('\\b${RegExp.escape(word)}\\b'), k[i]);
        }
      }
      return result;
    } catch (_) {
      return '';
    }
  }

  static String _randomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
