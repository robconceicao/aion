# Decisões de produto — interpretação de sonhos (Aion)

> Registra as duas decisões de avaliação pedidas junto com a atualização do aviso ético: profundidade da análise e a palavra "interpretação". Baseado no código atual (`backend/app/services/ai_service.py`, `dreams.py`, `analysis_result_screen.dart`, `narrative_result_screen.dart`).

## 1. Manter análise ampla ou só a direta?

**Achado:** o app já tem as duas coisas, e elas não competem — competem em telas diferentes:

- `AnalysisResultScreen` ("Mapa Arquetípico") — versão ampla/técnica: símbolos, arquétipos, função compensatória, dimensões, jornada do herói etc. Vem de `analise_completa`.
- `NarrativeResultScreen` ("Leitura Simbólica" / "Voz do Arquétipo") — versão direta e corrida, sem jargão, já com o aviso ético. Vem de `interpretacao_narrativa`.

Isso é exatamente o padrão dual descrito nos comentários do backend (`SPEC §5.1`): a IA gera as duas em uma única chamada, com conteúdo idêntico e forma diferente — uma para quem quer profundidade, outra para quem quer só a leitura acessível.

**Recomendação: manter as duas.** Não há necessidade de escolher uma só — o usuário já pode optar. Sugestão de melhoria (não implementada agora, fora do escopo pedido): deixar mais explícito no fluxo que "Mapa Arquetípico" é a versão técnica e "Leitura Simbólica" é a versão direta, para o usuário saber que pode alternar.

**Achado colateral (bug, não relacionado ao pedido original):** no mapeamento de `dreams.py` (`create_dream`, linhas ~279-298), os campos `mito_espelho` e `prospeccao` são sempre enviados vazios (`""`) para o frontend desde a migração para `synthesize_dual` — as seções "Mito Espelho" e "Prospecção" da tela `AnalysisResultScreen` hoje aparecem em branco. Vale abrir isso como item separado de bug, se quiser que eu corrija.

## 2. "Interpretação" é a melhor palavra?

**Achado:** o próprio app já evita a palavra em pontos-chave — a tela de narrativa já usa "LEITURA SIMBÓLICA" como rótulo de seção, e a tela técnica se chama "MAPA ARQUETÍPICO". "Interpretação" aparece hoje principalmente em nomes internos (endpoint `/dreams/`, campo `interpretacao_narrativa`, coluna `interpretacao` no Supabase) — não como palavra central da experiência do usuário.

**Recomendação:** usar "leitura simbólica" (ou "leitura possível") como termo padrão em qualquer texto novo voltado ao usuário — é o que já foi feito nos dois avisos éticos atualizados agora. Não renomear campos de API, colunas de banco (`interpretacao`, `interpretacao_narrativa`) nem nomes de classe/arquivo (`AnalysisResultScreen`, `analyze_dream`, `/dreams/`) — isso quebraria contratos entre frontend/backend/banco sem nenhum ganho para o usuário, que não vê esses nomes. Se no futuro quiser renomear também os identificadores técnicos, isso deve ser tratado como uma migração separada (endpoint + coluna + client), não como parte desta mudança de copy.
