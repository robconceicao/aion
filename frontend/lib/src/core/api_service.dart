import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AionConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static Dio get client {
    // Adiciona o interceptor se não existir
    if (_dio.interceptors.isEmpty) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          return handler.next(options);
        },
      ));
    }
    return _dio;
  }
}
