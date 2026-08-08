import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Résolveur DNS-over-HTTPS interne à l'app.
///
/// Pourquoi : sur les réseaux FAI français qui bloquent légalement les
/// hébergeurs de vidéos (uqload, vidmoly, doodstream…), le DNS système
/// renvoie des adresses « poison » (127.0.0.1 / IP piège) → `Connection
/// refused` à la connexion. Le système est contourné en demandant les
/// enregistrements A/AAAA directement à Google/Cloudflare en HTTPS.
///
/// Stratégie :
/// 1. Cache mémoire (+ TTL court)
/// 2. dns.google (JSON) en priorité, cloudflare-dns.com (JSON) en repli
/// 3. Repli sur la résolution système si le DoH échoue (jamais pire)
class DohResolver {
  DohResolver._();
  static final DohResolver instance = DohResolver._();

  static const Duration _ttl = Duration(minutes: 10);
  static const Duration _timeout = Duration(seconds: 5);

  final Map<String, (List<String> ips, DateTime expiry)> _cache = {};

  /// Résout [host] et renvoie la liste d'IPv4 candidates (meilleures d'abord).
  /// Jamais vide si une méthode quelconque réussit ; vide = 127.0.0.1 écarté.
  Future<List<String>> resolve(String host) async {
    // Une IP est déjà fournie → rien à résoudre
    if (InternetAddress.tryParse(host) != null) return [host];

    final cached = _cache[host];
    if (cached != null && cached.$2.isAfter(DateTime.now())) {
      return cached.$1;
    }

    // 1) DoH Google
    var ips = await _queryDoh('https://dns.google/resolve', host);
    // 2) DoH Cloudflare en repli
    if (ips.isEmpty) {
      ips = await _queryDoh('https://cloudflare-dns.com/dns-query', host,
          acceptHeader: 'application/dns-json');
    }
    // Filtrage des adresses « poison » de blocage FAI
    ips = ips.where((ip) => !_isPoison(ip)).toList();

    // 3) Repli système si le DoH n'a rien donné (rare : pas de réseau DoH)
    if (ips.isEmpty) {
      try {
        final list = await InternetAddress.lookup(host)
            .timeout(_timeout, onTimeout: () => const <InternetAddress>[]);
        ips = list
            .where((a) => a.type == InternetAddressType.IPv4)
            .map((a) => a.address)
            .toList();
      } catch (_) {}
      ips = ips.where((ip) => !_isPoison(ip)).toList();
    }

    _cache[host] = (ips, DateTime.now().add(_ttl));
    return ips;
  }

  bool _isPoison(String ip) =>
      ip == '127.0.0.1' ||
      ip == '127.0.1.1' ||
      ip.startsWith('127.') ||
      ip == '0.0.0.0';

  Future<List<String>> _queryDoh(String endpoint, String host,
      {String acceptHeader = 'application/dns-json'}) async {
    try {
      final url = Uri.parse('$endpoint?name=$host&type=A');
      final resp = await http
          .get(url, headers: {'Accept': acceptHeader})
          .timeout(_timeout);
      if (resp.statusCode != 200) return const [];
      final data = jsonDecode(resp.body);
      final answers = data['Answer'];
      if (answers is! List) return const [];
      final out = <String>[];
      for (final a in answers) {
        if (a is Map && a['type'] == 1 && a['data'] is String) {
          final ip = a['data'] as String;
          if (InternetAddress.tryParse(ip) != null) out.add(ip);
        }
      }
      // Un peu d'aléatoire pour répartir la charge entre IP équivalentes
      out.shuffle();
      return out;
    } catch (_) {
      return const [];
    }
  }

  void invalidate(String host) => _cache.remove(host);
}
