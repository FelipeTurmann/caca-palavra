# Fundo do mar — implementação aprovada

Data: 22/10/2026. Versão: **0.5.0+10**.

O usuário aprovou a [prévia cartoon](fundo-mar-aprovado.png) e autorizou o quarto tema. O fundo, a tartaruga e a concha da proposta foram incorporados ao aplicativo sem nova geração de arte.

## Resultado

- **Fundo do mar** disponível gratuitamente em **Temas**, abaixo de **Desafio diário**.
- Cenário em aqua e turquesa, com luz filtrada, corais, algas e areia nas bordas; tartaruguinha verde na home e na miniatura.
- Respostas sobre superfície clara, concha perolada centralizada sob as fichas creme e embaralhamento verde-petróleo.
- Tartaruga de canto na partida quando há espaço; variante discreta do cenário em configurações, loja, tutorial e seletor.
- Aplicação imediata, confirmação de salvamento e restauração da escolha ao reabrir, usando o fluxo existente.

O ID estável é `fundo_mar`. O **Jardim do Gatinho** permanece padrão; os três IDs anteriores e a correção de alinhamento da Biblioteca continuam válidos. Schema SQLite **6** e payload **2** preservados, sem migração adicional ou nova dependência. Trocar tema não altera partidas, palavras, níveis, moedas ou compras. A geometria e os eventos de arraste continuam os existentes. As ilustrações ignoram toque e leitura semântica.

O seletor dinâmico acomoda as quatro opções em uma coluna ou duas quando há largura e escala de texto compatíveis, com rolagem. A superfície de leitura da Biblioteca foi extraída para um componente compartilhado com o tema marinho, preservando dimensões e aparência da Biblioteca.

## Validação local

```powershell
dart format --output=none --set-exit-if-changed lib test/themes_test.dart test/themes_widget_test.dart integration_test/themes_flow_test.dart
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
git diff --check
```

- Análise estática sem problemas; formatação e whitespace verificados.
- **222 testes aprovados**, incluindo os quatro temas em oito tamanhos/orientações e texto 1×/2×, de celular pequeno a tablet.
- IDs antigos e marinho restaurados corretamente; gravações rápidas preservam a última escolha e as demais preferências.
- Migrações legadas para schema 6 preservam partidas, carteira e preferências. Selecionar e restaurar o tema marinho mantém o snapshot das partidas e os lançamentos de moedas.

## Capturas e validação Android

- [Home do Fundo do mar](antes-jardim-abelhas/10-home-fundo-mar.png).
- [Partida diária com concha e palavra formada por arraste](antes-jardim-abelhas/11-partida-fundo-mar.png).
- [Seletor com Fundo do mar em uso](antes-jardim-abelhas/09-seletor-fundo-mar.png).

```powershell
flutter drive --no-pub --driver=test_driver/themes_driver.dart --target=integration_test/themes_flow_test.dart -d emulator-5554
```

Integração aprovada: selecionar os quatro temas, preservar campanha e diário ao trocar de visual, formar palavra por arraste sobre a concha, embaralhar sem perder respostas, reabrir o banco e restaurar tema, snapshot e lançamentos de moedas. A retomada da campanha manteve as duas respostas anteriores; o diário manteve a resposta da Biblioteca e recebeu a próxima no tema marinho.

As três capturas marinhas foram inspecionadas: textos legíveis, concha centralizada com as fichas e o embaralhamento, tartaruga afastada dos controles. Os valores e palavras refletem o estado real do jogo, sem fixar dados da prévia. As capturas da versão anterior estão preservadas em `antes-fundo-mar/`.

Emulador Android API 35, `emulator-5554`, 1080×2400, build debug. A integração usa exclusivamente `themes_integration.db` e não limpa o banco normal do jogador. O emulador existente foi reaberto sem apagar seus dados. Não houve teste em aparelho físico ou medição de desempenho de produção.

## Artes e pacote

Arquivos finais, origem, prompts e pontos de configuração: [fundo-mar-recursos.md](fundo-mar-recursos.md).

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, com entrada `lib/main.dart`. Atualizar com `adb install -r` para preservar dados.

O APK **0.5.0+10** foi compilado, instalado por atualização com sucesso e iniciado no emulador ao concluir esta entrega.
