import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
// import doh_service removed

/// Client Dio professionnel avec interceptors et gestion d'erreurs
class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  /// Crée une instance Dio avec la configuration professionnelle
  static Dio _createDio() {
    // Créer une instance Dio standard
    final dio = Dio();

    // Configuration de base
    dio.options.baseUrl = AppConstants.baseUrl;
    dio.options.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Version': '1.0.0',
    });

    // Ajoute les interceptors
    _addInterceptors(dio);

    return dio;
  }

  /// Ajoute les interceptors pour le logging et la gestion d'erreurs
  static void _addInterceptors(Dio dio) {
    // Interceptor DoH pour cpasmieux.is (priorité haute) - appliqué à TOUTES les requêtes
    dio.interceptors.add(_createDoHInterceptor());

    // Interceptor de logging (seulement en debug)
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          error: true,
          logPrint: (obj) => print(obj),
        ),
      );
    }

    // Interceptor de gestion d'erreurs
    dio.interceptors.add(_createErrorInterceptor());

    // Interceptor de retry automatique
    dio.interceptors.add(_createRetryInterceptor(dio));
  }

  static InterceptorsWrapper _createErrorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) {
        String errorMessage = _getErrorMessage(error);

        if (kDebugMode) {
          print('[DIO ERROR] $errorMessage');
          print('[DIO ERROR] Status Code: ${error.response?.statusCode}');
          print('[DIO ERROR] Data: ${error.response?.data}');
        }

        // Create a custom error with user-friendly message
        final customError = DioException(
          requestOptions: error.requestOptions,
          response: error.response,
          type: error.type,
          error: errorMessage,
          message: errorMessage,
        );

        handler.next(customError);
      },
    );
  }

  static InterceptorsWrapper _createRetryInterceptor(Dio dio) {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        if (_shouldRetry(error)) {
          try {
            // Retry the request
            final response = await dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } catch (e) {
            // If retry fails, continue with original error
          }
        }
        handler.next(error);
      },
    );
  }

  static bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        (error.response?.statusCode != null &&
            error.response!.statusCode! >= 500);
  }

  static InterceptorsWrapper _createDoHInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final originalUrl = options.uri.toString();
        final host = options.uri.host;

        // Liste des domaines qui peuvent être problématiques avec le DNS FAI
        final problematicDomains = [
          'cpasmieux.is',
          'uqload.net',
          'uqload.cx',
          'uqload.co',
          'streamtape.com',
          'doodstream.com',
          'mixdrop.co',
          'multiup.us',
          'multiup.org',
          'node.zenix.sg', // Ajout du domaine principal
        ];

        // Vérifier si le domaine est dans la liste des problématiques
        final isProblematicDomain = problematicDomains.any(
            (domain) => host.contains(domain) || originalUrl.contains(domain));

        if (isProblematicDomain) {
          try {
            // Essayer de résoudre l'IP avec DoH
            final ip = null; // DoHService disabled
            if (ip != null) {
              final newUri = options.uri.replace(host: ip);

              // Créer une nouvelle RequestOptions avec la nouvelle URI
              final newOptions = options.copyWith(
                path: newUri.toString(),
              );

              // Ajouter le header Host pour que le serveur comprenne
              newOptions.headers['Host'] = host;

              print('DoH: Redirected $host request to $ip');
              return handler.next(newOptions);
            } else {
              print('DoH: Could not resolve IP for $host, using original URL');
            }
          } catch (e) {
            print(
                'DoH: DNS resolution failed for $host: $e, using original URL');
          }
        }

        return handler.next(options);
      },
    );
  }

  static String _getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Délai de connexion dépassé. Vérifiez votre connexion internet.';

      case DioExceptionType.badResponse:
        return _getHttpErrorMessage(error.response?.statusCode);

      case DioExceptionType.cancel:
        return 'Requête annulée';

      case DioExceptionType.connectionError:
        return 'Erreur de connexion. Vérifiez votre connexion internet.';

      case DioExceptionType.badCertificate:
        return 'Erreur de certificat SSL';

      case DioExceptionType.unknown:
      default:
        return 'Une erreur inattendue s\'est produite';
    }
  }

  static String _getHttpErrorMessage(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Requête invalide';
      case 401:
        return 'Non autorisé';
      case 403:
        return 'Accès interdit';
      case 404:
        return 'Ressource non trouvée';
      case 429:
        return 'Trop de requêtes. Veuillez réessayer plus tard.';
      case 500:
        return 'Erreur serveur interne';
      case 502:
        return 'Passerelle incorrecte';
      case 503:
        return 'Service indisponible';
      case 504:
        return 'Délai de passerelle dépassé';
      default:
        return 'Erreur HTTP $statusCode';
    }
  }

  static void clearInstance() {
    _instance?.close();
    _instance = null;
  }
}


