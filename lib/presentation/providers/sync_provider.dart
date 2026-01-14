import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncProvider = ChangeNotifierProvider((ref) => SyncProvider());

class SyncProvider extends ChangeNotifier {
  bool _isSyncing = false;
  String? _syncError;
  DateTime? _lastSyncTime;
  int _syncedEntriesCount = 0;
  bool _autoSyncEnabled = false;

  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get syncedEntriesCount => _syncedEntriesCount;
  bool get autoSyncEnabled => _autoSyncEnabled;

  Future<bool> syncProgress() async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));
    _lastSyncTime = DateTime.now();
    _syncedEntriesCount += 1;
    _isSyncing = false;
    notifyListeners();
    return true;
  }

  void setAutoSync(bool value) {
    _autoSyncEnabled = value;
    notifyListeners();
  }
}
