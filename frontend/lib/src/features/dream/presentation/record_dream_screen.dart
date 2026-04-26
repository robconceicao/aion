import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:dio/dio.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import 'widgets/mandala_spinner.dart';
import 'analysis_result_screen.dart';
import 'audio_recorder.dart';
import 'audio_recorder_platform.dart';

enum DreamInputMode { selection, voice, text }

class RecordDreamScreen extends StatefulWidget {
  const RecordDreamScreen({super.key});

  @override
  State<RecordDreamScreen> createState() => _RecordDreamScreenState();
}

class _RecordDreamScreenState extends State<RecordDreamScreen> with SingleTickerProviderStateMixin {
  late AudioRecorder _audioRecorder;
  late AnimationController _animationController;
  late AudioRecorderPlatform _platformRecorder;
  DreamInputMode _currentMode = DreamInputMode.selection;
  bool _isRecording = false;
  String? _audioPath;
  bool _isProcessing = false;
  String? _transcription;
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _textInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _platformRecorder = getPlatformRecorder();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _animationController.dispose();
    _reviewController.dispose();
    _textInputController.dispose();
    super.dispose();
  }

  // --- Voice Logic (Clean & Universal) ---
  Future<void> _startRecording() async {
    try {
      const config = RecordConfig();
      await _platformRecorder.start(_audioRecorder, config);

      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _platformRecorder.stop(_audioRecorder);
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });

      if (path != null) {
        await _sendToTranscription(path);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _sendToTranscription(String path) async {
    setState(() => _isProcessing = true);
    final dio = Dio();
    try {
      // Usamos a abstração para pegar os bytes do áudio (seja de arquivo ou BLOB)
      final bytes = await _platformRecorder.getAudioBytes(path);
      
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'recording.m4a'),
      });

      // Talking to the backend via central config
      final response = await dio.post(AionConfig.transcribeUrl, data: formData);
      
      setState(() {
        _transcription = response.data['text'];
        _reviewController.text = _transcription ?? '';
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('Transcription error: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A tradução vocal falhou. Se estiver na Web, verifique se o seu servidor backend está rodando e acessível.'),
            duration: Duration(seconds: 5),
          ),
        );
        setState(() => _currentMode = DreamInputMode.selection);
      }
    }
  }

  // --- Common Analysis Logic ---
  Future<void> _analyzeAndNavigate(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() => _isProcessing = true);
    final dio = Dio();
    try {
      final response = await dio.post(
        AionConfig.analyzeUrl, 
        data: {'text': text},
      );
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisResultScreen(
              analysis: response.data,
              dreamText: text, // Pass original text here
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Analysis error: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O Oráculo está em silêncio. Tente novamente mais tarde.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      appBar: AppBar(
        title: Text(
          _currentMode == DreamInputMode.selection ? 'COMO DESEJA RELATAR?' : 
          _currentMode == DreamInputMode.voice ? 'RELATO VOCAL' : 'RELATO ESCRITO',
          style: AionTheme.serifStyle(fontSize: 18, color: AionTheme.gold, letterSpacing: 2),
        ),
        leading: IconButton(
          icon: Icon(
            _currentMode == DreamInputMode.selection ? Icons.close : Icons.arrow_back_ios,
            color: AionTheme.gold,
          ),
          onPressed: () {
            if (_currentMode == DreamInputMode.selection) {
              Navigator.pop(context);
            } else {
              setState(() {
                _currentMode = DreamInputMode.selection;
                _transcription = null;
              });
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: _isProcessing 
                ? const MandalaSpinner(message: 'Aion está tecendo os símbolos...')
                : _buildBody(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_transcription != null) return _buildReviewView(theme);

    switch (_currentMode) {
      case DreamInputMode.selection:
        return _buildSelectionView(theme);
      case DreamInputMode.voice:
        return _buildRecordingView(theme);
      case DreamInputMode.text:
        return _buildTextInputView(theme);
    }
  }

  Widget _buildSelectionView(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSelectionCard(
          title: 'RELATO VOCAL',
          subtitle: 'Fale sua jornada para o Oráculo',
          icon: Icons.mic_none,
          color: Colors.amber.shade200,
          onTap: () => setState(() => _currentMode = DreamInputMode.voice),
        ),
        const SizedBox(height: 30),
        _buildSelectionCard(
          title: 'RELATO ESCRITO',
          subtitle: 'Escreva suas imagens e visões',
          icon: Icons.history_edu,
          color: Colors.deepPurple.shade200,
          onTap: () => setState(() => _currentMode = DreamInputMode.text),
        ),
      ],
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: AionTheme.darkAbyss,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AionTheme.gold.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AionTheme.gold),
            const SizedBox(height: 20),
            Text(
              title,
              style: AionTheme.serifStyle(fontSize: 22, color: AionTheme.gold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingView(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.1).animate(_animationController),
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AionTheme.gold.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: AionTheme.gold.withOpacity(_isRecording ? 0.2 : 0.05),
                  blurRadius: 30,
                  spreadRadius: 10,
                )
              ],
            ),
            child: IconButton(
              iconSize: 60,
              icon: Icon(
                _isRecording ? Icons.stop : Icons.mic_none,
                color: AionTheme.gold,
              ),
              onPressed: _isRecording ? _stopRecording : _startRecording,
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          _isRecording ? 'Gravando Jornada...' : 'Toque para iniciar o relato',
          style: AionTheme.serifStyle(fontSize: 20, color: AionTheme.gold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTextInputView(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AionTheme.darkAbyss,
              border: Border.all(color: AionTheme.gold.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _textInputController,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Descreva seu sonho com detalhes...',
                hintStyle: GoogleFonts.inter(color: Colors.white24),
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _textInputController.text.trim().length > 10
              ? () => _analyzeAndNavigate(_textInputController.text)
              : null,
          child: const Text('INTERPRETAR A MENSAGEM DO SONHO'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildReviewView(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Aion traduziu seu relato:',
            style: AionTheme.serifStyle(fontSize: 24, color: AionTheme.gold),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AionTheme.darkAbyss,
              border: Border.all(color: AionTheme.gold.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _reviewController,
              maxLines: 10,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _analyzeAndNavigate(_reviewController.text),
            child: const Text('CONFIRMAR E ANALISAR'),
          ),
          TextButton(
            onPressed: () => setState(() => _transcription = null),
            child: Text(
              'TENTAR NOVAMENTE',
              style: GoogleFonts.cormorantGaramond(color: AionTheme.gold, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}
