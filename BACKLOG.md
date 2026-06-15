# Backlog — Aion

Itens registrados durante a auditoria. Não são bugs em aberto; são features
removidas/adiadas que valem implementar com o pacote completo.

## Favoritar sonhos
Removido o contador "FAVORITOS" da dashboard (M-03) porque a coluna não existia.
Para implementar de verdade:
- Coluna `is_favorite boolean default false` em `dreams` (migration nova).
- Endpoint para marcar/desmarcar favorito (PATCH em `/dreams/{id}`).
- Botão de favoritar na UI (tela do sonho e/ou diário).
- Restaurar o contador na dashboard lendo `is_favorite`.

## Arquétipo predominante
Removido o contador "ARQUÉTIPO" da dashboard (M-03) pelo mesmo motivo.
Para implementar de verdade:
- Coluna `main_archetype text` em `dreams` (migration nova).
- No backend, extrair o arquétipo principal da interpretação e gravar em
  `main_archetype` no insert do sonho.
- Restaurar o contador agregando `main_archetype` na dashboard.

## Observações de auditoria (a investigar, não confirmados)
- `_searchResults` / `_showSearchResults` aparecem como "não usados" em
  dream_diary_screen.dart — possível UI de resultados da busca semântica
  incompleta. Confirmar ao testar a busca no app.