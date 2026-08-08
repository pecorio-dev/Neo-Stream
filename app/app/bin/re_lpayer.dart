// re_lpayer.dart — Reverse-engineering lpayer.embed4me.com (player SPA Vue,
// "moly-like" custom) — hébergeur anime très utilisé (PEMB, Psycho-Pass…).
//
// Algorithme cassé le 2026-08-08 depuis :
//   - https://lpayer.embed4me.com/  (shell SPA, id vidéo dans le FRAGMENT #id)
//   - https://lpayer.embed4me.com/assets/index-NylH0GhO.js (bundle obfusqué
//     javascript-obfuscator : tableau de strings rotaté + fonction ue())
//
// PIPELINE EXACT du frontend (miroir fidèle) :
//   1. videoId = location.hash.slice(1).split('&')[0]           (fonction M)
//   2. GET /api/v1/video?id={id}&w={screen.width}&h={screen.height}&r={host}
//      → réponse = HEX chiffré AES-128-CBC
//   3. Déchiffrement (fonction L) :
//      key = T(), iv = A() — DEUX CONSTANTES (le faux calcul dépendant de
//      location.protocol/hash se réduit à des constantes car seul
//      codePointAt(0/1) de « https: »/« #… » entre en jeu) :
//        key = "kiemtienmua911ca"  (16 o)
//        iv  = "1234567890oiuytr"  (16 o)
//      plaintext = JSON
//   4. JSON → {title, pk:{k,kx}, source (In-House), cf (Cloudflare
//      cf-master.*.txt), cfNative (m3u8 proxy pré-signé), hlsVideoTiktok,…}
//   5. URL finale (fonctions B/oe du loader HLS) : toute URL contenant
//      « /v4/ » reçoit « &k={pk.k}&kx={pk.kx} » (sauf si k déjà présent).
//      cfNative est déjà signé.
//
// Le param t= de /api/v1/player (AES-encrypt, fonction P) ne sert qu'à la
// télémétrie toutes les 10 s — INUTILE pour l'extraction : pk arrive dans
// la réponse /api/v1/video.
//
// Anti-bot présents dans le bundle (non bloquants pour nous : la vraie
// API ne les vérifie pas) : détection headless/UA (httpie, okhttp,
// node-fetch, axios, postman, puppeteer…), sandbox iframe, adblock.
//
// Pur Dart (dart:io uniquement) : AES-CBC decrypt réimplémenté ici.
//
// Usage : dart bin/re_lpayer.dart [url_embed …]

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// ══════════════════════════════════════════════════════════════════
//  0. Constantes cassées + HTTP TLS-tolérant
// ══════════════════════════════════════════════════════════════════

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/// Valeurs exactes produites par T() / A() du bundle (vérifiées par exécution
/// Node du code désobfusqué le 2026-08-08).
final _aesKey = Uint8List.fromList(utf8.encode('kiemtienmua911ca'));
final _aesIv = Uint8List.fromList(utf8.encode('1234567890oiuytr'));

const _apiBase = 'https://lpayer.embed4me.com';
const _referer = '$_apiBase/';

HttpClient _client() {
  final c = HttpClient();
  c.badCertificateCallback = (_, __, ___) => true;
  c.connectionTimeout = const Duration(seconds: 15);
  c.userAgent = _ua;
  return c;
}

Future<(int, String)> _httpGet(String url,
    {Map<String, String>? headers, String method = 'GET'}) async {
  final c = _client();
  try {
    final req =
        await c.openUrl(method, Uri.parse(url)).timeout(const Duration(seconds: 20));
    req.headers.set('User-Agent', _ua);
    headers?.forEach((k, v) => req.headers.set(k, v));
    final resp = await req.close().timeout(const Duration(seconds: 20));
    final txt = await resp.transform(utf8.decoder).join();
    return (resp.statusCode, txt);
  } finally {
    c.close(force: true);
  }
}

// ══════════════════════════════════════════════════════════════════
//  1. AES (S-box calculée) — encrypt (self-test) + decrypt CBC PKCS7
// ══════════════════════════════════════════════════════════════════

int _gmul(int a, int b) {
  var p = 0;
  for (var i = 0; i < 8; i++) {
    if (b & 1 != 0) p ^= a;
    final hi = a & 0x80;
    a = (a << 1) & 0xFF;
    if (hi != 0) a ^= 0x1B;
    b >>= 1;
  }
  return p;
}

int _gpow(int a, int e) {
  var r = 1;
  while (e > 0) {
    if (e & 1 == 1) r = _gmul(r, a);
    a = _gmul(a, a);
    e >>= 1;
  }
  return r;
}

int _rotl8(int v, int n) => ((v << n) | (v >> (8 - n))) & 0xFF;

List<int>? _sbox, _invSbox;

List<int> _getSbox() {
  if (_sbox != null) return _sbox!;
  final s = List<int>.filled(256, 0);
  for (var x = 0; x < 256; x++) {
    final inv = x == 0 ? 0 : _gpow(x, 254);
    s[x] = inv ^
        _rotl8(inv, 1) ^
        _rotl8(inv, 2) ^
        _rotl8(inv, 3) ^
        _rotl8(inv, 4) ^
        0x63;
  }
  _sbox = s;
  return s;
}

List<int> _getInvSbox() {
  if (_invSbox != null) return _invSbox!;
  final s = _getSbox();
  final inv = List<int>.filled(256, 0);
  for (var i = 0; i < 256; i++) {
    inv[s[i]] = i;
  }
  _invSbox = inv;
  return inv;
}

/// Expansion de clé commune (retourne les octets de toutes les round keys).
List<int> _expandKey(Uint8List key) {
  final sbox = _getSbox();
  final nk = key.length ~/ 4;
  final nr = nk + 6;
  final w = List<int>.filled(4 * (nr + 1) * 4, 0);
  for (var i = 0; i < key.length; i++) {
    w[i] = key[i];
  }
  var rcon = 1;
  for (var i = nk; i < 4 * (nr + 1); i++) {
    var t0 = w[(i - 1) * 4], t1 = w[(i - 1) * 4 + 1],
        t2 = w[(i - 1) * 4 + 2], t3 = w[(i - 1) * 4 + 3];
    if (i % nk == 0) {
      final tmp = t0;
      t0 = sbox[t1] ^ rcon;
      t1 = sbox[t2];
      t2 = sbox[t3];
      t3 = sbox[tmp];
      rcon = _gmul(rcon, 2);
    } else if (nk > 6 && i % nk == 4) {
      t0 = sbox[t0];
      t1 = sbox[t1];
      t2 = sbox[t2];
      t3 = sbox[t3];
    }
    w[i * 4] = w[(i - nk) * 4] ^ t0;
    w[i * 4 + 1] = w[(i - nk) * 4 + 1] ^ t1;
    w[i * 4 + 2] = w[(i - nk) * 4 + 2] ^ t2;
    w[i * 4 + 3] = w[(i - nk) * 4 + 3] ^ t3;
  }
  return w;
}

/// AES encrypt d'un bloc 16 octets (self-test / symmétrie).
List<int> aesEncryptBlock(Uint8List key, List<int> block) {
  final sbox = _getSbox();
  final nk = key.length ~/ 4;
  final nr = nk + 6;
  final w = _expandKey(key);
  final st = List<int>.from(block);
  void addRoundKey(int round) {
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        st[r + 4 * c] ^= w[(round * 4 + c) * 4 + r];
      }
    }
  }

  void subBytes() {
    for (var i = 0; i < 16; i++) {
      st[i] = sbox[st[i]];
    }
  }

  void shiftRows() {
    for (var r = 1; r < 4; r++) {
      final row = [st[r], st[r + 4], st[r + 8], st[r + 12]];
      for (var c = 0; c < 4; c++) {
        st[r + 4 * c] = row[(c + r) % 4];
      }
    }
  }

  void mixColumns() {
    for (var c = 0; c < 4; c++) {
      final a0 = st[4 * c], a1 = st[4 * c + 1],
          a2 = st[4 * c + 2], a3 = st[4 * c + 3];
      st[4 * c] = _gmul(a0, 2) ^ _gmul(a1, 3) ^ a2 ^ a3;
      st[4 * c + 1] = a0 ^ _gmul(a1, 2) ^ _gmul(a2, 3) ^ a3;
      st[4 * c + 2] = a0 ^ a1 ^ _gmul(a2, 2) ^ _gmul(a3, 3);
      st[4 * c + 3] = _gmul(a0, 3) ^ a1 ^ a2 ^ _gmul(a3, 2);
    }
  }

  addRoundKey(0);
  for (var round = 1; round < nr; round++) {
    subBytes();
    shiftRows();
    mixColumns();
    addRoundKey(round);
  }
  subBytes();
  shiftRows();
  addRoundKey(nr);
  return st;
}

/// AES decrypt d'un bloc 16 octets (FIPS-197 inversé).
List<int> _aesDecryptBlock(Uint8List key, List<int> block) {
  final invSbox = _getInvSbox();
  final nk = key.length ~/ 4;
  final nr = nk + 6;
  final w = _expandKey(key);
  final st = List<int>.from(block);
  void addRoundKey(int round) {
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        st[r + 4 * c] ^= w[(round * 4 + c) * 4 + r];
      }
    }
  }

  void invSubBytes() {
    for (var i = 0; i < 16; i++) {
      st[i] = invSbox[st[i]];
    }
  }

  void invShiftRows() {
    for (var r = 1; r < 4; r++) {
      final row = [st[r], st[r + 4], st[r + 8], st[r + 12]];
      for (var c = 0; c < 4; c++) {
        st[r + 4 * c] = row[(c + 4 - r) % 4];
      }
    }
  }

  void invMixColumns() {
    for (var c = 0; c < 4; c++) {
      final a0 = st[4 * c], a1 = st[4 * c + 1],
          a2 = st[4 * c + 2], a3 = st[4 * c + 3];
      st[4 * c] =
          _gmul(a0, 14) ^ _gmul(a1, 11) ^ _gmul(a2, 13) ^ _gmul(a3, 9);
      st[4 * c + 1] =
          _gmul(a0, 9) ^ _gmul(a1, 14) ^ _gmul(a2, 11) ^ _gmul(a3, 13);
      st[4 * c + 2] =
          _gmul(a0, 13) ^ _gmul(a1, 9) ^ _gmul(a2, 14) ^ _gmul(a3, 11);
      st[4 * c + 3] =
          _gmul(a0, 11) ^ _gmul(a1, 13) ^ _gmul(a2, 9) ^ _gmul(a3, 14);
    }
  }

  addRoundKey(nr);
  for (var round = nr - 1; round >= 1; round--) {
    invShiftRows();
    invSubBytes();
    addRoundKey(round);
    invMixColumns();
  }
  invShiftRows();
  invSubBytes();
  addRoundKey(0);
  return st;
}

/// AES-CBC decrypt + retrait padding PKCS7 (port exact de la fonction L du
//  bundle : crypto.subtle.decrypt({name:'AES-CBC', iv:A()}, T(), hexBytes)).
Uint8List aesCbcDecrypt(Uint8List key, Uint8List iv, Uint8List data) {
  if (data.length % 16 != 0) {
    throw ArgumentError('CBC: longueur ${data.length} non multiple de 16');
  }
  final out = BytesBuilder();
  var prev = iv;
  for (var off = 0; off < data.length; off += 16) {
    final block = data.sublist(off, off + 16);
    final dec = _aesDecryptBlock(key, block);
    for (var i = 0; i < 16; i++) {
      dec[i] ^= prev[i];
    }
    out.add(dec);
    prev = Uint8List.fromList(block);
  }
  var bytes = out.toBytes();
  final pad = bytes.isEmpty ? 0 : bytes.last;
  if (pad > 0 && pad <= 16 && bytes.length >= pad) {
    var ok = true;
    for (var i = bytes.length - pad; i < bytes.length; i++) {
      if (bytes[i] != pad) ok = false;
    }
    if (ok) bytes = bytes.sublist(0, bytes.length - pad);
  }
  return bytes;
}

// ══════════════════════════════════════════════════════════════════
//  2. Extracteur lpayer.embed4me.com
// ══════════════════════════════════════════════════════════════════

/// Ajoute k/kx à une URL /v4/ (port exact de la fonction B du bundle).
String _withPk(String url, Map<String, dynamic> pk) {
  final k = pk['k']?.toString() ?? '';
  final kx = pk['kx']?.toString() ?? '';
  if (k.isEmpty || !url.contains('/v4/') || url.contains('k=$k')) return url;
  return '$url${url.contains('?') ? '&' : '?'}k=$k&kx=$kx';
}

/// extractLpayerFinal(url) — extracteur autonome lpayer.embed4me.com.
///
/// Retourne un Map :
///   {success, video_url, server:'lpayer', type:'hls', is_hls:true, title,
///    headers:{User-Agent, Referer}, sources:[candidats], pk} ou {error}.
Future<Map<String, dynamic>> extractLpayerFinal(String url) async {
  // 1. videoId = fragment (fonction M du bundle)
  final frag = Uri.parse(url).fragment;
  final id = frag.split('&').first;
  if (id.length <= 1) {
    return {'error': 'lpayer: pas de videoId dans le fragment de $url'};
  }

  try {
    // 2-3. GET /api/v1/video + décrypt AES-CBC
    final (status, body) = await _httpGet(
      '$_apiBase/api/v1/video?id=$id&w=1920&h=1080&r=',
      headers: {'Referer': _referer},
    );
    if (status != 200) {
      return {'error': 'lpayer /api/v1/video HTTP $status: $body'};
    }
    if (!RegExp(r'^[\da-fA-F]+$').hasMatch(body.trim())) {
      return {'error': 'lpayer: réponse non-hex (api changée ?): '
          '${body.substring(0, min(120, body.length))}'};
    }
    final ct = body.trim();
    final bytes = Uint8List.fromList(List<int>.generate(
        ct.length ~/ 2,
        (i) => int.parse(ct.substring(i * 2, i * 2 + 2), radix: 16)));
    final plain = utf8.decode(aesCbcDecrypt(_aesKey, _aesIv, bytes));
    final json = jsonDecode(plain) as Map<String, dynamic>;

    final pk = json['pk'] as Map<String, dynamic>? ?? {};
    final title = json['title']?.toString();

    // 4-5. candidats dans l'ordre de robustesse mesurée
    final candidates = <String>[];
    final source = json['source']?.toString(); // In-House (IP directe)
    if (source != null && source.isNotEmpty) {
      candidates.add(_withPk(source, pk));
    }
    final cfNative = json['cfNative']?.toString(); // proxy lpayer pré-signé
    if (cfNative != null && cfNative.isNotEmpty) candidates.add(cfNative);
    final cf = json['cf']?.toString(); // Cloudflare cf-master.*.txt
    if (cf != null && cf.isNotEmpty) candidates.add(_withPk(cf, pk));
    if (candidates.isEmpty) {
      return {'error': 'lpayer: aucune source dans la réponse déchiffrée'};
    }

    return {
      'success': true,
      'video_url': candidates.first,
      'server': 'lpayer',
      'type': 'hls',
      'is_hls': true,
      'title': title,
      'sources': candidates,
      'pk': pk,
      'headers': {
        'User-Agent': _ua,
        'Referer': _referer,
      },
    };
  } catch (e, st) {
    return {'error': 'lpayer: $e', 'stack': '$st'};
  }
}

// ══════════════════════════════════════════════════════════════════
//  main : self-test AES + extraction réelle + preuve HEAD/Range + anti-troll
// ══════════════════════════════════════════════════════════════════

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<(int, int)> _probe(String url, {bool range = false}) async {
  final c = _client();
  try {
    final req = await c
        .openUrl(range ? 'GET' : 'HEAD', Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    req.headers.set('User-Agent', _ua);
    req.headers.set('Referer', _referer);
    if (range) req.headers.set('Range', 'bytes=0-65535');
    final resp = await req.close().timeout(const Duration(seconds: 20));
    var total = 0;
    await for (final chunk in resp) {
      total += chunk.length;
      if (range && total >= 65536) break;
    }
    stdout.writeln(
        '   → HTTP ${resp.statusCode} (${resp.headers.contentType}) $total octets lus');
    return (resp.statusCode, total);
  } finally {
    c.close(force: true);
  }
}

/// Vérifie que le master n'est pas un leurre : sous-playlist lisible et
/// durée cumulée EXTINF raisonnable pour un épisode (> 5 min).
Future<String?> _authenticate(String masterUrl) async {
  if (masterUrl.contains('/troll/')) return 'URL contient /troll/';
  final (code, body) = await _httpGet(masterUrl,
      headers: {'Referer': _referer, 'User-Agent': _ua});
  if (code != 200) return 'master HTTP $code';
  if (!body.contains('#EXTM3U')) return 'pas un M3U8';
  if (body.toLowerCase().contains('bigbuckbunny') ||
      body.toLowerCase().contains('bbb_')) {
    return 'contenu Big Buck Bunny détecté';
  }
  var sub = body
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
  if (sub.isEmpty) return 'master sans sous-playlist';
  final subUrl = sub.startsWith('http')
      ? sub
      : Uri.parse(masterUrl).resolve(sub).toString();
  final (sCode, sBody) = await _httpGet(subUrl, headers: {'Referer': _referer});
  if (sCode != 200) return 'sous-playlist HTTP $sCode';
  var dur = 0.0;
  for (final m in RegExp(r'#EXTINF:([\d.]+)').allMatches(sBody)) {
    dur += double.tryParse(m.group(1)!) ?? 0;
  }
  final segs =
      sBody.split('\n').where((l) => l.trim().isNotEmpty && !l.startsWith('#')).length;
  stdout.writeln(
      '   → sous-playlist : $segs segments, durée cumulée ${dur.toStringAsFixed(1)} s');
  if (dur < 300) return 'durée suspecte (${dur}s < 300s) — probable leurre';
  return null;
}

Future<void> main(List<String> args) async {
  final urls = args.isNotEmpty
      ? args
      : [
          'https://lpayer.embed4me.com/#h18ej', // PEMB S1 EP1
          'https://lpayer.embed4me.com/#pjwt9', // PEMB S1 EP2
        ];

  // Self-test AES-128 (vecteur NIST FIPS-197 : clé 0, bloc 0)
  final encOk =
      _hex(aesEncryptBlock(Uint8List(16), List<int>.filled(16, 0))) ==
          '66e94bd4ef8a2c3b884cfa59ca342b2e';
  stdout.writeln('[selftest] AES-128 encrypt(0,0) : ${encOk ? "OK" : "ÉCHEC"}');
  final decOk =
      _hex(_aesDecryptBlock(Uint8List(16), List<int>.filled(16, 0))) ==
          '140f0f1011b5223d79587717ffd9ec3a';
  stdout.writeln('[selftest] AES-128 decrypt(0,0) : ${decOk ? "OK" : "ÉCHEC"}');
  // Round-trip CBC : bloc chiffré à la main (ECB par bloc + XOR chaînage)
  final ptBlock = utf8.encode('0123456789abcdef'); // 16 o exactement
  final ctBlock = aesEncryptBlock(_aesKey, () {
    final b = List<int>.from(ptBlock);
    for (var i = 0; i < 16; i++) {
      b[i] ^= _aesIv[i];
    }
    return b;
  }());
  final rt = aesCbcDecrypt(_aesKey, _aesIv, Uint8List.fromList(ctBlock));
  final rtOk = utf8.decode(rt) == '0123456789abcdef';
  stdout.writeln('[selftest] CBC round-trip     : ${rtOk ? "OK" : "ÉCHEC"}');
  if (!encOk || !decOk || !rtOk) exit(2);

  var failures = 0;
  for (final url in urls) {
    stdout.writeln('\n[extract] $url');
    final sw = Stopwatch()..start();
    final res = await extractLpayerFinal(url);
    stdout.writeln('[extract] terminé en ${sw.elapsed.inMilliseconds} ms');
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(res));

    if (res['success'] != true) {
      failures++;
      continue;
    }
    final v = res['video_url'] as String;
    final fraud = await _authenticate(v);
    if (fraud != null) {
      stdout.writeln('\n❌ LEURRE DÉTECTÉ : $fraud — URL rejetée');
      failures++;
      continue;
    }
    stdout.writeln('\n[proof] HEAD $v');
    final (headCode, _) = await _probe(v);
    stdout.writeln('[proof] GET Range bytes=0-65535 (segment 1)');
    // master → sous-playlist → premier segment
    final (_, masterBody) =
        await _httpGet(v, headers: {'Referer': _referer});
    final sub = masterBody
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
    final subUrl =
        sub.startsWith('http') ? sub : Uri.parse(v).resolve(sub).toString();
    final (_, subBody) =
        await _httpGet(subUrl, headers: {'Referer': _referer});
    final seg = subBody
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
    final segUrl = seg.startsWith('http')
        ? seg
        : Uri.parse(subUrl).resolve(seg).toString();
    final (rangeCode, _) = await _probe(segUrl, range: true);
    if (headCode == 200 && (rangeCode == 200 || rangeCode == 206)) {
      stdout.writeln('\n✅ STREAM VALIDE : HEAD=$headCode Range=$rangeCode');
    } else {
      stdout.writeln('\n⚠️  codes inattendus HEAD=$headCode Range=$rangeCode');
      failures++;
    }
  }
  if (failures > 0) exitCode = 1;
}
