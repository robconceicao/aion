import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AionConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 60),
    // Interpretação dual + cold start do Render: tolerância alta
    receiveTimeout: const Duration(seconds: 180),
    sendTimeout: const Duration(seconds: 90),
  ));

  static Future<Session?>? _pendingRefresh;

  /// Access token ainda serve para autorizar um request (margem de 30s).
  static bool _isAccessTokenUsable(Session? session) {
    if (session == null) return false;
    final token = session.accessToken;
    if (token.isEmpty) return false;
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;
    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
        .isAfter(DateTime.now().add(const Duration(seconds: 30)));
  }

  static Future<Session?> _doRefresh() async {
    try {
      final result = await Supabase.instance.client.auth.refreshSession();
      return result.session;
    } catch (e) {
      debugPrint('[ApiService] refreshSession falhou: $e');
      return null;
    } finally {
      _pendingRefresh = null;
    }
  }

  /// Atualiza proativamente a sessão Supabase antes de operações longas
  /// (entrevista / análise de sonho / histórico), reduzindo risco de token
  /// expirar no meio.
  ///
  /// Se o refresh falhar por rede/timeout, NÃO trata como sessão expirada
  /// enquanto o access token atual ainda for utilizável.
  static Future<Session?> ensureFreshSession() async {
    try {
      final current = Supabase.instance.client.auth.currentSession;
      if (current == null) {
        _pendingRefresh ??= _doRefresh();
        final refreshed = await _pendingRefresh;
        return _isAccessTokenUsable(refreshed) ? refreshed : null;
      }

      // Refresh proativo se expira em menos de 5 minutos (ou expiresAt ausente)
      final expiresAt = current.expiresAt;
      final needsRefresh = expiresAt == null ||
          DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
              .isBefore(DateTime.now().add(const Duration(minutes: 5)));
      if (!needsRefresh) {
        return _isAccessTokenUsable(current) ? current : null;
      }

      _pendingRefresh ??= _doRefresh();
      final refreshed = await _pendingRefresh;
      if (_isAccessTokenUsable(refreshed)) return refreshed;

      // Refresh falhou: preferir token atual ainda válido a "sessão expirou"
      if (_isAccessTokenUsable(current)) return current;
      final latest = Supabase.instance.client.auth.currentSession;
      if (_isAccessTokenUsable(latest)) return latest;
      return null;
    } catch (e) {
      debugPrint('[ApiService] ensureFreshSession erro: $e');
      final fallback = Supabase.instance.client.auth.currentSession;
      return _isAccessTokenUsable(fallback) ? fallback : null;
    }
  }

  /// Header Authorization a partir de uma sessão já obtida (cinto e suspensório
  /// junto do interceptor). Preferir passar [session] quando a tela já chamou
  /// [ensureFreshSession].
  static Map<String, String> authHeaders([Session? session]) {
    final token = (session?.accessToken.isNotEmpty == true)
        ? session!.accessToken
        : Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  /// Options com Bearer explícito + timeouts opcionais.
  static Options authOptions({
    Session? session,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, dynamic>? extraHeaders,
  }) {
    return Options(
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      headers: {
        ...authHeaders(session),
        ...?extraHeaders,
      },
    );
  }

  static DioException _missingTokenException(RequestOptions options) {
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      error: 'missing_token',
      message: 'Sessão ausente: request sem Bearer',
      response: Response(
        requestOptions: options,
        statusCode: 401,
        data: {'detail': 'missing_token'},
      ),
    );
  }

  /// Endpoints públicos no backend (sem Depends(get_current_user)).
  /// Fail-closed não se aplica — a request pode ir sem Bearer.
  static bool _isPublicRequest(RequestOptions options) {
    final method = options.method.toUpperCase();
    final path = options.path.isNotEmpty
        ? options.path
        : options.uri.path;
    if (method == 'GET' &&
        (path == '/episodes/' ||
            path == '/episodes' ||
            path.startsWith('/episodes/'))) {
      return true;
    }
    if (method == 'GET' && (path == '/' || path.isEmpty)) {
      return true;
    }
    return false;
  }

  static Dio get client {
    // Adiciona interceptors se não existirem
    if (_dio.interceptors.isEmpty) {
      // Interceptor de autenticação + retry automático
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Se a tela já setou Authorization, não sobrescreve (Bearer explícito).
          final existing = options.headers['Authorization']?.toString() ?? '';
          if (existing.startsWith('Bearer ') && existing.length > 8) {
            return handler.next(options);
          }

          // Sempre tenta ter um token utilizável antes de sair.
          var session = await ensureFreshSession();
          if (session == null) {
            // Última chance: sessão crua do SDK (mesmo se perto de expirar)
            session = Supabase.instance.client.auth.currentSession;
            if (session != null && session.accessToken.isEmpty) {
              session = null;
            }
          }

          if (session != null && session.accessToken.isNotEmpty) {
            options.headers['Authorization'] =
                'Bearer ${session.accessToken}';
            return handler.next(options);
          }

          // Rotas públicas (ex.: canal) seguem sem Bearer.
          if (_isPublicRequest(options)) {
            return handler.next(options);
          }

          // Fail-closed: NÃO enviar request autenticado sem Bearer
          // (evita 401 missing_token no backend; UI trata o mesmo shape).
          debugPrint(
            '[ApiService] Request bloqueado SEM Bearer: ${options.method} ${options.uri}',
          );
          return handler.reject(_missingTokenException(options), true);
        },
        onError: (DioException err, handler) async {
          final statusCode = err.response?.statusCode;
          final isAuthError = statusCode == 401 || statusCode == 403;
          final isAuthRetry = err.requestOptions.extra['_isAuthRetry'] == true;
          final isLocalMissing = err.error == 'missing_token';

          // On 401/403 refresh the Supabase token silently and retry once
          // (não tenta retry em missing_token local sem sessão — inútil).
          if (isAuthError && !isAuthRetry && !isLocalMissing) {
            try {
              _pendingRefresh ??= _doRefresh();
              final newSession = await _pendingRefresh;
              if (newSession != null && newSession.accessToken.isNotEmpty) {
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

  /// Solicita a narração premium (ElevenLabs) de uma interpretação.
  ///
  /// POST /interpretacoes/{dreamId}/narracao
  /// Retorna { signedUrl, duracaoSegundos, cached }.
  ///
  /// Lança [NarracaoException] com mensagem já legível ao usuário — o chamador
  /// exibe `e.message` direto, sem precisar interpretar código de API.
  static Future<NarracaoResult> requestNarracao(String dreamId) async {
    try {
      final response = await client.post(AionConfig.narracaoUrl(dreamId));
      final data = response.data as Map<String, dynamic>;
      final signedUrl = data['signed_url'] as String?;
      if (signedUrl == null || signedUrl.isEmpty) {
        throw const NarracaoException(
          'A narração não pôde ser carregada. Tente novamente.',
        );
      }
      return NarracaoResult(
        signedUrl: signedUrl,
        duracaoSegundos: (data['duracao_segundos'] as num?)?.toDouble(),
        cached: data['cached'] == true,
      );
    } on DioException catch (e) {
      throw NarracaoException(_narracaoMessage(e));
    }
  }

  /// Traduz a falha em mensagem para o usuário final.
  /// O backend devolve `detail.error` tipado; nunca expor esse código na UI.
  static String _narracaoMessage(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final code = (data is Map && data['detail'] is Map)
        ? (data['detail']['error']?.toString() ?? '')
        : '';

    if (status == 429 || code == 'daily_limit_exceeded') {
      return 'Você atingiu o limite de narrações por hoje. '
          'O limite se renova amanhã — o texto continua disponível para leitura.';
    }
    if (status == 403) {
      return 'Esta interpretação não pertence à sua conta.';
    }
    if (status == 404) {
      return code == 'no_narrative'
          ? 'Este sonho não tem narrativa disponível para ouvir.'
          : 'Interpretação não encontrada.';
    }
    if (status == 401) {
      return 'Sua sessão expirou. Feche e reabra o app para ouvir a narração.';
    }
    switch (code) {
      case 'elevenlabs_rate_limited':
        return 'O serviço de narração está sobrecarregado agora. '
            'Tente de novo em alguns instantes.';
      case 'elevenlabs_timeout':
        return 'A narração demorou demais para ficar pronta. Tente novamente.';
      case 'elevenlabs_invalid_request':
        return 'Não foi possível narrar este texto.';
      case 'elevenlabs_auth_failed':
      case 'elevenlabs_failed':
        return 'A narração está indisponível no momento. '
            'O texto continua disponível para leitura.';
      case 'storage_failed':
      case 'signed_url_failed':
        return 'A narração foi criada mas não pôde ser carregada. Tente novamente.';
    }
    if (e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'O servidor demorou a responder. Tente novamente.';
    }
    return 'Não foi possível carregar a narração. '
        'Verifique sua internet e tente novamente.';
  }
}

/// Resultado de uma solicitação de narração.
class NarracaoResult {
  final String signedUrl;
  final double? duracaoSegundos;
  final bool cached;

  const NarracaoResult({
    required this.signedUrl,
    this.duracaoSegundos,
    required this.cached,
  });
}

/// Erro de narração com mensagem pronta para exibição ao usuário.
class NarracaoException implements Exception {
  final String message;
  const NarracaoException(this.message);

  @override
  String toString() => message;
}
