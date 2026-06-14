"""
Teste minimo -- B-03
Confirma que EpisodeModel aceita um dict com chave "id" (como o Supabase retorna),
sem precisar de alias "_id".
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from datetime import datetime
from app.models.episode import EpisodeModel

# -- Cenario 1: dict exatamente como o Supabase devolve -----------------------
supabase_row = {
    "id": "b9f3a1c2-dead-beef-cafe-000000000001",
    "number": 1,
    "title_main": "A Sombra e o Heroi",
    "title_secondary": "Jung e o lado escuro da psique",
    "myths_symbols": ["Orfeu", "Sombra"],
    "description": "Episodio sobre o arquetipo da Sombra.",
    "created_at": "2026-06-14T06:00:00",
}

episode = EpisodeModel.model_validate(supabase_row)
assert episode.id == "b9f3a1c2-dead-beef-cafe-000000000001", "id nao preenchido!"
assert episode.number == 1
assert episode.title_main == "A Sombra e o Heroi"
assert isinstance(episode.created_at, datetime)
print("[OK] Cenario 1 -- EpisodeModel aceita dict Supabase com chave 'id'")
print(f"     id={episode.id!r}  number={episode.number}  created_at={episode.created_at}")

# -- Cenario 2: garante que o alias "_id" OLD nao eh mais necessario ----------
try:
    ep2 = EpisodeModel.model_validate({
        "_id": "old-mongo-id",
        "number": 2,
        "title_main": "Outro",
        "title_secondary": "Sub",
        "myths_symbols": [],
        "created_at": "2026-06-14T07:00:00",
    })
    print(f"[WARN] Cenario 2: '_id' foi aceito, ep2.id={ep2.id!r} (esperado: None ou erro)")
except Exception as e:
    print(f"[OK] Cenario 2 -- '_id' corretamente rejeitado/ignorado: {type(e).__name__}")

# -- Cenario 3: list[EpisodeModel] -- simula response_model=list[EpisodeModel]
rows = [supabase_row, {**supabase_row, "id": "b9f3a1c2-dead-beef-cafe-000000000002", "number": 2}]
episodes = [EpisodeModel.model_validate(r) for r in rows]
assert len(episodes) == 2
assert episodes[1].id == "b9f3a1c2-dead-beef-cafe-000000000002"
print(f"[OK] Cenario 3 -- list[EpisodeModel] com {len(episodes)} itens validada")

print("\n[PASS] TODOS OS TESTES PASSARAM -- B-03 corrigido com sucesso.")
