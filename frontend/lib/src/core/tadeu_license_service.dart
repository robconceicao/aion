import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LicensedFeature {
  final String key;
  final int? limitValue;
  final String? limitUnit;

  const LicensedFeature({required this.key, this.limitValue, this.limitUnit});

  factory LicensedFeature.fromJson(Map<String, dynamic> json) => LicensedFeature(
        key: json['key'] as String,
        limitValue: json['limitValue'] as int?,
        limitUnit: json['limitUnit'] as String?,
      );
}

class TadeuLicense {
  final String plan;
  final List<LicensedFeature> features;
  final DateTime? expiresAt;
  final DateTime checkedAt;
  final bool offline;

  const TadeuLicense({
    required this.plan,
    required this.features,
    required this.expiresAt,
    required this.checkedAt,
    this.offline = false,
  });

  bool hasFeature(String key) =>
      plan == 'legacy' || features.any((feature) => feature.key == key);

  LicensedFeature? feature(String key) {
    for (final feature in features) {
      if (feature.key == key) return feature;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'plan': plan,
        'features': features
            .map((f) => {
                  'key': f.key,
                  'limitValue': f.limitValue,
                  'limitUnit': f.limitUnit,
                })
            .toList(),
        'expiresAt': expiresAt?.toIso8601String(),
        'checkedAt': checkedAt.toIso8601String(),
      };

  factory TadeuLicense.fromJson(Map<String, dynamic> json, {bool offline = false}) =>
      TadeuLicense(
        plan: json['plan'] as String,
        features: ((json['features'] as List?) ?? const [])
            .map((item) => LicensedFeature.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
        checkedAt: DateTime.parse(json['checkedAt'] as String),
        offline: offline,
      );
}

class UsageResult {
  final int used;
  final int? limit;
  final int? remaining;
  final String? unit;
  final bool duplicated;

  const UsageResult({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.unit,
    required this.duplicated,
  });
}

class UsageLimitException implements Exception {
  final String feature;
  final int used;
  final int? limit;

  const UsageLimitException(this.feature, this.used, this.limit);

  @override
  String toString() => 'Limite mensal atingido para $feature ($used/${limit ?? '-'})';
}

class TadeuLicenseService {
  static const _storage = FlutterSecureStorage();
  static const _refreshTokenKey = 'aion_tadeu_refresh_token';
  static const _cacheKey = 'aion_tadeu_license_cache';
  static const _maxOffline = Duration(hours: 24);
  static const _appSlug = 'aion';

  static const tadeuAppsUrl = String.fromEnvironment(
    'TADEU_APPS_URL',
    defaultValue: 'https://tadeu-apps-core-test2.vercel.app',
  );
  static const tadeuSupabaseUrl = String.fromEnvironment('TADEU_APPS_SUPABASE_URL');
  static const tadeuSupabaseAnonKey = String.fromEnvironment('TADEU_APPS_SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      tadeuAppsUrl.isNotEmpty && tadeuSupabaseUrl.isNotEmpty && tadeuSupabaseAnonKey.isNotEmpty;

  static SupabaseClient? _client;
  static SupabaseClient get client {
    if (!isConfigured) throw StateError('Licenciamento Tadeu Apps não configurado.');
    return _client ??= SupabaseClient(tadeuSupabaseUrl, tadeuSupabaseAnonKey);
  }

  static Future<void> restoreSession() async {
    if (!isConfigured) return;
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return;
    try {
      await client.auth.setSession(refreshToken);
    } catch (_) {
      await _storage.delete(key: _refreshTokenKey);
    }
  }

  static Future<void> signIn(String email, String password) async {
    final response = await client.auth.signInWithPassword(email: email.trim(), password: password);
    final refreshToken = response.session?.refreshToken;
    if (refreshToken == null) throw StateError('Sessão Tadeu Apps não retornada.');
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<void> signOut() async {
    if (isConfigured) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _cacheKey);
  }

  static Future<String> _accessToken() async {
    if (client.auth.currentSession == null) await restoreSession();
    var session = client.auth.currentSession;
    if (session == null) throw StateError('TADEU_AUTH_REQUIRED');

    final expiresAt = session.expiresAt;
    if (expiresAt != null &&
        DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
            .isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      final refreshed = await client.auth.refreshSession();
      session = refreshed.session;
      final refreshToken = session?.refreshToken;
      if (refreshToken != null) {
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
      }
    }
    final token = session?.accessToken;
    if (token == null || token.isEmpty) throw StateError('TADEU_AUTH_REQUIRED');
    return token;
  }

  static Future<TadeuLicense?> _readCache() async {
    final raw = await _storage.read(key: _cacheKey);
    if (raw == null) return null;
    try {
      final parsed = TadeuLicense.fromJson(jsonDecode(raw) as Map<String, dynamic>, offline: true);
      if (DateTime.now().difference(parsed.checkedAt) > _maxOffline) return null;
      if (parsed.expiresAt != null && parsed.expiresAt!.isBefore(DateTime.now())) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static Future<TadeuLicense> fetchLicense() async {
    if (!isConfigured) throw StateError('Licenciamento Tadeu Apps não configurado.');
    final token = await _accessToken();

    try {
      final response = await Dio().get<Map<String, dynamic>>(
        '$tadeuAppsUrl/api/apps/$_appSlug/license',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data ?? const <String, dynamic>{};
      if (data['license'] != 'active') throw StateError('TADEU_LICENSE_DENIED');

      final license = TadeuLicense(
        plan: data['plan'] as String,
        features: ((data['features'] as List?) ?? const [])
            .map((item) => LicensedFeature.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        expiresAt: data['expiresAt'] == null ? null : DateTime.parse(data['expiresAt'] as String),
        checkedAt: DateTime.now(),
      );
      await _storage.write(key: _cacheKey, value: jsonEncode(license.toJson()));
      return license;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
        await _storage.delete(key: _cacheKey);
        throw StateError('TADEU_LICENSE_DENIED');
      }
      final cached = await _readCache();
      if (cached != null) return cached;
      rethrow;
    }
  }

  static Future<UsageResult> consumeUsage({
    required String feature,
    int amount = 1,
    String? idempotencyKey,
  }) async {
    final token = await _accessToken();
    try {
      final response = await Dio().post<Map<String, dynamic>>(
        '$tadeuAppsUrl/api/apps/$_appSlug/usage',
        data: {
          'feature': feature,
          'amount': amount,
          if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status >= 200 && status < 500,
        ),
      );
      final data = response.data ?? const <String, dynamic>{};
      final used = (data['used'] as num?)?.toInt() ?? 0;
      final limit = (data['limit'] as num?)?.toInt();
      if (response.statusCode == 429 || data['allowed'] == false) {
        throw UsageLimitException(feature, used, limit);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError('TADEU_LICENSE_DENIED');
      }
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw StateError('TADEU_USAGE_FAILED');
      }
      return UsageResult(
        used: used,
        limit: limit,
        remaining: (data['remaining'] as num?)?.toInt(),
        unit: data['unit'] as String?,
        duplicated: data['duplicated'] == true,
      );
    } on DioException catch (_) {
      throw StateError('TADEU_USAGE_FAILED');
    }
  }
}
