// Banco central de dicas — usado pelo HintCard e pelo LoadingTips
class DreamTips {

  // ── Dicas para o Hint Card (práticas, orientadas à ação)
  static const List<String> registry = [
    'Anote palavras-chave antes de qualquer coisa — emoções primeiro, cena depois.',
    'Registre antes de verificar o celular. Notificações apagam a memória do sonho.',
    'Mesmo fragmentos têm valor. "Escuridão, água, medo" já é suficiente para o Oráculo.',
    'Não interprete enquanto anota — apenas descreva o que você viu e sentiu.',
    'O corpo também sonha. Inclua sensações físicas que permaneceram ao acordar.',
    'A última cena antes de acordar geralmente é a mais significativa.',
    'Se só se lembrar de uma emoção, registre só ela. Emoção sem cena ainda é um sonho.',
    'Não julgue o que sonhou. O Oráculo não tem filtro moral — e nem precisa ter.',
    'Sonhos recorrentes ficam mais claros quando anotados em série.',
    'Deixe um caderno ao lado da cama. O gesto físico de anotar consolida a memória.',
  ];

  // ── Placeholders rotativos do campo de texto
  static const List<String> placeholders = [
    'Comece pelas emoções que sentiu — a cena vem depois...',
    'Mesmo fragmentos têm valor. O que você viu?',
    'Não interprete ainda. Apenas descreva...',
    'Qual foi a última imagem antes de acordar?',
    'Esta noite eu sonhei que...',
    'Descreva qualquer detalhe que ainda está presente...',
  ];

  // ── Dicas de loading (contemplativas, sobre o processo simbólico)
  static const List<String> loading = [
    'O símbolo que mais incomoda costuma ser o mais importante.',
    'Sonhos recorrentes ficam mais claros quando anotados em série.',
    'Jung dizia que o sonho é a autorrepresentação espontânea da psique.',
    'A última cena antes de acordar geralmente é a mais significativa.',
    'Campbell via nos sonhos o mito pessoal em construção.',
    'O inconsciente fala em imagens porque nasceu antes das palavras.',
    'Mesmo um fragmento de sonho carrega uma mensagem inteira.',
    'O que você sentiu no sonho importa mais do que o que você viu.',
    'Toda figura que aparece no sonho é também uma parte de você.',
    'O abismo do sonho e o abismo da vida costumam ter o mesmo fundo.',
  ];
}
