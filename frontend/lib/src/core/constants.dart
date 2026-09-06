class AionConfig {
  // AION está oficialmente vivo no Render!
  static const String apiBaseUrl = 'https://aion-vvx7.onrender.com';
  
  static const String transcribeUrl = '$apiBaseUrl/voice/transcribe';
  // Ajustado: O endpoint correto no FastAPI é apenas /dreams/
  static const String analyzeUrl = '$apiBaseUrl/dreams/';
  static const String historyUrl   = '$apiBaseUrl/dreams/history';
  static const String episodesUrl  = '$apiBaseUrl/episodes/';
  static const String interviewUrl = '$apiBaseUrl/dreams/interview';
  static const String searchUrl    = '$apiBaseUrl/dreams/search';

  /// Filtro por emoção/fase. GET com query params — não POST.
  static const String filterUrl    = '$apiBaseUrl/dreams/filter';

  /// Exclusão de um sonho específico (LGPD art. 18, VI — direito de eliminação).
  static String deleteDreamUrl(String dreamId) => '$apiBaseUrl/dreams/$dreamId';

  /// Exclusão da conta e de todos os dados do usuário (LGPD art. 18, VI).
  static const String deleteAccountUrl = '$apiBaseUrl/auth/account';

  /// Endpoint de áudio on-demand com cache (Fase 2 — SPEC §6.2).
  /// POST para este URL gera ou recupera o áudio da interpretação narrativa.
  static String audioUrl(String dreamId) => '$apiBaseUrl/interpretacoes/$dreamId/audio';

  /// Narração premium (ElevenLabs), sob demanda e com cache.
  /// Coexiste com audioUrl (Edge TTS) — não o substitui.
  /// Retorna { signed_url, duracao_segundos, cached }.
  static String narracaoUrl(String dreamId) =>
      '$apiBaseUrl/interpretacoes/$dreamId/narracao';
}
