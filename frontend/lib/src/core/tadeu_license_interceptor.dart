import 'package:dio/dio.dart';
import 'tadeu_license_service.dart';

class TadeuLicenseInterceptor extends Interceptor {
  static bool _isAttached = false;

  static void attachTo(Dio dio) {
    if (_isAttached || !TadeuLicenseService.isConfigured) return;
    dio.interceptors.insert(0, TadeuLicenseInterceptor());
    _isAttached = true;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final required = _requiredFeature(options);
    if (required == null) {
      return handler.next(options);
    }

    try {
      final license = await TadeuLicenseService.fetchLicense();
      if (!license.hasFeature(required)) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 403,
              data: {
                'detail': {
                  'error': 'tadeu_feature_not_in_plan',
                  'feature': required,
                  'plan': license.plan,
                },
              },
            ),
            message: 'Recurso não incluído no plano ${license.plan}.',
          ),
          true,
        );
      }

      return handler.next(options);
    } catch (error) {
      if (error is DioException) return handler.reject(error, true);
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 403,
            data: const {
              'detail': {'error': 'tadeu_license_required'},
            },
          ),
          message: 'Licença Tadeu Apps não pôde ser validada.',
        ),
        true,
      );
    }
  }

  String? _requiredFeature(RequestOptions options) {
    final path = options.uri.path.toLowerCase();
    final method = options.method.toUpperCase();

    if (method == 'POST' && path.contains('/voice/transcribe')) {
      return 'voice_transcriptions_monthly';
    }
    if (method == 'POST' && path.contains('/interpretacoes/') && path.endsWith('/narracao')) {
      return 'premium_narrations_monthly';
    }
    if (method == 'POST' && path.contains('/interpretacoes/') && path.endsWith('/audio')) {
      return 'edge_tts_audio';
    }
    if (method == 'POST' && (path.contains('/interview') || path.contains('/dreams') || path.contains('/synth'))) {
      return 'ai_analyses_monthly';
    }
    return null;
  }
}
