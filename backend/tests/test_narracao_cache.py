import unittest
from unittest.mock import MagicMock

from app.services.narracao_cache import (
    compute_cache_key,
    get_cached_narracao,
    save_narracao_cache,
    count_generations_today,
)


class TestComputeCacheKey(unittest.TestCase):
    def test_deterministic_for_same_inputs(self):
        settings = {"stability": 0.6, "similarity_boost": 0.75, "style": 0.1, "speed": 0.92}
        key1 = compute_cache_key("texto", "voice-a", "model-a", settings)
        key2 = compute_cache_key("texto", "voice-a", "model-a", settings)
        self.assertEqual(key1, key2)

    def test_key_order_in_voice_settings_does_not_change_hash(self):
        settings_a = {"stability": 0.6, "similarity_boost": 0.75}
        settings_b = {"similarity_boost": 0.75, "stability": 0.6}
        key_a = compute_cache_key("texto", "voice-a", "model-a", settings_a)
        key_b = compute_cache_key("texto", "voice-a", "model-a", settings_b)
        self.assertEqual(key_a, key_b)

    def test_different_text_changes_hash(self):
        settings = {"stability": 0.6}
        key_a = compute_cache_key("texto um", "voice-a", "model-a", settings)
        key_b = compute_cache_key("texto dois", "voice-a", "model-a", settings)
        self.assertNotEqual(key_a, key_b)

    def test_different_voice_id_changes_hash(self):
        settings = {"stability": 0.6}
        key_a = compute_cache_key("texto", "voice-a", "model-a", settings)
        key_b = compute_cache_key("texto", "voice-b", "model-a", settings)
        self.assertNotEqual(key_a, key_b)

    def test_different_voice_settings_changes_hash(self):
        key_a = compute_cache_key("texto", "voice-a", "model-a", {"stability": 0.6})
        key_b = compute_cache_key("texto", "voice-a", "model-a", {"stability": 0.9})
        self.assertNotEqual(key_a, key_b)


def _fake_supabase_select(return_rows):
    supabase = MagicMock()
    query = MagicMock()
    supabase.table.return_value = query
    query.select.return_value = query
    query.eq.return_value = query
    query.gte.return_value = query
    query.limit.return_value = query
    result = MagicMock()
    result.data = return_rows
    result.count = len(return_rows)
    query.execute.return_value = result
    return supabase


class TestGetCachedNarracao(unittest.TestCase):
    def test_returns_none_on_cache_miss(self):
        supabase = _fake_supabase_select([])
        result = get_cached_narracao(supabase, "some-hash")
        self.assertIsNone(result)

    def test_returns_row_on_cache_hit(self):
        row = {"storage_path": "elevenlabs/user/hash.mp3", "duracao_segundos": 42.0}
        supabase = _fake_supabase_select([row])
        result = get_cached_narracao(supabase, "some-hash")
        self.assertEqual(result, row)


class TestCountGenerationsToday(unittest.TestCase):
    def test_counts_rows_returned(self):
        supabase = _fake_supabase_select([{"id": "1"}, {"id": "2"}, {"id": "3"}])
        count = count_generations_today(supabase, "user-1", "elevenlabs")
        self.assertEqual(count, 3)

    def test_zero_when_no_rows(self):
        supabase = _fake_supabase_select([])
        count = count_generations_today(supabase, "user-1", "elevenlabs")
        self.assertEqual(count, 0)


class TestSaveNarracaoCache(unittest.TestCase):
    def test_inserts_expected_fields(self):
        supabase = MagicMock()
        query = MagicMock()
        supabase.table.return_value = query
        query.insert.return_value = query
        query.execute.return_value = MagicMock()

        save_narracao_cache(
            supabase,
            dream_id="dream-1",
            user_id="user-1",
            provider="elevenlabs",
            cache_key="hash-abc",
            storage_path="elevenlabs/user-1/hash-abc.mp3",
            voice_id="voice-a",
            model_id="eleven_multilingual_v2",
            duracao_segundos=12.3,
        )

        supabase.table.assert_called_with("narracao_cache")
        inserted = query.insert.call_args[0][0]
        self.assertEqual(inserted["dream_id"], "dream-1")
        self.assertEqual(inserted["user_id"], "user-1")
        self.assertEqual(inserted["provider"], "elevenlabs")
        self.assertEqual(inserted["cache_key"], "hash-abc")
        self.assertEqual(inserted["storage_path"], "elevenlabs/user-1/hash-abc.mp3")
        self.assertEqual(inserted["duracao_segundos"], 12.3)


if __name__ == "__main__":
    unittest.main()
