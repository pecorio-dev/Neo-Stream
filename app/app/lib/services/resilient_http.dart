import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// HTTP résilient pour neo-stream.eu.
///
/// Quand le domaine ne répond plus (DNS défaillant, mauvais enregistrement…),
/// bascule automatiquement et définitivement sur l'IP du serveur en forçant
/// `Host: neo-stream.eu` (le vhost du bon compte) :
///
///  - 1re tentative sur le domaine normal ;
///  - échec de transport (DNS, TLS, connexion) → retry sur l'IP ;
///  - si l'IP répond, toutes les requêtes suivantes passent directement par
///    l'IP (zéro latence ajoutée) pour la session.
///
/// La connexion par IP n'accepte le certificat que pour cette IP
/// (le cert du domaine y est présenté mais ne couvre pas l'IP elle-même).
class ResilientHttp {
  ResilientHttp._();

  static const String domainHost = 'neo-stream.eu';
  static const String ipFallbackHost = '91.234.195.40';

  /// Relais serveur (live_proxy) : contourne les blocages FAI sur les CDN
  /// vidéo. À préfixer devant l'URL cible (encodée).
  static const String relayBase =
      'https://neo-stream.eu/api/live_proxy.php?action=proxy_stream&url=';

  /// Enrobe une URL de flux dans le relais serveur.
  static String relayFor(String url) =>
      '$relayBase${Uri.encodeComponent(url)}';

  /// true une fois qu'une bascule a réussi : toutes les requêtes suivantes
  /// passent par l'IP directement.
  static bool useIpFallback = false;

  static http.Client? _fallbackClient;
  static http.Client? _lenientClient;

  static http.Client _clientFor(Uri url) {
    if (url.host == ipFallbackHost) {
      return _fallbackClient ??= IOClient(
        HttpClient()
          ..badCertificateCallback = (cert, host, port) =>
              host == ipFallbackHost,
      );
    }
    if (url.host == domainHost) {
      // Domaine propre : chaîne stricte (sécurité).
      return http.Client();
    }
    // Hébergeurs vidéo (uqload, vidmoly, doodstream, bigwarp, 96ar, multiup…) :
    // leurs chaînes de certificats sont très souvent incomplètes/self-signed
    // et dart:io les rejette. Tolérance volontaire — le contenu vient déjà
    // d'URLs fournies par l'API de confiance.
    return _lenientClient ??= IOClient(
      HttpClient()
        ..badCertificateCallback = (cert, host, port) => true,
    );
  }

  /// Indique si l'erreur est de transport (DNS, TLS, connexion) et non
  /// applicative — public pour les fallbacks externes (ex: relais serveur).
  static bool isTransportError(Object e) => _isTransportError(e);

  static bool _isTransportError(Object e) {
    final s = e.toString().toLowerCase();
    return e is SocketException ||
        e is HandshakeException ||
        e is http.ClientException ||
        s.contains('failed host lookup') ||
        s.contains('handshakeexception') ||
        s.contains('certificate_verify_failed') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('connection closed') ||
        s.contains('socketexception');
  }

  static Uri _effective(Uri url) {
    if (useIpFallback && url.host == domainHost) {
      return url.replace(host: ipFallbackHost);
    }
    return url;
  }

  static Map<String, String> _withHostIfNeeded(
      Uri url, Map<String, String>? headers) {
    final out = <String, String>{...?headers};
    if (url.host == ipFallbackHost && !out.containsKey('Host')) {
      out['Host'] = domainHost;
    }
    return out;
  }

  static Future<http.StreamedResponse> _openStream(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final client = _clientFor(url);
    final req = http.Request(method, url);
    req.headers.addAll(headers ?? const {});
    if (body != null) {
      if (body is String) {
        req.body = body;
      } else if (body is List<int>) {
        req.bodyBytes = body;
      } else {
        req.body = body.toString();
      }
    }
    return client.send(req).timeout(timeout ?? const Duration(seconds: 30));
  }

  /// Version streamée avec repli IP (pour les gros téléchargements).
  static Future<http.StreamedResponse> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final effective = _effective(url);
    try {
      return await _openStream(
        method,
        effective,
        headers: _withHostIfNeeded(effective, headers),
        body: body,
        timeout: timeout,
      );
    } catch (e) {
      if (effective.host == domainHost && _isTransportError(e)) {
        final retryUri = url.replace(host: ipFallbackHost);
        final response = await _openStream(
          method,
          retryUri,
          headers: _withHostIfNeeded(retryUri, headers),
          body: body,
          timeout: timeout,
        );
        useIpFallback = true;
        return response;
      }
      rethrow;
    }
  }

  static Future<http.Response> _attempt(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final streamed = await _openStream(
      method,
      url,
      headers: headers,
      body: body,
      timeout: timeout,
    );
    return http.Response.fromStream(streamed);
  }

  static Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final effective = _effective(url);
    try {
      return await _attempt(
        method,
        effective,
        headers: _withHostIfNeeded(effective, headers),
        body: body,
        timeout: timeout,
      );
    } catch (e) {
      // Bascule si le domaine est en cause (pas pour des erreurs applicatives)
      if (effective.host == domainHost && _isTransportError(e)) {
        final retryUri = url.replace(host: ipFallbackHost);
        final response = await _attempt(
          method,
          retryUri,
          headers: _withHostIfNeeded(retryUri, headers),
          body: body,
          timeout: timeout,
        );
        // Bascule réussie → définitive pour la session.
        useIpFallback = true;
        return response;
      }
      rethrow;
    }
  }

  // ── API type http.* ─────────────────────────────────────────────────────

  static Future<http.Response> get(Uri url,
          {Map<String, String>? headers, Duration? timeout}) =>
      _send('GET', url, headers: headers, timeout: timeout);

  static Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body, Duration? timeout}) =>
      _send('POST', url, headers: headers, body: body, timeout: timeout);

  static Future<http.Response> put(Uri url,
          {Map<String, String>? headers, Object? body, Duration? timeout}) =>
      _send('PUT', url, headers: headers, body: body, timeout: timeout);

  static Future<http.Response> delete(Uri url,
          {Map<String, String>? headers, Duration? timeout}) =>
      _send('DELETE', url, headers: headers, timeout: timeout);
}
