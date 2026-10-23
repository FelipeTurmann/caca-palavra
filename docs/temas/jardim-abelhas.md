# Jardim das abelhas — implementação aprovada

Data: 22/10/2026. Versão: **0.6.0+11**.

O usuário aprovou a [prévia cartoon](jardim-abelhas-aprovado.png) e autorizou o quinto tema. O fundo, a abelhinha e a margarida da proposta foram incorporados ao aplicativo sem nova geração de arte.

## Resultado

- **Jardim das abelhas** disponível gratuitamente em **Temas**, abaixo de **Desafio diário**.
- Jardim ensolarado em tons de mel e creme, com margaridas, folhas e pequena colmeia nas bordas. Abelhinha sorridente na home e na miniatura.
- Flor centralizada sob fichas verde-petróleo com letras brancas e embaralhamento central. Seleção mantém os destaques existentes.
- Respostas em células separadas e alinhadas, sobre superfície clara com contornos em tom de mel.
- Abelha de canto quando há espaço; cenário discreto nas telas auxiliares.
- Aplicação imediata e restauração da escolha ao reabrir, com o fluxo existente de confirmação e tentativa de salvamento.

O ID estável é `jardim_abelhas`. O **Jardim do Gatinho** permanece padrão e os quatro IDs anteriores continuam válidos. Schema SQLite **6** e payload **2** preservados, sem migração adicional ou nova dependência. Trocar tema não altera partidas, palavras, níveis, moedas ou compras. A geometria e os eventos de arraste continuam os existentes. Todas as ilustrações ignoram toque e leitura semântica.

O seletor dinâmico acomoda cinco opções em uma coluna ou duas quando há espaço e escala de texto compatível, com rolagem para a última opção.

## Validação local

```powershell
dart format --output=none --set-exit-if-changed lib test/themes_test.dart test/themes_widget_test.dart integration_test/themes_flow_test.dart
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
git diff --check
```

- Análise estática sem problemas; formatação e whitespace verificados.
- **222 testes aprovados**, incluindo os cinco temas em oito tamanhos/orientações e texto 1×/2×, de celular pequeno a tablet.
- IDs antigos e novo restaurados corretamente; gravações rápidas preservam a última escolha e as demais preferências.
- Migrações legadas para schema 6 preservam partidas, carteira e preferências. Selecionar e restaurar o tema das abelhas mantém o snapshot das partidas e os lançamentos de moedas.

## Capturas e validação Android

- [Home do Jardim das abelhas](antes-escola-magia/13-home-jardim-abelhas.png).
- [Partida com a flor e fichas verde-petróleo](antes-escola-magia/14-partida-jardim-abelhas.png).
- [Seletor com Jardim das abelhas em uso](antes-escola-magia/12-seletor-jardim-abelhas.png).

```powershell
flutter drive --no-pub --driver=test_driver/themes_driver.dart --target=integration_test/themes_flow_test.dart -d emulator-5554
```

Integração aprovada: selecionar os cinco temas; comparar snapshot e carteira antes/depois da troca para abelhas; retomar a campanha com as respostas existentes; formar a última palavra por arraste; avançar de nível e formar outra palavra sobre a flor; embaralhar sem perder respostas; retomar o diário com suas respostas anteriores; reabrir o banco e restaurar tema, snapshot, carteira e a nova rodada da campanha.

As três capturas foram inspecionadas: controles e textos legíveis, flor e fichas centralizadas, abelha afastada das letras e da instrução. Níveis, saldo e palavras são dados reais do jogo. A captura da home é anterior à conclusão do primeiro nível; a partida mostra o nível 2 e o saldo após sua recompensa. Não foram fixados valores da prévia. Capturas da versão anterior preservadas em `antes-jardim-abelhas/`.

Emulador Android API 35, `emulator-5554`, 1080×2400, build debug. O teste usa exclusivamente `themes_integration.db`; não limpa o banco normal do jogador. Não houve teste em aparelho físico ou medição de desempenho de produção.

## Artes e pacote

Arquivos finais, origem, prompts e pontos de configuração: [jardim-abelhas-recursos.md](jardim-abelhas-recursos.md).

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, entrada `lib/main.dart`. Atualizar com `adb install -r` para preservar dados.

O APK **0.6.0+11** foi compilado, instalado por atualização com sucesso e iniciado no emulador ao concluir esta entrega.
