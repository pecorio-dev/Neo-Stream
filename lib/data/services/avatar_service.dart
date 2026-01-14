import '../models/avatar.dart';

/// Service pour gérer les avatars disponibles
class AvatarService {
  static const List<Avatar> _avatars = [
    Avatar(
      id: 1,
      name: 'Nexus Runner',
      imagePath: 'avatar_1.png',
      description: 'Hacker de l\'ombre spécialisé dans l\'infiltration de réseaux corporatifs',
      category: 'Cyberpunk',
      colors: ['#00ffff', '#ffffff', '#404040'],
    ),
    Avatar(
      id: 2,
      name: 'Chrome Angel',
      imagePath: 'avatar_2.png',
      description: 'Netrunner élite naviguant dans les méandres du cyberespace',
      category: 'Cyberpunk',
      colors: ['#ff00ff', '#ff69b4', '#2a1a2a'],
    ),
    Avatar(
      id: 3,
      name: 'Ghost Protocol',
      imagePath: 'avatar_3.png',
      description: 'Opérateur furtif maîtrisant les codes de la matrice digitale',
      category: 'Hacker',
      colors: ['#00ff00', '#003300', '#000000'],
    ),
    Avatar(
      id: 4,
      name: 'Plasma Soldier',
      imagePath: 'avatar_4.png',
      description: 'Mercenaire augmenté équipé d\'implants de combat de dernière génération',
      category: 'Warrior',
      colors: ['#ffaa00', '#ff8800', '#4a4a4a'],
    ),
    Avatar(
      id: 5,
      name: 'Shadow Byte',
      imagePath: 'avatar_5.png',
      description: 'Assassin cybernétique utilisant la furtivité et les nano-technologies',
      category: 'Ninja',
      colors: ['#8800ff', '#bb00ff', '#2a002a'],
    ),
    Avatar(
      id: 6,
      name: 'Riot Code',
      imagePath: 'avatar_6.png',
      description: 'Révolutionnaire numérique luttant contre l\'oppression corporative',
      category: 'Punk',
      colors: ['#ff0000', '#ffffff', '#2a2a2a'],
    ),
    Avatar(
      id: 7,
      name: 'Neural Link',
      imagePath: 'avatar_7.png',
      description: 'Ingénieur en intelligence artificielle connecté au réseau neural global',
      category: 'Tech',
      colors: ['#0088ff', '#ffffff', '#2a3a4a'],
    ),
    Avatar(
      id: 8,
      name: 'Corp Executive',
      imagePath: 'avatar_8.png',
      description: 'Dirigeant de mégacorporation aux implants de luxe et au pouvoir immense',
      category: 'Elite',
      colors: ['#ffdd00', '#4a4a2a', '#000000'],
    ),
    Avatar(
      id: 9,
      name: 'Bio Hacker',
      imagePath: 'avatar_9.png',
      description: 'Scientifique rebelle fusionnant biotechnologie et code génétique',
      category: 'Bio-Tech',
      colors: ['#00aa00', '#00ff00', '#2a4a2a'],
    ),
    Avatar(
      id: 10,
      name: 'Psychic Node',
      imagePath: 'avatar_10.png',
      description: 'Telepath augmenté capable de naviguer dans les réseaux par la pensée',
      category: 'Psychic',
      colors: ['#aa00aa', '#ffffff', '#4a2a3a'],
    ),
    Avatar(
      id: 11,
      name: 'Void Walker',
      imagePath: 'avatar_11.png',
      description: 'Pilote de vaisseau spatial explorant les confins de la galaxie digitale',
      category: 'Space',
      colors: ['#4400ff', '#ffffff', '#3a3a4a'],
    ),
    Avatar(
      id: 12,
      name: 'Synth Core',
      imagePath: 'avatar_12.png',
      description: 'Intelligence artificielle évoluée ayant développé sa propre conscience',
      category: 'Android',
      colors: ['#8a8a8a', '#ff0000', '#00ffff'],
    ),
  ];

  /// Récupère tous les avatars disponibles
  static List<Avatar> getAllAvatars() {
    return List.unmodifiable(_avatars);
  }

  /// Récupère un avatar par son ID
  static Avatar? getAvatarById(int id) {
    try {
      return _avatars.firstWhere((avatar) => avatar.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Récupère les avatars par catégorie
  static List<Avatar> getAvatarsByCategory(String category) {
    return _avatars.where((avatar) => avatar.category == category).toList();
  }

  /// Récupère toutes les catégories disponibles
  static List<String> getCategories() {
    final categories = _avatars.map((avatar) => avatar.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// Récupère un avatar aléatoire
  static Avatar getRandomAvatar() {
    final random = DateTime.now().millisecondsSinceEpoch % _avatars.length;
    return _avatars[random];
  }

  /// Récupère les avatars recommandés (les plus populaires)
  static List<Avatar> getRecommendedAvatars() {
    // Retourne les 6 premiers avatars comme recommandés
    return _avatars.take(6).toList();
  }

  /// Recherche des avatars par nom ou description
  static List<Avatar> searchAvatars(String query) {
    if (query.isEmpty) return getAllAvatars();
    
    final lowerQuery = query.toLowerCase();
    return _avatars.where((avatar) {
      return avatar.name.toLowerCase().contains(lowerQuery) ||
             avatar.description.toLowerCase().contains(lowerQuery) ||
             avatar.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Vérifie si un avatar existe
  static bool avatarExists(int id) {
    return _avatars.any((avatar) => avatar.id == id);
  }

  /// Récupère l\'avatar par défaut (le premier)
  static Avatar getDefaultAvatar() {
    return _avatars.first;
  }
}