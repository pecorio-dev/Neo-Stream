import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content.dart';
import 'anime_extractor.dart';
import 'video_extractor.dart';

/// Statuts possibles d'une tâche de téléchargement.
enum DownloadStatus { queued, extracting, downloading, completed, failed, cancelled }

extension DownloadStatusX on DownloadStatus {
  bool get isActive =>
      this == DownloadStatus.queued ||
      this == DownloadStatus.extracting ||
      this == DownloadStatus.downloading;
}

/// Une tâche de téléchargement persistée.
class DownloadTask {
  final String id;
  final String title;
  final String subtitle; // ex: "S01E02 · VF" ou "Film"
  final String? posterUrl;
  final String sourceUrl; // lien embed/page hébergeur (avant extraction)
  String qualityLabel;
  DownloadStatus status;
  double progress; // 0..1
  int receivedBytes;
  int totalBytes;
  String? filePath;
  String? error;

  DownloadTask({
    required this.id,
    required this.title,
    required this.subtitle,
    this.posterUrl,
    required this.sourceUrl,
    this.qualityLabel = 'Auto',
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.filePath,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'posterUrl': posterUrl,
        'sourceUrl': sourceUrl,
        'qualityLabel': qualityLabel,
        'status': status.name,
        'progress': progress,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'filePath': filePath,
        'error': error,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        subtitle: j['subtitle'] ?? '',
        posterUrl: j['posterUrl'],
        sourceUrl: j['sourceUrl'] ?? '',
        qualityLabel: j['qualityLabel'] ?? 'Auto',
        status: DownloadStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => DownloadStatus.failed,
        ),
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        receivedBytes: (j['receivedBytes'] as num?)?.toInt() ?? 0,
        totalBytes: (j['totalBytes'] as num?)?.toInt() ?? 0,
        filePath: j['filePath'],
        error: j['error'],
      );
}

/// Gestionnaire de téléchargements (films, épisodes de séries, anime).
///
/// — 1 téléchargement à la fois (file FIFO), extraction via les extracteurs
///   existants ([VideoExtractor] / [AnimeExtractor]).
/// — MP4 : téléchargement streamé direct.
/// — HLS (.m3u8) : la playlist est résolue puis les segments .ts sont
///   téléchargés et concaténés en un seul fichier .ts lisible partout.
/// — Persistance sur disque : les tâches survivent aux redémarrages.
/// — Stockage : répertoire applicatif externe (aucune permission requise),
///   visible depuis un gestionnaire de fichiers :
///   Android/data/eu.neostream.neo_stream/files/Downloads/
class DownloadService extends ChangeNotifier {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  static const _prefsKey = 'neo_downloads_v1';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  final List<DownloadTask> tasks = [];
  bool _running = false;
  bool _initialized = false;
  final Set<String> _cancelled = {};
  http.Client? _activeClient;

  // ── Init / persistance ────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _restore();
    // Les tâches interrompues par un kill de l'app repartent en file.
    for (final t in tasks) {
      if (t.status.isActive) {
        t.status = DownloadStatus.queued;
        t.progress = 0;
        t.error = null;
      }
    }
    _persist();
    _pump();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is List) {
        tasks
          ..clear()
          ..addAll(list
              .whereType<Map<String, dynamic>>()
              .map(DownloadTask.fromJson));
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(tasks.map((t) => t.toJson()).toList()));
    } catch (_) {}
  }

  // ── API publique ──────────────────────────────────────────────────────

  bool isDownloading(String sourceUrl) =>
      tasks.any((t) => t.sourceUrl == sourceUrl && t.status.isActive);

  String? completedFileFor(String sourceUrl) {
    for (final t in tasks) {
      if (t.sourceUrl == sourceUrl &&
          t.status == DownloadStatus.completed &&
          t.filePath != null &&
          File(t.filePath!).existsSync()) {
        return t.filePath;
      }
    }
    return null;
  }

  /// Ajoute un film à la file. Retourne la tâche créée.
  Future<DownloadTask?> addFilm({
    required String title,
    String? posterUrl,
    required WatchLink link,
  }) =>
      _enqueue(
        id: 'film_${_slug(title)}_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        subtitle: 'Film · ${link.serverName}',
        posterUrl: posterUrl,
        sourceUrl: link.url,
      );

  /// Ajoute un épisode de série.
  Future<DownloadTask?> addEpisode({
    required String seriesTitle,
    String? posterUrl,
    required Episode episode,
    required WatchLink link,
  }) =>
      _enqueue(
        id: 'ep_${_slug(seriesTitle)}_S${episode.season}E${episode.episode}_${DateTime.now().millisecondsSinceEpoch}',
        title: seriesTitle,
        subtitle: '${episode.label} · ${link.serverName}',
        posterUrl: posterUrl,
        sourceUrl: link.url,
      );

  /// Ajoute un épisode d'anime (source brute, extraction via AnimeExtractor).
  Future<DownloadTask?> addAnimeEpisode({
    required String animeTitle,
    String? posterUrl,
    required String episodeLabel,
    required String sourceUrl,
  }) =>
      _enqueue(
        id: 'an_${_slug(animeTitle)}_${_slug(episodeLabel)}_${DateTime.now().millisecondsSinceEpoch}',
        title: animeTitle,
        subtitle: episodeLabel,
        posterUrl: posterUrl,
        sourceUrl: sourceUrl,
      );

  Future<DownloadTask?> _enqueue({
    required String id,
    required String title,
    required String subtitle,
    String? posterUrl,
    required String sourceUrl,
  }) async {
    if (sourceUrl.trim().isEmpty) return null;
    if (isDownloading(sourceUrl) || completedFileFor(sourceUrl) != null) {
      return null; // déjà en file ou déjà téléchargé
    }
    final task = DownloadTask(
      id: id,
      title: title,
      subtitle: subtitle,
      posterUrl: posterUrl,
      sourceUrl: sourceUrl,
    );
    tasks.insert(0, task);
    await _persist();
    notifyListeners();
    _pump();
    return task;
  }

  void cancel(String taskId) {
    final task = tasks.firstWhere((t) => t.id == taskId,
        orElse: () => tasks.first);
    if (!task.status.isActive) return;
    _cancelled.add(taskId);
    _activeClient?.close();
    _activeClient = null;
    if (task.status == DownloadStatus.queued ||
        task.status == DownloadStatus.extracting) {
      task.status = DownloadStatus.cancelled;
      _persist();
      notifyListeners();
    }
    // si downloading : le flag sera vu par la boucle de téléchargement
  }

  Future<void> remove(String taskId) async {
    cancel(taskId);
    final idx = tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;
    final t = tasks[idx];
    if (t.filePath != null) {
      try {
        final f = File(t.filePath!);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    tasks.removeAt(idx);
    _cancelled.remove(taskId);
    await _persist();
    notifyListeners();
  }

  Future<void> retry(String taskId) async {
    final idx = tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;
    final t = tasks[idx];
    if (t.status.isActive) return;
    _cancelled.remove(t.id);
    t.status = DownloadStatus.queued;
    t.progress = 0;
    t.receivedBytes = 0;
    t.totalBytes = 0;
    t.error = null;
    _persist();
    notifyListeners();
    _pump();
  }

  Future<void> clearFinished() async {
    tasks.removeWhere((t) =>
        t.status == DownloadStatus.cancelled ||
        t.status == DownloadStatus.failed);
    await _persist();
    notifyListeners();
  }

  int get activeCount => tasks.where((t) => t.status.isActive).length;
  int get completedCount =>
      tasks.where((t) => t.status == DownloadStatus.completed).length;

  // ── Moteur ────────────────────────────────────────────────────────────

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = tasks.firstWhere(
            (t) => t.status == DownloadStatus.queued,
            orElse: () => tasks.first);
        if (next.status != DownloadStatus.queued) break;
        await _runTask(next);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _runTask(DownloadTask task) async {
    task.status = DownloadStatus.extracting;
    notifyListeners();

    try {
      // 1) Extraction → URL directe (extracteur anime vs films/séries)
      final isAnime = task.id.startsWith('an_');
      final extraction = isAnime
          ? await AnimeExtractor.extract(task.sourceUrl)
          : await VideoExtractor.extract(task.sourceUrl);
      if (_isCancelled(task)) return;

      if (extraction['success'] != true) {
        throw Exception(
            extraction['error']?.toString() ?? 'Extraction impossible');
      }

      final videoUrl = (extraction['video_url'] ?? '').toString();
      if (videoUrl.isEmpty) throw Exception('URL vidéo introuvable');
      final headers = <String, String>{
        'User-Agent': _userAgent,
        ...?(extraction['headers'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString())),
      };
      final bool isHls = extraction['is_hls'] == true ||
          videoUrl.contains('.m3u8');

      // Qualité : la meilleure variante si fournie par l'extracteur
      String playUrl = videoUrl;
      final qualities = extraction['qualities'];
      if (isHls && qualities is List && qualities.isNotEmpty) {
        task.qualityLabel = qualities.first['label']?.toString() ?? 'Auto';
        final qUrl = qualities.first['url']?.toString();
        if (qUrl != null && qUrl.isNotEmpty) playUrl = qUrl;
      }

      task.status = DownloadStatus.downloading;
      notifyListeners();

      final file = await _targetFile(task, isHls ? '.ts' : '.mp4');
      task.filePath = file.path;

      if (isHls) {
        await _downloadHls(task, playUrl, headers, file);
      } else {
        await _downloadFile(task, playUrl, headers, file);
      }
      if (_isCancelled(task)) {
        await _silentDelete(file);
        return;
      }

      task.status = DownloadStatus.completed;
      task.progress = 1;
      // Notifie Android MediaStore (visible dans les apps de fichiers)
      try {
        await const MethodChannel('app.channel.media_scanner')
            .invokeMethod('scanFile', {'path': file.path});
      } catch (_) {}
    } catch (e) {
      if (_isCancelled(task)) {
        return;
      }
      task.status = DownloadStatus.failed;
      task.error = e.toString();
    } finally {
      _activeClient = null;
      _persist();
      notifyListeners();
    }
  }

  bool _isCancelled(DownloadTask task) {
    if (_cancelled.contains(task.id)) {
      _cancelled.remove(task.id);
      task.status = DownloadStatus.cancelled;
      _persist();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<File> _targetFile(DownloadTask task, String ext) async {
    Directory base;
    if (!kIsWeb && Platform.isAndroid) {
      base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final dir = Directory(
        '${base.path}/Downloads/${_slug(task.title)}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final name = task.subtitle.replaceAll(' · ', '_').replaceAll(' ', '_');
    return File('${dir.path}/${_slug(task.title)}_$name$ext');
  }

  Future<void> _silentDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Téléchargement direct (mp4) avec progression réelle.
  Future<void> _downloadFile(DownloadTask task, String url,
      Map<String, String> headers, File out) async {
    final client = http.Client();
    _activeClient = client;
    try {
      final req = http.Request('GET', Uri.parse(url))..headers.addAll(headers);
      final resp = await client.send(req).timeout(const Duration(seconds: 30));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      task.totalBytes = resp.contentLength ?? 0;
      final sink = out.openWrite();
      var lastNotify = 0;
      try {
        await for (final chunk in resp.stream) {
          if (_isCancelled(task)) break;
          sink.add(chunk);
          task.receivedBytes += chunk.length;
          if (task.totalBytes > 0) {
            task.progress =
                (task.receivedBytes / task.totalBytes).clamp(0.0, 1.0);
          } else {
            task.progress = 0.02; // inconnu → progression indicative
          }
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastNotify > 500) {
            lastNotify = now;
            notifyListeners();
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (_isCancelled(task)) throw _Cancelled();
    } on _Cancelled {
      rethrow;
    } finally {
      client.close();
      _activeClient = null;
    }
  }

  /// HLS : télécharge la playlist, puis chaque segment .ts en séquence,
  /// concaténés dans un unique fichier .ts (lisible directement).
  Future<void> _downloadHls(DownloadTask task, String playlistUrl,
      Map<String, String> headers, File out) async {
    final playlist = await _fetchText(playlistUrl, headers);
    if (!playlist.contains('#EXTM3U')) {
      throw Exception('Playlist HLS invalide');
    }

    // Si la playlist est un master (variantes), prendre la 1re media playlist
    var mediaUrl = playlistUrl;
    if (playlist.contains('#EXT-X-STREAM-INF')) {
      final lines = playlist.split('\n').map((l) => l.trim()).toList();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('#EXT-X-STREAM-INF') && i + 1 < lines.length) {
          mediaUrl = _resolveUrl(playlistUrl, lines[i + 1]);
          break;
        }
      }
    }

    final media = await _fetchText(mediaUrl, headers);
    final segments = <String>[];
    // Clé AES-128 éventuelle : non supportée (rare sur les hosters extraits)
    if (media.contains('#EXT-X-KEY') && !media.contains('METHOD=NONE')) {
      throw Exception('Flux chiffré (AES) non téléchargeable');
    }
    for (final line in media.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      if (t.contains('.ts') || t.contains('.m4s') || !t.contains('#')) {
        segments.add(_resolveUrl(mediaUrl, t));
      }
    }
    if (segments.isEmpty) throw Exception('Aucun segment dans la playlist');

    task.totalBytes = segments.length; // progression par segment
    final sink = out.openWrite();
    try {
      for (var i = 0; i < segments.length; i++) {
        if (_isCancelled(task)) throw _Cancelled();
        final bytes = await _fetchBytes(segments[i], headers);
        sink.add(bytes);
        task.receivedBytes = i + 1;
        task.progress = ((i + 1) / segments.length).clamp(0.0, 1.0);
        notifyListeners();
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    task.totalBytes = task.receivedBytes = await out.length();
  }

  Future<String> _fetchText(String url, Map<String, String> headers) async {
    final resp = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) throw Exception('Playlist HTTP ${resp.statusCode}');
    return utf8.decode(resp.bodyBytes, allowMalformed: true);
  }

  Future<List<int>> _fetchBytes(String url, Map<String, String> headers,
      {int attempts = 3}) async {
    Object? lastErr;
    for (var a = 0; a < attempts; a++) {
      try {
        final resp = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 25));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          return resp.bodyBytes;
        }
        lastErr = 'HTTP ${resp.statusCode}';
      } catch (e) {
        lastErr = e;
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
    throw Exception('Segment: $lastErr');
  }

  String _resolveUrl(String base, String maybeRelative) {
    if (maybeRelative.startsWith('http')) return maybeRelative;
    return Uri.parse(base).resolve(maybeRelative).toString();
  }

  String _slug(String input) {
    final s = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return (s.length > 40 ? s.substring(0, 40) : s)
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

class _Cancelled implements Exception {}
