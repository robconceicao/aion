# Prompt: Atualização da interpretação de sonhos — Aion

> Use este prompt em uma sessão de código (ex: Claude Code / Antigravity) com acesso ao repositório do Aion. Ele consolida os ajustes pedidos para tornar a interpretação mais responsável e transparente.

## Contexto

Você vai atualizar o app **Aion — Mito & Psique**. A lógica de geração da interpretação está em `backend/app/services/ai_service.py`. A tela que exibe o resultado é `frontend/lib/src/features/dream/presentation/analysis_result_screen.dart`, que já tem uma seção "Aviso ético" no topo. Leia `CLAUDE.md` na raiz do projeto antes de alterar qualquer coisa — ele documenta a arquitetura completa (stack, endpoints, cadeia de fallback de IA, RLS, banco duplo Mongo/Supabase).

## Objetivo

Deixar claro para o usuário que a interpretação de um sonho não é única nem definitiva: é uma leitura possível entre muitas, construída a partir da descrição do sonho e das respostas da entrevista, usando como referência Jung e Campbell — e que não substitui acompanhamento profissional.

## Tarefas

### 1. Aviso antes da interpretação
Inserir, antes do conteúdo interpretativo, um texto (fixo no app, e refletido também no prompt da IA) com esta mensagem — adaptar o tom, manter o sentido:

> "Não existe uma única interpretação para um sonho — ela depende das perguntas feitas e de quem interpreta. Aqui, buscamos uma leitura possível entre muitas, com base no que você descreveu e nas suas respostas, usando como referência as ideias de Carl Jung e Joseph Campbell. Para um entendimento mais profundo, o acompanhamento com um psicólogo é o caminho mais indicado."

Avaliar se isso expande a seção "Aviso ético" já existente em `AnalysisResultScreen` ou se deve virar um bloco próprio, exibido sempre antes da seção "Essência".

### 2. Revisar a palavra "interpretação"
Avaliar, na UI e no prompt da IA, se "interpretação" é o termo certo, ou se algo como "leitura simbólica", "amplificação" ou "exploração" comunica melhor que isso não é um diagnóstico. Aplicar a escolha de forma consistente em frontend e backend (textos, nomes de tela, prompt).

### 3. Ajustar o tom do prompt de IA
Reescrever o prompt em `ai_service.py` para que a resposta não soe como análise/diagnóstico fechado. Preferir formulações como "segundo as pesquisas de Jung...", "segundo as teorias de Campbell...", "uma leitura possível seria..." em vez de afirmações categóricas ("isso significa...", "seu sonho revela...").

### 4. Decidir profundidade da análise
Avaliar se o app deve manter a análise ampla atual (arquétipos, sombra/luz, símbolos, jornada do herói, mito espelho etc. — ver ordem de seções no CLAUDE.md) ou migrar para uma versão mais direta, com menos seções mas mais detalhe em cada uma. Apresentar prós/contras antes de implementar.

### 5. Adequação à LGPD
Levantar as obrigações da LGPD aplicáveis a um app que coleta relatos de sonho (dado sensível em potencial), áudio de voz e dados de conta. Propor adaptações: base legal para o tratamento, texto de consentimento, política de privacidade, direito de exclusão/portabilidade, prazo de retenção — considerando a arquitetura dupla (MongoDB + Supabase) e as políticas de RLS já existentes em `public.dreams` e `public.episodes`.

### 6. Site de vendas (Wix)
Estruturar um site de vendas do Aion no Wix: proposta de valor, como o app funciona, disclaimers de uso (reforçando que não substitui terapia), espaço para capturas de tela, chamada para download.

## Entregáveis esperados

- Prompt atualizado em `ai_service.py`, com o aviso e o tom menos categórico
- Texto de disclaimer implementado em `analysis_result_screen.dart`
- Decisão registrada sobre escopo/profundidade da análise (ampla vs. direta)
- Checklist de adequação LGPD (base legal, consentimento, retenção, exclusão)
- Estrutura de conteúdo (ou site publicado) no Wix
