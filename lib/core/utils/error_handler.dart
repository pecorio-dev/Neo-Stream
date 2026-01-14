import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';

/// Gestionnaire d'erreurs centralisé pour l'application
class ErrorHandler {
  
  /// Traite une erreur et retourne un message utilisateur approprié
  static String handleError(dynamic error) {
    if (kDebugMode) {
      print('ErrorHandler: $error');
    }
    
    if (error is DioException) {
      return _handleDioError(error);
    }
    
    if (error is FormatException) {
      return 'Erreur de format des données';
    }
    
    if (error is TypeError) {
      return 'Erreur de type de données';
    }
    
    if (error is Exception) {
      return _handleGenericException(error);
    }
    
    return AppConfig.unknownErrorMessage;
  }
  
  /// Traite les erreurs Dio (réseau/API)
  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Délai de connexion dépassé. Vérifiez votre connexion internet.';
        
      case DioExceptionType.badResponse:
        return _handleHttpError(error.response?.statusCode);
        
      case DioExceptionType.cancel:
        return 'Requête annulée';
        
      case DioExceptionType.connectionError:
        return 'Erreur de connexion. Vérifiez votre connexion internet.';
        
      case DioExceptionType.badCertificate:
        return 'Erreur de certificat SSL';
        
      case DioExceptionType.unknown:
      default:
        return AppConfig.networkErrorMessage;
    }
  }
  
  /// Traite les erreurs HTTP selon le code de statut
  static String _handleHttpError(int? statusCode) {
    if (statusCode == null) {
      return AppConfig.serverErrorMessage;
    }
    
    switch (statusCode) {
      case AppConstants.statusBadRequest:
        return 'Requête invalide';
        
      case AppConstants.statusUnauthorized:
        return 'Accès non autorisé';
        
      case AppConstants.statusForbidden:
        return 'Accès interdit';
        
      case AppConstants.statusNotFound:
        return 'Contenu non trouvé';
        
      case AppConstants.statusInternalServerError:
        return 'Erreur interne du serveur';
        
      case AppConstants.statusBadGateway:
        return 'Erreur de passerelle';
        
      case AppConstants.statusServiceUnavailable:
        return 'Service temporairement indisponible';
        
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return 'Erreur client (Code: $statusCode)';
        } else if (statusCode >= 500) {
          return 'Erreur serveur (Code: $statusCode)';
        } else {
          return 'Erreur HTTP (Code: $statusCode)';
        }
    }
  }
  
  /// Traite les exceptions génériques
  static String _handleGenericException(Exception exception) {
    final message = exception.toString();
    
    if (message.contains('SocketException')) {
      return 'Pas de connexion internet';
    }
    
    if (message.contains('HandshakeException')) {
      return 'Erreur de sécurité SSL';
    }
    
    if (message.contains('FormatException')) {
      return 'Format de données invalide';
    }
    
    if (message.contains('TimeoutException')) {
      return 'Délai d\'attente dépassé';
    }
    
    // Extraire le message d'erreur personnalisé si disponible
    final customMessageMatch = RegExp(r'Exception: (.+)').firstMatch(message);
    if (customMessageMatch != null) {
      return customMessageMatch.group(1) ?? AppConfig.unknownErrorMessage;
    }
    
    return AppConfig.unknownErrorMessage;
  }
  
  /// Détermine si une erreur est récupérable (peut être retentée)
  static bool isRetryableError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
          
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          // Retry sur les erreurs serveur (5xx) mais pas sur les erreurs client (4xx)
          return statusCode != null && statusCode >= 500;
          
        default:
          return false;
      }
    }
    
    final message = error.toString();
    return message.contains('SocketException') || 
           message.contains('TimeoutException');
  }
  
  /// Obtient le code d'erreur pour le logging/analytics
  static int getErrorCode(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return AppConstants.errorCodeTimeout;
          
        case DioExceptionType.badResponse:
          return error.response?.statusCode ?? AppConstants.errorCodeServer;
          
        case DioExceptionType.connectionError:
          return AppConstants.errorCodeNetwork;
          
        case DioExceptionType.cancel:
          return AppConstants.errorCodeUnknown;
          
        default:
          return AppConstants.errorCodeNetwork;
      }
    }
    
    return AppConstants.errorCodeUnknown;
  }
  
  /// Log une erreur pour le debugging
  static void logError(dynamic error, {StackTrace? stackTrace, String? context}) {
    if (!kDebugMode && !AppConfig.enableApiLogging) return;
    
    final errorCode = getErrorCode(error);
    final errorMessage = handleError(error);
    
    print('=== ERROR LOG ===');
    print('Context: ${context ?? 'Unknown'}');
    print('Code: $errorCode');
    print('Message: $errorMessage');
    print('Original Error: $error');
    
    if (stackTrace != null) {
      print('Stack Trace:');
      print(stackTrace.toString());
    }
    
    print('=================');
  }
  
  /// Crée une exception personnalisée avec message
  static Exception createException(String message) {
    return Exception(message);
  }
  
  /// Vérifie si une erreur indique un problème de réseau
  static bool isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
             error.type == DioExceptionType.connectionTimeout ||
             error.type == DioExceptionType.sendTimeout ||
             error.type == DioExceptionType.receiveTimeout;
    }
    
    final message = error.toString();
    return message.contains('SocketException') ||
           message.contains('NetworkException') ||
           message.contains('No internet');
  }
  
  /// Vérifie si une erreur indique un problème serveur
  static bool isServerError(dynamic error) {
    if (error is DioException && error.response != null) {
      final statusCode = error.response!.statusCode!;
      return statusCode >= 500;
    }
    
    return false;
  }
  
  /// Vérifie si une erreur indique un problème client
  static bool isClientError(dynamic error) {
    if (error is DioException && error.response != null) {
      final statusCode = error.response!.statusCode!;
      return statusCode >= 400 && statusCode < 500;
    }
    
    return false;
  }
}