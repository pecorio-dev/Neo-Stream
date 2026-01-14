import 'package:shared_preferences/shared_preferences.dart';
import '../watch_progress_service.dart';
import '../local_storage/watch_progress_local_service.dart';

class AutoSyncService {
  static const String _tag = 'AutoSyncService';
  static const String _lastSyncKey = 'last_sync_time';
  static const int _syncIntervalMinutes = 5;

  final WatchProgressLocalService _localService;

  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  AutoSyncService({
    WatchProgressLocalService? localService,
  }) : _localService = localService ?? WatchProgressLocalService();

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initialise le service
  Future<void> initialize() async {
    try {
      print('$_tag: Initializing...');
      await _loadLastSyncTime();
      print('$_tag: ✅ Initialized (last sync: $_lastSyncTime)');
    } catch (e) {
      print('$_tag: ❌ Initialize error: $e');
    }
  }

  /// Synchronise si nécessaire
  Future<bool> syncIfNeeded() async {
    try {
      if (_isSyncing) {
        print('$_tag: Already syncing');
        return false;
      }

      final shouldSync = _shouldSync();
      if (!shouldSync) {
        print('$_tag: No need to sync');
        return false;
      }

      return await sync();
    } catch (e) {
      print('$_tag: ❌ syncIfNeeded error: $e');
      return false;
    }
  }

  /// Synchronise les données localement
  Future<bool> sync() async {
    try {
      _isSyncing = true;
      print('$_tag: Starting local sync...');

      // Récupérer les progressions locales
      final localProgress = await WatchProgressService.getAllProgress();
      print('$_tag: Found ${localProgress.length} local progress entries');

      // Marquer les items comme synchronisés
      await _localService.markAsSynced(localProgress.map((p) => p.id).toList());

      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();

      _isSyncing = false;
      print('$_tag: ✅ Sync completed');
      return true;
    } catch (e) {
      _isSyncing = false;
      print('$_tag: ❌ Sync error: $e');
      return false;
    }
  }

  /// Force une synchronisation immédiate
  Future<bool> forceSyncNow() async {
    return await sync();
  }

  /// Récupère les statistiques de synchronisation
  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final localProgress = await WatchProgressService.getAllProgress();
      return {
        'isSyncing': _isSyncing,
        'lastSync': _lastSyncTime?.toIso8601String(),
        'localEntries': localProgress.length,
        'pendingSync': 0,
      };
    } catch (e) {
      return {
        'isSyncing': false,
        'lastSync': null,
        'localEntries': 0,
        'pendingSync': 0,
        'error': e.toString(),
      };
    }
  }

  /// Réinitialise le temps de dernière synchronisation
  Future<void> resetSyncTime() async {
    _lastSyncTime = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
    print('$_tag: Sync time reset');
  }

  /// Vérifie si une synchronisation est nécessaire
  bool _shouldSync() {
    if (_lastSyncTime == null) {
      return true;
    }
    final diff = DateTime.now().difference(_lastSyncTime!);
    return diff.inMinutes >= _syncIntervalMinutes;
  }

  /// Charge le temps de dernière synchronisation
  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString(_lastSyncKey);
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
      }
    } catch (e) {
      print('$_tag: Error loading last sync time: $e');
    }
  }

  /// Sauvegarde le temps de dernière synchronisation
  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastSyncTime != null) {
        await prefs.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
      }
    } catch (e) {
      print('$_tag: Error saving last sync time: $e');
    }
  }
}
