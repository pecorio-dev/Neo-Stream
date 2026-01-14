import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/zenix_api_service.dart';
import '../services/dio_client.dart';

/// Provider pour l'instance Dio
final dioProvider = Provider<Dio>((ref) {
  return DioClient.instance;
});

/// Provider pour le service API Zenix
final zenixApiProvider = Provider<ZenixApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ZenixApiService(dio);
});
