// re_goudcloud.dart — Reverse-engineering gcloud / goudcloud / k-drive
// ═══════════════════════════════════════════════════════════════════
// MISSION (2026-08-08) : trouver des liens gcloud/goudcloud (k-drive)
// vivants dans les catalogues anime.
//
// STATUT FINAL : ☠️  SERVICE MORT — aucun lien vivant trouvé.
//
// PREUVES COLLECTÉES (2026-08-08) :
//   1. Catalogue :
//        - base anime complète (2317 animes, ~192 000 sources) :
//          0 occurrence de « gcloud », « goudcloud », « k-drive » ;
//        - catalogue anime-sama.to actuel : absent des players listés
//          (ansembed/sibnet/lpayer/minochinos/uqload/sendvid…) ;
//        - MySQL prod (anime/movies/series) : 0 ligne.
//   2. Domaines :
//        - gcloud.live : HTTP 200 MAIS backend « Joken » (même stack
//          Phoenix/Elixir que vidmoly.to — challenge JS signé JWT HS256,
//          rate-limit 429 mutualisé vidmoly/gcloud).
//          Après résolution du challenge (sid cookie + JWT) :
//          302 → http://www.torroclk.com/feed/click/?t1=...&subid=
//          gcloud.live …  = réseau d'arbitrage publicitaire PPC
//          (observé aussi 302 → http://ww547.gcloud.live : landing
//          « Gcloud Live » type coquille parking, ni player ni upload).
//          → le domaine ne sert PLUS de vidéos, il monétise le
//            trafic résiduel. Service vidéo mort.
//        - goudcloud.com   → connexion impossible ;
//        - k-drive.com     → HTTP 200 parking
//          (<script>window.location.href="/lander"</script>) ;
//        - kdrive.video, gcloudfile.com → injoignables.
//
// CONNAISSANCE CONSERVÉE (format historique, au cas où) :
//   Les pages gcloud étaient des players packés Dean Edwards avec
//   config JSON {"file": "...m3u8|.mp4"} — l'unpacker générique de
//   AnimeExtractor._extractGoudcloud + patterns m3u8 couvre ce format.
//
// Ce fichier démontre la preuve « gcloud.live → challenge → ads »
// sur requête réelle.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  stdout.writeln('=== re_goudcloud — diagnostic 2026-08-08 ===');
  final c = HttpClient();
  c.badCertificateCallback = (_, __, ___) => true;
  c.connectionTimeout = const Duration(seconds: 15);
  c.userAgent = _ua;

  // 1. sondage domaines
  for (final d in ['https://gcloud.live/', 'https://goudcloud.com/', 'https://k-drive.com/']) {
    try {
      final req = await c.getUrl(Uri.parse(d)).timeout(const Duration(seconds: 18));
      req.followRedirects = false;
      final resp = await req.close().timeout(const Duration(seconds: 18));
      final body = await resp.transform(latin1.decoder).join();
      var note = 'HTTP ${resp.statusCode}';
      final loc = resp.headers.value('location');
      if (loc != null) note += ' → $loc';
      if (body.contains('/lander')) note += ' (PARKING lander)';
      final ch = RegExp(r"window\.location\.replace\('([^']+)'").firstMatch(body);
      stdout.writeln('  $d → $note');
      // 2. si challenge Joken, le résoudre et montrer la destination ads
      if (ch != null) {
        for (final ck in resp.cookies) {
          stdout.writeln('     set-cookie: ${ck.name}=${ck.value.substring(0, ck.value.length < 18 ? ck.value.length : 18)}…');
        }
        final req2 = await c.getUrl(Uri.parse(ch.group(1)!)).timeout(const Duration(seconds: 18));
        req2.followRedirects = false;
        final resp2 = await req2.close().timeout(const Duration(seconds: 18));
        final loc2 = resp2.headers.value('location') ?? '';
        await resp2.drain<void>();
        stdout.writeln('     challenge → HTTP ${resp2.statusCode} → $loc2');
        if (loc2.contains('torroclk') || loc2.contains('ads') || loc2.contains('click')) {
          stdout.writeln('     ⇒ 302 vers réseau ADS : service vidéo MORT');
        }
      }
    } catch (e) {
      stdout.writeln('  $d → INJOIGNABLE (${e.runtimeType})');
    }
  }
  c.close(force: true);

  stdout.writeln('');
  stdout.writeln('★ STATUT : MORT — 0 URL « gcloud/goudcloud/k-drive » dans');
  stdout.writeln('  192 000 sources anime ; domaines restants = parking/ads.');
  exitCode = 1;
}
