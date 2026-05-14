import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/content.dart';
import '../services/api_service.dart';

/// Auth Provider — manages login state and user data
class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isPremium => _user?.premiumActive ?? false;
  bool get hasStoredSession => _api.isLoggedIn;

  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final success = await _api.loadSavedCredentials();
      if (success) {
        _user = _api.currentUser;
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = humanizeApiError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.login(username, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = humanizeApiError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.register(username, email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = humanizeApiError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_user == null) return;
    try {
      final success = await _api.loadSavedCredentials();
      if (success) {
        _user = _api.currentUser;
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Content Provider — manages home data, lists, etc.
class ContentProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // Home data sections
  List<Content> _hero = [];
  List<Content> _addedToday = [];
  List<Content> _dailyTop = [];
  List<Content> _recommended = [];
  List<Content> _continueWatching = [];
  List<Content> _popularFilms = [];
  List<Content> _popularSeries = [];
  List<Content> _recentFilms = [];
  List<Content> _recentSeries = [];
  List<Map<String, dynamic>> _byGenre = [];
  List<Map<String, dynamic>> _myLibrary = [];
  bool _isPremium = false;
  int _totalAvailable = 0;
  int _totalFilms = 0;
  int _totalSeries = 0;

  bool _isLoadingHome = false;
  String? _homeError;

  // Getters
  List<Content> get hero => _hero;
  List<Content> get addedToday => _addedToday;
  List<Content> get dailyTop => _dailyTop;
  List<Content> get recommended => _recommended;
  List<Content> get continueWatching => _continueWatching;
  List<Content> get popularFilms => _popularFilms;
  List<Content> get popularSeries => _popularSeries;
  List<Content> get recentFilms => _recentFilms;
  List<Content> get recentSeries => _recentSeries;
  List<Map<String, dynamic>> get byGenre => _byGenre;
  List<Map<String, dynamic>> get myLibrary => _myLibrary;
  bool get isPremium => _isPremium;
  int get totalAvailable => _totalAvailable;
  int get totalFilms => _totalFilms;
  int get totalSeries => _totalSeries;
  bool get isLoadingHome => _isLoadingHome;
  String? get homeError => _homeError;

  List<Content> _parseContentList(dynamic data) {
    if (data == null || data is! List) return [];
    return data
        .map((e) {
          if (e is Map<String, dynamic>) return Content.fromJson(e);
          return null;
        })
        .whereType<Content>()
        .where((c) => c.hasPoster)
        .toList();
  }

  Future<void> loadHome() async {
    _isLoadingHome = true;
    _homeError = null;
    notifyListeners();

    try {
      final data = await _api.getHome();

      _isPremium = data['is_premium'] == true;
      _totalAvailable = (data['total_available'] is int)
          ? data['total_available']
          : int.tryParse(data['total_available']?.toString() ?? '') ?? 0;
      _totalFilms = (data['total_films'] is int)
          ? data['total_films']
          : int.tryParse(data['total_films']?.toString() ?? '') ?? 0;
      _totalSeries = (data['total_series'] is int)
          ? data['total_series']
          : int.tryParse(data['total_series']?.toString() ?? '') ?? 0;
      _hero = _parseContentList(data['hero']);
      _addedToday = _parseContentList(data['added_today']);
      _dailyTop = _parseContentList(data['daily_top']);
      _recommended = _parseContentList(data['recommended']);
      _popularFilms = _parseContentList(data['popular_films']);
      _popularSeries = _parseContentList(data['popular_series']);
      _recentFilms = _parseContentList(data['recent_films']);
      _recentSeries = _parseContentList(data['recent_series']);
      _byGenre =
          (data['by_genre'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _myLibrary =
          (data['my_library'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Continue watching
      if (data['continue_watching'] != null &&
          data['continue_watching'] is List) {
        _continueWatching = (data['continue_watching'] as List).map((e) {
          final map = e as Map<String, dynamic>;
          return Content(
            id: (map['content_id'] is int)
                ? map['content_id']
                : int.tryParse(map['content_id']?.toString() ?? '') ?? 0,
            title: map['title']?.toString() ?? '',
            contentType: map['content_type']?.toString() ?? 'film',
            poster: map['poster']?.toString(),
            posterUrl: map['poster_url']?.toString(),
            genres: map['genres'] is List
                ? (map['genres'] as List).map((g) => g.toString()).toList()
                : [],
            rating: (map['rating'] is num) ? map['rating'].toDouble() : 0,
            progressPercent: (map['progress_percent'] is num)
                ? map['progress_percent'].toDouble()
                : null,
            currentEpisodeId: map['episode_id']?.toString(),
          );
        }).where((c) => c.hasPoster).toList();
      }

      _isLoadingHome = false;
      notifyListeners();
    } catch (e) {
      _homeError = humanizeApiError(e);
      _isLoadingHome = false;
      notifyListeners();
    }
  }
}
