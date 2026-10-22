# Validação da etapa 4

Data: 21/10/2026. Projeto: `C:\Users\felip\Desktop\dev\workspace\caca-palavra`.

## Entrega e decisões

Implementados: lojinha pelo saldo da home, campanha, diário e resultados; quatro pacotes simulados; anúncio simulado de +15; Super Dica de 100; diário separado com prêmio único de 50 por data. Compras e anúncio são explicitamente simulados, sem cobrança ou vídeo. Não foram adicionados SDKs, credenciais, backend ou serviços externos.

O diário usa data/fuso local, sete conteúdos curados em rotação determinística, expiração da rodada incompleta na virada e bloqueio de datas anteriores à última aceita. O selo diário é visual e as extras continuam revelando letras gratuitamente, sem +10 diário. A campanha mantém suas recompensas de 20 e 10.

SQLite foi migrado de 2 para 3, acrescentando vínculo entre lançamentos e operação; payload atual é 2, com leitura do payload 1. Não houve reset da carteira ou reemissão de recompensas. A Super Dica persiste a palavra e as posições escolhidas; um uso pode resolver todas as posições restantes e gerar débito e prêmio separados no mesmo commit.

## Comandos e resultados

Ambiente Windows, Flutter 3.44.9 / Dart 3.12.2. Android: emulador `emulator-5554`, API 35. Não foi usado aparelho físico.

| Comando | Resultado |
|---|---|
| Baseline `flutter analyze --no-pub` | Nenhum problema |
| Baseline `flutter test --no-pub --reporter expanded` | 91 testes aprovados |
| `dart format lib test integration_test` | Arquivos formatados |
| `flutter analyze --no-pub` | Nenhum problema |
| `flutter test --no-pub --reporter expanded` | **141 testes aprovados** |
| `flutter test integration_test/stage4_flow_test.dart -d emulator-5554 --reporter expanded` | **Aprovado** |
| `flutter build apk --debug -t integration_test/stage4_recovery_app.dart` | Fixture compilada |
| `./tool/test_stage4_recovery.ps1` | **Seis fases aprovadas em novos processos** |
| `flutter build apk --debug -t lib/main.dart` | APK normal gerado |
| `git diff --check` | Sem erros de whitespace |

## Cobertura verificada

- Pacotes 500/1.000/2.500/5.000 com preços aprovados; saldo inicial 60 resulta em 560/1.060/2.560/5.060 para cada compra isolada.
- Recibos simulados persistidos, cancelamento sem crédito, pedido repetido sem duplicação e nova confirmação do mesmo pacote com novo crédito.
- Anúncio 60 →75 →90; dez ativações concorrentes resultam em um único +15. Falhas e perda de confirmação usam o mesmo pedido.
- Loja única, retorno à origem e saldo compartilhado, mantendo snapshots da campanha e do diário.
- Super Dica priorizando posições desconhecidas, sorteando apenas entre máximos empatados, excluindo palavras encontradas e mantendo acentos/cedilha. Resolução completa é aceita na restauração sem alterar a política de dicas comuns.
- Saldo 99 não antecipa prêmio; 100 →0 num uso comum, 100 →20 na conclusão da campanha e 100 →50 na conclusão diária. Débito e crédito são lançamentos separados vinculados ao mesmo pedido.
- Rollback antes do ledger, entre lançamentos, antes de atualizar perfil e antes do commit; recuperação do sorteio original e perda da confirmação após commit sem repetição financeira.
- Diário determinístico, sete definições distintas, sem repetição consecutiva na virada do ciclo, restauração da mesma data e preservação da definição ao atualizar catálogo.
- Rodadas e resultados pendentes independentes entre modos, contexto antigo rejeitado mesmo quando os IDs numéricos coincidem, carteira única e diário disponível após concluir a campanha.
- Expiração sem reembolso, calendário em mudanças de mês/ano e ano bissexto, salto de dias sem prêmios retroativos e retorno do relógio bloqueando somente o diário, inclusive após observar a virada sem iniciar outra rodada.
- Confirmação de dica antiga fechada sem cobrança; crédito da loja preservado quando a rodada de origem expira; operação preparada antiga rejeitada e operação já confirmada antes da virada preservada.
- Migração de fixture v2 para v3 conservando saldo, revisão, ledger, selo, dica e resultado pendente; compatibilidade com payload antigo e operações antigas preparadas.
- Loja e confirmação em 320×568, 568×320 e 412×915 com texto 2×. Regressão de gestos, normalização, extras, redução de movimento e dez níveis mantida.

O agendamento usa a próxima data de calendário, não uma soma fixa de 24 horas. Os testes usam relógio injetado para simular datas e viradas, sem alterar o relógio do aparelho. Não houve reconfiguração manual do fuso do sistema nem ensaio físico de horário de verão; os cálculos locais ficam a cargo do calendário `DateTime` do sistema.

## Fluxo Android

A integração utilizou `stage4_integration.db`, exclusivo de teste. Verificou compra de +500 e anúncio +15, Super Dica na campanha, preservação do resultado pendente ao entrar no diário, extras sem bônus diário de selo, Dica de 30, Super Dica de 100, conclusão de +50, loja aberta a partir do resultado e retomada da campanha. O saldo final verificado foi **430 moedas**. Um segundo diário expirou com uma confirmação aberta, sem débito.

## Recuperação com force-stop

A fixture usou somente `stage4_recovery.db`. Cada etapa encerrou o processo via `am force-stop` e iniciou outra Activity, preservando dados. `adb install -r` foi usado; não houve desinstalação para simular recuperação.

| Fase | Verificação | PID |
|---|---|---:|
| `seed` | Compra, anúncio, Super Dica da campanha, selo, diário com extra/dica/Super Dica e fichas embaralhadas; saldo 355 | 18795 |
| `verify_partial` | Payload idêntico e recibos repetidos sem crédito adicional; saldo 355 | 18916 |
| `complete` | Super Dica final diária confirmada; saldo 305; execução parada antes da animação | 18985 |
| `verify_completed` | Resultado diário restaurado já premiado e reconhecido sem novo crédito | 19063 |
| `prepare_uncommitted` | Super Dica da data seguinte preparada, mas sem commit; saldo 305 | 19131 |
| `verify_expired` | Nova data rejeita proposta anterior, mantém saldo 305 e histórico confirmado, e oferece novo desafio | 19207 |

Nenhum desses testes abriu ou limpou `conecte_palavras_v1.db`. Não foram gerados prints, imagens ou vídeos.

## Arquivos e limites

Configurações de economia, pacotes, preços, calendário, catálogo e durações estão documentadas no README. Os provedores são simulados e seus recibos não podem ser interpretados como pagamento real. O relógio local não protege totalmente contra adulteração: avançá-lo pode antecipar conteúdo; regressões de data são bloqueadas. Conteúdo diário pode reaparecer após o ciclo de sete definições. Não há desafios retroativos, login ou sincronização.

O teste Android foi realizado em emulador API 35. O APK de entrega é de depuração. Persistência é local; desinstalar ou limpar os dados do Android pode removê-los.

## APK final

Gerado a partir de `lib/main.dart` em `build/app/outputs/flutter-apk/app-debug.apk`, reinstalado com `adb install -r` e aberto no emulador. O banco de produção foi mantido; a versão temporária de teste foi substituída pelo aplicativo normal.

SHA-256: `A6DAA5D72AE01747EB4D3CED8DDC577E0F057D77EEE57F90B1AB237521B44BA1`.
