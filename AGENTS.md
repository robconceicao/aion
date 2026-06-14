# Aion — Regras do projeto (lidas em todo prompt)

Stack: Flutter (cliente) / FastAPI (backend) / Supabase com pgvector.
App de análise de sonhos com interpretação junguiana.

## Invariantes do produto
- Fluxo de interpretação dual: Mapa Arquetípico + Leitura Simbólica. As duas
  precisam funcionar de forma independente — a falha de uma não pode pendurar a UI.
- Modo Entrevista é sessão longa: a sessão JWT do Supabase precisa sobreviver e
  refrescar durante a entrevista. Perder uma entrevista em andamento é inaceitável.
- Busca semântica via pgvector; detecção de sonhos recorrentes; trilha da Jornada
  do Herói; push notifications.

## Hygiene e resiliência
- Nenhuma API key hardcoded; segredos via env.
- Provedores de LLM podem estar sem quota/credito — o app degrada com mensagem
  clara, nunca crasha.

## Disciplina de execução
- Antes de editar qualquer arquivo: `git status` limpo. Havendo mudança não
  commitada, PARE e avise — nunca sobrescreva trabalho não commitado.
- Toda mudança: DIFF antes de aplicar, espere aprovação explícita.
- Nada pronto sem rodar a verificação e colar a saída real.