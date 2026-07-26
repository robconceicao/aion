import unittest
from app.services.tts_sanitizer import sanitize_for_tts

# Exemplo real de interpretacao_narrativa retornado pelo pipeline de síntese
# (POST /dreams/, resposta real capturada em teste manual — sonho de floresta escura).
REAL_NARRATIVE_SAMPLE = (
    "Você entra em uma floresta escura — este é o cenário da sua própria mente "
    "quando ela enfrenta o desconhecido, quando você se depara com aquilo que "
    "ainda não compreende de si mesmo. Esta escuridão não é má; ela é simplesmente "
    "o terreno onde as coisas ainda não foram vistas, compreendidas, integradas.\n\n"
    "E no meio dessa escuridão, você enxerga uma luz. Isto é profundamente "
    "significativo: uma parte sua sabe exatamente para onde ir. Essa luz é você "
    "em sua plenitude — a pessoa que você está destinado a se tornar, mais sábio, "
    "mais completo, mais autêntico. Seu coração já conhece essa direção.\n\n"
    "Mas quando você começa a caminhar na direção daquela luz, algo estranho "
    "acontece: o caminho parece não terminar nunca."
)


class TestSanitizeForTts(unittest.TestCase):
    def test_real_pipeline_sample_collapses_double_newlines(self):
        result = sanitize_for_tts(REAL_NARRATIVE_SAMPLE)
        self.assertNotIn("\n\n", result)
        self.assertIn("Você entra em uma floresta escura", result)
        self.assertIn("Mas quando você começa a caminhar", result)

    def test_real_pipeline_sample_has_no_stray_whitespace(self):
        result = sanitize_for_tts(REAL_NARRATIVE_SAMPLE)
        self.assertEqual(result, result.strip())
        self.assertNotIn("  ", result)

    def test_removes_bold_and_italic_markers(self):
        result = sanitize_for_tts("Isso é **muito** importante, e *também* isso.")
        self.assertEqual(result, "Isso é muito importante, e também isso.")

    def test_removes_headers(self):
        result = sanitize_for_tts("## Título\nTexto normal.")
        self.assertNotIn("#", result)
        self.assertIn("Título", result)
        self.assertIn("Texto normal.", result)

    def test_removes_bullet_markers(self):
        result = sanitize_for_tts("- primeiro item\n- segundo item")
        self.assertNotIn("- ", result)
        self.assertIn("primeiro item", result)
        self.assertIn("segundo item", result)

    def test_removes_blockquote_markers(self):
        result = sanitize_for_tts("> uma citação")
        self.assertFalse(result.startswith(">"))
        self.assertIn("uma citação", result)

    def test_removes_inline_and_block_code(self):
        result = sanitize_for_tts("Use `codigo()` ou ```bloco de codigo```.")
        self.assertNotIn("`", result)
        self.assertIn("codigo()", result)
        self.assertIn("bloco de codigo", result)

    def test_markdown_link_keeps_anchor_text_drops_url(self):
        result = sanitize_for_tts("Veja [este link](https://exemplo.com/pagina).")
        self.assertIn("este link", result)
        self.assertNotIn("https://", result)
        self.assertNotIn("(", result)

    def test_bare_url_is_removed(self):
        result = sanitize_for_tts("Acesse https://exemplo.com/pagina para saber mais.")
        self.assertNotIn("https://", result)
        self.assertIn("Acesse", result)
        self.assertIn("para saber mais.", result)

    def test_empty_and_none_safe(self):
        self.assertEqual(sanitize_for_tts(""), "")
        self.assertEqual(sanitize_for_tts(None), "")

    def test_multiple_blank_lines_become_single_newline(self):
        result = sanitize_for_tts("Parágrafo um.\n\n\n\nParágrafo dois.")
        self.assertEqual(result, "Parágrafo um.\nParágrafo dois.")


if __name__ == "__main__":
    unittest.main()
