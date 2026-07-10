/// Représente une release GitHub (tag + assets).
class GithubRelease {
  final String tagName;
  final String name;
  final String body;
  final bool isDraft;
  final bool isPrerelease;
  final DateTime publishedAt;
  final List<GithubAsset> assets;

  const GithubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.isDraft,
    required this.isPrerelease,
    required this.publishedAt,
    required this.assets,
  });

  /// Extrait la version depuis le tagName (enlève 'v' si présent).
  String get version {
    var v = tagName.trim();
    if (v.isNotEmpty && (v[0] == 'v' || v[0] == 'V')) v = v.substring(1);
    return v;
  }

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    final assetsList = (json['assets'] as List?)
            ?.map((a) => GithubAsset.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];

    return GithubRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isDraft: json['draft'] as bool? ?? false,
      isPrerelease: json['prerelease'] as bool? ?? false,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ??
          DateTime.now(),
      assets: assetsList,
    );
  }

  /// Retourne l'asset le plus approprié pour la plateforme courante.
  GithubAsset? assetForPlatform(String platform) {
    // Ordonner par priorité : la plus spécifique d'abord.
    const priorities = {
      'android': ['app-arm64-release.apk', 'app-release.apk', '.apk'],
      'linux': ['.deb', '.AppImage', '.tar.gz'],
      'windows': ['.exe', '.msi', '.zip'],
    };

    final suffixes = priorities[platform];
    if (suffixes == null) return null;

    // 1) Chercher une correspondance exacte dans les suffixes prioritaires
    for (final suffix in suffixes) {
      if (suffix.startsWith('.')) {
        final match =
            assets.where((a) => a.name.endsWith(suffix)).toList();
        if (match.isNotEmpty) return match.first;
      } else {
        final match =
            assets.where((a) => a.name == suffix).toList();
        if (match.isNotEmpty) return match.first;
      }
    }

    // 2) Fallback : chercher n'importe quel asset du bon type
    for (final suffix in suffixes.where((s) => s.startsWith('.'))) {
      final match = assets.where((a) => a.name.endsWith(suffix)).toList();
      if (match.isNotEmpty) return match.first;
    }

    return null;
  }
}

/// Un asset attaché à une release (APK, .deb, .exe…).
class GithubAsset {
  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final String contentType;

  const GithubAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.contentType,
  });

  /// Taille lisible (ex. "42.3 MB").
  String get readableSize {
    const mb = 1024 * 1024;
    if (sizeBytes < mb) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < mb * 1024) {
      return '${(sizeBytes / mb).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (mb * 1024)).toStringAsFixed(1)} GB';
  }

  factory GithubAsset.fromJson(Map<String, dynamic> json) {
    return GithubAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      sizeBytes: json['size'] as int? ?? 0,
      contentType: json['content_type'] as String? ?? '',
    );
  }
}
