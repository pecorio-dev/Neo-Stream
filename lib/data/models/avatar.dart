/// Modèle pour représenter un avatar utilisateur
class Avatar {
  final int id;
  final String name;
  final String imagePath;
  final String description;
  final String category;
  final List<String> colors;

  const Avatar({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.description,
    required this.category,
    required this.colors,
  });

  /// Chemin complet vers l'image de l'avatar
  String get fullImagePath => 'assets/avatars/$imagePath';

  factory Avatar.fromJson(Map<String, dynamic> json) {
    return Avatar(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      imagePath: json['imagePath'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      colors: List<String>.from(json['colors'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'description': description,
      'category': category,
      'colors': colors,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Avatar && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Avatar(id: $id, name: $name, category: $category)';
  }
}