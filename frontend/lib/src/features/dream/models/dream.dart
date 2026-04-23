class Dream {
  final String id;
  final String text;
  final String emotion;
  final List<String> tags;
  final bool isRecurrent;
  final DateTime createdAt;
  final DreamAnalysis? analysis;

  Dream({
    required this.id,
    required this.text,
    required this.emotion,
    required this.tags,
    required this.isRecurrent,
    required this.createdAt,
    this.analysis,
  });
}

class DreamAnalysis {
  final String essence;
  final List<String> archetypes;
  final String compensation;
  final List<String> symbols;
  final String journeyStage;
  final String projection;
  final String myth;
  final String reflection;

  DreamAnalysis({
    required this.essence,
    required this.archetypes,
    required this.compensation,
    required this.symbols,
    required this.journeyStage,
    required this.projection,
    required this.myth,
    required this.reflection,
  });
}
