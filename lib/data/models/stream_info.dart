/// Informations sur un stream vidéo
class StreamInfo {
  final String url;
  final String title;
  final String quality;
  final Map<String, String> headers;
  final String? referer;
  final String? userAgent;

  StreamInfo({
    required this.url,
    required this.title,
    this.quality = '',
    this.headers = const {},
    this.referer,
    this.userAgent,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      quality: json['quality'] ?? '',
      headers: Map<String, String>.from(json['headers'] ?? {}),
      referer: json['referer'],
      userAgent: json['user_agent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'quality': quality,
      'headers': headers,
      'referer': referer,
      'user_agent': userAgent,
    };
  }

  /// Crée un StreamInfo avec des en-têtes par défaut
  factory StreamInfo.withDefaults({
    required String url,
    required String title,
    String quality = '',
    Map<String, String>? customHeaders,
    String? referer,
    String? userAgent,
  }) {
    final defaultHeaders = {
      'User-Agent': userAgent ?? 'Mozilla/5.0 (Linux; Android 10; SM-A105F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
      'Accept': 'video/webm,video/ogg,video/*;q=0.9,application/ogg;q=0.7,audio/*;q=0.6,*/*;q=0.5',
      'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
      'Accept-Encoding': 'identity',
      'Connection': 'keep-alive',
    };

    if (referer != null && referer.isNotEmpty) {
      defaultHeaders['Referer'] = referer;
    }

    if (customHeaders != null) {
      defaultHeaders.addAll(customHeaders);
    }

    return StreamInfo(
      url: url,
      title: title,
      quality: quality,
      headers: defaultHeaders,
      referer: referer,
      userAgent: userAgent,
    );
  }

  /// Vérifie si l'URL est valide
  bool get isValidUrl {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Obtient l'extension du fichier depuis l'URL
  String get fileExtension {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      if (path.contains('.')) {
        return path.split('.').last;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Vérifie si le format est supporté
  bool get isSupportedFormat {
    const supportedFormats = ['mp4', 'm3u8', 'mkv', 'avi', 'mov', 'webm'];
    final extension = fileExtension;
    return supportedFormats.contains(extension) ||
        url.contains('stream') ||
        url.contains('video');
  }

  /// Vérifie si l'URL est un lien uqload
  bool get isUqloadUrl {
    try {
      final lowerUrl = url.toLowerCase();
      return lowerUrl.contains('uqload.com') || 
             lowerUrl.contains('uqload.net') ||
             lowerUrl.contains('uqload');
    } catch (e) {
      return false;
    }
  }

  /// Copie avec de nouveaux paramètres
  StreamInfo copyWith({
    String? url,
    String? title,
    String? quality,
    Map<String, String>? headers,
    String? referer,
    String? userAgent,
  }) {
    return StreamInfo(
      url: url ?? this.url,
      title: title ?? this.title,
      quality: quality ?? this.quality,
      headers: headers ?? this.headers,
      referer: referer ?? this.referer,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  /// Crée une copie avec les headers fusionnés
  StreamInfo copyWithMergedHeaders(Map<String, String> newHeaders) {
    final mergedHeaders = {...headers, ...newHeaders};
    return copyWith(headers: mergedHeaders);
  }

  /// Obtient tous les headers incluant Referer et UserAgent
  Map<String, String> getCompleteHeaders() {
    final completeHeaders = {...headers};

    // ✅ Ajouter le UserAgent s'il n'existe pas
    if (!completeHeaders.containsKey('User-Agent') && userAgent != null) {
      completeHeaders['User-Agent'] = userAgent!;
    }

    // ✅ Ajouter le Referer s'il n'existe pas
    if (!completeHeaders.containsKey('Referer') && referer != null) {
      completeHeaders['Referer'] = referer!;
    }

    return completeHeaders;
  }

  /// Convertit en format JSON pour sérialisation
  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'quality': quality,
      'headers': headers,
      'referer': referer,
      'userAgent': userAgent,
    };
  }

  /// Crée depuis un Map
  factory StreamInfo.fromMap(Map<String, dynamic> map) {
    return StreamInfo(
      url: map['url'] as String? ?? '',
      title: map['title'] as String? ?? '',
      quality: map['quality'] as String? ?? '',
      headers: Map<String, String>.from(map['headers'] as Map? ?? {}),
      referer: map['referer'] as String?,
      userAgent: map['userAgent'] as String?,
    );
  }

  @override
  String toString() {
    return 'StreamInfo(url: $url, title: $title, quality: $quality, referer: $referer, userAgent: ${userAgent != null ? 'defined' : 'null'})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreamInfo &&
        other.url == url &&
        other.title == title &&
        other.quality == quality &&
        other.referer == referer &&
        other.userAgent == userAgent;
  }

  @override
  int get hashCode {
    return url.hashCode ^ title.hashCode ^ quality.hashCode ^ referer.hashCode ^ userAgent.hashCode;
  }
}
