# Design da voz de narração — Aion

## Voz ativa em produção

- **Nome interno (ElevenLabs):** Aion - Narrador Principal
- **voice_id:** `tAkJipX1HdgNSt3HObzr`
- **Criada em:** 2026-07-25
- **Modelo de síntese:** eleven_multilingual_v2

> Verificado em produção em 2026-07-26: o `voice_id` acima é o efetivamente
> usado pelo backend — confirmado pela linha gravada em `narracao_cache`
> (coluna `voice_id`) após a primeira narração real.

## Prompt de Voice Design usado

> A native Brazilian Portuguese male voice, early fifties, low-pitched and
> warm with a slight natural rasp. He speaks slowly and deliberately, leaving
> unhurried pauses between clauses, like an experienced analyst thinking aloud
> at the end of a long session. Intellectually serious but never cold: curious,
> attentive, quietly reassuring. Neutral São Paulo accent, clean articulation,
> even volume. Plain and grounded delivery — no theatrical emphasis, no
> whispering, no soothing meditation-guide cadence. Studio-quality recording,
> close microphone, minimal room tone.

## Texto de preview usado

> A imagem da casa submersa não pede tradução literal. Repare que você não
> tentava escapar da água: você descia. Em Jung, esse movimento costuma
> indicar aproximação de conteúdos que a consciência ainda não integrou.
> Não é mau presságio. É um convite a olhar para aquilo que você vem adiando.

## Parâmetros de geração

- **seed:** NÃO RECUPERÁVEL. O campo não apareceu na interface no momento da
  geração e não foi anotado. Recuperação retroativa confirmada como impossível:
  a API de Voice Design não expõe o seed de uma voz já salva em My Voices.
- **guidance_scale:** NÃO RECUPERÁVEL — mesma situação do seed.

> ⚠️ **Consequência prática:** esta voz é **não determinística e
> irreproduzível**. A cópia salva em My Voices é a única existente. Regerar
> com o mesmo prompt produzirá uma voz de caráter semelhante, porém diferente.
> Não deletar a voz da conta ElevenLabs sem antes ter substituta testada e
> aprovada — ver seção "Como regenerar".
- **Custo da geração:** 290 créditos (três amostras, uma selecionada)

## voice_settings em uso (síntese, não geração)

Preset **`mais_estavel`**, fixado como default em `app/core/config.py`
após a calibração de 2026-07-26.

| Parâmetro | Valor |
|---|---|
| stability | 0.80 |
| similarity_boost | 0.75 |
| style | 0.05 |
| speed | 0.92 |

## Variantes testadas e descartadas

- Voz 2: descartada — fugiu do contexto esperado de como a voz deveria soar.
- Voz 3: descartada — mesmo motivo da Voz 2.

## Calibração de voice_settings (2026-07-26)

Material gerado por `backend/scripts/calibrar_voz.py` sobre **duas
interpretações reais** do banco (1.994 e 2.754 chars), truncadas em 600
caracteres por amostra para economia de crédito. Arquivos em
`backend/scripts/calibracao_out/` (fora do versionamento).

| Preset | stability | similarity_boost | style | speed |
|---|---|---|---|---|
| baseline | 0.60 | 0.75 | 0.10 | 0.92 |
| mais_estavel | 0.80 | 0.75 | 0.05 | 0.92 |
| mais_expressivo | 0.40 | 0.75 | 0.35 | 0.92 |
| mais_lento | 0.60 | 0.75 | 0.10 | 0.85 |
| similaridade_alta | 0.60 | 0.95 | 0.10 | 0.92 |

- **Preset escolhido:** `mais_estavel` (stability 0.80 / style 0.05)
- **Motivo da escolha:** todos os presets soaram igualmente bons na amostra de
  600 caracteres. A escolha recai sobre o preset que erra para o lado mais
  seguro quando escalado para o tamanho real de produção (~2.400 chars), em vez
  do que tem maior variância potencial. Decisão de risco, não de preferência
  estética.

Consumo da calibração: ~6.000 caracteres (10 amostras × 600 chars).

## Como regenerar

Se o seed foi capturado: mesmo prompt + mesmo seed no endpoint de Voice
Design reproduz a voz de forma determinística.

Se o seed não foi capturado: uma nova geração produzirá voz de caráter
semelhante, não idêntica. A voz salva em My Voices é a única cópia —
não deletar sem backup do áudio de preview e sem gerar substituta testada.

## Segurança

O `voice_id` não é segredo e pode permanecer versionado neste documento e em
código. A `ELEVENLABS_API_KEY` é provisionada exclusivamente como variável de
ambiente no Render e no `.env` local (não versionado) — nunca em código,
teste, fixture, log ou mensagem de commit.
