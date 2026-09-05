# AION — Checklist de QA Mobile (Tester)

**Versão:** 1.0 · **Data de referência:** 2026-07-18  
**Build a testar:** `main` (commits com responsividade + busca limpa + TTS nativo)  
**Tempo estimado:** ~25–35 min (rápido) · ~50–60 min (completo com 2 devices)

---

## Como usar

1. Preencha o cabeçalho abaixo.
2. Marque cada linha com:
   - `[x]` **Pass**
   - `[ ]` **Fail** (descreva na coluna Observação / no fim)
   - `N/A` se não se aplicar ao device
3. No fim, preencha o **resultado final** e anexe prints se houver falha.

### Cabeçalho do teste

| Campo | Valor |
|---|---|
| Tester | |
| Data | |
| Build / commit / loja | |
| Device 1 (flagship) | modelo: ______ · SO: ______ |
| Device 2 (entrada) | modelo: ______ · SO: ______ · RAM: ______ |
| Ambiente | [ ] produção · [ ] staging · [ ] local |
| Conta de teste | |

**Legenda de severidade (em falhas):**  
`S1` crash/bloqueio · `S2` feature quebrada · `S3` UX ruim · `S4` cosmético

---

# Setup (2 min)

- [ ] App instalado e abre sem crash
- [ ] Login com conta de teste ok
- [ ] Há **pelo menos 3 sonhos** no diário (se não houver: registrar 3 antes do bloco de busca)
- [ ] Pelo menos **1 sonho com interpretação** (Leitura Simbólica preenchida)
- [ ] Volume do celular em nível audível (~50%)
- [ ] Wi‑Fi/dados disponíveis (exceto onde o caso pede offline)

---

# QA-01 — Responsividade + Acessibilidade + Performance fraca

## 1.1 Layout em portrait (device 1)

Navegar Home → Histórico → Interpretação → Arquétipos → Canal.

| # | Caso | Pass |
|---|---|---|
| 1.1.1 | **Home/Diário:** sem overflow, textos cortados ou botões sobrepostos | [ ] |
| 1.1.2 | Botões Home (Registrar, Histórico, Arquétipos, Canal) fáceis de tocar (dedo) | [ ] |
| 1.1.3 | **Histórico:** campo de busca e filtros usáveis; lista rolável | [ ] |
| 1.1.4 | **Interpretação:** abas INTERPRETAÇÃO / ANÁLISE COMPLETA legíveis; player não corta | [ ] |
| 1.1.5 | Título “Voz do Arquétipo” e texto da leitura sem corte lateral | [ ] |
| 1.1.6 | **Galeria dos Arquétipos:** cards e navegação sem sobreposição | [ ] |
| 1.1.7 | **Canal:** lista/empty state e nav sem overflow | [ ] |
| 1.1.8 | Espaçamento sem “vazio excessivo” que force scroll desnecessário | [ ] |

## 1.2 Landscape (opcional, 1 device)

| # | Caso | Pass |
|---|---|---|
| 1.2.1 | Girar em Home: layout usável | [ ] / N/A |
| 1.2.2 | Girar em Interpretação com texto longo: sem crash | [ ] / N/A |
| 1.2.3 | Girar com TTS tocando: áudio continua ou retoma sem crash | [ ] / N/A |

## 1.3 Acessibilidade — leitor de tela

**Android:** Configurações → Acessibilidade → TalkBack → Ativar  
**iOS:** Ajustes → Acessibilidade → VoiceOver → Ativar

| # | Caso | Pass |
|---|---|---|
| 1.3.1 | TalkBack/VoiceOver ativo; app permanece navegável | [ ] |
| 1.3.2 | Home: cada botão anuncia nome (ex.: “REGISTRAR SONHO”) | [ ] |
| 1.3.3 | Histórico: botão Voltar anuncia “Voltar” (ou similar) | [ ] |
| 1.3.4 | Histórico: botão Atualizar anuncia ação | [ ] |
| 1.3.5 | Campo de busca anuncia algo como “Buscar no diário do sonho” | [ ] |
| 1.3.6 | Filtros (emoção/jornada) são focáveis e anunciam o nome | [ ] |
| 1.3.7 | Card de sonho anuncia data / ação de abrir | [ ] |
| 1.3.8 | Interpretação: botão play anuncia reproduzir/pausar | [ ] |
| 1.3.9 | Interpretação: stop e velocidade são focáveis e anunciados | [ ] |
| 1.3.10 | Arquétipos: cards anunciam nome do arquétipo | [ ] |
| 1.3.11 | Canal/Arquétipos: botões de nav (INÍCIO, + SONHO, etc.) anunciados | [ ] |
| 1.3.12 | Ícones sem texto (voltar, refresh, play, stop, limpar) têm label | [ ] |

*Desligar TalkBack/VoiceOver antes dos próximos blocos se preferir.*

## 1.4 Dynamic Type / fonte grande

**Android:** Tamanho da fonte no máximo (ou display size grande)  
**iOS:** Acessibilidade → Texto maior → quase máximo

| # | Caso | Pass |
|---|---|---|
| 1.4.1 | Home ainda usável (botões e textos legíveis, sem corte grave) | [ ] |
| 1.4.2 | Histórico: busca + lista sem sobreposição crítica | [ ] |
| 1.4.3 | Interpretação: leitura ainda rolável e legível | [ ] |
| 1.4.4 | Nenhum crash com fonte máxima | [ ] |

*Restaurar tamanho de fonte padrão.*

## 1.5 Contraste (tema escuro)

| # | Caso | Pass |
|---|---|---|
| 1.5.1 | Texto principal (leitura/ghost) legível sobre fundo escuro | [ ] |
| 1.5.2 | Botões dourados legíveis (texto sobre gold ou gold sobre dark) | [ ] |
| 1.5.3 | Placeholders/hints legíveis o suficiente para uso | [ ] |
| 1.5.4 | Aviso ético (teal) legível | [ ] |

## 1.6 Performance em device de entrada (Device 2)

| # | Caso | Pass | Tempo (s) |
|---|---|---|---|
| 1.6.1 | Abertura Home após login (meta &lt; 2s na UI interativa) | [ ] | ___ |
| 1.6.2 | Abertura Histórico (meta &lt; 2s até lista/skeleton) | [ ] | ___ |
| 1.6.3 | Abertura Interpretação (meta &lt; 2s até texto) | [ ] | ___ |
| 1.6.4 | Abertura Galeria Arquétipos (meta &lt; 2s) | [ ] | ___ |
| 1.6.5 | Abertura Canal (meta &lt; 2s) | [ ] | ___ |
| 1.6.6 | Scroll da lista de sonhos suave (sem travar &gt; 1s) | [ ] | |
| 1.6.7 | Scroll da Galeria de Arquétipos suave | [ ] | |
| 1.6.8 | Animações de fundo não deixam UI “pesada” demais | [ ] | |
| 1.6.9 | Uso contínuo 10 min: sem crash | [ ] | |
| 1.6.10 | Após 10 min: app ainda responsivo ao toque | [ ] | |

---

# QA-02 — Busca no Diário do Sonho

## 2.1 Busca limpa

| # | Caso | Pass |
|---|---|---|
| 2.1.1 | Campo **não** mostra histórico de pesquisas anteriores do app | [ ] |
| 2.1.2 | Campo **não** sugere chips/palavras automáticas do app (ex.: “perda”) | [ ] |
| 2.1.3 | Placeholder é limpo (ex.: “Buscar no diário...”) sem exemplos de palavras | [ ] |
| 2.1.4 | Teclado **não** força sugestões agressivas do app (só teclado do SO, se houver) | [ ] |

## 2.2 Acessibilidade da busca

| # | Caso | Pass |
|---|---|---|
| 2.2.1 | Com leitor de tela: focar o campo e digitar um termo | [ ] |
| 2.2.2 | Submeter busca (ação “buscar” do teclado) funciona | [ ] |
| 2.2.3 | Botão limpar (X) anunciado e limpa a busca | [ ] |

## 2.3 Funcional + bordas

| # | Caso | Pass | Observação |
|---|---|---|---|
| 2.3.1 | Busca termo comum presente nos sonhos (ex.: palavra do relato) | [ ] | |
| 2.3.2 | Busca termo incomum / sem resultado → mensagem de vazio | [ ] | |
| 2.3.3 | Busca com acentos (ex.: `coração`, `ânsia`) | [ ] | |
| 2.3.4 | Busca com caracteres especiais (`@#&"'-`) sem crash | [ ] | |
| 2.3.5 | Busca com texto **muito longo** (colar ~300 caracteres) sem crash | [ ] | |
| 2.3.6 | Limpar campo (X) restaura lista normal | [ ] | |
| 2.3.7 | Filtro por emoção funciona sozinho | [ ] | |
| 2.3.8 | Filtro por jornada funciona sozinho | [ ] | |
| 2.3.9 | Alternar rápido: busca → filtro emoção → “Todos” → outra busca | [ ] | |
| 2.3.10 | Filtro + lista permanece estável (sem tela branca/crash) | [ ] | |

## 2.4 Performance da busca (Device 2)

| # | Caso | Pass | Tempo (s) |
|---|---|---|---|
| 2.4.1 | Busca com poucos sonhos (meta: resposta aceitável &lt; 5s) | [ ] | ___ |
| 2.4.2 | Se possível, com **muitos** sonhos (&gt;20): busca ainda usável | [ ] / N/A | ___ |
| 2.4.3 | Loading no campo (spinner) aparece durante busca | [ ] | |

---

# QA-03 — Text-to-Speech (Interpretação AION)

Pré: abrir um sonho com **Leitura Simbólica** preenchida (aba Interpretação).

## 3.1 Happy path

| # | Caso | Pass |
|---|---|---|
| 3.1.1 | Botão play **não** mostra “ÁUDIO INDISPONÍVEL” no estado inicial (mostra “ESCUTAR…”) | [ ] |
| 3.1.2 | Ao tocar play: estado de preparando / narrando | [ ] |
| 3.1.3 | Voz lê a **Leitura Simbólica** (não a análise completa) | [ ] |
| 3.1.4 | Qualidade de voz aceitável (inteligível em pt-BR se disponível) | [ ] |
| 3.1.5 | Pause funciona | [ ] |
| 3.1.6 | Continuar / play de novo funciona | [ ] |
| 3.1.7 | Stop interrompe a qualquer momento | [ ] |
| 3.1.8 | Alternar velocidade 0.8× / 1× / 1.2× altera a fala (ou na próxima fala) | [ ] |
| 3.1.9 | UI permanece responsiva enquanto narra (rolar texto, trocar aba) | [ ] |

## 3.2 Acessibilidade do player

| # | Caso | Pass |
|---|---|---|
| 3.2.1 | TalkBack/VoiceOver foca o botão de play e ativa | [ ] |
| 3.2.2 | Estado play/pause é compreensível (anúncio ou label muda) | [ ] |
| 3.2.3 | Stop e velocidade controláveis só com gestos de acessibilidade | [ ] |

## 3.3 Bordas e erro

| # | Caso | Pass |
|---|---|---|
| 3.3.1 | Volume no mínimo: app não crasha (áudio inaudível ok) | [ ] |
| 3.3.2 | Iniciar/parar TTS **5 vezes seguidas**: estável | [ ] |
| 3.3.3 | Durante narração: **Voltar** → áudio **para** | [ ] |
| 3.3.4 | Durante narração: sair da tela (pop) → áudio **para** | [ ] |
| 3.3.5 | Girar orientação durante narração: sem crash | [ ] / N/A |
| 3.3.6 | **Modo avião** (sem rede): TTS ainda funciona (é nativo) | [ ] |
| 3.3.7 | Sonho **sem** leitura simbólica: mensagem clara (não crash) | [ ] / N/A |
| 3.3.8 | *(Opcional)* Desativar TTS do SO / sem engine: mensagem amigável | [ ] / N/A |

## 3.4 Performance TTS (Device 2)

| # | Caso | Pass |
|---|---|---|
| 3.4.1 | Iniciar narração em device fraco: sem freeze &gt; 3s | [ ] |
| 3.4.2 | App continua rolável durante TTS | [ ] |
| 3.4.3 | Após várias narrações: sem lentidão grave | [ ] |
| 3.4.4 | Observação subjetiva: sem aquecimento extremo em 5 min de TTS | [ ] |

---

# QA-04 — Regressão geral

## 4.1 Fluxos principais

| # | Caso | Pass | Observação |
|---|---|---|---|
| 4.1.1 | **Criar novo sonho** (texto) e concluir fluxo até ver resultado | [ ] | |
| 4.1.2 | Novo sonho **aparece no Histórico** | [ ] | |
| 4.1.3 | Abrir sonho → **Interpretação** carrega (abas ok) | [ ] | |
| 4.1.4 | Aba **Análise Completa** abre (ou aviso legacy se antigo) | [ ] | |
| 4.1.5 | Navegação Home ↔ Histórico ↔ Arquétipos ↔ Canal sem erro | [ ] | |
| 4.1.6 | Galeria: abrir detalhe de um arquétipo e voltar | [ ] | |
| 4.1.7 | Canal: lista ou empty state sem crash | [ ] | |
| 4.1.8 | Login/sessão: após matar o app e reabrir, ainda autenticado (se esperado) | [ ] | |

## 4.2 Integração E2E (obrigatório)

| # | Caso | Pass |
|---|---|---|
| 4.2.1 | Fluxo: **criar sonho** → **buscar no diário** → **abrir interpretação** → **ouvir TTS** → **voltar** | [ ] |
| 4.2.2 | Mesmo fluxo no **Device 2** (entrada) | [ ] |

## 4.3 Itens de regressão relacionados às mudanças

| # | Caso | Pass |
|---|---|---|
| 4.3.1 | Busca ainda funciona após gravar sonho novo | [ ] |
| 4.3.2 | Filtros de emoção/jornada não quebrados | [ ] |
| 4.3.3 | Transições de tela sem tela preta/travada | [ ] |
| 4.3.4 | Nenhum botão principal “morto” (sem resposta) | [ ] |
| 4.3.5 | Sem crash ao alternar abas Interpretação / Análise com TTS ativo | [ ] |

## 4.4 Uso prolongado

| # | Caso | Pass |
|---|---|---|
| 4.4.1 | 10 min de uso misto (navegar + busca + TTS): sem crash | [ ] |
| 4.4.2 | Após isso, Home ainda abre rápido o suficiente | [ ] |

---

# Bugs encontrados

| ID | Severidade | Tela | Passos | Esperado | Obtido | Device |
|---|---|---|---|---|---|---|
| B1 | | | | | | |
| B2 | | | | | | |
| B3 | | | | | | |

---

# Resultado final

| Bloco | Pass | Fail | N/A | Status bloco |
|---|---|---|---|---|
| QA-01 Responsividade / A11y / Perf | __ | __ | __ | [ ] OK · [ ] NOK |
| QA-02 Busca | __ | __ | __ | [ ] OK · [ ] NOK |
| QA-03 TTS | __ | __ | __ | [ ] OK · [ ] NOK |
| QA-04 Regressão | __ | __ | __ | [ ] OK · [ ] NOK |

### Critérios de aceite (assinatura do tester)

- [ ] App responsivo e usável no(s) device(s) testado(s)
- [ ] Acessibilidade básica (TalkBack/VoiceOver) ok nos fluxos principais
- [ ] Busca limpa (sem histórico/sugestões do app)
- [ ] TTS narra Leitura Simbólica com controles ok
- [ ] Nenhum fluxo principal quebrado (regressão)
- [ ] Desempenho aceitável no device de entrada (sem travamentos graves)

**Veredito:** [ ] **APROVADO** · [ ] **APROVADO COM RESSALVAS** · [ ] **REPROVADO**

**Assinatura tester:** _________________ **Data:** ________

**Ressalvas / notas finais:**

```
(escrever aqui)
```

---

## Roteiro cronometrado (atalho ~25 min)

Se o tempo for curto, rode **nesta ordem**:

| Min | O quê |
|---|---|
| 0–2 | Setup + 3 sonhos se necessário |
| 2–7 | QA-01 layout (todas as telas portrait) |
| 7–12 | QA-01 TalkBack/VoiceOver só Home + Histórico + Interpretação |
| 12–17 | QA-02 busca (limpo + bordas + empty) |
| 17–23 | QA-03 TTS happy path + stop ao voltar + 5× play/stop |
| 23–30 | QA-04 E2E criar → buscar → ouvir → voltar (+ device 2 se houver) |

---

## Evidências recomendadas (em falha)

1. Print da tela  
2. Modelo + SO  
3. Passos 1–2–3  
4. Severidade S1–S4  
5. Se TTS: se o engine de voz do SO está instalado (pt-BR)
