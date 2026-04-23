class AionConfig {
  // Se estiver usando o APK no celular, NÃO use 'localhost'.
  // Use o endereço IP do seu computador na rede Wi-Fi (Ex: 'http://192.168.1.5:8000')
  // No emulador Android, use 'http://10.0.2.2:8000'
  static const String apiBaseUrl = 'http://localhost:8000';
  
  static const String transcribeUrl = '$apiBaseUrl/voice/transcribe';
  static const String analyzeUrl = '$apiBaseUrl/dreams/analyze';
}
