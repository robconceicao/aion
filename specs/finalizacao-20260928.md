# Finalização de homologação — 28/09/2026

A autorização atual inclui corrigir pendências, validar e gerar novos APKs de teste.
Licenciamento oficial permanece; bypass somente em build homologation. Billing real desligado.

## AIO-01 — comando durável

O cliente grava UUID e payload por usuário antes do POST. Timeout/reinício reutiliza
o mesmo comando. Respostas não podem cruzar contas. Mudanças num comando pendente
são recusadas até sua resolução. Rascunhos são isolados por usuário.

O backend autentica antes de reservar (user_id, command_id) no Postgres. Hash de
payload impede reutilização divergente. Concorrência recebe 409. Geração é salva
num checkpoint durável antes do insert do sonho; uma repetição termina a persistência
sem chamar novamente a IA. Resposta concluída é recuperada do mesmo comando.
Se o processo morrer durante a chamada externa sem checkpoint, não é seguro repetir
automaticamente: estado incerto exige revisão. Isso não promete exactly-once no provedor.

RPCs são exclusivas de service_role; nenhum dado ou papel de usuário é aceito do
cliente para autorizar. Testes: concorrência, resposta perdida, retomada de checkpoint,
payload divergente, isolamento por dono e recuperação após reinício do cliente.
Migration precisa ser aplicada no projeto AION antes do APK novo.
