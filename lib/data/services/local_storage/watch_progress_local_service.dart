import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/watch_progress.dart';

/// Service pour stocker localement la progression de visionnage
class WatchProgressLocalService {
  static const String _tag = 'WatchProgressLocalService';
  static const String _dbName = 'neo_stream.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'watch_progress';

  static final WatchProgressLocalService _instance =
      WatchProgressLocalService._internal();

  Database? _database;

  WatchProgressLocalService._internal();

  factory WatchProgressLocalService() {
    return _instance;
  }

  /// Obtient la base de données
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialise la base de données
  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);

      print('$_tag: Opening database at $path');

      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('$_tag: Error initializing database: $e');
      rethrow;
    }
  }

  /// Crée les tables
  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE $_tableName (
          id TEXT PRIMARY KEY,
          contentId TEXT NOT NULL,
          contentType TEXT NOT NULL,
          title TEXT NOT NULL,
          position INTEGER NOT NULL,
          duration INTEGER NOT NULL,
          lastWatched TEXT NOT NULL,
          seasonNumber INTEGER,
          episodeNumber INTEGER,
          episodeTitle TEXT,
          syncedAt TEXT,
          isSyncPending INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      print('$_tag: Database tables created');
    } catch (e) {
      print('$_tag: Error creating tables: $e');
      rethrow;
    }
  }

  /// Met à jour la structure de la base de données
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('$_tag: Database upgraded from $oldVersion to $newVersion');
  }

  /// Sauvegarde une progression de visionnage
  Future<void> saveProgress(WatchProgress progress) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      await db.insert(
        _tableName,
        {
          'id': progress.id,
          'contentId': progress.contentId,
          'contentType': progress.contentType,
          'title': progress.title,
          'position': progress.position,
          'duration': progress.duration,
          'lastWatched': progress.lastWatched.toIso8601String(),
          'seasonNumber': progress.seasonNumber,
          'episodeNumber': progress.episodeNumber,
          'episodeTitle': progress.episodeTitle,
          'isSyncPending': 1,
          'createdAt': now,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('$_tag: Saved progress for ${progress.title}');
    } catch (e) {
      print('$_tag: Error saving progress: $e');
      rethrow;
    }
  }

  /// Obtient tous les progressions
  Future<List<WatchProgress>> getAllProgress() async {
    try {
      final db = await database;
      final maps = await db.query(_tableName);

      return maps
          .map((map) => WatchProgress.fromJson(
                Map<String, dynamic>.from(map),
              ))
          .toList();
    } catch (e) {
      print('$_tag: Error getting all progress: $e');
      return [];
    }
  }

  /// Obtient les progressions en attente de synchronisation
  Future<List<WatchProgress>> getPendingSyncProgress() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'isSyncPending = ?',
        whereArgs: [1],
      );

      return maps
          .map((map) => WatchProgress.fromJson(
                Map<String, dynamic>.from(map),
              ))
          .toList();
    } catch (e) {
      print('$_tag: Error getting pending sync progress: $e');
      return [];
    }
  }

  /// Obtient un progrès spécifique
  Future<WatchProgress?> getProgress(String contentId,
      {int? seasonNumber, int? episodeNumber}) async {
    try {
      final db = await database;

      String whereClause = 'contentId = ?';
      List<dynamic> whereArgs = [contentId];

      if (seasonNumber != null && episodeNumber != null) {
        whereClause += ' AND seasonNumber = ? AND episodeNumber = ?';
        whereArgs = [contentId, seasonNumber, episodeNumber];
      }

      final maps = await db.query(
        _tableName,
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return WatchProgress.fromJson(Map<String, dynamic>.from(maps.first));
      }

      return null;
    } catch (e) {
      print('$_tag: Error getting progress: $e');
      return null;
    }
  }

  /// Met à jour le statut de synchronisation
  Future<void> markAsSynced(List<String> progressIds) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      for (final id in progressIds) {
        await db.update(
          _tableName,
          {
            'isSyncPending': 0,
            'syncedAt': now,
            'updatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      print('$_tag: Marked ${progressIds.length} items as synced');
    } catch (e) {
      print('$_tag: Error marking as synced: $e');
      rethrow;
    }
  }

  /// Marque tout comme en attente de sync
  Future<void> markAllAsPending() async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      await db.update(
        _tableName,
        {
          'isSyncPending': 1,
          'updatedAt': now,
        },
      );

      print('$_tag: Marked all items as pending sync');
    } catch (e) {
      print('$_tag: Error marking all as pending: $e');
      rethrow;
    }
  }

  /// Supprime une progression
  Future<void> deleteProgress(String contentId) async {
    try {
      final db = await database;

      await db.delete(
        _tableName,
        where: 'contentId = ?',
        whereArgs: [contentId],
      );

      print('$_tag: Deleted progress for $contentId');
    } catch (e) {
      print('$_tag: Error deleting progress: $e');
      rethrow;
    }
  }

  /// Obtient le nombre total de progressions
  Future<int> getProgressCount() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
      );
      return count ?? 0;
    } catch (e) {
      print('$_tag: Error getting count: $e');
      return 0;
    }
  }

  /// Obtient le nombre de progressions en attente
  Future<int> getPendingSyncCount() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_tableName WHERE isSyncPending = 1',
        ),
      );
      return count ?? 0;
    } catch (e) {
      print('$_tag: Error getting pending count: $e');
      return 0;
    }
  }

  /// Exporte toutes les progressions en JSON
  Future<String> exportAsJson() async {
    try {
      final allProgress = await getAllProgress();
      final json = jsonEncode({
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'entries': allProgress.map((p) => p.toJson()).toList(),
      });
      return json;
    } catch (e) {
      print('$_tag: Error exporting as JSON: $e');
      rethrow;
    }
  }

  /// Importe des progressions depuis JSON
  Future<void> importFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final entries = data['entries'] as List<dynamic>?;

      if (entries != null) {
        for (final entry in entries) {
          final progress =
              WatchProgress.fromJson(entry as Map<String, dynamic>);
          await saveProgress(progress);
        }
      }

      print('$_tag: Imported ${entries?.length ?? 0} progress entries');
    } catch (e) {
      print('$_tag: Error importing from JSON: $e');
      rethrow;
    }
  }

  /// Vide la base de données
  Future<void> clearDatabase() async {
    try {
      final db = await database;
      await db.delete(_tableName);
      print('$_tag: Database cleared');
    } catch (e) {
      print('$_tag: Error clearing database: $e');
      rethrow;
    }
  }

  /// Ferme la base de données
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('$_tag: Database closed');
    }
  }
}
