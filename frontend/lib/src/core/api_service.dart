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

  static Future<Session?>? _pendingRefresh;

  static Future<Session?> _doRefresh() async {
    try {
      final result = await Supabase.instance.client.auth.refreshSession();
      return result.session;
    } catch (_) {
      return null;
    } finally {
      _pendingRefresh = null;
    }
  }

  static Dio get client {
    // Adiciona interceptors se não existirem
    if (_dio.interceptors.isEmpty) {
      // Interceptor de autenticação + retry automático
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          var session = Supabase.instance.client.auth.currentSession;
          if (session == null) {
            _pendingRefresh ??= _doRefresh();
            session = await _pendingRefresh;
          }
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

  /// Requisita o áudio on-demand de uma interpretação (SPEC §6.2).
  ///
  /// POST /interpretacoes/{dreamId}/audio
  /// Retorna a signed URL do áudio MP3 gerado ou recuperado do cache.
  ///
  /// Lança [DioException] em caso de erro de rede ou resposta não-2xx.
  /// O chamador deve tratar e exibir estado de erro sem afetar o texto.
  static Future<String> requestAudio(String dreamId) async {
    final response = await client.post(AionConfig.audioUrl(dreamId));
    final signedUrl = response.data['signed_url'] as String?;
    if (signedUrl == null || signedUrl.isEmpty) {
      throw Exception('Resposta de áudio inválida: signed_url ausente');
    }
    return signedUrl;
  }
}
