import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/content.dart';
import '../models/user.dart';
import 'video_extractor.dart';

String humanizeApiError(Object error) {
  final raw = error.toString().trim();
  final lower = raw.toLowerCase();

  if (lower.contains('database connection failed') ||
      lower.contains('server error') ||
      lower.contains('error 500')) {
    return 'Le service est temporairement indisponible. Merci de reessayer dans un instant.';
  }

  if (lower.contains('failed host lookup') ||
      lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('connection closed') ||
      lower.contains('timed out') ||
      lower.contains('timedout')) {
    return 'Connexion impossible pour le moment. Verifiez votre reseau puis reessayez.';
  }

  if (lower.contains('handshakeexception') ||
      lower.contains('tlshandshake') ||
      lower.contains('certificate_verify_failed') ||
      lower.contains('bad certificate')) {
    return 'Echec de la connexion securisee (certificat ou TLS). Verifiez la date et l heure du systeme.';
  }

  if (lower.contains('formatexception') ||
      (lower.contains('json') && lower.contains('parse'))) {
    return 'Reponse du serveur illisible. Le service est peut-etre en maintenance.';
  }

  if (RegExp(r'error 5\d\d').hasMatch(lower) ||
      lower.contains('server error') ||
      lower.contains('internal server error')) {
    return 'Le serveur signale une erreur interne. Reessayez plus tard ou contactez le support.';
  }

  if (lower.contains('app verification') || lower.contains('session expired')) {
    return 'La session a expire. Reconnectez-vous pour continuer.';
  }

  if (lower.startsWith('exception: ')) {
    return raw.substring('Exception: '.length);
  }

  return raw;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  final ValueNotifier<int> libraryRevision = ValueNotifier<int>(0);

  String? _username;
  String? _password;
  String? _integrityToken;
  DateTime? _integrityExpiry;
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _username != null && _password != null;
  bool get isPremium => _currentUser?.premiumActive ?? false;
  bool get hasIntegritySession =>
      _integrityToken != null &&
      _integrityExpiry != null &&
      _integrityExpiry!.isAfter(DateTime.now());
  DateTime? get integrityExpiresAt => _integrityExpiry;

  String get _platform => Platform.operatingSystem;

  void _notifyLibraryChanged() {
    libraryRevision.value = libraryRevision.value + 1;
  }

  Map<String, String> _baseHeaders({
    bool includeAuth = false,
    bool includeIntegrity = false,
    bool includeJsonContentType = true,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent':
          'Neo-Stream/${AppConstants.appVersion} ($_platform; Flutter)',
      'X-App-Client': AppConstants.appClient,
      'X-App-Version': AppConstants.appVersion,
      'X-App-Platform': _platform,
    };
    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    if (includeAuth && _username != null && _password != null) {
      final credentials = base64Encode(utf8.encode('$_username:$_password'));
      headers['Authorization'] = 'Basic $credentials';
    }

    if (includeIntegrity && _integrityToken != null) {
      headers['X-App-Integrity'] = _integrityToken!;
    }

    return headers;
  }

  Future<void> _saveCredentials(String username, String password) async {
    _username = username;
    _password = password;
    await _storage.write(key: 'neo_username', value: username);
    await _storage.write(key: 'neo_password', value: password);
  }

  DateTime? _parseExpiry(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
    }
    final parsedInt = int.tryParse(value?.toString() ?? '');
    if (parsedInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(parsedInt * 1000);
    }
    return DateTime.tryParse(value?.toString() ?? '');
  }

  Future<void> _saveSecurityEnvelope(dynamic security) async {
    if (security is! Map) return;
    _integrityToken = security['integrity_token']?.toString();
    _integrityExpiry = _parseExpiry(security['expires_at']);
    if (_integrityToken != null) {
      await _storage.write(key: 'neo_app_integrity', value: _integrityToken);
    }
    if (_integrityExpiry != null) {
      await _storage.write(
        key: 'neo_app_integrity_expiry',
        value: _integrityExpiry!.toIso8601String(),
      );
    }
  }

  Future<void> _loadSecurityEnvelope() async {
    _integrityToken = await _storage.read(key: 'neo_app_integrity');
    final expiryRaw = await _storage.read(key: 'neo_app_integrity_expiry');
    _integrityExpiry = DateTime.tryParse(expiryRaw ?? '');
  }

  Future<void> _clearSecurityEnvelope() async {
    _integrityToken = null;
    _integrityExpiry = null;
    await _storage.delete(key: 'neo_app_integrity');
    await _storage.delete(key: 'neo_app_integrity_expiry');
  }

  Future<bool> loadSavedCredentials() async {
    _username = await _storage.read(key: 'neo_username');
    _password = await _storage.read(key: 'neo_password');
    await _loadSecurityEnvelope();

    if (_username != null && _password != null) {
      try {
        final user = await checkAuth();
        _currentUser = user;
        return true;
      } on AuthException {
        await clearCredentials();
        return false;
      } catch (_) {
        // Keep local credentials for transient backend outages.
        return false;
      }
    }
    return false;
  }

  Future<void> clearCredentials() async {
    _username = null;
    _password = null;
    _currentUser = null;
    await _storage.deleteAll();
    await _clearSecurityEnvelope();
  }

  Future<void> _ensureIntegritySession() async {
    if (!isLoggedIn) return;

    if (!hasIntegritySession ||
        _integrityExpiry!.isBefore(
          DateTime.now().add(AppConstants.integrityRefreshMargin),
        )) {
      await refreshSecuritySession();
    }
  }

  Future<void> refreshSecuritySession() async {
    if (!isLoggedIn) return;

    final url = AppConstants.apiUri('auth/app-session');
    final response = await http
        .get(
          url,
          headers: _baseHeaders(
            includeAuth: true,
            includeJsonContentType: false,
          ),
        )
        .timeout(AppConstants.apiTimeout);

    if (response.statusCode >= 400) {
      if (response.statusCode == 401) {
        throw AuthException('App verification refresh failed');
      }
      throw ApiException('Security refresh failed', response.statusCode);
    }

    final data = json.decode(response.body);
    await _saveSecurityEnvelope((data as Map<String, dynamic>)['security']);
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    return json.decode(response.body);
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    final raw = response.body.trim();
    final lower = raw.toLowerCase();
    if (raw.startsWith('<!') ||
        lower.startsWith('<html') ||
        lower.contains('<!doctype html')) {
      return humanizeApiError(
        'Internal Server Error ${response.statusCode}',
      );
    }
    try {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic> && data['error'] != null) {
        return humanizeApiError(data['error'].toString());
      }
    } catch (_) {}
    return humanizeApiError(fallback);
  }

  Future<dynamic> _get(
    String endpoint, {
    Duration? timeout,
    bool allowRetry = true,
  }) async {
    await _ensureIntegritySession();

    final url = AppConstants.apiUri(endpoint);
    final response = await http
        .get(
          url,
          headers: _baseHeaders(
            includeAuth: true,
            includeIntegrity: true,
            includeJsonContentType: false,
          ),
        )
        .timeout(timeout ?? AppConstants.apiTimeout);

    if (response.statusCode == 401 && allowRetry && isLoggedIn) {
      await refreshSecuritySession();
      return _get(endpoint, timeout: timeout, allowRetry: false);
    }

    if (response.statusCode == 401) {
      throw AuthException(
        _extractErrorMessage(response, 'Invalid credentials'),
      );
    }
    if (response.statusCode == 403) {
      throw PremiumRequiredException(
        _extractErrorMessage(response, 'Premium required'),
      );
    }
    if (response.statusCode == 429) {
      throw RateLimitException(
        _extractErrorMessage(response, 'Too many requests'),
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        _extractErrorMessage(response, 'Error ${response.statusCode}'),
        response.statusCode,
      );
    }

    return _decodeResponse(response);
  }

  Future<dynamic> _post(
    String endpoint,
    Map<String, dynamic> body, {
    Duration? timeout,
    bool allowRetry = true,
  }) async {
    await _ensureIntegritySession();

    final url = AppConstants.apiUri(endpoint);
    final response = await http
        .post(
          url,
          headers: _baseHeaders(includeAuth: true, includeIntegrity: true),
          body: json.encode(body),
        )
        .timeout(timeout ?? AppConstants.apiTimeout);

    if (response.statusCode == 401 && allowRetry && isLoggedIn) {
      await refreshSecuritySession();
      return _post(endpoint, body, timeout: timeout, allowRetry: false);
    }

    if (response.statusCode == 401) {
      throw AuthException(
        _extractErrorMessage(response, 'Invalid credentials'),
      );
    }
    if (response.statusCode == 403) {
      throw PremiumRequiredException(
        _extractErrorMessage(response, 'Premium required'),
      );
    }
    if (response.statusCode == 429) {
      throw RateLimitException(
        _extractErrorMessage(response, 'Too many requests'),
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        _extractErrorMessage(response, 'Error ${response.statusCode}'),
        response.statusCode,
      );
    }

    return _decodeResponse(response);
  }

  Future<User> login(String username, String password) async {
    final url = AppConstants.apiUri('auth/login');
    final response = await http
        .post(
          url,
          headers: _baseHeaders(),
          body: json.encode({'username': username, 'password': password}),
        )
        .timeout(AppConstants.apiTimeout);

    if (response.statusCode == 401) {
      throw AuthException(
        _extractErrorMessage(response, 'Identifiants invalides'),
      );
    }
    if (response.statusCode == 403) {
      throw AuthException(_extractErrorMessage(response, 'Compte bloque'));
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        _extractErrorMessage(response, 'Erreur de connexion'),
        response.statusCode,
      );
    }

    final data = _decodeResponse(response) as Map<String, dynamic>;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    _currentUser = user;
    await _saveCredentials(username, password);
    await _saveSecurityEnvelope(data['security']);
    return user;
  }

  Future<User> register(String username, String email, String password) async {
    final url = AppConstants.apiUri('auth/register');
    final response = await http
        .post(
          url,
          headers: _baseHeaders(),
          body: json.encode({
            'username': username,
            'email': email,
            'password': password,
          }),
        )
        .timeout(AppConstants.apiTimeout);

    if (response.statusCode >= 400) {
      throw ApiException(
        _extractErrorMessage(response, 'Erreur d inscription'),
        response.statusCode,
      );
    }

    final data = _decodeResponse(response) as Map<String, dynamic>;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    _currentUser = user;
    await _saveCredentials(username, password);
    await _saveSecurityEnvelope(data['security']);
    return user;
  }

  Future<User> checkAuth() async {
    final url = AppConstants.apiUri('auth/check');
    final response = await http
        .get(
          url,
          headers: _baseHeaders(
            includeAuth: true,
            includeJsonContentType: false,
          ),
        )
        .timeout(AppConstants.apiTimeout);

    if (response.statusCode == 401) {
      throw AuthException(
        _extractErrorMessage(response, 'Invalid credentials'),
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        _extractErrorMessage(response, 'Auth check failed'),
        response.statusCode,
      );
    }

    final data = _decodeResponse(response) as Map<String, dynamic>;
    await _saveSecurityEnvelope(data['security']);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    _currentUser = user;
    return user;
  }

  Future<void> logout() async {
    await clearCredentials();
  }

  Future<Map<String, dynamic>> getHome() async {
    return (await _get('content/home')) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getContentList({
    String? type,
    String? genre,
    int? year,
    String sort = 'recent',
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (genre != null) params['genre'] = genre;
    if (year != null) params['year'] = year.toString();
    params['sort'] = sort;
    params['page'] = page.toString();
    params['per_page'] = perPage.toString();

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return (await _get('content/list?$query')) as Map<String, dynamic>;
  }

  Future<Content> getContentDetail(int id) async {
    final data = await _get('content/detail/$id');
    return Content.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getSeriesMergePreview(int id) async {
    return (await _get('content/series-merge/$id')) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> applySeriesMerge(
    int id, {
    bool apply = true,
  }) async {
    return (await _post('content/series-merge/$id', {'apply': apply}))
        as Map<String, dynamic>;
  }

  Future<List<Content>> searchContent(String query, {int page = 1}) async {
    final data = await _get(
      'content/search?q=${Uri.encodeComponent(query)}&page=$page',
    );
    final items = ((data as Map<String, dynamic>)['items'] as List?) ?? [];
    return items
        .map((e) => Content.fromJson(e as Map<String, dynamic>))
        .where((c) => c.hasPoster)
        .toList();
  }

  Future<List<Content>> getDailyTop({String? type, int limit = 10}) async {
    final params = <String, String>{'limit': limit.toString()};
    if (type != null) params['type'] = type;
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final data = await _get('content/daily-top?$query');
    final items = data is List
        ? data
        : ((data as Map<String, dynamic>)['items'] as List?) ?? const [];
    return items
        .map((e) => Content.fromJson(e as Map<String, dynamic>))
        .where((c) => c.hasPoster)
        .toList();
  }

  Future<List<Content>> getRecommended({int limit = 20}) async {
    final data = await _get('content/recommended?limit=$limit');
    final items = data is List
        ? data
        : ((data as Map<String, dynamic>)['items'] as List?) ?? const [];
    return items
        .map((e) => Content.fromJson(e as Map<String, dynamic>))
        .where((c) => c.hasPoster)
        .toList();
  }

  Future<List<Content>> getTrending() async {
    final data = await _get('content/trending');
    final items = data is List
        ? data
        : ((data as Map<String, dynamic>)['items'] as List?) ?? const [];
    return items
        .map((e) => Content.fromJson(e as Map<String, dynamic>))
        .where((c) => c.hasPoster)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getGenres() async {
    final data = await _get('content/genres');
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return (((data as Map<String, dynamic>)['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> extractVideoUrl(String url) async {
    // Utiliser uniquement l'extraction locale
    try {
      final localResult = await VideoExtractor.extract(url);
      
      if (localResult['success'] == true && localResult['video_url'] != null) {
        return localResult;
      }
      
      debugPrint('Local extraction failed: ${localResult['error']}');
    } catch (e) {
      debugPrint('Local extraction error: $e');
    }
    
    // Fallback vers le serveur API PHP si l'extraction locale échoue
    return (await _post('extract', {
          'url': url,
        }, timeout: AppConstants.extractTimeout))
        as Map<String, dynamic>;
  }

  Future<void> saveProgress({
    required int contentId,
    required double currentTime,
    required double totalDuration,
    String? episodeId,
  }) async {
    await _post('progress/save', {
      'content_id': contentId,
      'current_time': currentTime,
      'total_duration': totalDuration,
      'episode_id': episodeId,
    });
  }

  Future<void> saveAnimeProgress({
    required int animeId,
    required int seasonNumber,
    required int episodeNumber,
    required double currentTime,
    required double totalDuration,
  }) async {
    await _post('progress/save-anime', {
      'anime_id': animeId,
      'season_number': seasonNumber,
      'episode_number': episodeNumber,
      'current_time': currentTime,
      'total_duration': totalDuration,
    });
  }

  Future<Map<String, dynamic>?> getProgress(int contentId) async {
    final data = await _get('progress/get/$contentId');
    return (data as Map<String, dynamic>)['progress'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getAnimeProgress({
    required int animeId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    final data = await _get(
      'progress/get-anime/$animeId?season=$seasonNumber&episode=$episodeNumber',
    );
    return (data as Map<String, dynamic>)['progress'] as Map<String, dynamic>?;
  }

  Future<void> addToLibrary(int contentId) async {
    await _post('library/add', {'content_id': contentId});
    _notifyLibraryChanged();
  }

  Future<void> removeFromLibrary(int contentId) async {
    await _post('library/remove', {'content_id': contentId});
    _notifyLibraryChanged();
  }

  Future<List<Map<String, dynamic>>> getLibrary({int page = 1}) async {
    final data = await _get('library/list?page=$page');
    return (((data as Map<String, dynamic>)['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getHistory({int page = 1}) async {
    final data = await _get('progress/history?page=$page');
    return (((data as Map<String, dynamic>)['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> deleteHistory() async {
    await _post('progress/delete-history', {});
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _post('auth/change-password', {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<List<Map<String, dynamic>>> getSubAccounts() async {
    final data = await _get('subaccounts/list');
    return (((data as Map<String, dynamic>)['sub_accounts'] as List?) ??
            const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createSubAccount(
    String username,
    String password, {
    bool requirePassword = true,
  }) async {
    return (await _post('subaccounts/create', {
          'username': username,
          'password': password,
          'require_password': requirePassword ? 1 : 0,
        }))
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSubAccount(
    int subId, {
    String? username,
    String? password,
    bool? requirePassword,
  }) async {
    final body = <String, dynamic>{'sub_id': subId};
    if (username != null) body['username'] = username;
    if (password != null) body['password'] = password;
    if (requirePassword != null) {
      body['require_password'] = requirePassword ? 1 : 0;
    }
    return (await _post('subaccounts/update', body)) as Map<String, dynamic>;
  }

  Future<void> deleteSubAccount(int subId) async {
    await _post('subaccounts/delete', {'sub_id': subId});
  }

  Future<Map<String, dynamic>> validateAffiliateCode(String code) async {
    return (await _get('affiliate/validate?code=${Uri.encodeComponent(code)}'))
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> redeemLicenseKey(String licenseKey) async {
    final response =
        (await _post('license/redeem', {'license_key': licenseKey}))
            as Map<String, dynamic>;

    final userJson = response['user'];
    if (userJson is Map<String, dynamic>) {
      _currentUser = User.fromJson(userJson);
    }

    return response;
  }

  Future<List<Map<String, dynamic>>> getLicenseHistory() async {
    final data = await _get('license/history');
    return (((data as Map<String, dynamic>)['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  // ═══════════════════════════════════════════════════════
  // ANIME API
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getAnimeList({
    int page = 1,
    int limit = 20,
    String? genre,
    String sort = 'recent',
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort,
    };
    if (genre != null) params['genre'] = genre;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return (await _get('anime?action=list&$query')) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnimeDetail(int id) async {
    return (await _get('anime?action=detail&id=$id')) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnimeDetailByAnimeId(String animeId) async {
    return (await _get('anime?action=detail&anime_id=${Uri.encodeComponent(animeId)}'))
        as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> searchAnime(String query, {int limit = 20}) async {
    final data = await _get(
      'anime?action=search&q=${Uri.encodeComponent(query)}&limit=$limit',
    );
    final results = ((data as Map<String, dynamic>)['results'] as List?) ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getAnimeSeasons(int id) async {
    return (await _get('anime?action=seasons&id=$id')) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnimeStats() async {
    return (await _get('anime?action=stats')) as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════════════════
  // ANIME LIBRARY (FAVORIS)
  // ═══════════════════════════════════════════════════════

  Future<void> addAnimeToLibrary(int animeId) async {
    await _post('library/add', {'anime_id': animeId});
    _notifyLibraryChanged();
  }

  Future<void> removeAnimeFromLibrary(int animeId) async {
    await _post('library/remove', {'anime_id': animeId});
    _notifyLibraryChanged();
  }

  Future<bool> checkAnimeInLibrary(int animeId) async {
    final data = await _get('library/check?anime_id=$animeId');
    return ((data as Map<String, dynamic>)['in_library'] as bool?) ?? false;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class AuthException extends ApiException {
  AuthException(String message) : super(message, 401);
}

class PremiumRequiredException extends ApiException {
  PremiumRequiredException(String message) : super(message, 403);
}

class RateLimitException extends ApiException {
  RateLimitException(String message) : super(message, 429);
}
