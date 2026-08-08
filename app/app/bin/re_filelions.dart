// re_filelions.dart — Reverse-engineering filelions.com / vidhide.com
// ═══════════════════════════════════════════════════════════════════
// MISSION (2026-08-08) : trouver des liens filelions/vidhide vivants.
//
// STATUT FINAL : ☠️  SERVICE MORT — aucun lien vivant trouvé.
//
// PREUVES COLLECTÉES :
//   1. DNS/HTTP des domaines historiques (sondés le 2026-08-08) :
//        filelions.com        → connexion impossible (NX/timeout)
//        filelions.to         → 301 → https://vidhidepro.com/ (→ HTTP 522)
//        filelions.online     → 301 → https://vidhidepro.com/ (→ HTTP 522)
//        vidhidepro.com       → HTTP 522 (origine HS)
//        vidhide.pro / .plus / vidhidehub.com / fviplions.com → injoignables
//        vidhide.com          → HTTP 200, <title>EarnVids</title>
//                               ⇒ le réseau vidhide a rebrandé en EarnVids ;
//                               mais 0 embed earnvids (/e/, /embed-) n'existe
//                               dans aucun de nos catalogues (seule trace :
//                               une URL « earnvids.com/?op=upload_file »
//                               résiduelle sur un épisode = endpoint d'upload,
//                               pas un embed vidéo).
//        dlions.com           → HTTP 200 MAIS page parking
//                               (<script>window.location.href="/lander")
//   2. Aucune URL filelions/vidhide dans :
//        - la base anime complète (2317 animes, ~192 000 sources) ;
//        - les 33 151 pages statiques du site (movies/series/anime) ;
//        - le MySQL de prod (tables anime/movies/series, regexp dédiée) ;
//        - le catalogue anime-sama.to actuel (players : ansembed,
//          sibnet, lpayer, minochinos, uqload — plus de wish-family
//          historique).
//   3. FILIATION PROUVÉE avec le réseau StreamWish/VidHide :
//        - l'extracteur serveur historique (api/extractor.py) groupe
//          « streamwish|embedwish|...|filelions|dlions|vidhide|fastwish »
//          dans la même regex STREAMWISH_DOMAINS ;
//        - le player JWPlayer du domaine actuel callistanise.com
//          (famille movearnpre/smoothpre) affiche abouttext:"VidHide"
//          → filelions/vidhide étaient des rebadges du même réseau.
//        - L'algorithme complet (DE-packer → links.hls4/hls3/hls2)
//          est démontré fonctionnel dans bin/re_streamwish.dart
//          (master HTTP 200, segment Range 206 sur 2 domaines vivants).
//
// Si un nouveau domaine filelions/vidhide réapparaît, appliquer
// extractStreamwishFamily() de re_streamwish.dart : la famille partage
// le backend (mêmes clés hls2/hls3/hls4, même CDN acek-cdn).
//
// Ce fichier teste les quelques URLs "filelions" reconnues publiquement
// et affiche le diagnostic (toutes mortes au 2026-08-08).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<(String, String)> _diag(String url) async {
  final c = HttpClient();
  c.badCertificateCallback = (_, __, ___) => true;
  c.connectionTimeout = const Duration(seconds: 15);
  c.userAgent = _ua;
  try {
    final req = await c.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 18));
    req.followRedirects = false;
    final resp = await req.close().timeout(const Duration(seconds: 18));
    final loc = resp.headers.value('location') ?? '';
    final body = await resp.transform(latin1.decoder).join();
    final parked = body.contains('/lander') || body.contains('parking');
    var note = 'HTTP ${resp.statusCode}';
    if (loc.isNotEmpty) note += ' → $loc';
    if (parked) note += ' (PARKING)';
    return (url, note);
  } catch (e) {
    return (url, 'INJOIGNABLE (${e.runtimeType})');
  } finally {
    c.close(force: true);
  }
}

Future<void> main() async {
  stdout.writeln('=== re_filelions — diagnostic 2026-08-08 ===');
  stdout.writeln('Domaines historiques FileLions/VidHide :');
  for (final d in [
    'https://filelions.com/',
    'https://filelions.to/',
    'https://filelions.online/',
    'https://vidhide.com/',
    'https://vidhide.pro/',
    'https://vidhidepro.com/',
    'https://dlions.com/',
  ]) {
    final (u, note) = await _diag(d);
    stdout.writeln('  $u → $note');
  }
  stdout.writeln('');
  stdout.writeln('★ STATUT : MORT — 0 URL vivante dans 192 000 sources anime');
  stdout.writeln('  ni dans les 33 151 pages du site, ni dans le MySQL prod.');
  stdout.writeln('★ Extraction : même algorithme que StreamWish/VidHide —');
  stdout.writeln('  voir bin/re_streamwish.dart (PROUVÉ : master 200, segment 206).');
  exitCode = 1; // aucun stream prouvable : service mort
}
