# Conclusão por extras e dicas

Data: 23/10/2026. Versão: **0.9.0+14**.

O usuário confirmou que a nova regra vale tanto para palavras extras quanto para a Dica de 30 moedas.

## Comportamento

- Cada extra inédita continua revelando uma única posição e contando para o selo Explorador.
- A dica comum continua custando 30 moedas e revelando uma única posição.
- Ambas podem revelar a última letra. Nesse caso, a palavra é marcada como encontrada, deixa de ser elegível para revelações e passa a contar no progresso.
- Se todas as respostas estiverem encontradas, a rodada é concluída com o resultado, recompensa e navegação já existentes.
- Extras repetidas não concedem outra revelação. Rodadas concluídas não aceitam novas respostas.
- A Super Dica mantém a regra de resolver uma palavra inteira pelo preço de 100 moedas.

A confirmação da dica explica que a última letra completa a palavra. Quando apenas uma palavra é resolvida, o retorno identifica a conclusão pela dica ou pelo bônus da extra; a extra continua identificada separadamente como palavra extra.

## Gravação e moedas

Revelação, palavra encontrada, conclusão e operações de moedas são confirmadas na mesma transação. A interface só publica o estado confirmado.

| Situação | Resultado econômico |
|---|---|
| Dica final na campanha | Débito de 30 e prêmio de 20 em lançamentos separados. |
| Dica final no diário | Débito de 30 e prêmio de 50 em lançamentos separados. |
| Extra final que também conquista Explorador na campanha | Prêmio de conclusão de 20 e bônus Explorador de 10, uma vez cada. |
| Extra final no diário | Prêmio diário de 50; o selo continua visual, sem bônus monetário de Explorador. |

A dica exige saldo de pelo menos 30 **antes** da compra. O prêmio não financia uma compra com saldo insuficiente. Repetir uma confirmação, perder a resposta de commit ou reiniciar com uma operação preparada não duplica débitos ou recompensas.

O schema SQLite continua **6** e o payload **2**. Revelações antigas e rodadas existentes continuam legíveis. Uma palavra totalmente revelada precisa constar como encontrada no snapshot; um estado inconsistente é rejeitado. Não há migração ou redefinição de progresso.

## Alterações

- `game_engine.dart`: elegibilidade inclui a última posição; conclusão automática atualiza alvos e fase; resultado de extra informa também a palavra completada; restauração valida o novo estado.
- `game_session_coordinator.dart`: recibo da dica registra eventual conclusão; débito e recompensa são atômicos; uma extra pode confirmar Explorador e conclusão na mesma operação.
- `game_controller.dart`: apresenta o resultado da dica e agenda a conclusão, inclusive após retry.
- `game_screen.dart` e `selection_feedback.dart`: confirmação e retornos da nova regra.
- `pubspec.yaml`: versão do aplicativo.

Os temas e a geometria de gesto permanecem os existentes.

## Verificação local

- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --reporter expanded`: **243 testes aprovados**.
- Conclusão parcial e final pela interface; avanço para o próximo nível; movimento normal e reduzido.
- Campanha e diário, extra e dica paga, palavra e origem preservadas após reabrir o banco.
- Falha após o primeiro lançamento reverte toda a operação; reiniciar confirma a proposta exata uma vez.
- Resposta de commit perdida recupera o recibo original.
- Saldo de 29 não permite comprar a dica final.
- Formatação verificada em 78 arquivos Dart e `git diff --check` aprovado.

Os testes novos estão em `test/reveal_completion_test.dart` e `test/reveal_completion_widget_test.dart`. Os testes existentes do motor e de persistência foram atualizados para substituir a regra anterior de manter uma letra escondida.

## Android

Fluxo aprovado no emulador Android API 35, 1080×2400, build debug. Foram verificados os quatro casos: dica e extra concluindo campanha e diário. A tela de resultado apareceu automaticamente em todos eles, com os saldos esperados. O fluxo dedicado usa somente bancos com prefixo `hint_completion_`; não limpa o banco normal do jogador.

```powershell
flutter drive --no-pub --driver=test_driver/reveal_completion_driver.dart --target=integration_test/reveal_completion_flow_test.dart -d emulator-5554
```

Capturas de antes e depois ficam em `docs/revelacao-completa/screenshots/`. Uma cópia preventiva dos bancos do emulador está em `build/theme-qa-backup/before-hint-completion-android.tar`, fora do controle de versão.

- [Antes da última dica na campanha](screenshots/01-antes-campanha-dica.png).
- [Campanha concluída pela dica, saldo 20](screenshots/02-resultado-campanha-dica.png).
- [Campanha concluída pela extra com Explorador, saldo 60](screenshots/04-resultado-campanha-extra.png).
- [Diário concluído pela dica, saldo 50](screenshots/06-resultado-diario-dica.png).
- [Diário concluído pela extra, saldo 80](screenshots/08-resultado-diario-extra.png).

As capturas usam uma fixture com 120 moedas iniciais, três dicas preparatórias e duas respostas já encontradas. Os valores exibidos são os resultados reais dessas operações. Imagens inspecionadas: estado anterior com uma posição vazia, resultado de campanha pela extra e resultado diário pela dica, com textos e botões legíveis. Não houve teste em aparelho físico nem medição de desempenho de produção.

## Pacote

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, entrada `lib/main.dart`. Atualizar com `adb install -r` preserva os dados.

O APK normal **0.9.0+14** foi compilado, instalado por atualização e iniciado com sucesso no emulador. O Android confirmou `versionName=0.9.0`, `versionCode=14` e a presença do banco normal do jogador após a atualização.

