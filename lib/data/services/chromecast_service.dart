import 'package:flutter/foundation.dart';

/// Service pour la gestion du Chromecast
/// Note: Implémentation temporaire sans flutter_cast_framework
class ChromecastService {
  static final ChromecastService _instance = ChromecastService._internal();
  factory ChromecastService() => _instance;
  ChromecastService._internal();

  // État du Chromecast
  bool _isConnected = false;
  String? _deviceName;
  bool _isInitialized = false;
  List<CastDevice> _availableDevices = [];
  CastDevice? _connectedDevice;
  final List<VoidCallback> _listeners = [];
  
  // Getters
  bool get isConnected => _isConnected;
  String? get deviceName => _deviceName;
  bool get isAvailable => false; // Toujours false sans le package
  bool get isInitialized => _isInitialized;
  List<CastDevice> get availableDevices => List.unmodifiable(_availableDevices);
  CastDevice? get connectedDevice => _connectedDevice;

  /// Initialise le service Chromecast
  Future<void> initialize() async {
    if (kDebugMode) {
      print('🎭 ChromecastService: Initialisation (mode simulation)');
    }
    // Simulation d'initialisation
    await Future.delayed(const Duration(milliseconds: 500));
    _isInitialized = true;
    _notifyListeners();
  }

  /// Recherche les appareils Chromecast disponibles
  Future<List<CastDevice>> discoverDevices() async {
    if (kDebugMode) {
      print('🎭 ChromecastService: Recherche d\'appareils (simulation)');
    }
    // Retourne une liste vide en simulation
    return [];
  }

  /// Se connecte à un appareil Chromecast
  Future<bool> connectToDevice(CastDevice device) async {
    if (kDebugMode) {
      print('🎭 ChromecastService: Connexion à ${device.name} (simulation)');
    }
    
    // Simulation de connexion
    await Future.delayed(const Duration(seconds: 1));
    _isConnected = true;
    _deviceName = device.name;
    _connectedDevice = device;
    _notifyListeners();
    
    return true;
  }

  /// Se déconnecte du Chromecast
  Future<void> disconnect() async {
    if (kDebugMode) {
      print('🎭 ChromecastService: Déconnexion (simulation)');
    }
    
    _isConnected = false;
    _deviceName = null;
    _connectedDevice = null;
    _notifyListeners();
  }

  /// Lance la lecture d'un média
  Future<bool> playMedia({
    required String url,
    required String title,
    String? description,
    String? imageUrl,
    Duration? startTime,
  }) async {
    if (!_isConnected) {
      throw Exception('Aucun appareil Chromecast connecté');
    }

    if (kDebugMode) {
      print('🎭 ChromecastService: Lecture de $title (simulation)');
      print('🎭 URL: $url');
    }

    // Simulation de lecture
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  /// Met en pause la lecture
  Future<void> pause() async {
    if (kDebugMode) {
      print('🎭 ChromecastService: Pause (simulation)');
    }
  }

  /// Reprend la lecture
  Future<void> resume() async {
    if (kDebugMode) {
      print('🎭 ChromecastService: Reprise (simulation)');
    }
  }

  /// Arrête la lecture
  Future<void> stop() async {
    if (kDebugMode) {
      print('🎭 ChromecastService: Arrêt (simulation)');
    }
  }

  /// Change la position de lecture
  Future<void> seek(Duration position) async {
    if (kDebugMode) {
      print('🎭 ChromecastService: Seek à ${position.inSeconds}s (simulation)');
    }
  }

  /// Change le volume
  Future<void> setVolume(double volume) async {
    if (kDebugMode) {
      print('🎭 ChromecastService: Volume à ${(volume * 100).round()}% (simulation)');
    }
  }

  /// Obtient le statut de lecture actuel
  Future<MediaStatus?> getMediaStatus() async {
    if (!_isConnected) return null;
    
    // Retourne un statut simulé
    return MediaStatus(
      isPlaying: true,
      position: Duration.zero,
      duration: const Duration(minutes: 90),
      volume: 0.5,
    );
  }

  /// Ajoute un listener pour les changements d'état
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Retire un listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notifie tous les listeners
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        if (kDebugMode) {
          print('Erreur lors de la notification du listener: $e');
        }
      }
    }
  }

  /// Dispose des ressources
  void dispose() {
    _isConnected = false;
    _deviceName = null;
    _connectedDevice = null;
    _listeners.clear();
  }
}

/// Classe représentant un appareil Chromecast
class CastDevice {
  final String id;
  final String name;
  final String type;
  final bool isAvailable;

  const CastDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isAvailable = true,
  });

  // Getters for compatibility
  String get deviceName => name;
  String get deviceId => id;

  @override
  String toString() => 'CastDevice(id: $id, name: $name, type: $type)';
}

/// État de la session Chromecast
enum CastState {
  notConnected,
  connecting,
  connected,
  disconnecting,
}

/// Session Chromecast
class CastSession {
  final String sessionId;
  final CastDevice device;
  final CastState state;

  const CastSession({
    required this.sessionId,
    required this.device,
    required this.state,
  });
}

/// Statut de lecture du média
class MediaStatus {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double volume;

  const MediaStatus({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.volume,
  });

  PlayerState get playerState => isPlaying ? PlayerState.playing : PlayerState.paused;
}

/// État du lecteur
enum PlayerState {
  idle,
  playing,
  paused,
  buffering,
  finished,
}