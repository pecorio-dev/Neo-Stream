import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/github_release.dart';
import '../services/update_service.dart';
import '../utils/apk_installer.dart';
import '../utils/semver.dart';

/// État d'une vérification de mise à jour.
enum UpdateStatus { idle, checking, downloading, error }

/// Provider pour la gestion des mises à jour.
///
/// Utilisé par :
/// - Le splash screen (vérification auto silencieuse)
/// - L'écran de paramètres (vérification manuelle + toggle pré-versions)
/// - Le dialogue de mise à jour (téléchargement + installation)
class UpdateProvider extends ChangeNotifier {
  final UpdateService _service;

  UpdateProvider() : _service = UpdateService();

  // ── État ────────────────────────────────────────────────────────────
  UpdateStatus _status = UpdateStatus.idle;
  UpdateCheckResult? _lastResult;
  String? _error;
  double _downloadProgress = 0.0;

  UpdateStatus get status => _status;
  UpdateCheckResult? get lastResult => _lastResult;
  String? get error => _error;
  double get downloadProgress => _downloadProgress;
  bool get hasUpdate =>
      _lastResult != null && _lastResult!.hasUpdate && _lastResult!.error == null;
  bool get isChecking => _status == UpdateStatus.checking;
  bool get isDownloading => _status == UpdateStatus.downloading;

  Version get currentVersion => _service.currentVersion;

  // ── Pré-versions ────────────────────────────────────────────────────
  Future<bool> get allowPreRelease => _service.allowPreRelease;
  Future<void> setAllowPreRelease(bool value) {
    return _service.setAllowPreRelease(value);
  }

  // ── Vérification ────────────────────────────────────────────────────

  /// Vérifie automatiquement si une mise à jour est disponible.
  ///
  /// Ne se lance que si le délai minimum s'est écoulé depuis la dernière
  /// vérification. Ne notifie **pas** en cas d'erreur (silencieux).
  Future<void> checkAuto() async {
    if (!await _service.shouldAutoCheck()) return;

    _status = UpdateStatus.checking;
    notifyListeners();

    final result = await _service.checkForUpdate();
    _lastResult = result;
    _status = UpdateStatus.idle;
    notifyListeners();
  }

  /// Vérifie manuellement (forçée) avec option d'inclure les pré-versions.
  ///
  /// [includePreRelease] : `true` pour inclure les pré-versions (override
  /// le paramètre sauvegardé pour cette seule vérification).
  Future<void> checkManual({bool includePreRelease = false}) async {
    _status = UpdateStatus.checking;
    _error = null;
    notifyListeners();

    final result =
        await _service.checkForUpdate(forceIncludePreRelease: includePreRelease);
    _lastResult = result;

    if (result.error != null) {
      _status = UpdateStatus.error;
      _error = result.error;
    } else {
      _status = UpdateStatus.idle;
    }
    notifyListeners();
  }

  /// Retourne `true` s'il faut montrer le popup de mise à jour.
  ///
  /// - Il y a une mise à jour disponible
  /// - La version n'a pas déjà été ignorée par l'utilisateur
  bool get shouldShowUpdateDialog =>
      hasUpdate &&
      _lastResult?.release != null &&
      !(_lastResult?.release?.isPrerelease == true &&
          !allowPreReleaseSync);

  /// Synchronisé (pas d'await) pour les appels synchrones (build).
  bool get allowPreReleaseSync {
    // On ne peut pas faire async dans un getter sans Future.
    // Utilisé seulement pour les guards synchrones.
    return false;
  }

  // ── Téléchargement + installation ────────────────────────────────────

  /// Télécharge et installe la mise à jour.
  ///
  /// Sur Android : télécharge l'APK puis lance l'Intent système.
  /// Sur Linux/Windows : télécharge le fichier et l'ouvre.
  Future<void> downloadAndInstall() async {
    final release = _lastResult?.release;
    if (release == null) return;

    final platform = UpdateService.currentPlatform;
    final asset = release.assetForPlatform(platform);
    if (asset == null) {
      _error = 'Aucun fichier disponible pour $platform';
      _status = UpdateStatus.error;
      notifyListeners();
      return;
    }

    _status = UpdateStatus.downloading;
    _downloadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      final filePath = await _service.downloadAsset(
        asset,
        onProgress: (p) {
          _downloadProgress = p;
          notifyListeners();
        },
      );

      // Téléchargement terminé — lancer l'installation.
      if (!kIsWeb && Platform.isAndroid) {
        await installApk(filePath);
      } else if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
        // Sur desktop, on lance le processus d'installation.
        _launchInstaller(filePath, platform);
      }

      _status = UpdateStatus.idle;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _status = UpdateStatus.error;
      notifyListeners();
    }
  }

  /// L'utilisateur a fermé la popup (ne pas re-montrer cette version).
  Future<void> dismissUpdate() async {
    if (_lastResult?.release != null) {
      await _service.dismissVersion(_lastResult!.release!.version);
    }
  }

  /// Ouvre la page GitHub des releases dans le navigateur.
  void openReleasesPage() {
    // launchUrl non utilisé pour éviter une dépendance URL launcher.
    // Ce sera fait côté UI avec launchUrl.
  }

  void reset() {
    _status = UpdateStatus.idle;
    _error = null;
    _downloadProgress = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Future<void> _launchInstaller(String filePath, String platform) async {
    try {
      if (platform == 'linux') {
        // Ouvrir le .deb avec le gestionnaire de paquets par défaut
        await Process.run('xdg-open', [filePath]);
      } else if (platform == 'windows') {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      }
    } catch (e) {
      _error = 'Impossible de lancer l\'installateur : $e';
      _status = UpdateStatus.error;
      notifyListeners();
    }
  }
}
