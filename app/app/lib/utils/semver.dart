/// Comparaison de versions sémantiques légère (pas de dépendance externe).
///
/// Gère les pré-releases : `1.2.0-beta.1` < `1.2.0`.
/// On ignore les métadonnées de build (`+20240101`).
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;

  const Version(this.major, this.minor, this.patch, [this.preRelease = const []]);

  /// `true` si c'est une pré-version (ex. `-beta.1`, `-rc.2`).
  bool get isPreRelease => preRelease.isNotEmpty;

  factory Version.parse(String raw) {
    var input = raw.trim();
    // Retirer un éventuel 'v' ou 'V' en préfixe.
    if (input.isNotEmpty && (input[0] == 'v' || input[0] == 'V')) {
      input = input.substring(1);
    }
    // Séparer version de base / pré-release / build.
    String core = input;
    String pre = '';
    if (input.contains('+')) {
      core = input.split('+').first;
    }
    if (core.contains('-')) {
      final parts = core.split('-');
      core = parts.first;
      pre = parts.sublist(1).join('-');
    }
    final segments = core.split('.');
    final major = int.tryParse(segments.isNotEmpty ? segments[0] : '0') ?? 0;
    final minor = int.tryParse(segments.length > 1 ? segments[1] : '0') ?? 0;
    final patch = int.tryParse(segments.length > 2 ? segments[2] : '0') ?? 0;
    final preRelease = pre.isEmpty
        ? const <String>[]
        : pre.split('.').where((e) => e.isNotEmpty).toList();
    return Version(major, minor, patch, preRelease);
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // Une version sans pré-release est > à une version avec pré-release.
    // (semver : 1.0.0 > 1.0.0-beta)
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    // Comparer identifiant par identifiant.
    final maxLen = preRelease.length > other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var i = 0; i < maxLen; i++) {
      if (i >= preRelease.length) return -1; // plus court = plus petit
      if (i >= other.preRelease.length) return 1;
      final a = preRelease[i];
      final b = other.preRelease[i];
      final aNum = int.tryParse(a);
      final bNum = int.tryParse(b);
      if (aNum != null && bNum != null) {
        if (aNum != bNum) return aNum.compareTo(bNum);
      } else if (aNum != null) {
        return -1; // numérique < alphanumérique
      } else if (bNum != null) {
        return 1;
      } else {
        final cmp = a.compareTo(b);
        if (cmp != 0) return cmp;
      }
    }
    return 0;
  }

  bool operator <(Version other) => compareTo(other) < 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator >=(Version other) => compareTo(other) >= 0;

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    if (preRelease.isEmpty) return base;
    return '$base-${preRelease.join('.')}';
  }

  @override
  bool operator ==(Object other) =>
      other is Version && compareTo(other) == 0;

  @override
  int get hashCode => toString().hashCode;
}
