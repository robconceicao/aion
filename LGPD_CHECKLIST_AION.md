# Checklist de adequação à LGPD — Aion

> Baseado na arquitetura atual do Aion (MongoDB + Supabase/Postgres com RLS, relatos de sonho, respostas de entrevista, áudio de voz, embeddings via Gemini) e na agenda regulatória vigente da ANPD (2025–2026), que colocou **dados de saúde e IA** como eixos prioritários de fiscalização até 2027.

## 1. Classificação do dado
Relatos de sonho, junto com as respostas da entrevista, podem revelar conteúdo emocional e psicológico da pessoa — na prática, tratam-se como **dado sensível** (equiparável a dado de saúde/estado psicológico) nos termos do art. 5º, II da LGPD. Isso vale mesmo sem diagnóstico clínico envolvido: o critério é o conteúdo revelado, não o rótulo do produto.

- [ ] Formalizar internamente que `dreams.relato`, `interview_answers`, `analise_completa`, `interpretacao_narrativa` e o áudio de voz são tratados como dado sensível.
- [ ] Mapear onde esse dado circula: Supabase (`public.dreams`), MongoDB, embeddings (pgvector), logs de backend, provedores de IA (Anthropic/Gemini/xAI).

## 2. Base legal e consentimento
Dado sensível de saúde exige **consentimento específico e destacado** (art. 11, I) — não pode estar diluído nos Termos de Uso genéricos.

- [ ] Tela de consentimento própria, separada do aceite de Termos/Privacidade, explicando: o que é coletado (texto, áudio, respostas), para que serve (gerar a leitura simbólica, detectar recorrência), quem processa (quais provedores de IA recebem o relato) e que a IA pode reter/usar esses dados conforme a política de cada provedor.
- [ ] Consentimento deve ser opt-in ativo (sem caixas pré-marcadas) e revogável a qualquer momento dentro do app (ex: em `profile_screen.dart`).
- [ ] Registrar data/hora do consentimento e sua versão (para provar consentimento em caso de fiscalização — o ônus da prova é do controlador).

## 3. Transparência (Política de Privacidade)
- [ ] Publicar Política de Privacidade específica do Aion (hoje não há indicação disso no repositório) cobrindo: dados coletados, finalidade, base legal, prazo de retenção, provedores terceiros (Anthropic, Google/Gemini, xAI/Grok, Supabase, Render), direitos do titular e canal de contato do encarregado (DPO).
- [ ] Deixar claro que sonhos são analisados por modelos de IA de terceiros (Claude, Gemini, Grok) — isso é uma transferência/compartilhamento de dado sensível que precisa estar explícita.

## 4. Direitos do titular (art. 18)
- [ ] Exclusão de conta e dados (hoje não identificado endpoint de exclusão de sonhos/conta no backend — `dreams.py` não tem DELETE).
- [ ] Exportação/portabilidade do histórico de sonhos.
- [ ] Correção de dados de cadastro.
- [ ] Confirmação de existência de tratamento e acesso aos dados (parcialmente coberto por `GET /dreams/history`).

Ação sugerida: adicionar endpoint `DELETE /dreams/{id}` e `DELETE /account` (com exclusão em cascata no Supabase e no Mongo), respeitando RLS já existente.

## 5. Retenção e minimização
- [ ] Definir prazo de retenção do relato de sonho, áudio e embeddings — hoje o schema não parece ter TTL/expiração.
- [ ] Avaliar se o áudio bruto (antes da transcrição) precisa ser retido após gerar o texto — se não, descartar logo após `voice_service.py` transcrever.
- [ ] Confirmar se os provedores de IA (Anthropic, Google, xAI) retêm o conteúdo enviado e por quanto tempo — isso deve constar na Política de Privacidade.

## 6. Segurança técnica
- [x] RLS já ativo em `public.dreams` e `public.episodes` (ownership por usuário) — mantido, não desabilitar (regra já existe no `CLAUDE.md`).
- [ ] Confirmar que `SUPABASE_KEY`/`service_role` usada no backend nunca é exposta ao cliente (checar `database.py`).
- [ ] Criptografia em trânsito (HTTPS já via Render/Vercel) e, se possível, avaliar criptografia adicional em repouso para o campo `relato`.
- [ ] Log de acesso: registrar quem/quando acessou dados sensíveis para fins de auditoria (ANPD tem priorizado fiscalização de dado de saúde + IA em 2026–2027).

## 7. Uso de IA (ponto de atenção específico da ANPD 2026–2027)
A ANPD definiu IA como eixo prioritário de fiscalização, com foco em dados sensíveis tratados por sistemas de IA.

- [ ] Documentar formalmente o papel de cada provedor de IA como operador de dados (Anthropic, Google/Gemini, xAI) — idealmente com DPA (Data Processing Agreement) assinado.
- [ ] Informar ao usuário, na política, que a resposta é gerada por IA e pode envolver processamento fora do Brasil (transferência internacional de dado sensível — art. 33).
- [ ] Considerar Relatório de Impacto à Proteção de Dados Pessoais (RIPD) dado o volume de dado sensível processado por IA — recomendado mesmo sem obrigatoriedade explícita ainda regulamentada.

## 8. Encarregado (DPO)
- [ ] Nomear encarregado de dados (mesmo informal, pode ser o próprio responsável pelo produto) e publicar canal de contato — obrigatório mesmo para operações pequenas.

## Observação legal
Este checklist é um ponto de partida técnico-organizacional baseado em fontes públicas atuais; não substitui análise de um advogado especializado em proteção de dados antes de publicar a Política de Privacidade ou o fluxo de consentimento.

---

**Fontes consultadas:**
- [Dados sensíveis — LGPD (Serpro)](https://www.serpro.gov.br/lgpd/menu/protecao-de-dados/dados-sensiveis-lgpd)
- [Tratamento de dados em saúde: Bases legais, limites e boas práticas (Migalhas)](https://www.migalhas.com.br/depeso/449916/tratamento-de-dados-em-saude-bases-legais-limites-e-boas-praticas)
- [Desenvolver Aplicativo de Saúde: LGPD e ANVISA em 2026](https://www.mestresdaweb.com.br/tecnologias/como-desenvolver-aplicativo-de-saude)
- [Agenda regulatória 2025-2026 da ANPD destaca 16 temas (Machado Meyer)](https://www.machadomeyer.com.br/pt/inteligencia-juridica/publicacoes-ij/direito-digital/agenda-regulatoria-2025-2026-da-anpd-destaca-16-temas)
- [ANPD e Regulação de IA no Brasil: Guia 2026-2027 (Confidata)](https://confidata.com.br/blog/anpd-regulacao-ia-brasil-2026-2027)
- [LGPD em 2026: o que a ANPD espera das organizações brasileiras (Confidata)](https://confidata.com.br/blog/lgpd-2026-o-que-anpd-espera)
