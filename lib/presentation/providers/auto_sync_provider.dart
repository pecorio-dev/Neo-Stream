import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/sync/auto_sync_service.dart';
import '../../data/services/local_storage/watch_progress_local_service.dart';

final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  final localService = WatchProgressLocalService();
  return AutoSyncService(localService: localService);
});

final autoSyncInitializeProvider = FutureProvider<void>((ref) async {
  final syncService = ref.watch(autoSyncServiceProvider);
  await syncService.initialize();
});

final autoSyncSyncIfNeededProvider = FutureProvider<bool>((ref) async {
  final syncService = ref.watch(autoSyncServiceProvider);
  return await syncService.syncIfNeeded();
});

final autoSyncForceSyncProvider = FutureProvider<bool>((ref) async {
  final syncService = ref.watch(autoSyncServiceProvider);
  return await syncService.forceSyncNow();
});

final autoSyncStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final syncService = ref.watch(autoSyncServiceProvider);
  return await syncService.getSyncStats();
});

final autoSyncResetProvider = FutureProvider<void>((ref) async {
  final syncService = ref.watch(autoSyncServiceProvider);
  await syncService.resetSyncTime();
});
