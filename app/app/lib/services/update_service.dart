import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/github_release.dart';
import '../utils/semver.dart';

/// Réultat de la vérification de mise à jour.
class UpdateCheckResult {
  final bool hasUpdate;
  final Version? latestVersion;
  final Version currentVersion;
  final GithubRelease? release;
  final String? error;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    required this.currentVersion,
    this.release,
    this.error,
  });

  factory UpdateCheckResult.noUpdate(Version current) =>
      UpdateCheckResult(hasUpdate: false, currentVersion: current);

  factory UpdateCheckResult.withUpdate(Version current, GithubRelease r) =>
      UpdateCheckResult(
        hasUpdate: true,
        currentVersion: current,
        latestVersion: Version.parse(r.version),
        release: r,
      );

  factory UpdateCheckResult.error(Version current, String e) =>
      UpdateCheckResult(hasUpdate: false, currentVersion: current, error: e);
}

/// Service de vérification de mise à jour via GitHub Releases.
///
/// Fonctionnalités :
/// - Vérifie si une nouvelle version existe sur GitHub
/// - Détecte les pré-versions (configurable)
/// - Télécharge l'asset adapté à la plateforme
/// - Retourne le chemin du fichier téléchargé
class UpdateService {
  static const _prefAllowPreRelease = 'update_allow_prerelease';
  static const _prefLastCheck = 'update_last_check_timestamp';
  static const _prefDismissedVersion = 'update_dismissed_version';

  final http.Client _client;

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// Plateforme courante (android / linux / windows / web / ios).
  static String get currentPlatform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  Version get currentVersion => Version.parse(AppConstants.appVersion);

  // ── Préférences ──────────────────────────────────────────────────────

  Future<bool> get allowPreRelease async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAllowPreRelease) ?? false;
  }

  Future<void> setAllowPreRelease(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAllowPreRelease, value);
  }

  Future<DateTime?> get _lastCheck async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_prefLastCheck);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> _setLastCheck(DateTime t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLastCheck, t.millisecondsSinceEpoch);
  }

  /// Retourne `true` si la vérification auto est nécessaire (pas de check récent).
  Future<bool> shouldAutoCheck() async {
    final last = await _lastCheck;
    if (last == null) return true;
    return DateTime.now().difference(last) > AppConstants.autoCheckMinInterval;
  }

  /// Mémorise la version dont l'utilisateur a fermé la popup (ne pas re-montrer).
  Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDismissedVersion, version);
  }

  /// Vérifie si une version donnée a déjà été ignorée.
  Future<bool> isVersionDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefDismissedVersion) == version;
  }

  /// Réinitialise le flag de "version ignorée" (utile après install).
  Future<void> clearDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefDismissedVersion);
  }

  // ── API GitHub ─────────────────────────────────────────────────────

  /// Vérifie les releases GitHub et retourne le résultat.
  ///
  /// [forceIncludePreRelease] : forcer l'inclusion des pré-releases
  /// pour cette seule vérification.
  Future<UpdateCheckResult> checkForUpdate({
    bool? forceIncludePreRelease,
  }) async {
    try {
      final includePre = forceIncludePreRelease ?? await allowPreRelease;
      final uri = AppConstants.githubReleasesUri;
      final response = await _client
          .get(uri, headers: {'Accept': 'application/vnd.github+json'}).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        return UpdateCheckResult.error(
          currentVersion,
          'GitHub erreur ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return UpdateCheckResult.error(
          currentVersion,
          'Réponse GitHub invalide',
        );
      }

      final List<dynamic> releasesJson = decoded;

      // Trouver la dernière release applicable (non-draft, version > actuelle).
      for (final raw in releasesJson) {
        if (raw is! Map<String, dynamic>) continue;
        final release = GithubRelease.fromJson(raw);

        // Ignorer les drafts (jamais visibles publiquement).
        if (release.isDraft) continue;

        // Ignorer les pré-versions si l'utilisateur ne les veut pas.
        if (release.isPrerelease && !includePre) continue;

        final latest = Version.parse(release.version);

        // On veut une version strictement supérieure.
        if (latest > currentVersion) {
          return UpdateCheckResult.withUpdate(currentVersion, release);
        }

        // Dès qu'on tombe sur une release <= à la version actuelle,
        // on arrête : les releases sont ordonnées du plus récent au plus ancien.
        if (latest <= currentVersion) break;
      }

      await _setLastCheck(DateTime.now());
      return UpdateCheckResult.noUpdate(currentVersion);
    } catch (e) {
      return UpdateCheckResult.error(currentVersion, e.toString());
    }
  }

  /// Télécharge un asset et retourne le chemin du fichier local.
  ///
  /// [onProgress] est appelé avec la progression (0.0 → 1.0).
  Future<String> downloadAsset(
    GithubAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${asset.name}');

    final request = http.Request('GET', Uri.parse(asset.downloadUrl));
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Téléchargement échoué (${response.statusCode})');
    }

    final totalBytes = asset.sizeBytes > 0 ? asset.sizeBytes : -1;
    int downloaded = 0;
    final sink = file.openWrite();

    await response.stream.listen(
      (chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(downloaded / totalBytes);
        }
      },
      onDone: sink.close,
      onError: (e) {
        sink.close();
        file.deleteSync();
        throw e;
      },
    ).asFuture();

    return file.path;
  }

  void dispose() {
    _client.close();
  }
}
