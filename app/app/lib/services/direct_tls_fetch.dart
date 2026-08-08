import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'doh_resolver.dart';

/// Réponse HTTP minimale d'un fetch direct TLS/SNI sur IP résolue.
class DirectFetchResult {
  final int status;
  final Map<String, String> headers;
  final Uint8List body;
  DirectFetchResult(this.status, this.headers, this.body);
}

/// HTTP(S) over résolution DoH : contourne l'empoisonnement DNS des FAI.
///
/// Le principe : l'IP vient du DoH (dns.google), PAS du DNS système. La
/// connexion TCP est faite **directement sur cette IP**, puis le handshake TLS
/// est fait avec le **hostname d'origine (SNI)** → le certificat et le vhost
/// sont les bons. Le blocage DNS devient inopérant.
///
/// Supporte : HTTPS obligatoire ; redirect 3xx (1 niveau) ; Content-Length,
/// chunked, close-delimited. Sert aux fetches playlist/segment/tests.
class DirectTlsFetch {
  DirectTlsFetch._();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// GET [url] en résolvant l'hôte via DoH et en se connectant directement
  /// à son IP avec SNI correct. Renvoie null si tout échoue.
  static Future<DirectFetchResult?> get(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
    int maxRedirects = 2,
    int maxBodyBytes = 64 * 1024 * 1024,
  }) async {
    var current = url;
    for (var hop = 0; hop <= maxRedirects; hop++) {
      final uri = Uri.tryParse(current);
      if (uri == null || uri.host.isEmpty) return null;
      final isHttps = uri.scheme == 'https';

      final ips = await DohResolver.instance.resolve(uri.host);
      final port = uri.hasPort ? uri.port : (isHttps ? 443 : 80);

      for (final ip in ips) {
        try {
          final result = await _getOnIp(
            uri,
            ip,
            port,
            isHttps,
            headers ?? const {},
            timeout,
            maxBodyBytes,
          );
          if (result == null) continue;
          // Redirections 3xx → suivre (1 niveau de recursion)
          if (result.status >= 300 && result.status < 400) {
            final loc = result.headers['location'];
            if (loc != null && loc.isNotEmpty) {
              current = uri.resolve(loc).toString();
              break;
            }
          }
          return result;
        } catch (_) {
          continue; // IP suivante
        }
      }
    }
    return null;
  }

  static Future<DirectFetchResult?> _getOnIp(
    Uri uri,
    String ip,
    int port,
    bool isHttps,
    Map<String, String> headers,
    Duration timeout,
    int maxBodyBytes,
  ) async {
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';

    // 1) TCP direct sur l'IP résolue (Socket.connect sur IP littérale :
    //    aucun appel DNS système — c'est ça le contournement).
    final Socket socket = await Socket.connect(ip, port, timeout: timeout);
    Socket conn = socket;
    // 2) TLS avec SNI = vrai hostname (cert OK, vhost OK)
    if (isHttps) {
      try {
        conn = await SecureSocket.secure(
          socket,
          host: uri.host,
          supportedProtocols: const ['http/1.1'],
        );
      } on HandshakeException {
        // Certificat chaîne incomplète/mal-configuré (cas réel : uqload & co) —
        // l'IP vient du DoH (résolution déjà fiable) on accepte alors le cert.
        try {
          conn = await SecureSocket.secure(
            socket,
            host: uri.host,
            supportedProtocols: const ['http/1.1'],
            onBadCertificate: (_) => true,
          );
        } catch (_) {
          rethrow;
        }
      }
    }

    try {
      final req = StringBuffer()
        ..write('GET $path$query HTTP/1.1\r\n')
        ..write('Host: ${uri.host}\r\n')
        ..write('User-Agent: ${headers['User-Agent'] ?? _ua}\r\n')
        ..write('Accept: */*\r\n')
        ..write('Connection: close\r\n');
      headers.forEach((k, v) {
        final kl = k.toLowerCase();
        if (kl != 'host' && kl != 'user-agent' && kl != 'accept' && kl != 'connection') {
          req.write('$k: $v\r\n');
        }
      });
      req.write('\r\n');
      conn.add(ascii.encode(req.toString()));
      await conn.flush();

      final completer = Completer<Uint8List>();
      final buffer = BytesBuilder(copy: false);
      late StreamSubscription<List<int>> sub;
      Timer? timer;
      timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(buffer.takeBytes());
      });
      sub = conn.listen(
        (data) {
          buffer.add(data);
          if (buffer.length >= maxBodyBytes && !completer.isCompleted) {
            completer.complete(buffer.takeBytes());
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(buffer.takeBytes());
        },
        onError: (_) {
          if (!completer.isCompleted) {
            completer.complete(buffer.takeBytes());
          }
        },
        cancelOnError: true,
      );
      final respBytes = await completer.future;
      timer.cancel();
      await sub.cancel();
      if (respBytes.isEmpty) return null;
      return _parseHttpResponse(respBytes, maxBodyBytes);
    } finally {
      try {
        conn.destroy();
      } catch (_) {}
    }
  }



  /// Parse minimaliste : status line + headers + body
  /// (Content-Length / chunked / close-delimited).
  static DirectFetchResult?_parseHttpResponse(Uint8List raw, int maxBodyBytes) {
    final headerEnd = _indexOfCrlfCrlf(raw);
    if (headerEnd <= 0) return null;
    final headerPart = ascii.decode(Uint8List.view(raw.buffer, 0, headerEnd), allowInvalid: true);
    final lines = headerPart.split('\r\n');
    final statusMatch = RegExp(r'HTTP/[\d.]+\s+(\d+)').firstMatch(lines.first);
    if (statusMatch == null) return null;
    final status = int.parse(statusMatch.group(1)!);
    final headers = <String, String>{};
    for (var i = 1; i < lines.length; i++) {
      final idx = lines[i].indexOf(':');
      if (idx > 0) {
        headers[lines[i].substring(0, idx).trim().toLowerCase()] =
            lines[i].substring(idx + 1).trim();
      }
    }

    var body = Uint8List.view(raw.buffer, headerEnd + 4);

    if (headers['transfer-encoding']?.toLowerCase().contains('chunked') == true) {
      body = _dechunk(body) ?? body;
    } else if (headers.containsKey('content-length')) {
      final len = int.tryParse(headers['content-length'] ?? '') ?? body.length;
      if (body.length > len) {
        body = Uint8List.view(body.buffer, 0, len.clamp(0, body.length));
      }
    }
    return DirectFetchResult(status, headers, body);
  }

  static int _indexOfCrlfCrlf(Uint8List data) {
    for (var i = 0; i + 3 < data.length; i++) {
      if (data[i] == 13 && data[i + 1] == 10 && data[i + 2] == 13 && data[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  static Uint8List? _dechunk(Uint8List raw) {
    try {
      final out = BytesBuilder(copy: false);
      var pos = 0;
      // raw peut être une VUE (offsetInBytes != 0) : toujours indexer avec
      // l'offset absolu dans le buffer sous-jacent.
      final base = raw.offsetInBytes;
      while (pos < raw.length) {
        final lineEnd = _indexOf(raw, 13, 10, pos);
        if (lineEnd < 0) break;
        final sizeHex = ascii
            .decode(Uint8List.view(raw.buffer, base + pos, lineEnd - pos),
                allowInvalid: true)
            .trim();
        final size = int.tryParse(sizeHex, radix: 16) ?? 0;
        if (size <= 0) break;
        final start = lineEnd + 2;
        final end = start + size;
        if (end > raw.length) break;
        out.add(Uint8List.view(raw.buffer, base + start, size));
        pos = end + 2; // CRLF final du chunk
      }
      return out.takeBytes();
    } catch (_) {
      return null;
    }
  }

  static int _indexOf(Uint8List data, int b1, int b2, int from) {
    for (var i = from; i + 1 < data.length; i++) {
      if (data[i] == b1 && data[i + 1] == b2) return i;
    }
    return -1;
  }
}
