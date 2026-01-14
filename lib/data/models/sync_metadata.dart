class SyncMetadata {
  final String version;
  final DateTime lastSyncedAt;
  final int entryCount;
  final String deviceName;
  final String? userId;

  SyncMetadata({
    required this.version,
    required this.lastSyncedAt,
    required this.entryCount,
    required this.deviceName,
    this.userId,
  });

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      version: json['version'] ?? '1.0',
      lastSyncedAt: DateTime.parse(
          json['lastSyncedAt'] ?? DateTime.now().toIso8601String()),
      entryCount: json['entryCount'] ?? 0,
      deviceName: json['deviceName'] ?? 'Unknown',
      userId: json['userId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'lastSyncedAt': lastSyncedAt.toIso8601String(),
      'entryCount': entryCount,
      'deviceName': deviceName,
      'userId': userId,
    };
  }

  SyncMetadata copyWith({
    String? version,
    DateTime? lastSyncedAt,
    int? entryCount,
    String? deviceName,
    String? userId,
  }) {
    return SyncMetadata(
      version: version ?? this.version,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      entryCount: entryCount ?? this.entryCount,
      deviceName: deviceName ?? this.deviceName,
      userId: userId ?? this.userId,
    );
  }

  @override
  String toString() =>
      'SyncMetadata(v$version, entries: $entryCount, device: $deviceName, lastSynced: ${lastSyncedAt.toString()}, userId: $userId)';
}
