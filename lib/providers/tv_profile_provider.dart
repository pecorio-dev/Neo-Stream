import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TVProfile {
  final int id;
  final String username;
  final String? avatarEmoji;
  final int? avatarColor;
  final String? pinCode;
  final bool isAdult;
  final Map<String, dynamic>? watchPreferences;
  final DateTime? lastLogin;

  const TVProfile({
    required this.id,
    required this.username,
    this.avatarEmoji,
    this.avatarColor,
    this.pinCode,
    this.isAdult = false,
    this.watchPreferences,
    this.lastLogin,
  });

  factory TVProfile.fromJson(Map<String, dynamic> json) {
    return TVProfile(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      username: json['username']?.toString() ?? '',
      avatarEmoji: json['avatar_emoji']?.toString(),
      avatarColor: json['avatar_color'] is int
          ? json['avatar_color']
          : int.tryParse(json['avatar_color']?.toString() ?? ''),
      pinCode: json['pin_code']?.toString(),
      isAdult: json['is_adult'] == 1 || json['is_adult'] == true,
      watchPreferences: json['watch_preferences'] is Map
          ? Map<String, dynamic>.from(json['watch_preferences'])
          : null,
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar_emoji': avatarEmoji,
      'avatar_color': avatarColor,
      'pin_code': pinCode,
      'is_adult': isAdult ? 1 : 0,
      'watch_preferences': watchPreferences,
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  TVProfile copyWith({
    int? id,
    String? username,
    String? avatarEmoji,
    int? avatarColor,
    String? pinCode,
    bool? isAdult,
    Map<String, dynamic>? watchPreferences,
    DateTime? lastLogin,
  }) {
    return TVProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColor: avatarColor ?? this.avatarColor,
      pinCode: pinCode ?? this.pinCode,
      isAdult: isAdult ?? this.isAdult,
      watchPreferences: watchPreferences ?? this.watchPreferences,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

class TVProfileProvider extends ChangeNotifier {
  static const String _storageKey = 'tv_user_profiles';
  static const String _selectedKey = 'tv_selected_profile';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<TVProfile> _profiles = [];
  TVProfile? _selectedProfile;
  bool _isLoading = false;
  String? _error;

  List<TVProfile> get profiles => _profiles;
  TVProfile? get selectedProfile => _selectedProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfiles => _profiles.isNotEmpty;

  Future<void> loadProfiles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _storage.read(key: _storageKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(data);
        _profiles = jsonList
            .map((e) => TVProfile.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      final selectedId = await _storage.read(key: _selectedKey);
      if (selectedId != null && _profiles.isNotEmpty) {
        final id = int.tryParse(selectedId);
        if (id != null) {
          _selectedProfile = _profiles.firstWhere(
            (p) => p.id == id,
            orElse: () => _profiles.first,
          );
        }
      }
    } catch (e) {
      _error = 'Failed to load profiles: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveProfiles() async {
    try {
      final jsonList = _profiles.map((p) => p.toJson()).toList();
      await _storage.write(key: _storageKey, value: json.encode(jsonList));
    } catch (e) {
      _error = 'Failed to save profiles: $e';
      notifyListeners();
    }
  }

  Future<void> selectProfile(TVProfile profile) async {
    _selectedProfile = profile;
    notifyListeners();

    try {
      await _storage.write(key: _selectedKey, value: profile.id.toString());
    } catch (e) {
      _error = 'Failed to save selected profile: $e';
    }
  }

  Future<void> addProfile(TVProfile profile) async {
    _profiles.add(profile);
    await saveProfiles();
    notifyListeners();
  }

  Future<void> updateProfile(TVProfile profile) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
      if (_selectedProfile?.id == profile.id) {
        _selectedProfile = profile;
      }
      await saveProfiles();
      notifyListeners();
    }
  }

  Future<void> deleteProfile(int id) async {
    _profiles.removeWhere((p) => p.id == id);
    if (_selectedProfile?.id == id) {
      _selectedProfile = _profiles.isNotEmpty ? _profiles.first : null;
      if (_selectedProfile != null) {
        await _storage.write(key: _selectedKey, value: _selectedProfile!.id.toString());
      }
    }
    await saveProfiles();
    notifyListeners();
  }

  int _generateId() {
    if (_profiles.isEmpty) return 1;
    return _profiles.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<TVProfile> createProfile({
    required String username,
    String? avatarEmoji,
    int? avatarColor,
    String? pinCode,
    bool isAdult = false,
  }) async {
    final profile = TVProfile(
      id: _generateId(),
      username: username,
      avatarEmoji: avatarEmoji,
      avatarColor: avatarColor,
      pinCode: pinCode,
      isAdult: isAdult,
    );
    await addProfile(profile);
    return profile;
  }
}
