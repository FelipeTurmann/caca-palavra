# Validação — etapa 3

Data: 20/10/2026. Projeto: `C:\Users\felip\Desktop\dev\workspace\caca-palavra`.

## Entrega

Implementados bootstrap persistente, tela inicial, carteira, compra de dica, recuperação de rodada, resultado pendente, recompensa única e avanço da campanha. As extras gratuitas, meta e selo Explorador continuam funcionando. Nenhum botão de anúncio foi incluído, conforme a decisão do usuário. Nenhum print foi salvo ou adicionado à documentação.

A configuração econômica está em `Economy`, no arquivo `lib/features/game/application/campaign_models.dart`: 60 moedas no primeiro perfil, +20 por conclusão inédita e −30 por dica. O catálogo atual continua com dez níveis e 39 respostas; o léxico tem 61 entradas curadas.

## Implementação verificada

- `LocalGameDatabase.version = 2`: tabelas `profiles`, `coin_transactions` e `operation_requests`; migração v1 → v2 transacional.
- `CampaignProfile` tem payload schema 1. Saldo e revisão ficam nas colunas autoritativas do perfil, fora do JSON do progresso.
- `GameSessionCoordinator` serializa comandos e prepara uma proposta antes de efetivar a transação. A proposta inclui identidade da rodada e a posição sorteada, permitindo a retomada exata.
- Comandos só publicam mudanças e efeitos de sucesso após a confirmação. Uma perda de confirmação consulta o resultado por `operationId` antes de repetir.
- A conclusão usa `level-completion:<levelId>`, independente da versão do catálogo. Último alvo, crédito, conclusão, desbloqueio e resultado pendente são confirmados juntos.
- A restauração reconstrói e valida os snapshots; não reenvia palavras nem executa sorteios para reconstruir descobertas.
- Catálogo, schema e versão SQLite são separados. Anexar níveis preserva recompensas anteriores, inclusive se o resultado do último nível antigo ainda estiver pendente. Alterar o conteúdo de um nível jogado é detectado por fingerprint.
- O botão de voltar cancela um gesto ativo; depois disso retorna à home. A navegação aguarda a operação de gravação ativa. Falha preserva o estado confirmado e oferece nova tentativa com a proposta original.

## Ambiente e comandos

Flutter 3.44.9 / Dart 3.12.2, Windows. Android: emulador `emulator-5554`, Medium Phone, API 35 (Android 15). Não foi usado um aparelho físico.

| Comando | Resultado |
|---|---|
| Baseline anterior: `flutter test --no-pub --reporter expanded` | 53 testes aprovados |
| `flutter pub get` | Dependências resolvidas |
| `dart format lib test integration_test` | Código formatado |
| `flutter analyze --no-pub` | Nenhum problema encontrado |
| `flutter test --no-pub --reporter expanded` | 79 testes aprovados |
| `flutter test integration_test/game_flow_test.dart -d emulator-5554 --reporter expanded` | Integração Android aprovada |
| `flutter build apk --debug -t integration_test/recovery_app.dart` | APK da fixture de recuperação compilado |
| `./tool/test_android_recovery.ps1` | Oito etapas de recuperação aprovadas com novos processos |
| `flutter build apk --debug` | APK normal gerado para entrega |

Os 53 testes da base foram adaptados: a entrada direta virou cobertura da home, e a expectativa de reiniciar no último nível foi substituída pela preservação da campanha. A cobertura de gestos, acentos, extras, selo, timers, redução de movimento, layouts, callbacks e revelações foi mantida.

## Host: SQLite real e interface

Os testes de persistência usam um arquivo SQLite temporário por cenário, fechado e reaberto em novas instâncias. Não são apenas mocks. Cobrem:

- Crédito inicial único, inclusive se a configuração inicial mudar depois.
- Alvo, extra, origem da revelação e ordem das fichas após reabrir o banco.
- Duas compras 60 → 30 → 0, repetição do mesmo ID com saldo zero, rejeição de parâmetros diferentes e concorrência sem saldo negativo.
- Saldo 29 insuficiente; saldo 30 permite somente uma compra concorrente.
- Dicas gratuitas e pagas sem repetir posição, exclusão de palavras encontradas e limite de uma posição escondida por palavra.
- Falhas antes do ledger, após o ledger, antes de atualizar o perfil e antes do commit: rollback mantém saldo e revelações anteriores; nova tentativa confirma a mesma posição proposta.
- Falha após o commit: consulta do recibo resolve a confirmação incerta sem duplicar o lançamento.
- Reinício com proposta preparada e recuperação do mesmo sorteio.
- Conclusão e recompensa atômicas; dupla submissão final e duplo avanço sem duplicação ou salto de nível.
- Revisão divergente em dois coordenadores, migração v1 → v2, payload inválido e fingerprint incompatível sem reset.
- Catálogo ampliado antes ou depois de reconhecer o último resultado antigo.
- Campanha completa sem compras: **260 moedas**, dez rodadas preservadas e onze lançamentos (um inicial e dez recompensas).

Os testes de widgets usam respostas imediatas para controlar o relógio simulado, enquanto a suíte de persistência verifica as garantias transacionais reais. A interface cobre abrir/cancelar/comprar dica, falta exata de uma moeda, ausência de anúncios, erro de carga com nova tentativa e mensagem de versão incompatível, retorno/continuação e resultado já premiado. Foi verificado o layout em 320×568 com texto 2×, incluindo o diálogo rolável de dica.

Durante a implementação, os testes detectaram e levaram à correção de um callback de `setState` que devolvia Future, transbordamento da carteira com texto ampliado e falta de rolagem no diálogo. As verificações finais foram executadas após essas correções.

## Android: fluxo real e recuperação após encerrar o processo

A integração usa `stage3_integration.db`, exclusivamente de teste. Verificou home com 60 moedas, arrastes reais, extra TOGA e selo, cancelamento sem cobrança, compra com débito, acentos/cedilha, os dez níveis e home final com **230 moedas** (uma compra ao longo da campanha). A campanha não foi reiniciada.

A fixture `integration_test/recovery_app.dart` usa `stage3_recovery.db` e marcadores de texto próprios. O roteiro instala com `adb install -r`, encerra com `am force-stop` e abre novamente a Activity. Não foi usada desinstalação para simular recuperação. Os PIDs abaixo evidenciam as novas execuções:

| Etapa | Resultado observado | PID |
|---|---|---:|
| `seed` | GATO, TOGA, ordem embaralhada e duas revelações (uma gratuita e uma paga); saldo 30 | 6472 |
| `verify_partial` | Payload idêntico após encerramento, mesmas posições e saldo 30 | 6624 |
| `complete` | Commit concluído, saldo 50 e resultado pendente; execução parada antes de montar a tela/animação | 6757 |
| `verify_completed` | Resultado restaurado já premiado; saldo 50, sem novo crédito | 6922 |
| `advance` | Próxima rodada no nível 2, saldo 50 | 7058 |
| `verify_advance` | Nível 2 retomado; histórico e revelações do nível 1 preservados | 7149 |
| `finish` | Dez níveis concluídos e reconhecidos, saldo 230 | 7219 |
| `verify_final` | Nova abertura mantém campanha completa, dez rodadas e saldo 230 | 7312 |

O banco normal `conecte_palavras_v1.db` não foi limpo pelos testes. Após a fixture, a versão normal foi recompilada e reinstalada com `adb install -r`.

## Artefatos e limites

- APK normal de teste: `build/app/outputs/flutter-apk/app-debug.apk`.
- Roteiro reproduzível: `tool/test_android_recovery.ps1`.
- Instruções de execução, localização do save e configurações: `README.md`.
- Sem novas imagens, capturas de tela ou vídeos na documentação.

A validação Android ocorreu em emulador API 35; não abrange todos os aparelhos ou versões do sistema. O APK é de depuração para teste. O progresso é local: desinstalar ou limpar dados do Android pode removê-lo. O léxico é curado e limitado às entradas do projeto. Não há conta, sincronização ou anúncios nesta entrega.

As dependências foram escolhidas conforme a [receita oficial de SQLite no Flutter](https://docs.flutter.dev/cookbook/persistence/sqlite), a documentação de [sqflite](https://pub.dev/packages/sqflite) e [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi). As evidências deste relatório são das execuções locais descritas acima.

## APK final instalado

A versão normal (`lib/main.dart`) foi instalada com `adb install -r` e aberta no emulador; processo observado: **7613**. Após a abertura, foi confirmada a criação de `conecte_palavras_v1.db`, independente do banco da fixture. O arquivo de entrega tem **173.211.110 bytes**.

SHA-256: `573D026134EB2BEFE7E3975B2D8D2D7C31FF6F3C930EBCBC5C3E19149C608008`.
