class AionConfig {
  // O Oráculo está oficialmente vivo no Render!
  static const String apiBaseUrl = 'https://aion-vvx7.onrender.com';
  
  static const String transcribeUrl = '$apiBaseUrl/voice/transcribe';
  // Ajustado: O endpoint correto no FastAPI é apenas /dreams/
  static const String analyzeUrl = '$apiBaseUrl/dreams/';
}
