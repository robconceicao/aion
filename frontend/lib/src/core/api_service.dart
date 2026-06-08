import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AionConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 60),
  ));

  static Dio get client {
    // Adiciona interceptors se não existirem
    if (_dio.interceptors.isEmpty) {
      // Interceptor de autenticação + retry automático
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Injeta o Bearer token do Supabase em todas as requisições
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          return handler.next(options);
        },
        onError: (DioException err, handler) async {
          final statusCode = err.response?.statusCode;
          final isAuthError = statusCode == 401 || statusCode == 403;
          final isAuthRetry = err.requestOptions.extra['_isAuthRetry'] == true;

          // On 401/403 refresh the Supabase token silently and retry once
          if (isAuthError && !isAuthRetry) {
            try {
              final result =
                  await Supabase.instance.client.auth.refreshSession();
              final newSession = result.session;
              if (newSession != null) {
                final opts = err.requestOptions;
                opts.headers['Authorization'] =
                    'Bearer ${newSession.accessToken}';
                opts.extra['_isAuthRetry'] = true;
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              }
            } catch (_) {
              // Refresh failed — propagate so callers can redirect to login
            }
          }

          // Retry automático para timeout e erros de servidor (cold start do Render free tier)
          final shouldRetry =
              err.type == DioExceptionType.receiveTimeout ||
              err.type == DioExceptionType.connectionTimeout ||
              err.type == DioExceptionType.sendTimeout ||
              (err.response?.statusCode != null &&
               err.response!.statusCode! >= 500);

          final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

          if (shouldRetry && retryCount < 2) {
            // Backoff progressivo: 3s na 1ª tentativa, 6s na 2ª
            await Future.delayed(Duration(seconds: 3 * (retryCount + 1)));
            final opts = err.requestOptions;
            opts.extra['retryCount'] = retryCount + 1;
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(err);
            }
          }
          return handler.next(err);
        },
      ));
    }
    return _dio;
  }
}
