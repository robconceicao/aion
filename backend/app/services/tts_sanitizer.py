"""
Sanitização de texto para TTS (ElevenLabs).

O texto exibido na tela (interpretacao_narrativa) pode conter marcação leve
que o LLM às vezes insere apesar do prompt pedir "texto corrido". Sintetizar
esse texto sem limpar faz o TTS ler literalmente "asterisco" ou pausar
errado em cada quebra de linha.
"""
import re


def sanitize_for_tts(text: str) -> str:
    """Remove marcação markdown e normaliza espaçamento para síntese de voz.

    Ordem importa: blocos de código e links são resolvidos antes dos
    marcadores de ênfase, para não deixar `**`/`*` residuais dentro deles.
    """
    if not text:
        return ""

    result = text

    # Blocos de código ``` ... ``` e inline `código` — mantém o conteúdo.
    result = re.sub(r"```([\s\S]*?)```", r"\1", result)
    result = re.sub(r"`([^`]*)`", r"\1", result)

    # Links markdown [texto](url) — mantém apenas o texto âncora.
    result = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", result)

    # URLs soltas (http/https) — removidas, não fazem sentido faladas.
    result = re.sub(r"https?://\S+", "", result)

    # Ênfase: **negrito**, __negrito__, *itálico*, _itálico_ — mantém o texto.
    result = re.sub(r"(\*\*|__)(.*?)\1", r"\2", result)
    result = re.sub(r"(\*|_)(.*?)\1", r"\2", result)

    # Headers (#, ##, ...), bullets (-, *) e blockquote (>) no início de linha.
    result = re.sub(r"^\s{0,3}#{1,6}\s*", "", result, flags=re.MULTILINE)
    result = re.sub(r"^\s{0,3}[-*]\s+", "", result, flags=re.MULTILINE)
    result = re.sub(r"^\s{0,3}>\s?", "", result, flags=re.MULTILINE)

    # Quebras de linha múltiplas → pausa única (uma quebra de linha).
    result = re.sub(r"\n{2,}", "\n", result)

    # Espaços múltiplos → um espaço; trim geral.
    result = re.sub(r"[ \t]{2,}", " ", result)
    result = "\n".join(line.strip() for line in result.split("\n"))
    result = result.strip()

    return result
