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
import 'archetypes_screen.dart';
import 'canal_screen.dart';
import 'dream_choice_screen.dart';

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
    _ctxController.text = "Transição de carreira, busca por propósito..."; // Pre-preenchido
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
        _textInputController.text = _textInputController.text.isNotEmpty 
          ? '${_textInputController.text} $_transcription'
          : _transcription ?? '';
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('Transcription error: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A tradução vocal falhou. Verifique se o servidor backend está rodando e acessível.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // --- Common Analysis Logic ---
  Future<void> _analyzeAndNavigate(String text) async {
    if (text.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    final dio = Dio();

    // Recupera e-mail salvo localmente (simples SharedPreferences ou fallback)
    // Por ora usamos um identificador persistido em memória
    const userEmail = 'usuario@aion.app'; // Substituir por auth real

    try {
      // 1ª chamada: análise estruturada (com e-mail para histórico)
      final analysisResponse = await dio.post(
        AionConfig.analyzeUrl,
        options: Options(headers: {'x-user-email': userEmail}),
        data: {
          'text': text,
          'emotion': _mood != 'Não informar' ? _mood : null,
          if (_tags.isNotEmpty) 'tags': _tags,
          'is_recurrent': _recurring,
        },
      );

      final detailedAnalysis = analysisResponse.data as Map<String, dynamic>;

      // 2ª chamada: narrativa — passa contexto da análise para coerência
      final narrativeResponse = await dio.post(
        AionConfig.narrativeUrl,
        data: {
          'text': text,
          'analysis_context': detailedAnalysis,
          'user_email': userEmail,
        },
      );

      final narrativeText = narrativeResponse.data['narrative'] as String;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DreamChoiceScreen(
              dreamText: text,
              detailedAnalysis: detailedAnalysis,
              narrativeText: narrativeText,
            ),
          ),
        );
      }
    } catch (e) {
      String errorMessage = 'O Oráculo está em silêncio.';
      if (e is DioException) {
        errorMessage = 'Erro na conexão: ${e.response?.statusCode} - ${e.response?.data}';
      } else {
        errorMessage = 'Erro inesperado: $e';
      }
      
      debugPrint('Analysis error: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    }
  }

  String _mood = 'Não informar';
  final List<String> _moods = ['Não informar', 'Aterrorizado', 'Ansioso', 'Neutro', 'Curioso', 'Revigorado', 'Eufórico', 'Triste', 'Lúcido'];
  final TextEditingController _ctxController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final List<String> _tags = [];
  bool _recurring = false;
  bool _deepMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 36.0),
              child: _isProcessing 
                ? const MandalaSpinner(message: 'Buscando os melhores significados\nsegundo o seu contexto...')
                : _buildBody(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNav(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('M I T O  &  P S I Q U E', style: TextStyle(fontSize: 9, letterSpacing: 5, color: AionTheme.gold)),
                const SizedBox(height: 8),
                const Text('Registrar Sonho', style: TextStyle(fontSize: 24, letterSpacing: 3, fontFamily: 'Georgia', color: Colors.white)),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _navBtn(context, 'INÍCIO', false, () => Navigator.pop(context)),
                _navBtn(context, '+ SONHO', true, () {}),
                _navBtn(context, 'ARQUÉTIPOS', false, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ArchetypesScreen()),
                  );
                }),
                _navBtn(context, 'CANAL', false, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CanalScreen()),
                  );
                }),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _navBtn(BuildContext context, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AionTheme.gold : Colors.transparent,
          border: Border.all(color: isActive ? AionTheme.gold : AionTheme.veil),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AionTheme.darkVoid : AionTheme.silver,
            fontSize: 10,
            letterSpacing: 2,
            fontFamily: 'Georgia',
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNav(context),
          
          // Dream Text Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AionTheme.deep,
              border: Border.all(
                color: _textInputController.text.length > 20 
                    ? AionTheme.gold.withOpacity(0.6) 
                    : AionTheme.shadow,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'R E L A T O   D O   S O N H O   *',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AionTheme.gold,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isRecording ? Icons.stop : Icons.mic_none,
                        color: _isRecording ? AionTheme.crimson : AionTheme.gold,
                      ),
                      onPressed: _isRecording ? _stopRecording : _startRecording,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isRecording)
                   const Text(
                     'Gravando...',
                     style: TextStyle(color: AionTheme.crimson, fontSize: 12),
                   ),
                TextField(
                  controller: _textInputController,
                  maxLines: 6,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    height: 1.85,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Descreva seu sonho — personagens, lugares, sensações, cores, emoções, ações...',
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white24,
                      fontFamily: 'Georgia',
                      fontSize: 15,
                    ),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_textInputController.text.length} car. ${_textInputController.text.length < 20 ? "— mínimo 20" : ""}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _textInputController.text.length < 20 ? AionTheme.crimson : AionTheme.silver,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mood + Context
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final children = [
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AionTheme.deep,
                      border: Border.all(color: AionTheme.shadow),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('E S T A D O   A O   A C O R D A R', style: TextStyle(color: AionTheme.silver, fontSize: 10, letterSpacing: 2)),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AionTheme.darkVoid,
                            border: Border.all(color: AionTheme.shadow),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _mood,
                              dropdownColor: AionTheme.darkVoid,
                              style: const TextStyle(color: AionTheme.silver, fontSize: 13, fontFamily: 'Georgia'),
                              icon: const Icon(Icons.keyboard_arrow_down, color: AionTheme.silver),
                              isExpanded: true,
                              onChanged: (val) => setState(() => _mood = val!),
                              items: _moods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isWide) const SizedBox(width: 14) else const SizedBox(height: 14),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AionTheme.deep,
                      border: Border.all(color: AionTheme.shadow),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('C O N T E X T O   D E   V I D A', style: TextStyle(color: AionTheme.silver, fontSize: 10, letterSpacing: 2)),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AionTheme.darkVoid,
                            border: Border.all(color: AionTheme.shadow),
                          ),
                          child: TextField(
                            controller: _ctxController,
                            style: const TextStyle(color: AionTheme.silver, fontSize: 13, fontFamily: 'Georgia'),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
              return isWide ? Row(children: children) : Column(children: children);
            },
          ),
          const SizedBox(height: 16),

          // Tags
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AionTheme.deep,
              border: Border.all(color: AionTheme.shadow),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('T A G S   P E R S O N A L I Z A D A S', style: TextStyle(color: AionTheme.silver, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AionTheme.darkVoid,
                          border: Border.all(color: AionTheme.shadow),
                        ),
                        child: TextField(
                          controller: _tagController,
                          style: const TextStyle(color: AionTheme.silver, fontSize: 13, fontFamily: 'Georgia'),
                          decoration: const InputDecoration(
                            hintText: 'Digite uma tag e pressione Enter...',
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty && !_tags.contains(val.trim())) {
                              setState(() => _tags.add(val.trim()));
                              _tagController.clear();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        if (_tagController.text.trim().isNotEmpty && !_tags.contains(_tagController.text.trim())) {
                          setState(() => _tags.add(_tagController.text.trim()));
                          _tagController.clear();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        decoration: BoxDecoration(
                          color: AionTheme.darkVoid,
                          border: Border.all(color: AionTheme.shadow),
                        ),
                        child: const Text('+ A D D', style: TextStyle(color: AionTheme.silver, fontSize: 10, letterSpacing: 2)),
                      ),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AionTheme.veil),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t, style: const TextStyle(color: AionTheme.silver, fontSize: 12, fontFamily: 'Georgia')),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _tags.remove(t)),
                          child: const Icon(Icons.close, size: 14, color: AionTheme.silver),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Options
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final children = [
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: InkWell(
                    onTap: () => setState(() => _recurring = !_recurring),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _recurring ? AionTheme.gold.withOpacity(0.05) : AionTheme.darkVoid,
                        border: Border.all(color: _recurring ? AionTheme.gold : AionTheme.shadow),
                      ),
                      child: Row(
                        children: [
                          Icon(_recurring ? Icons.check_box : Icons.check_box_outline_blank, color: _recurring ? AionTheme.gold : AionTheme.silver, size: 16),
                          const SizedBox(width: 12),
                          const Text('Sonho recorrente', style: TextStyle(color: AionTheme.silver, fontSize: 13, fontFamily: 'Georgia')),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isWide) const SizedBox(width: 12) else const SizedBox(height: 12),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: InkWell(
                    onTap: () => setState(() => _deepMode = !_deepMode),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _deepMode ? AionTheme.gold.withOpacity(0.05) : AionTheme.darkVoid,
                        border: Border.all(color: _deepMode ? AionTheme.gold : AionTheme.shadow),
                      ),
                      child: Row(
                        children: [
                          Icon(_deepMode ? Icons.check_box : Icons.check_box_outline_blank, color: _deepMode ? AionTheme.gold : AionTheme.silver, size: 16),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Análise Aprofundada', style: TextStyle(color: AionTheme.silver, fontSize: 13, fontFamily: 'Georgia')),
                              Text('Perguntas guiadas', style: TextStyle(color: AionTheme.silver, fontSize: 10, fontFamily: 'Georgia')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
              return isWide ? Row(children: children) : Column(children: children);
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _textInputController.text.trim().length > 20
                  ? () => _analyzeAndNavigate(_textInputController.text)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AionTheme.gold,
                foregroundColor: AionTheme.darkVoid,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: const Text('B U S C A R   O   S I G N I F I C A D O', style: TextStyle(letterSpacing: 3, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '"Um mesmo sonho não possui um significado único, fixo ou determinado por dicionários de sonhos, mas sim inúmeras possibilidades de análise e significados que dependem do contexto do sonhador."',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AionTheme.silver,
              fontSize: 10,
              fontStyle: FontStyle.italic,
              fontFamily: 'Georgia',
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
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
