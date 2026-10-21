# Bônus do selo Explorador

Implementado em 21/10/2026.

Conquistar a meta de extras de um nível concede **10 moedas uma única vez**, além da revelação gratuita. O valor aparece no feedback da conquista e o saldo é atualizado após a confirmação do salvamento. A lista de extras informa a recompensa disponível ou já recebida.

A conquista, a extra, a revelação e o crédito são salvos juntos. O lançamento usa `explorer-reward:<levelId>` e o perfil registra `explorerRewardedLevelIds`. Repetir extras, embaralhar, avançar ou reabrir não repete o crédito. Selos de versões anteriores são preservados; a nova recompensa vale para novas conquistas. O campo do payload é opcional para manter compatibilidade, inclusive com operações antigas pendentes.

Configuração: `Economy.explorerReward` em `lib/features/game/application/campaign_models.dart`.

Validação de host:

- `dart format lib test integration_test`: arquivos formatados.
- `flutter analyze --no-pub`: nenhum problema encontrado.
- `flutter test --no-pub --reporter expanded`: **91 testes aprovados**.
- Casos novos: crédito único por nível, meta com duas extras, extras posteriores ao selo, submissões concorrentes, perda de confirmação do commit, rollback em quatro etapas, recuperação da mesma revelação após reabrir SQLite, saves antigos, operação antiga pendente, consistência do ledger e bônus sem quadrado elegível.
- Dez níveis sem compras e sem selos continuam totalizando **260 moedas**. Os dez selos novos acrescentam **100**, totalizando **360 moedas**.

Nenhuma captura de tela foi salva.

Validação Android:

- `flutter test integration_test/game_flow_test.dart -d emulator-5554 --reporter expanded`: aprovado no emulador API 35.
- Conquista do primeiro selo: **60 → 70**; repetição mantém 70; compra de dica: **70 → 40**.
- Fluxo com arrastes reais, extras, selo, dicas, acentos e dez níveis concluído. Saldo final **240 moedas**, considerando um selo e uma compra.
