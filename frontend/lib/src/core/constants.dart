class AionConfig {
  // AION está oficialmente vivo no Render!
  static const String apiBaseUrl = 'https://aion-vvx7.onrender.com';
  
  static const String transcribeUrl = '$apiBaseUrl/voice/transcribe';
  // Ajustado: O endpoint correto no FastAPI é apenas /dreams/
  static const String analyzeUrl = '$apiBaseUrl/dreams/';
  static const String dreamUrl     = '$apiBaseUrl/dreams/';
  static const String historyUrl   = '$apiBaseUrl/dreams/history';
  static const String episodesUrl  = '$apiBaseUrl/episodes/';
  static const String interviewUrl = '$apiBaseUrl/dreams/interview';
  static const String searchUrl    = '$apiBaseUrl/dreams/search';
  static const String filterUrl    = '$apiBaseUrl/dreams/filter';
  static const String narrativeUrl = '$apiBaseUrl/dreams/narrative';
}
