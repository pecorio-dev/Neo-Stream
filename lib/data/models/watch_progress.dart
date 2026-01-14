class WatchProgress {
  final String contentId; // ID du film ou de la série
  final String contentType; // 'movie' ou 'series'
  final String title;
  final int position; // Position en secondes
  final int duration; // Durée totale en secondes
  final DateTime lastWatched;
  
  // Pour les séries
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeTitle;
  
  // ID unique pour cette progression
  String get id => generateId(contentId, seasonNumber: seasonNumber, episodeNumber: episodeNumber);
  
  // Vérifie si c'est un épisode
  bool get isEpisode => contentType == 'series';
  
  // Vérifie si le contenu est terminé
  bool get isCompleted => progressPercentage >= 0.95;
  
  WatchProgress({
    required this.contentId,
    required this.contentType,
    required this.title,
    required this.position,
    required this.duration,
    required this.lastWatched,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeTitle,
  });

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    return WatchProgress(
      contentId: json['contentId'] ?? '',
      contentType: json['contentType'] ?? 'movie',
      title: json['title'] ?? '',
      position: (json['position'] ?? 0).toInt(),
      duration: (json['duration'] ?? 0).toInt(),
      lastWatched: DateTime.parse(json['lastWatched'] ?? DateTime.now().toIso8601String()),
      seasonNumber: json['seasonNumber'],
      episodeNumber: json['episodeNumber'],
      episodeTitle: json['episodeTitle'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contentId': contentId,
      'contentType': contentType,
      'title': title,
      'position': position,
      'duration': duration,
      'lastWatched': lastWatched.toIso8601String(),
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
    };
  }

  // Calculer le pourcentage de progression
  double get progressPercentage {
    if (duration <= 0) return 0.0;
    return (position / duration).clamp(0.0, 1.0);
  }

  // Vérifier si le contenu est presque terminé (>90%)
  bool get isNearlyFinished => progressPercentage > 0.9;

  // Obtenir la position de reprise (10 secondes avant)
  int get resumePosition {
    final resumePos = position - 10;
    return resumePos > 0 ? resumePos : 0;
  }

  // Formater le temps de position
  String get formattedPosition {
    final hours = position ~/ 3600;
    final minutes = (position % 3600) ~/ 60;
    final seconds = position % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
  }

  // Formater la durée totale
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
  }
  
  // Formater le temps restant
  String get formattedTimeLeft {
    final remaining = duration - position;
    final hours = remaining ~/ 3600;
    final minutes = (remaining % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m restantes';
    } else {
      return '${minutes}m restantes';
    }
  }
  
  /// Génère un ID unique pour une progression
  static String generateId(String contentId, {int? seasonNumber, int? episodeNumber}) {
    if (seasonNumber != null && episodeNumber != null) {
      return '${contentId}_S${seasonNumber}E${episodeNumber}';
    }
    return contentId;
  }
  
  /// Crée un WatchProgress depuis une Map
  factory WatchProgress.fromMap(Map<String, dynamic> map) {
    return WatchProgress(
      contentId: map['contentId'] ?? '',
      contentType: map['contentType'] ?? 'movie',
      title: map['title'] ?? '',
      position: (map['position'] ?? 0).toInt(),
      duration: (map['duration'] ?? 0).toInt(),
      lastWatched: DateTime.parse(map['lastWatched'] ?? DateTime.now().toIso8601String()),
      seasonNumber: map['seasonNumber'],
      episodeNumber: map['episodeNumber'],
      episodeTitle: map['episodeTitle'],
    );
  }
  
  /// Convertit en Map
  Map<String, dynamic> toMap() {
    return {
      'contentId': contentId,
      'contentType': contentType,
      'title': title,
      'position': position,
      'duration': duration,
      'lastWatched': lastWatched.toIso8601String(),
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
    };
  }

  // Créer une copie avec des valeurs mises à jour
  WatchProgress copyWith({
    String? contentId,
    String? contentType,
    String? title,
    int? position,
    int? duration,
    DateTime? lastWatched,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
  }) {
    return WatchProgress(
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      title: title ?? this.title,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      lastWatched: lastWatched ?? this.lastWatched,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeTitle: episodeTitle ?? this.episodeTitle,
    );
  }

  @override
  String toString() {
    if (contentType == 'series') {
      return 'WatchProgress(${title} S${seasonNumber}E${episodeNumber} - ${formattedPosition}/${formattedTimeLeft})';
    } else {
      return 'WatchProgress(${title} - ${formattedPosition}/${formattedTimeLeft})';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WatchProgress &&
        other.contentId == contentId &&
        other.seasonNumber == seasonNumber &&
        other.episodeNumber == episodeNumber;
  }

  @override
  int get hashCode {
    return Object.hash(contentId, seasonNumber, episodeNumber);
  }
}