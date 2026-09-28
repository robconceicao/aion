# AIO-01 a AIO-04
Homologação; sem APK, deploy ou cobrança real.
- Retry automático de erro ambíguo de transporte/5xx somente GET/HEAD. POST de sonho/entrevista/voz nunca repete automaticamente. Refresh após 401 antes da autorização do endpoint permanece.
- Persistência: verificar id+user_id antes de cada tentativa; após exceção de insert verificar novamente (inclusive último retry). Não sobrescrever conteúdo em conflito; UUID da operação permanece.
- Flutter timezone 4.1.1 fornece IANA do aparelho; tz.local configurado antes do agendamento. Falha não usa UTC silenciosamente. Reentrada no app atualiza fuso e agenda habilitada.
- Registrar sonho com sucesso suprime só o lembrete de hoje, rearmando recorrência amanhã; iniciar entrevista ou falhar não suprime. Cancelar todos desativa reagendamento.
- Testes de regressão: retry por método, gravação confirmada com SELECT temporariamente indisponível/conflito, fuso São Paulo e transição DST, agenda de amanhã.
Limite: não deduplica solicitações manuais diferentes do usuário; para isso é necessário protocolo de command-id ponta a ponta. Resultado de entrega Android depende de teste de aparelho.
Fonte API de fuso: https://pub.dev/packages/flutter_timezone/versions/4.1.1
