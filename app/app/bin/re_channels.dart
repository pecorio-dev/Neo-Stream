// re_channels.dart — Reverse-engineering des portails FStream derrière
// Cloudflare (« Under Attack Mode »), mesuré le 2026-08-08.
//
// PORTAILS MESURÉS
// ================
// 1. kakaflix.lol  — portail ACTIF. Back-end LiteSpeed derrière CF.
//    - GET /                        → 200 (corps vide) pour TOUT client.
//    - GET /tokyo/newPlayer.php?id= → 200 immédiat avec fingerprint Dart
//      (BoringSSL) *et* curl/openssl : sub-system NON protégé.
//      · id mort  → 200 « Aucune vidéo avec cet ID, veuillez vérifier. » (44 o)
//      · id vivant → **302 Found** vers hoster dood-family (preuve urlquery
//        2026-08-08 : /tokyo/... → doply.net/e/xxx → dsvplay.com/pass_md5/...
//        → master.m3u8 ; /viper/... → bf0skv.org/e/xxx → ico3c.com/bkg/xxx
//        → be2719.rcr22.ams01.i8yz83pn.com/hls2/.../master.m3u8).
//      ⇒ extraction = suivre le 302 puis extracteur dood/voe EXISTANT.
//    - GET /sydney/newPlayer.php    → HOLD (tarpit) : TCP+TLS OK puis 0 octet,
//      timeout infini, pour TOUT id (vivant, mort ou invalide). Résiste à :
//      curl http1.1/http2 + headers Chrome complets, Dart/BoringSSL, ET vrai
//      Chrome (FlareSolverr 3.5, 110 s). Insensible aux headers
//      Referer/X-Requested-With. ⇒ needs_browser (probablement réputation-IP :
//      VPS datacenter = hold ; IP résidentielle/4G plausible — le WebView
//      headless de l'app tourne sur le device mobile, exactement ce cas).
//    - GET /viper/newplayer.php (case : tout minuscule) → hold pour les id au
//      format actif (base62, ex. YsKjAkuQguBwADMub7rnE), MAIS 302 immédiat avec
//      « Location: [] » (vide → id inconnu) pour un id UUID étranger : le
//      backend répond vite seulement aux requêtes manifestement invalides.
//    - 32 autres noms de villes balayés ⇒ 404 LiteSpeed propres et immédiats.
//      Sub-systems vivants trouvés : sydney, tokyo, viper.
//    - AUCUNE API JSON publique trouvée (/api/, /ajax/, /sydney/api,
//      /api/videos ⇒ 404 ou hold).
//
// 2. kokoflix.lol  — MORT : 403 + page parking style Bodis («shrink-to-fit=no»).
//
// 3. sequoia.lol   — MORT : domaine expiré, redirect JS /lander →
//    forsale.godaddy.com (à vendre). Tout 200 = parking, pas du contenu.
//
// 4. bigwarp.art   — 301 → bigwarp.pro (vrai domaine). CF managed-challenge
//    (403 + window._cf_chl_opt + header cf-mitigated: challenge) pour curl ET
//    Dart. FlareSolverr (Chrome, VPS) le résout en ~2 s (cf_clearance).
//    MAIS la page player n'expose QUE le troll :
//      jwplayer("vplayer").setup({ sources: [{file:
//      "https://bigwarp.io/player/321.mp4", label:"HD"}], ... })
//    321.mp4 = 11,8 Mo servi sans referer-lock (HEAD 200) = clip leurre.
//    Vrai infra fichier = fs63.bigwarp.io (thumb /i/02/00000/<hash>.jpg) mais
//    **TCP injoignable** (timeout depuis local + VPS au 2026-08-08).
//    /dl?op=view&file_code=…&hash=<id>-<ip>-<ts>-<md5> = simple compteur.
//    ⇒ needs_browser, et même avec navigateur : TROLL-ONLY sur l'embed public.
//
// 5. fsvid.lol     — 403 nginx SEC (pas de challenge CF : cf-cache-status
//    DYNAMIC, body 403 nginx générique) identique pour curl, Dart et vrai
//    Chrome (FlareSolverr), avec ou sans Referer. ID embed mort ou allowlist
//    origin. Rappel : réseau s1.fsvid.lol = source troll « /troll/ » connue.
//
// RECETTE EXPLOITABLE (prouvée) POUR LE CATALOGUE FRENCHSTREAM
// ============================================================
// frenchstream.lol :
//   - GET /                        → 200 (cache CF) en curl/Dart.
//   - GET fiche/saison/épisode     → 403 managed-challenge (curl+Dart) ;
//     FlareSolverr (Chrome) OK (challenge solved, ~2-12 s).
//   - GET /engine/ajax/getxfield.php?id=<news>&xfield=<srv>&token=
//     POST /engine/ajax/Season.php (id=<episode>, xfield=<srv>,
//     action=playEpisode)
//       → **200 SANS COOKIE** même depuis IP locale, dès lors que headers :
//         User-Agent: Chrome 126, Referer: <url_fiche>, X-Requested-With:
//         XMLHttpRequest  (curl ET Dart validés)
//       → corps = `<iframe src='…'>` hoster réel (d000d.xyz/e/…, playmogo.com,
//         uqload.io, vidoza.net, younetu.org/embed_player.php?vid=…).
//   ⇒ Catalogage (liste des xfields) : needs_browser ; résolution hoster :
//     OK direct (recette) ensuite extracteurs existants (dood, uqload, voe…).
//
// Usage : dart bin/re_channels.dart            # probe live des 5 portails
//         dart bin/re_channels.dart --json     # sortie machine

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const _deadId = 'ededa494-4a6b-445a-b7b4-d6362851f75b'; // Veille sur moi (mort)

// Statuts par portail (constantes exactes à réutiliser dans l'app) :

// kakaflix.lol
const kKakaflixHost = 'kakaflix.lol';
const kKakaflixOpenSubsystem = 'tokyo'; // OK via Dart TLS fingerprint
const kKakaflixHoldSubsystems = ['sydney', 'viper']; // needs_browser
const kKakaflixPlayerPath = '/newPlayer.php'; // GET ?id=<uuid> → 302 hoster

// bigwarp
const kBigwarpHost = 'bigwarp.pro'; // .art redirige ici
const kBigwarpTrollUrl = 'https://bigwarp.io/player/321.mp4'; // LEURRE
const kBigwarpStatus = 'needs_browser'; // managed-challenge + troll-only

// fsvid
const kFsvidStatus = 'refused_403'; // nginx 403 sec, tout client

// kokoflix / sequoia
const kKokoflixStatus = 'dead_parked';
const kSequoiaStatus = 'dead_parked';

// frenchstream (source catalogue)
const kFrenchstreamHost = 'frenchstream.lol';
const kFrenchstreamAjaxGetxfield = '/engine/ajax/getxfield.php';
const kFrenchstreamAjaxSeason = '/engine/ajax/Season.php';
const kFrenchstreamAjaxHeaders = {
  'User-Agent': _ua,
  'X-Requested-With': 'XMLHttpRequest',
  // + 'Referer': <url fiche/épisode exacte>
};

// ─── Probe minimaliste (HttpClient Dart = fingerprint BoringSSL) ───────────

class _Probe {
  final int? status;
  final int bytes;
  final String snippet;
  final bool hold;
  final bool cfChallenge;
  final String? location;
  final Duration elapsed;
  _Probe(this.status, this.bytes, this.snippet, this.hold, this.cfChallenge,
      this.location, this.elapsed);
}

Future<_Probe> _get(String url, {String? referer, int timeoutSec = 14}) async {
  final sw = Stopwatch()..start();
  final client = HttpClient()
    ..connectionTimeout = Duration(seconds: timeoutSec)
    ..idleTimeout = Duration(seconds: timeoutSec)
    ..autoUncompress = true;
  try {
    final req = await client
        .getUrl(Uri.parse(url))
        .timeout(Duration(seconds: timeoutSec));
    req.headers.set(HttpHeaders.userAgentHeader, _ua);
    req.headers.set(HttpHeaders.acceptHeader, 'text/html,*/*;q=0.8');
    if (referer != null) {
      req.headers.set(HttpHeaders.refererHeader, referer);
      req.headers.set('X-Requested-With', 'XMLHttpRequest');
    }
    req.followRedirects = false;
    final resp = await req.close().timeout(Duration(seconds: timeoutSec));
    final body = await resp
        .transform(utf8.decoder)
        .join()
        .timeout(Duration(seconds: timeoutSec));
    final cf = body.contains('_cf_chl_opt') ||
        (resp.headers.value('cf-mitigated') ?? '') == 'challenge';
    final loc = resp.headers.value(HttpHeaders.locationHeader);
    final snip = body.replaceAll(RegExp(r'\s+'), ' ');
    return _Probe(resp.statusCode, body.length,
        snip.substring(0, snip.length < 90 ? snip.length : 90), false, cf, loc,
        sw.elapsed);
  } catch (e) {
    return _Probe(null, 0, e.toString(), e is TimeoutException, false, null,
        sw.elapsed);
  } finally {
    client.close(force: true);
  }
}

String _statusOf(_Probe p) {
  if (p.hold) return 'needs_browser (TARPIT hold)';
  if (p.cfChallenge) return 'needs_browser (CF challenge)';
  if (p.status == 200) return 'OK via Dart TLS fingerprint';
  if (p.status == 302 || (p.status != null && p.status! >= 300 && p.status! < 400)) {
    final loc = (p.location == null || p.location!.isEmpty)
        ? 'vide (id inconnu)'
        : p.location;
    return 'OK redirect→ $loc';
  }
  if (p.status == 403) return 'refused_403';
  return 'HTTP ${p.status}';
}

Future<void> main(List<String> args) async {
  final asJson = args.contains('--json');
  final report = <String, Map<String, String>>{};

  final targets = <String, List<List<String?>>>{
    'kakaflix.lol': [
      ['root 200-vide', '/', null],
      ['tokyo newPlayer (id mort)', '/tokyo/newPlayer.php?id=$_deadId', null],
      ['sydney newPlayer', '/sydney/newPlayer.php?id=$_deadId', null],
      ['viper newplayer', '/viper/newplayer.php?id=$_deadId', null],
    ],
    'kokoflix.lol': [
      ['home', '/', null],
    ],
    'sequoia.lol': [
      ['home', '/', null],
    ],
    'bigwarp.art': [
      ['embed (redir .pro)', '/embed-7bz7cc41bnux.html', null],
    ],
    'fsvid.lol': [
      ['embed', '/embed-soon09l6c0wv.html', null],
    ],
    'frenchstream.lol': [
      ['home', '/', null],
      ['ajax getxfield dood', '/engine/ajax/getxfield.php?id=45279&xfield=dood&token=', 'https://frenchstream.lol/45279-tables-turned.html'],
    ],
  };

  final out = StringBuffer();
  for (final e in targets.entries) {
    out.writeln('══ ${e.key}');
    report[e.key] = {};
    for (final t in e.value) {
      final label = t[0]!;
      final url = 'https://${e.key}${t[1]}';
      final p = await _get(url, referer: t[2]);
      final st = _statusOf(p);
      report[e.key]![label] =
          '$st | ${p.status ?? "-"} | ${p.bytes}o | ${p.elapsed.inMilliseconds}ms | ${p.snippet}';
      out.writeln('  [$label] $st  (HTTP ${p.status ?? "-"} '
          '${p.bytes}o ${p.elapsed.inMilliseconds}ms)');
      if (p.snippet.isNotEmpty) out.writeln('      «${p.snippet}»');
    }
  }

  out.writeln('\n══ STATUTS FIXÉS (mesure 2026-08-08)');
  out.writeln('kakaflix.lol/tokyo   : OK via Dart TLS fingerprint — 302 → '
      'dood-family → master.m3u8 (id vivant requis)');
  out.writeln('kakaflix.lol/sydney  : $kKakaflixHoldSubsystems → needs_browser '
      '(tarpit ; viper répond 302 vide seulement si id étranger à la base)');
  out.writeln('kokoflix.lol         : $kKokoflixStatus (Bodis-like 403)');
  out.writeln('sequoia.lol          : $kSequoiaStatus (GoDaddy for-sale)');
  out.writeln('bigwarp.art/.pro     : $kBigwarpStatus — embed ne sert que le '
      'troll $kBigwarpTrollUrl');
  out.writeln('fsvid.lol            : $kFsvidStatus (nginx sec, tous clients)');
  out.writeln('frenchstream.lol ajax: OK direct (recette) — headers UA Chrome '
      '+ Referer fiche + X-Requested-With, sans cookie');

  stdout.write(out);

  if (asJson) {
    stderr.writeln(jsonEncode(report));
  }
  exit(0);
}
