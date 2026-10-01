import 'notification_service.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/dream_command_journal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/api_service.dart';
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
  final _dio = ApiService.client;
  bool _isLoading = false;
  late final String _ownerId;
  String get _draftKey => 'interview_draft:$_ownerId';

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _ownerId = Supabase.instance.client.auth.currentUser?.id ?? '';
    for (var _ in widget.perguntas) {
      _controllers.add(TextEditingController());
    }
    _tryRestoreDraft();
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

  void _tryRestoreDraft() {
    try {
      final savedCommand = Hive.box('dreams').get(DreamCommandJournal.key(_ownerId));
      if (savedCommand != null) {
        final payload = jsonDecode(savedCommand['payload'] as String) as Map;
        if (payload['text'] == widget.dreamText) {
          final answers = List<Map>.from(payload['interview_answers'] as List);
          if (answers.length == widget.perguntas.length && List.generate(answers.length, (i) => answers[i]['pergunta'] == widget.perguntas[i]).every((v) => v)) {
            for (var i = 0; i < answers.length; i++) { _controllers[i].text = answers[i]['resposta'] as String; }
            return;
          }
        }
      }
      final draft = Hive.box('dreams').get(_draftKey);
      if (draft == null || draft['dreamText'] != widget.dreamText) return;
      final savedQs = List<String>.from(draft['questions'] as List? ?? []);
      if (savedQs.length != widget.perguntas.length) return;
      for (int i = 0; i < savedQs.length; i++) {
        if (savedQs[i] != widget.perguntas[i]) return;
      }
      final answers = List<String>.from(draft['answers'] as List? ?? []);
      for (int i = 0; i < _controllers.length && i < answers.length; i++) {
        _controllers[i].text = answers[i];
      }
    } catch (_) {}
  }

  bool get _allAnswered =>
      _controllers.every((c) => c.text.trim().isNotEmpty);

  Future<void> _submitAnswers() async {
    if (!_allAnswered || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (_ownerId.isEmpty || Supabase.instance.client.auth.currentUser?.id != _ownerId) {
        throw StateError('A conta mudou. Reabra a entrevista na conta original.');
      }
      await Hive.box('dreams').put(_draftKey, {
        'dreamText': widget.dreamText,
        'questions': widget.perguntas,
        'answers': _controllers.map((c) => c.text).toList(),
      });
      // Refresh da sessão antes da análise longa (evita expirar no meio)
      final session = await ApiService.ensureFreshSession();
      if (session == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sua sessão expirou (sem token local). Suas respostas estão preservadas — '
              'feche e reabra o app, depois toque em Revelar o Significado novamente.',
              style: GoogleFonts.ptSerif(color: Colors.white),
            ),
            backgroundColor: AionTheme.crimson,
            duration: const Duration(seconds: 10),
          ),
        );
        return;
      }

      final interviewAnswers = List.generate(
        widget.perguntas.length,
        (i) => {
          'pergunta': widget.perguntas[i],
          'resposta': _controllers[i].text.trim(),
        },
      );

      if (session.user.id != _ownerId) {
        throw StateError('A conta mudou. Reabra a entrevista na conta original.');
      }
      final payload = <String, dynamic>{
        'text': widget.dreamText,
        if (widget.tagsEmocao.isNotEmpty) 'tags_emocao': widget.tagsEmocao,
        if (widget.temas.isNotEmpty) 'temas': widget.temas,
        if (widget.residuosDiurnos.isNotEmpty) 'residuos_diurnos': widget.residuosDiurnos,
        'interview_answers': interviewAnswers,
        'is_recurrent': false,
      };
      final box = Hive.box('dreams');
      final journal = DreamCommandJournal(box.get, box.put);
      final command = await journal.prepare(_ownerId, payload);
      final response = await _dio.post(
        AionConfig.analyzeUrl,
        data: {...payload, 'command_id': command['command_id']},
        options: ApiService.authOptions(
          session: session,
          extraHeaders: {'X-Tadeu-Idempotency-Key': 'dream:${command["command_id"]}'},
          receiveTimeout: const Duration(seconds: 180),
          sendTimeout: const Duration(seconds: 90),
        ),
      );

      if (Supabase.instance.client.auth.currentUser?.id != _ownerId) {
        throw StateError('A conta mudou. O resultado permanece no histórico da conta original.');
      }
      final detailedAnalysis = response.data as Map<String, dynamic>;
      // Only a successfully persisted dream suppresses today's reminder.
      try { await AionNotificationService.cancelTodaysMorning(); }
      catch (error) { debugPrint('Lembrete não atualizado: $error'); }
      final narrativeText = (detailedAnalysis['narrative'] as String?) ?? '';

      if (!mounted) return;

      await box.delete(_draftKey);
      await box.delete(DreamCommandJournal.key(_ownerId));
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
      final int? status = e.response?.statusCode;
      final String msg;
      if (status == 401 || status == 403) {
        final detail = e.response?.data is Map
            ? (e.response!.data['detail']?.toString() ?? '')
            : '';
        final hint = detail.isNotEmpty ? ' [$detail]' : '';
        msg = 'Sua sessão expirou (HTTP $status$hint). Suas respostas estão preservadas — '
            'feche e reabra o app, depois toque em Revelar o Significado novamente.';
      } else if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        msg = 'A resposta não chegou. Suas respostas e o identificador foram preservados. Tente novamente para recuperar a mesma análise.';
      } else if (e.response?.data is Map && e.response!.data['detail'] is Map) {
        msg = e.response!.data['detail']['message']?.toString() ?? 'A operação está pendente. Tente consultar novamente.';
      } else if (status != null) {
        msg = 'Não foi possível analisar o sonho (HTTP $status). Verifique sua internet e tente novamente.';
      } else {
        msg = 'Não foi possível analisar o sonho. Verifique sua internet e tente novamente.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.ptSerif(color: Colors.white)),
          backgroundColor: AionTheme.crimson,
          duration: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError ? e.message.toString() : 'Não foi possível confirmar a operação. Suas respostas foram mantidas na tela.',
            style: GoogleFonts.ptSerif(color: Colors.white),
          ),
          backgroundColor: AionTheme.crimson,
          duration: const Duration(seconds: 8),
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
        body: const MandalaSpinner(
          message: 'Aion está interpretando...\nIsso pode levar de 1 a 2 minutos.',
        ),
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
                              color: AionTheme.silver),
                          const SizedBox(width: 8),
                          Text('VOLTAR',
                              style: GoogleFonts.ptSerif(
                                fontSize: 9, letterSpacing: 3,
                                color: AionTheme.silver,
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
                      'Aion precisa\nde mais contexto.',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 30, height: 1.2, color: AionTheme.ghost,
                        fontWeight: FontWeight.w300, fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Responda com o que vier à mente. Não há respostas certas.',
                      style: GoogleFonts.ptSerif(
                        fontSize: 13, color: AionTheme.silver,
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
                  border: Border.all(color: AionTheme.gold.withValues(alpha: 0.5)),
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
                    // Alto contraste no texto de leitura (WCAG-ish sobre darkVoid)
                    fontSize: 17, height: 1.5, color: const Color(0xFFF5F5F5),
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
                fontSize: 15, color: const Color(0xFFF5F5F5), height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'Sua resposta...',
                hintStyle: GoogleFonts.ptSerif(
                  color: AionTheme.silver, fontSize: 14,
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
                colors: [Colors.transparent, AionTheme.gold.withValues(alpha: 0.3)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('✦',
              style: TextStyle(color: AionTheme.gold.withValues(alpha: 0.5), fontSize: 10)),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AionTheme.gold.withValues(alpha: 0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
