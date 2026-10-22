# Conecte palavras — etapa 5

Aplicativo Flutter/Dart para Android, com palavras em português brasileiro, campanha, desafio diário e carteira local em SQLite. A tela inicial oferece Jogar, Continuar ou Ver resultado da campanha, além de um cartão independente do desafio diário.

## Experiência e apresentação (0.2.0+2)

Visual com cenário botânico desenhado pelo aplicativo, gatinho estático original, fonte Nunito local e botões com volume. As dicas continuam laterais nos celulares validados e agora exibem seus preços; paisagem usa respostas e círculo em duas áreas. Texto ampliado mantém a preferência do usuário, com rolagem quando necessária, inclusive horizontal na grade de palavras longas.

A engrenagem na home e na partida abre **Configurações**: efeitos sonoros, vibração e redução de animações independentes. A redução do sistema prevalece. São nove efeitos WAV curtos, sem música, com reprodução nativa Android pré-carregada e falha de mídia tolerada. O gesto não espera o áudio. Preferências são carregadas antes de qualquer efeito e gravadas em fila; uma falha mantém a escolha na sessão e oferece nova tentativa.

O tutorial de quatro passos usa G, A, T e O numa sessão isolada: arrastar, soltar, embaralhar e conhecer as ajudas. Tem pular, voltar, experimentar novamente e alternativa sem gesto. O aplicativo abre diretamente na tela inicial, inclusive em perfis novos ou com uma introdução antiga incompleta. A demonstração fica disponível somente em **Configurações → Como jogar**, sem alterar progresso, moedas ou o estado de introdução já armazenado.

A migração SQLite **3 → 4** adiciona somente `app_settings`, com preferências e estado da introdução. Preserva payload 2, ledger, operações preparadas, carteira, campanha e diário. Não reinstale limpando dados; atualize com `adb install -r`.

Documentação desta entrega:

- [Validação e limites da etapa 5](docs/validacao-etapa-5.md).
- [Origem, licenças, prompt da arte e pontos de configuração](docs/recursos-etapa-5.md).
- [Roteiro de teste com jogadores](docs/roteiro-jogadores.md).

## Loja simulada

Tocar no saldo da home, campanha, diário ou resultado abre a **Loja**. A rodada é preservada ao abrir e fechar. O painel identifica permanentemente: **Loja em teste: compras simuladas, sem cobrança real.**

| Pacote | Moedas | Preço de referência |
|---|---:|---:|
| `coins_500` | 500 | R$ 3,99 |
| `coins_1000` | 1.000 | R$ 5,99 |
| `coins_2500` | 2.500 | R$ 10,99 |
| `coins_5000` | 5.000 | R$ 18,99 |

Selecionar um pacote exige **Simular compra**. Cancelar não credita. Uma nova compra confirmada pode repetir o pacote; retentar o mesmo pedido não repete o crédito.

**Assistir anúncio · +15 moedas** é uma simulação sem vídeo, espera artificial ou limite diário. O botão fica bloqueado enquanto a operação está em andamento. Outro toque deliberado após o sucesso concede mais 15.

Não há cobrança real, SDK de pagamentos, AdMob, credenciais ou backend. Os provedores de compra/anúncio são interfaces separadas, com implementações simuladas. Pedidos, recibos e lançamentos registram `simulated`; esses recibos não comprovam pagamentos reais e não devem ser reaproveitados como tal numa integração futura.

Moedas de recompensas voam até o saldo, no estilo da coleta de extras: selo Explorador (+10), conclusão da campanha (+20 por nível) e conclusão diária (+50). O crédito já está confirmado antes do voo; concluir a animação não altera o saldo. Reabrir resultado, repetir resposta ou retentar o mesmo recibo não repete o efeito. A redução de movimento mantém a atualização do saldo sem voo.

Uma resposta inédita formada pelo jogador recebe um “Muito bem!” animado com a palavra encontrada e brilho somente na sua linha. Extras e Super Dica mantêm seus retornos específicos; a última resposta usa a comemoração de conclusão. A opção de reduzir animações preserva a mensagem estática, sem brilho ou movimento. O tempo fica em `GameTiming.wordCelebration`.

## Dicas e recompensas

- **60 moedas iniciais**, concedidas uma única vez por perfil.
- Campanha: **+20 por primeira conclusão de nível** e **+10 por selo Explorador inédito**. Selos de versões anteriores continuam preservados sem crédito retroativo.
- **Dica · 30 moedas** revela uma posição inédita de uma palavra ainda não encontrada.
- Cada extra inédita continua revelando uma posição gratuitamente e contando para o selo.
- Dicas comuns e extras deixam pelo menos uma posição escondida por palavra. Se não houver posições elegíveis, não cobram nem revelam outra letra.
- **Super Dica · 100 moedas** resolve uma palavra inteira. Prioriza a maior quantidade de posições escondidas, descontando revelações anteriores; sorteia apenas entre empatadas. A confirmação não mostra antecipadamente a resposta.
- A Super Dica é uma exceção ao limite de uma posição escondida: a palavra é marcada como encontrada e sua origem assistida é persistida. Cada operação conta como um uso, independentemente da quantidade de letras.
- Uma Super Dica final gera débito e prêmio separados na mesma transação: **100 → 20** na campanha ou **100 → 50** no diário. Saldo 99 não permite antecipar o prêmio para financiar a compra.
- Insuficiência de moedas oferece **Ir à loja**. Voltar exige nova confirmação da dica; nenhuma compra é acionada automaticamente.

## Desafio diário

O diário usa o calendário e o fuso local do aparelho, sem cronômetro de partida. A conclusão rende **50 moedas uma única vez por data**. Extras mantêm revelações gratuitas e selo visual; o diário não soma +20 da campanha nem +10 do selo.

Campanha e diário possuem rodadas e resultados pendentes independentes, com carteira compartilhada. O diário continua disponível depois de concluir toda a campanha. Sair e entrar no mesmo dia retoma alvos, extras, ordem, dicas e resoluções assistidas; não há replay depois de reconhecer a conclusão.

O catálogo local separado contém sete definições curadas, em rotação determinística com data-base. Mesma data e versão produzem o mesmo conteúdo, independentemente do progresso da campanha. Não há repetição em dias consecutivos, inclusive entre ciclos. Conteúdo pode reaparecer após o ciclo. A definição e o léxico usados ficam incorporados no diário iniciado para preservar a rodada após atualização do catálogo.

À meia-noite local, a rodada incompleta expira sem reembolso de dicas. A data é conferida ao iniciar, em cada comando, ao retomar o aplicativo e ao abrir/fechar a loja. Um agendamento renovável também verifica a virada enquanto o aplicativo está ativo. A próxima meia-noite é calculada por calendário, sem somar 24 horas.

Confirmações não efetivadas de uma data expirada são rejeitadas sem débito. Operações já confirmadas conservam recibo e prêmio, mesmo quando a resposta chega depois da virada. Créditos da loja pertencem à carteira e sobrevivem à expiração. Pular dias não cria desafios retroativos nem moedas. Retornar o relógio antes da última data diária aceita bloqueia o diário com uma mensagem; campanha e loja continuam disponíveis.

O relógio é local, sem fonte de tempo confiável externa. Um avanço artificial pode antecipar desafios. Não há proteção completa contra manipulação de relógio nesta etapa.

## Persistência e migração

O banco privado continua em `conecte_palavras_v1.db`. A versão SQLite atual é **5** e o payload atual é **2**, com leitura compatível do payload 1. As versões do catálogo da campanha e do diário são independentes.

- `app_settings`: preferências e introdução, independentes de rodadas e moedas.
- `profiles`: saldo, revisão e payload. Não há carteira duplicada nos snapshots.
- `coin_transactions`: lançamentos com IDs próprios e `parent_operation_id` vinculando os lançamentos a um pedido.
- `operation_requests`: propostas preparadas e recibos confirmados. A escolha de letra/palavra está na proposta antes do commit.

O coordenador serializa mutações de campanha, diário e loja. Estado e efeitos visuais só são publicados após commit. Uma Super Dica final pode gravar débito e recompensa num único commit com lançamentos auditáveis separados. O saldo é validado contra a soma do ledger e contra o saldo anterior necessário à compra.

Recompensas preservam suas chaves: `level-completion:<levelId>`, `explorer-reward:<levelId>` e `daily-completion:YYYY-MM-DD`. A identidade econômica do diário não inclui a versão do catálogo. Migração não reemite welcome, recompensas ou selos anteriores. Dados incompatíveis não são apagados: a carga apresenta erro e nova tentativa.

Em falhas, a interface mantém o último estado confirmado e oferece retry com o mesmo pedido. A recuperação resolve recibos antes de efetivar propostas. Propostas diárias ainda não confirmadas revalidam a data; as expiradas são rejeitadas.

O progresso é local. Desinstalar ou limpar os dados do Android pode removê-lo. O ledger assegura consistência operacional; não é proteção absoluta contra alteração manual de arquivos num aparelho comprometido.

## Executar e validar

Na pasta `C:\Users\felip\Desktop\dev\workspace\caca-palavra`:

```powershell
flutter pub get
flutter run -d emulator-5554
dart format lib test integration_test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test integration_test/stage4_flow_test.dart -d emulator-5554 --reporter expanded
flutter test integration_test/stage5_flow_test.dart -d emulator-5554 --reporter expanded
flutter build apk --debug
```

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`.

Recuperação em processos separados, com banco exclusivo de teste:

```powershell
flutter build apk --debug -t integration_test/stage4_recovery_app.dart
./tool/test_stage4_recovery.ps1
# Restaurar a versão normal, mantendo os dados:
flutter build apk --debug -t lib/main.dart
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

A integração nova usa `stage4_integration.db`; a fixture de recuperação usa `stage4_recovery.db`. Os testes antigos usam seus próprios bancos `stage3_*`. Nenhum teste limpa o banco normal. Os testes de host usam SQLite real em arquivos temporários. Os testes de widgets usam um repositório de resposta imediata para controlar o relógio simulado. Não são salvos prints.

## Configuração

| Item | Local |
|---|---|
| Valores 60 / 20 / 10 / 30 / 100 / 50 / 15 | `Economy` em `lib/features/game/application/campaign_models.dart` |
| Pacotes e preços de referência | `lib/features/game/application/shop_models.dart` |
| Interfaces e provedores simulados | `lib/features/game/application/shop_models.dart` |
| Catálogo da campanha e metas de extras | `assets/data/levels.json` |
| Léxico curado | `assets/data/lexicon_pt_br.json` |
| Catálogo diário, versão e data-base | `assets/data/daily_levels.json` |
| Agendamento determinístico | `lib/features/game/data/daily_catalog.dart` |
| Calendário, contexto e snapshots diários | `lib/features/game/application/daily_models.dart` |
| Comandos, datas, recibos e retomada | `lib/features/game/application/game_session_coordinator.dart` |
| SQLite, migrações e validações | `lib/features/game/data/progress_repository.dart` |
| Seleção de palavra e posições assistidas | `lib/features/game/domain/game_engine.dart` |
| Tema e cores | `lib/core/theme/game_theme.dart` |
| Durações das animações e agendamento da verificação de data | `lib/features/game/presentation/game_controller.dart` |
| Home e saldo | `lib/features/game/presentation/home_screen.dart` |
| Loja | `lib/features/game/presentation/shop_screen.dart` |
| Partida, confirmações e resultado | `lib/features/game/presentation/game_screen.dart` |

A campanha permanece com dez níveis, 39 respostas e 61 entradas no léxico. Novos níveis podem ser anexados mantendo IDs e ordem. Alterar conteúdo de um nível já jogado exige migração explícita; o fingerprint detecta incompatibilidades. Atualizações do catálogo diário devem incrementar sua versão; rodadas iniciadas conservam a definição salva.

Gestos, acentos/cedilha, fichas repetidas, segmentos rápidos, desfazer, multitouch, redução de movimento e selo Explorador foram preservados. Não há conta, sincronização, ranking ou cronômetro. O léxico é curado e limitado, não um dicionário completo.

Resultados desta entrega: `docs/validacao-etapa-4.md`. Relatórios anteriores permanecem como histórico.


## Plano sem anúncios (protótipo)

O botão redondo AD com bloqueio à esquerda da seleção abre a Loja. Dica e Super Dica permanecem à direita; a seleção e os parabéns têm margens iguais e ficam alinhados ao centro do círculo. No texto ampliado, os controles usam uma faixa própria.

O plano de R$ 15,00 é uma compra única **simulada**, com confirmação explícita, sem cobrança. A ativação fica na tabela SQLite `simulated_entitlements` (schema 5), independente das moedas e das preferências. Ativações repetidas não duplicam o registro. Falha de gravação permite tentar novamente e não confirma a ativação. Os anúncios opcionais de recompensa continuam disponíveis. Ainda não há anúncios automáticos nem integração de pagamento real: esta ativação serve para validar a experiência e não representa recibo de compra real.
