"""
Script de DEV para calibração de voz da ElevenLabs (Fase 4).

Gera o MESMO texto com N configurações de voz diferentes, salvando os MP3
lado a lado para comparação auditiva humana. A escolha final de voice_id e
voice_settings é HUMANA — este script apenas prepara o material.

NÃO é um endpoint. Não roda em produção. Não é importado pela aplicação.

Uso:
    # texto vem de uma interpretação real no banco (recomendado)
    python scripts/calibrar_voz.py --dream-id <uuid>

    # ou de um arquivo .txt com uma interpretação real já exportada
    python scripts/calibrar_voz.py --arquivo interpretacao.txt

    # limitar quantos caracteres sintetizar (economiza credito na calibração)
    python scripts/calibrar_voz.py --dream-id <uuid> --max-chars 600

Requer ELEVENLABS_API_KEY e ELEVENLABS_VOICE_ID no ambiente (.env não versionado).
Para comparar vozes diferentes, passe --voice-ids id1,id2,id3.

Saída: backend/scripts/calibracao_out/<voice_id>__<preset>.mp3
"""
import argparse
import asyncio
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import httpx

from app.core.config import settings
from app.services.tts_sanitizer import sanitize_for_tts

OUT_DIR = os.path.join(os.path.dirname(__file__), "calibracao_out")

# Presets a comparar. O primeiro é o default atual da config (baseline).
# Ajuste/adicione presets conforme a escuta for orientando.
PRESETS = {
    "baseline": {"stability": 0.60, "similarity_boost": 0.75, "style": 0.10, "speed": 0.92},
    "mais_estavel": {"stability": 0.80, "similarity_boost": 0.75, "style": 0.05, "speed": 0.92},
    "mais_expressivo": {"stability": 0.40, "similarity_boost": 0.75, "style": 0.35, "speed": 0.92},
    "mais_lento": {"stability": 0.60, "similarity_boost": 0.75, "style": 0.10, "speed": 0.85},
    "similaridade_alta": {"stability": 0.60, "similarity_boost": 0.95, "style": 0.10, "speed": 0.92},
}


def carregar_texto_do_banco(dream_id: str) -> str:
    """Busca interpretacao_narrativa real no Supabase (service_role)."""
    from app.database import get_supabase_service

    supabase = get_supabase_service()
    res = (
        supabase.table("dreams")
        .select("interpretacao_narrativa")
        .eq("id", dream_id)
        .single()
        .execute()
    )
    if not res.data or not (res.data.get("interpretacao_narrativa") or "").strip():
        raise SystemExit(f"Sonho {dream_id} sem interpretacao_narrativa.")
    return res.data["interpretacao_narrativa"]


async def gerar(voice_id: str, preset_nome: str, voice_settings: dict, texto: str) -> None:
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream"
    headers = {
        "xi-api-key": settings.ELEVENLABS_API_KEY,
        "Content-Type": "application/json",
    }
    payload = {
        "text": texto,
        "model_id": settings.ELEVENLABS_MODEL_ID,
        "voice_settings": voice_settings,
    }
    params = {"output_format": settings.ELEVENLABS_OUTPUT_FORMAT}

    async with httpx.AsyncClient(timeout=120.0) as client:
        res = await client.post(url, headers=headers, params=params, json=payload)

    if res.status_code != 200:
        # Nunca imprime headers (contêm a chave).
        print(f"  [FALHA] {voice_id}/{preset_nome}: HTTP {res.status_code} {res.text[:160]}")
        return

    destino = os.path.join(OUT_DIR, f"{voice_id}__{preset_nome}.mp3")
    with open(destino, "wb") as f:
        f.write(res.content)
    print(f"  [OK] {destino} ({len(res.content)} bytes)")


async def main() -> None:
    parser = argparse.ArgumentParser(description="Calibração de voz ElevenLabs (dev)")
    origem = parser.add_mutually_exclusive_group(required=True)
    origem.add_argument("--dream-id", help="UUID de um sonho real com interpretacao_narrativa")
    origem.add_argument("--arquivo", help="Arquivo .txt com uma interpretação real")
    parser.add_argument(
        "--voice-ids",
        default="",
        help="IDs de voz separados por vírgula (default: ELEVENLABS_VOICE_ID do ambiente)",
    )
    parser.add_argument(
        "--max-chars",
        type=int,
        default=0,
        help="Trunca o texto para economizar crédito na calibração (0 = texto inteiro)",
    )
    args = parser.parse_args()

    if not settings.ELEVENLABS_API_KEY:
        raise SystemExit("ELEVENLABS_API_KEY ausente no ambiente.")

    voice_ids = [v.strip() for v in args.voice_ids.split(",") if v.strip()]
    if not voice_ids:
        if not settings.ELEVENLABS_VOICE_ID:
            raise SystemExit("Informe --voice-ids ou configure ELEVENLABS_VOICE_ID.")
        voice_ids = [settings.ELEVENLABS_VOICE_ID]

    if args.dream_id:
        texto_bruto = carregar_texto_do_banco(args.dream_id)
    else:
        with open(args.arquivo, encoding="utf-8") as f:
            texto_bruto = f.read()

    # Mesmo sanitizador do fluxo de produção — calibrar sobre o texto real enviado.
    texto = sanitize_for_tts(texto_bruto)
    if args.max_chars > 0:
        texto = texto[: args.max_chars]

    os.makedirs(OUT_DIR, exist_ok=True)

    total = len(voice_ids) * len(PRESETS)
    custo_chars = len(texto) * total
    print(f"Texto sanitizado: {len(texto)} chars")
    print(f"Combinações: {len(voice_ids)} voz(es) x {len(PRESETS)} presets = {total} arquivos")
    print(f"Consumo estimado: ~{custo_chars} caracteres de crédito ElevenLabs")
    print(f"Saída: {OUT_DIR}\n")

    for voice_id in voice_ids:
        print(f"Voz {voice_id}:")
        for preset_nome, voice_settings in PRESETS.items():
            await gerar(voice_id, preset_nome, voice_settings, texto)

    # Manifesto para rastrear qual arquivo corresponde a qual configuração.
    manifesto = {
        "model_id": settings.ELEVENLABS_MODEL_ID,
        "output_format": settings.ELEVENLABS_OUTPUT_FORMAT,
        "chars_sintetizados": len(texto),
        "voice_ids": voice_ids,
        "presets": PRESETS,
    }
    with open(os.path.join(OUT_DIR, "manifesto.json"), "w", encoding="utf-8") as f:
        json.dump(manifesto, f, ensure_ascii=False, indent=2)

    print("\nEscute os arquivos e escolha voice_id + preset.")
    print("Depois fixe em ELEVENLABS_VOICE_ID / ELEVENLABS_STABILITY / etc. no Render.")


if __name__ == "__main__":
    asyncio.run(main())
