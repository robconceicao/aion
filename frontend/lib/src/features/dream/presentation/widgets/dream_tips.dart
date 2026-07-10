import 'dart:math';

// ─── BANCO DE DICAS PRINCIPAL (spec AionDreamTips) ────────────

class AionDreamTips {

  // Dicas para o hint card — tom prático e acolhedor
  static const List<String> cardTips = [
    'Anote palavras-chave primeiro — emoções, cores, sensações. A cena vem depois.',
    'Registre antes de verificar o celular. Notificações apagam a memória do sonho.',
    'Mesmo fragmentos têm valor. "Escuridão, água, medo" já é suficiente para o Aion.',
    'Não interprete enquanto anota. Apenas descreva o que você viu e sentiu.',
    'O corpo também sonha. Inclua sensações físicas que sentiu durante o sonho.',
    'A última imagem antes de acordar é geralmente a mais significativa.',
    'Sonhos recorrentes ficam mais claros quando anotados em série.',
    'Se só se lembrar de uma emoção, registre só ela. Emoção sem cena ainda é um sonho.',
    'Deixe um caderno ao lado da cama. O gesto físico de anotar consolida a memória.',
    'Não julgue o que sonhou. O inconsciente não tem filtro moral — e não precisa ter.',
  ];

  // Placeholders rotativos para o campo de texto
  static const List<String> textPlaceholders = [
    'Comece pelas emoções que sentiu — a cena vem depois...',
    'Mesmo fragmentos têm valor. O que você ainda lembra?',
    'Não interprete ainda. Apenas descreva o que você viu...',
    'Esta noite eu estava em...',
    'O que ficou na memória ao acordar?',
    'Uma palavra, uma cor, uma sensação — já é suficiente.',
  ];

  // Dicas para o loading — com citações de Jung e Campbell
  static const List<String> loadingTips = [
    'O Aion está amplificando os símbolos...\n\n"Todo sonho é uma porta para o que você ainda não sabe sobre si mesmo."',
    'Consultando os arquétipos...\n\n"Sonhos recorrentes ficam mais claros quando anotados em série."',
    'Navegando pela Jornada do Herói...\n\n"A última cena antes de acordar geralmente carrega a mensagem principal."',
    'Buscando o mito espelho...\n\n"Emoções do sonho são tão válidas quanto as imagens — às vezes mais."',
    'Mapeando as dimensões psíquicas...\n\n"Jung dizia: o sonho não mente. Ele diz o que você precisa ouvir, não o que quer."',
    'Atravessando o limiar simbólico...\n\n"Figuras desconhecidas em sonhos geralmente representam partes suas ainda não integradas."',
    'Interpretando as camadas do sonho...\n\n"A repetição de um símbolo é um convite — não uma ameaça."',
    'Revelando os arquétipos ocultos...\n\n"Sonhar com água quase sempre fala sobre emoções que você ainda não nomeou."',
  ];

  static String getRandomCardTip() =>
      cardTips[Random().nextInt(cardTips.length)];

  static String getRandomPlaceholder() =>
      textPlaceholders[Random().nextInt(textPlaceholders.length)];

  static String getRandomLoadingTip() =>
      loadingTips[Random().nextInt(loadingTips.length)];
}


// ─── BANCO DE DICAS LEGADO (compatibilidade com hint_card e loading_tip) ────

class DreamTips {

  // ── Dicas para o Hint Card (práticas, orientadas à ação)
  static const List<String> registry = [
    'Anote palavras-chave antes de qualquer coisa — emoções primeiro, cena depois.',
    'Registre antes de verificar o celular. Notificações apagam a memória do sonho.',
    'Mesmo fragmentos têm valor. "Escuridão, água, medo" já é suficiente para o AION.',
    'Não interprete enquanto anota — apenas descreva o que você viu e sentiu.',
    'O corpo também sonha. Inclua sensações físicas que permaneceram ao acordar.',
    'A última cena antes de acordar geralmente é a mais significativa.',
    'Se só se lembrar de uma emoção, registre só ela. Emoção sem cena ainda é um sonho.',
    'Não julgue o que sonhou. O AION não tem filtro moral — e nem precisa ter.',
    'Sonhos recorrentes ficam mais claros quando anotados em série.',
    'Deixe um caderno ao lado da cama. O gesto físico de anotar consolida a memória.',
  ];

  // ── Placeholders rotativos do campo de texto
  static const List<String> placeholders = [
    'Comece pelas emoções que sentiu — a cena vem depois...',
    'Mesmo fragmentos têm valor. O que você viu?',
    'Não interprete ainda. Apenas descreva o que você viu e sentiu...',
    'Esta noite eu sonhei que...',
    'Descreva qualquer detalhe que ainda está presente...',
    'O que ficou na memória ao acordar? Descreva livremente...',
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

