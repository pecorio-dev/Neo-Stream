// re_filemoon.dart — Reverse-engineering filemoon.sx (SPA "Byse Frontend")
// et famille Byse/netu : bysebuho.com, younetu.com, bysewihe.com.
//
// Algorithme cassé le 2026-08-08 depuis :
//   - https://filemoon.sx/assets/index-DocunfmE.js        (shell + RPC /api/...)
//   - https://filemoon.sx/assets/videoPagesBundle-Bgi0QmPo.js (pages vidéo)
//   - https://filemoon.sx/assets/pow-DEJGtdh2.js          (PoW + attestation)
//
// PIPELINE EXACT du frontend (miroir fidèle) :
//   1. GET  /api/videos/{code}/embed/settings   → captcha_required ?
//   2. POST /api/videos/access/challenge        → {challenge_id, nonce}
//      signature ECDSA P-256 / SHA-256 du nonce (r||s 64o, base64url)
//      POST /api/videos/access/attest {viewer_id:'', device_id:'',
//        challenge_id, nonce, signature, public_key(JWK), client, storage,
//        attributes:{entropy}}                 → {token, viewer_id, device_id,
//                                                  confidence}
//   3. PoW captcha (si captcha_required) :
//      POST /api/videos/{code}/embed/captcha {} → {pow_nonce, pow_difficulty,
//                                                   pow_token}
//      solver : hash propriétaire gr() (IV SHA-256 + ronde ChaCha quarter,
//      mémoire 512×u32, 2 passes) ; trouver s tel que
//      leadingZeroBits(gr(pow_nonce + ':' + s)) >= pow_difficulty
//      POST /api/videos/{code}/embed/captcha/verify {pow_token, solution,
//        fingerprint}                          → {status:'ok', token}
//   4. POST /api/videos/{code}/embed/playback {fingerprint:{token, viewer_id,
//      device_id, confidence}} + header X-Captcha-Token: <captcha token>
//                                              → {playback:{key_parts, version,
//                                                  iv, payload}}
//   5. Déchiffrement playback (AES-GCM) :
//      version N → key = concat(base64url(key_parts[N-1]),
//                               base64url(key_parts[31-N-1]))
//      plaintext = AES-GCM(key, iv=b64u(iv), payload=b64u(payload))
//      → JSON {sources:[{quality, label, mime_type, url, ...}], tracks}
//   6. sources[].url = master.m3u8 HLS signé (e=10800s), CDN sprintcdn.
//
// Tout est en pur Dart (dart:io uniquement) : SHA-256, ECDSA P-256, AES-GCM
// et le hash PoW sont réimplémentés ici (zéro dépendance externe).
//
// Usage : dart bin/re_filemoon.dart [url_embed_filemoon]
// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures, unused_local_variable, unused_element, unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// ══════════════════════════════════════════════════════════════════
//  0. Utilitaires base64url + HTTP TLS-tolérant
// ══════════════════════════════════════════════════════════════════

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

String b64uEncode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll(RegExp(r'=+$'), '');

Uint8List b64uDecode(String s) {
  var t = s.replaceAll('-', '+').replaceAll('_', '/');
  final r = t.length % 4;
  if (r != 0) t += '=' * (4 - r);
  return Uint8List.fromList(base64.decode(t));
}

HttpClient _client() {
  final c = HttpClient();
  c.badCertificateCallback = (_, __, ___) => true;
  c.connectionTimeout = const Duration(seconds: 15);
  c.userAgent = _ua;
  return c;
}

Future<(int, String)> _httpJson(
  String method,
  String url, {
  Map<String, String>? headers,
  Object? body,
}) async {
  final c = _client();
  try {
    final req = await c
        .openUrl(method, Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    req.headers.set('User-Agent', _ua);
    req.headers.set('Accept', 'application/json, */*');
    headers?.forEach((k, v) => req.headers.set(k, v));
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final resp =
        await req.close().timeout(const Duration(seconds: 20));
    final txt = await resp.transform(utf8.decoder).join();
    return (resp.statusCode, txt);
  } finally {
    c.close(force: true);
  }
}

// ══════════════════════════════════════════════════════════════════
//  1. SHA-256 (pur Dart — requis pour la signature ECDSA WebCrypto)
// ══════════════════════════════════════════════════════════════════

const _k256 = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

Uint8List sha256bytes(Uint8List msg) {
  final h = <int>[
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];
  final ml = msg.length;
  final padded = BytesBuilder()
    ..add(msg)
    ..addByte(0x80);
  while ((padded.length % 64) != 56) padded.addByte(0);
  final bitLen = ml * 8;
  for (var i = 7; i >= 0; i--) padded.addByte((bitLen >> (i * 8)) & 0xFF);
  final data = padded.toBytes();
  int rotr(int v, int n) => ((v >> n) | (v << (32 - n))) & 0xFFFFFFFF;
  final w = List<int>.filled(64, 0);
  for (var off = 0; off < data.length; off += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = (data[off + 4 * i] << 24) |
          (data[off + 4 * i + 1] << 16) |
          (data[off + 4 * i + 2] << 8) |
          data[off + 4 * i + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3],
        e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ (~e & g);
      final t1 = (hh + s1 + ch + _k256[i] + w[i]) & 0xFFFFFFFF;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xFFFFFFFF;
      hh = g; g = f; f = e;
      e = (d + t1) & 0xFFFFFFFF;
      d = c; c = b; b = a;
      a = (t1 + t2) & 0xFFFFFFFF;
    }
    h[0] = (h[0] + a) & 0xFFFFFFFF;
    h[1] = (h[1] + b) & 0xFFFFFFFF;
    h[2] = (h[2] + c) & 0xFFFFFFFF;
    h[3] = (h[3] + d) & 0xFFFFFFFF;
    h[4] = (h[4] + e) & 0xFFFFFFFF;
    h[5] = (h[5] + f) & 0xFFFFFFFF;
    h[6] = (h[6] + g) & 0xFFFFFFFF;
    h[7] = (h[7] + hh) & 0xFFFFFFFF;
  }
  final out = Uint8List(32);
  for (var i = 0; i < 8; i++) {
    out[4 * i] = (h[i] >> 24) & 0xFF;
    out[4 * i + 1] = (h[i] >> 16) & 0xFF;
    out[4 * i + 2] = (h[i] >> 8) & 0xFF;
    out[4 * i + 3] = h[i] & 0xFF;
  }
  return out;
}

// ══════════════════════════════════════════════════════════════════
//  2. ECDSA P-256 (BigInt) — remplace crypto.subtle.generateKey/sign
// ══════════════════════════════════════════════════════════════════

final _p256 = BigInt.parse(
    'ffffffff00000001000000000000000000000000ffffffffffffffffffffffff',
    radix: 16);
final _n256 = BigInt.parse(
    'ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551',
    radix: 16);
final _b256 = BigInt.parse(
    '5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b',
    radix: 16);
final _gx256 = BigInt.parse(
    '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296',
    radix: 16);
final _gy256 = BigInt.parse(
    '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
    radix: 16);

class _EcPoint {
  final BigInt? x, y; // null => infini
  _EcPoint(this.x, this.y);
}

_EcPoint _ecAdd(_EcPoint a, _EcPoint b) {
  if (a.x == null) return b;
  if (b.x == null) return a;
  final ax = a.x!, ay = a.y!, bx = b.x!, by = b.y!;
  if (ax == bx && (ay + by) % _p256 == BigInt.zero) {
    return _EcPoint(null, null);
  }
  BigInt m;
  if (ax == bx && ay == by) {
    // pente tangente : (3x² + a) / (2y), avec a = p - 3
    final nume = (BigInt.from(3) * ax * ax - BigInt.from(3)) % _p256;
    final deno = (BigInt.from(2) * ay).modInverse(_p256);
    m = (nume * deno) % _p256;
  } else {
    final nume = (by - ay) % _p256;
    final deno = (bx - ax).modInverse(_p256);
    m = (nume * deno) % _p256;
  }
  final rx = (m * m - ax - bx) % _p256;
  final ry = (m * (ax - rx) - ay) % _p256;
  return _EcPoint((rx + _p256) % _p256, (ry + _p256) % _p256);
}

_EcPoint _ecMul(BigInt k, _EcPoint pt) {
  var r = _EcPoint(null, null);
  var q = pt;
  for (var i = 0; i < k.bitLength; i++) {
    if ((k >> i) & BigInt.one == BigInt.one) r = _ecAdd(r, q);
    q = _ecAdd(q, q);
  }
  return r;
}

BigInt _randScalar() {
  final rng = Random.secure();
  while (true) {
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    var hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final v = BigInt.parse(hex, radix: 16);
    if (v > BigInt.zero && v < _n256) return v;
  }
}

class _EcdsaKey {
  final BigInt d; // privé
  final _EcPoint pub;
  _EcdsaKey(this.d, this.pub);

  Map<String, String> jwk() {
    String pad(BigInt v) => b64uEncode(_bigIntToBytes(v, 32));
    return {'kty': 'EC', 'crv': 'P-256', 'x': pad(pub.x!), 'y': pad(pub.y!)};
  }

  /// Signature ECDSA/SHA-256 (format r||s 64 octets — IEEE P1363 de WebCrypto).
  Uint8List sign(Uint8List message) {
    final z = BigInt.parse(
        sha256bytes(message).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16);
    while (true) {
      final k = _randScalar();
      final rp = _ecMul(k, _EcPoint(_gx256, _gy256));
      final r = rp.x! % _n256;
      if (r == BigInt.zero) continue;
      final s = (k.modInverse(_n256) * (z + r * d)) % _n256;
      if (s == BigInt.zero) continue;
      return Uint8List.fromList(_bigIntToBytes(r, 32) + _bigIntToBytes(s, 32));
    }
  }
}

List<int> _bigIntToBytes(BigInt v, int len) {
  final hex = v.toRadixString(16).padLeft(len * 2, '0');
  return List<int>.generate(
      len, (i) => int.parse(hex.substring(2 * i, 2 * i + 2), radix: 16));
}

_EcdsaKey ecdsaGenerate() {
  final d = _randScalar();
  return _EcdsaKey(d, _ecMul(d, _EcPoint(_gx256, _gy256)));
}

// ══════════════════════════════════════════════════════════════════
//  3. Hash PoW propriétaire (port exact de gr()/ye()/wr() du chunk pow)
//     — annoncé côté API comme "sha256-leading-zero-bits"
// ══════════════════════════════════════════════════════════════════

int _rotl32(int v, int n) => ((v << n) | (v >> (32 - n))) & 0xFFFFFFFF;

void _powYe(List<int> t) {
  t[0] = (t[0] + t[1]) & 0xFFFFFFFF;
  t[3] = _rotl32(t[3] ^ t[0], 16);
  t[2] = (t[2] + t[3]) & 0xFFFFFFFF;
  t[1] = _rotl32(t[1] ^ t[2], 12);
  t[0] = (t[0] + t[1]) & 0xFFFFFFFF;
  t[3] = _rotl32(t[3] ^ t[0], 8);
  t[2] = (t[2] + t[3]) & 0xFFFFFFFF;
  t[1] = _rotl32(t[1] ^ t[2], 7);
}

Uint32List _powGr(Uint8List input) {
  final e = Uint32List.fromList(
      [1779033703, 3144134277, 1013904242, 2773480762]);
  for (var i = 0; i < input.length; i++) {
    e[0] = (e[0] + input[i]) & 0xFFFFFFFF;
    e[0] = _rotl32(e[0], 7);
    _powYe(e);
  }
  for (var i = 0; i < 8; i++) _powYe(e);
  final r = Uint32List(512);
  for (var i = 0; i < 512; i++) {
    _powYe(e);
    r[i] = (e[0] ^ e[2]) & 0xFFFFFFFF;
  }
  for (var i = 0; i < 2; i++) {
    for (var s = 0; s < 512; s++) {
      final a = r[s] & 511;
      var c = (r[s] + r[a]) & 0xFFFFFFFF;
      c = _rotl32(c, 13);
      c = (c ^ ((r[(s + 1) & 511] * 2654435761) & 0xFFFFFFFF)) & 0xFFFFFFFF;
      r[s] = c;
      e[0] = (e[0] ^ c) & 0xFFFFFFFF;
      _powYe(e);
    }
  }
  final n = Uint32List(8);
  for (var i = 0; i < 8; i++) {
    _powYe(e);
    var s = e[0];
    final base = i * 64;
    for (var c = 0; c < 64; c++) {
      final d = r[base + c];
      s = (s + d) & 0xFFFFFFFF;
      s = _rotl32(s, 5);
      s = (s ^ ((d * 2246822519) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    }
    n[i] = (s ^ e[2]) & 0xFFFFFFFF;
  }
  return n;
}

int _powLeadingZeros(Uint32List words) {
  var acc = 0;
  for (final w in words) {
    if (w == 0) {
      acc += 32;
      continue;
    }
    var n = 0;
    for (var i = 31; i >= 0; i--) {
      if ((w >> i) & 1 == 1) break;
      n++;
    }
    return acc + n;
  }
  return acc;
}

/// solvePow : cherche s tel que gr(powNonce + ':' + s) ait >= [difficulty]
/// bits de tête nuls. Retourne la solution en string, ou null (timeout).
Future<String?> solvePow(String powNonce, int difficulty,
    {Duration timeout = const Duration(seconds: 120)}) async {
  if (difficulty <= 0) return '0';
  final prefix = powNonce + ':';
  final sw = Stopwatch()..start();
  var s = 0;
  while (true) {
    for (var c = 0; c < 4096; c++) {
      final h = _powGr(Uint8List.fromList(utf8.encode('$prefix$s')));
      if (_powLeadingZeros(h) >= difficulty) return '$s';
      s++;
    }
    if (sw.elapsed > timeout) return null;
    await Future.delayed(Duration.zero); // laisse respirer l'event loop
  }
}

// ══════════════════════════════════════════════════════════════════
//  4. AES (S-box calculée — zéro table forcée) + CTR pour GCM
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

List<int>? _sbox;

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

/// AES encrypt d'un bloc 16 octets (clé 16/24/32 octets). FIPS-197 textbook.
List<int> _aesEncryptBlock(Uint8List key, List<int> block) {
  final sbox = _getSbox();
  final nk = key.length ~/ 4;
  final nr = nk + 6;
  // Key expansion (colonnes de 4 octets)
  final w = List<int>.filled(4 * (nr + 1) * 4, 0);
  for (var i = 0; i < key.length; i++) {
    w[i] = key[i];
  }
  var rcon = 1;
  for (var i = nk; i < 4 * (nr + 1); i++) {
    var t0 = w[(i - 1) * 4], t1 = w[(i - 1) * 4 + 1],
        t2 = w[(i - 1) * 4 + 2], t3 = w[(i - 1) * 4 + 3];
    if (i % nk == 0) {
      // RotWord + SubWord + Rcon
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
  // État : state[r][c] = block[r + 4c]
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

/// GCM CTR (32 derniers bits du compteur incrémentés, big-endian).
Uint8List aesGcmCtrCrypt(Uint8List key, Uint8List iv12, Uint8List data) {
  if (iv12.length != 12) throw ArgumentError('IV GCM 12 octets attendu');
  final counter = Uint8List(16)
    ..setRange(0, 12, iv12)
    ..[15] = 1; // J0 = iv || 0x00000001
  Uint8List out = Uint8List(data.length);
  var offset = 0;
  while (offset < data.length) {
    // inc32
    for (var i = 15; i >= 12; i--) {
      counter[i] = (counter[i] + 1) & 0xFF;
      if (counter[i] != 0) break;
    }
    final ks = _aesEncryptBlock(key, counter);
    final n = min(16, data.length - offset);
    for (var i = 0; i < n; i++) {
      out[offset + i] = data[offset + i] ^ ks[i];
    }
    offset += n;
  }
  return out;
}

// ══════════════════════════════════════════════════════════════════
//  5. Extracteur filemoon/byse
// ══════════════════════════════════════════════════════════════════

/// extractFilemoonFinal(url) — extracteur autonome filemoon.sx / byse.
///
/// Retourne un Map :
///   {success, video_url, type:'hls', label/quality, headers:{User-Agent,
///    Referer, Origin}, sources:[...], server:'filemoon'} ou {error}.
Future<Map<String, dynamic>> extractFilemoonFinal(String url) async {
  final m = RegExp(r'/(e|v|d|p)/([A-Za-z0-9]+)').firstMatch(url);
  if (m == null) return {'error': 'Filemoon: code introuvable dans $url'};
  final code = m.group(2)!;
  final uri = Uri.parse(url);
  final base = '${uri.scheme}://${uri.host}';
  final ref = '$base/e/$code';
  final api = '$base/api/videos';

  try {
    // ── 1. settings ─────────────────────────────────────────────
    final (sStatus, sBody) =
        await _httpJson('GET', '$api/$code/embed/settings', headers: {
      'Referer': ref,
    });
    if (sStatus != 200) {
      return {'error': 'Filemoon settings HTTP $sStatus: $sBody'};
    }
    final settings = jsonDecode(sBody) as Map<String, dynamic>;
    final captchaRequired = settings['captcha_required'] == true;

    // ── 2. attestation device (ECDSA P-256) ─────────────────────
    final key = ecdsaGenerate();
    final (cStatus, cBody) = await _httpJson(
        'POST', '$api/access/challenge', headers: {'Referer': ref});
    if (cStatus != 200) {
      return {'error': 'Filemoon challenge HTTP $cStatus: $cBody'};
    }
    final ch = jsonDecode(cBody) as Map<String, dynamic>;
    final sig = key.sign(Uint8List.fromList(utf8.encode('${ch['nonce']}')));
    final attestPayload = {
      'viewer_id': '',
      'device_id': '',
      'challenge_id': ch['challenge_id'],
      'nonce': ch['nonce'],
      'signature': b64uEncode(sig),
      'public_key': key.jwk(),
      'client': {
        'user_agent': _ua,
        'pixel_ratio': 1,
        'screen_width': 1920,
        'screen_height': 1080,
        'color_depth': 24,
        'languages': ['en-US', 'en'],
        'timezone': 'Europe/Paris',
        'hardware_concurrency': 8,
        'device_memory': 8,
        'touch_points': 0,
        'webgl_vendor': 'Google Inc. (NVIDIA)',
        'webgl_renderer':
            'ANGLE (NVIDIA, NVIDIA GeForce GTX 1650 Direct3D11 vs_5_0 ps_5_0, D3D11)',
        'extra': {'vendor': 'Google Inc.', 'appVersion': _ua.replaceFirst('Mozilla/', '')},
      },
      'storage': <String, dynamic>{},
      'attributes': {'entropy': 'medium'},
    };
    final (aStatus, aBody) = await _httpJson('POST', '$api/access/attest',
        headers: {'Referer': ref}, body: attestPayload);
    if (aStatus != 200) {
      return {'error': 'Filemoon attest HTTP $aStatus: $aBody'};
    }
    final att = jsonDecode(aBody) as Map<String, dynamic>;
    final fingerprint = {
      'token': att['token'],
      'viewer_id': att['viewer_id'],
      'device_id': att['device_id'],
      'confidence': att['confidence'],
    };

    // ── 3. captcha PoW (si requis) ──────────────────────────────
    String? captchaToken;
    if (captchaRequired) {
      final (p1s, p1b) = await _httpJson('POST', '$api/$code/embed/captcha',
          headers: {'Referer': ref}, body: {'fingerprint': fingerprint});
      if (p1s != 200) {
        return {'error': 'Filemoon captcha HTTP $p1s: $p1b'};
      }
      final p1 = jsonDecode(p1b) as Map<String, dynamic>;
      final nonce = p1['pow_nonce'] as String;
      final difficulty = (p1['pow_difficulty'] as num).toInt();
      final solution = await solvePow(nonce, difficulty);
      if (solution == null) {
        return {'error': 'Filemoon PoW: timeout'};
      }
      final (p2s, p2b) = await _httpJson(
          'POST', '$api/$code/embed/captcha/verify',
          headers: {'Referer': ref},
          body: {
            'pow_token': p1['pow_token'],
            'solution': solution,
            'fingerprint': fingerprint,
          });
      if (p2s != 200) {
        return {'error': 'Filemoon captcha verify HTTP $p2s: $p2b'};
      }
      final p2 = jsonDecode(p2b) as Map<String, dynamic>;
      if (p2['status'] != 'ok') {
        return {'error': 'Filemoon PoW refusé: $p2b'};
      }
      captchaToken = p2['token'] as String;
    }

    // ── 4. playback (chiffré) ───────────────────────────────────
    final headers = <String, String>{'Referer': ref};
    if (captchaToken != null) headers['X-Captcha-Token'] = captchaToken;
    final (pbStatus, pbBody) = await _httpJson(
        'POST', '$api/$code/embed/playback',
        headers: headers, body: {'fingerprint': fingerprint});
    if (pbStatus != 200) {
      return {'error': 'Filemoon playback HTTP $pbStatus: $pbBody'};
    }
    final pb = jsonDecode(pbBody) as Map<String, dynamic>;
    final encrypted = pb['playback'] as Map<String, dynamic>?;
    if (encrypted == null) {
      return {'error': 'Filemoon: pas de payload playback: $pbBody'};
    }

    // ── 5. déchiffrement AES-GCM ────────────────────────────────
    final parts =
        ((encrypted['key_parts'] as List?) ?? const []).cast<String>();
    if (parts.isEmpty) {
      return {'error': 'Filemoon: key_parts vide'};
    }
    final version = int.tryParse('${encrypted['version']}');
    List<String> selected = parts;
    if (version != null) {
      final sel = [version, 31 - version];
      final ok = sel.every((i) => i >= 1 && i <= parts.length);
      if (ok) {
        final picked =
            sel.map((i) => parts[i - 1]).where((s) => s.isNotEmpty).toList();
        if (picked.isNotEmpty) selected = picked;
      }
    }
    final keyBytes = <int>[];
    for (final p in selected) {
      keyBytes.addAll(b64uDecode(p));
    }
    final iv = b64uDecode('${encrypted['iv']}');
    final ct = b64uDecode('${encrypted['payload']}');
    if (ct.length < 17) {
      return {'error': 'Filemoon: payload trop court'};
    }
    // GCM : 16 derniers octets = tag (non vérifié — JSON.parse valide)
    final plainBytes = aesGcmCtrCrypt(Uint8List.fromList(keyBytes), iv,
        Uint8List.fromList(ct.sublist(0, ct.length - 16)));
    final plain = utf8.decode(plainBytes);
    final decoded = jsonDecode(plain) as Map<String, dynamic>;
    final sources = ((decoded['sources'] as List?) ?? const []);
    if (sources.isEmpty) {
      return {'error': 'Filemoon: sources vides après déchiffrement'};
    }
    final best = sources.first as Map<String, dynamic>;
    final videoUrl = best['url'] as String;
    final streamHeaders = {
      'User-Agent': _ua,
      'Referer': '$base/',
      'Origin': base,
    };

    return {
      'success': true,
      'video_url': videoUrl,
      'server': 'filemoon',
      'type': (best['mime_type'] == 'application/vnd.apple.mpegurl' ||
              videoUrl.contains('.m3u8'))
          ? 'hls'
          : 'mp4',
      'label': best['label'],
      'quality': best['quality'],
      'sources': sources,
      'tracks': decoded['tracks'] ?? const [],
      'headers': streamHeaders,
    };
  } catch (e, st) {
    return {'error': 'Filemoon: $e', 'stack': '$st'};
  }
}

// ══════════════════════════════════════════════════════════════════
//  main : auto-tests crypto + extraction réelle + preuve HEAD/Range
// ══════════════════════════════════════════════════════════════════

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<int> _probe(String url, {bool range = false}) async {
  final c = _client();
  try {
    final req = await c
        .openUrl(range ? 'GET' : 'HEAD', Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    req.headers.set('User-Agent', _ua);
    if (range) req.headers.set('Range', 'bytes=0-65535');
    final resp = await req.close().timeout(const Duration(seconds: 20));
    var total = 0;
    await for (final chunk in resp) {
      total += chunk.length;
      if (range && total >= 65536) break;
    }
    stdout.writeln(
        '   → HTTP ${resp.statusCode} (${resp.headers.contentType}) $total octets lus');
    return resp.statusCode;
  } finally {
    c.close(force: true);
  }
}

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args[0] : 'https://filemoon.sx/e/gq9aqo046qjm';

  // Auto-test SHA-256
  final shaOk = _hex(sha256bytes(Uint8List.fromList(utf8.encode('abc')))) ==
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
  stdout.writeln('[selftest] SHA-256("abc") : ${shaOk ? "OK" : "ÉCHEC"}');
  if (!shaOk) exit(2);

  // Auto-test AES-256 (vecteur NIST : clé 0, bloc 0)
  final aesOk = _hex(_aesEncryptBlock(Uint8List(32), List<int>.filled(16, 0))) ==
      'dc95c078a2408989ad48a21492842087';
  stdout.writeln('[selftest] AES-256(0,0)   : ${aesOk ? "OK" : "ÉCHEC"}');
  if (!aesOk) exit(2);

  stdout.writeln('[extract] $url');
  final sw = Stopwatch()..start();
  final res = await extractFilemoonFinal(url);
  stdout.writeln('[extract] terminé en ${sw.elapsed.inMilliseconds} ms');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(res));

  if (res['success'] == true) {
    final v = res['video_url'] as String;
    stdout.writeln('\n[proof] HEAD $v');
    final headCode = await _probe(v);
    stdout.writeln('[proof] GET Range bytes=0-65535');
    final rangeCode = await _probe(v, range: true);
    if (headCode == 200 && (rangeCode == 200 || rangeCode == 206)) {
      stdout.writeln('\n✅ STREAM VALIDE : HEAD=$headCode Range=$rangeCode');
    } else {
      stdout.writeln('\n⚠️  codes inattendus HEAD=$headCode Range=$rangeCode');
      exitCode = 1;
    }
  } else {
    exitCode = 1;
  }
}

void _noop() {}
