/// Configuração do Supabase via --dart-define-from-file.
///
/// Crie um arquivo dart_define.json (NÃO versionado) na raiz do projeto
/// copiando dart_define.example.json e preenchendo com os valores reais.
///
/// Para rodar:
///   flutter run --dart-define-from-file=dart_define.json
///
/// Para build:
///   flutter build apk --dart-define-from-file=dart_define.json
///   flutter build web --dart-define-from-file=dart_define.json
class SupabaseConfig {
  static const String url =
      String.fromEnvironment('SUPABASE_URL');

  static const String anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Valida em tempo de execução que as variáveis foram injetadas.
  /// Lança StateError com mensagem clara antes de tentar conectar ao Supabase,
  /// alinhado à regra "degradar com mensagem clara" do AGENTS.md.
  static void assertConfigured() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        '[Aion] Configuração ausente: SUPABASE_URL e SUPABASE_ANON_KEY '
        'precisam ser injetadas via --dart-define-from-file=dart_define.json.\n'
        'Copie dart_define.example.json para dart_define.json e preencha '
        'com os valores reais do projeto Supabase.',
      );
    }
  }
}
