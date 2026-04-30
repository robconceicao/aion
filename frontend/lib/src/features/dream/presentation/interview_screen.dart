import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import 'dream_choice_screen.dart';
import '../../../features/dream/presentation/widgets/mandala_spinner.dart';

class InterviewScreen extends StatefulWidget {
  final String dreamText;
  final List<String> tagsEmocao;
  final List<String> temas;
  final List<String> residuosDiurnos;
  final List<String> perguntas;

  const InterviewScreen({
    super.key,
    required this.dreamText,
    required this.tagsEmocao,
    required this.temas,
    required this.residuosDiurnos,
    required this.perguntas,
  });

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = [];
  final _dio = Dio();
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    for (var _ in widget.perguntas) {
      _controllers.add(TextEditingController());
    }
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool get _allAnswered =>
      _controllers.every((c) => c.text.trim().isNotEmpty);

  Future<void> _submitAnswers() async {
    if (!_allAnswered || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final interviewAnswers = List.generate(
        widget.perguntas.length,
        (i) => {
          'pergunta': widget.perguntas[i],
          'resposta': _controllers[i].text.trim(),
        },
      );

      final response = await _dio.post(
        AionConfig.analyzeUrl,
        data: {
          'text': widget.dreamText,
          if (widget.tagsEmocao.isNotEmpty) 'tags_emocao': widget.tagsEmocao,
          if (widget.temas.isNotEmpty) 'temas': widget.temas,
          if (widget.residuosDiurnos.isNotEmpty) 'residuos_diurnos': widget.residuosDiurnos,
          'interview_answers': interviewAnswers,
          'is_recurrent': false,
        },
      );

      final detailedAnalysis = response.data as Map<String, dynamic>;
      final narrativeText = (detailedAnalysis['narrative'] as String?) ?? '';

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DreamChoiceScreen(
            dreamText: widget.dreamText,
            detailedAnalysis: detailedAnalysis,
            narrativeText: narrativeText,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao analisar: ${e.message}',
            style: GoogleFonts.ptSerif(color: Colors.white),
          ),
          backgroundColor: AionTheme.crimson,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AionTheme.darkVoid,
        body: const MandalaSpinner(message: 'O Oráculo está interpretando...'),
      );
    }

    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: FadeTransition(
              opacity: _fadeIn,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // — Voltar
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, size: 14,
                              color: AionTheme.silver.withOpacity(0.5)),
                          const SizedBox(width: 8),
                          Text('VOLTAR',
                              style: GoogleFonts.ptSerif(
                                fontSize: 9, letterSpacing: 3,
                                color: AionTheme.silver.withOpacity(0.5),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // — Header
                    Text('MODO ENTREVISTA',
                        style: GoogleFonts.ptSerif(
                          fontSize: 9, letterSpacing: 4, color: AionTheme.gold,
                        )),
                    const SizedBox(height: 12),
                    Text(
                      'O Oráculo precisa\nde mais contexto.',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 30, height: 1.2, color: AionTheme.ghost,
                        fontWeight: FontWeight.w300, fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Responda com o que vier à mente. Não há respostas certas.',
                      style: GoogleFonts.ptSerif(
                        fontSize: 13, color: AionTheme.silver.withOpacity(0.6),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _buildDivider(),
                    const SizedBox(height: 32),

                    // — Perguntas
                    ...List.generate(widget.perguntas.length, (i) =>
                      _buildQuestionCard(i, widget.perguntas[i], _controllers[i]),
                    ),

                    const SizedBox(height: 16),

                    // — Botão
                    ListenableBuilder(
                      listenable: Listenable.merge(_controllers),
                      builder: (context, _) {
                        final ready = _allAnswered;
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: ready ? _submitAnswers : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ready
                                  ? AionTheme.gold
                                  : AionTheme.shadow,
                              foregroundColor: AionTheme.darkVoid,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: const RoundedRectangleBorder(),
                              elevation: 0,
                            ),
                            child: Text(
                              'REVELAR O SIGNIFICADO',
                              style: GoogleFonts.ptSerif(
                                fontSize: 11,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, String question, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número + pergunta
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AionTheme.gold.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.ptSerif(
                      fontSize: 10, color: AionTheme.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  question,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17, height: 1.5, color: AionTheme.ghost,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Campo de resposta
          Container(
            decoration: BoxDecoration(
              color: AionTheme.darkAbyss,
              border: Border.all(color: AionTheme.shadow),
            ),
            child: TextField(
              controller: controller,
              style: GoogleFonts.ptSerif(
                fontSize: 14, color: AionTheme.ghost, height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'Sua resposta...',
                hintStyle: GoogleFonts.ptSerif(
                  color: AionTheme.silver.withOpacity(0.3), fontSize: 14,
                ),
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
              ),
              maxLines: 3,
              minLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AionTheme.gold.withOpacity(0.3)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('✦',
              style: TextStyle(color: AionTheme.gold.withOpacity(0.5), fontSize: 10)),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AionTheme.gold.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
