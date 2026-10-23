# Escola de magia — implementação aprovada

Data: 23/10/2026. Versão: **0.7.0+12**.

O usuário aprovou a [prévia cartoon](escola-magia-aprovado.png) e autorizou o sexto tema. O cenário, o dragãozinho de asas recolhidas e o caldeirão foram incorporados sem nova geração de arte. O nome adotado é **Escola de magia**, conforme o pedido, substituindo o título antigo Oficina de magia da referência inicial.

## Resultado

- **Escola de magia** disponível gratuitamente em **Temas**, abaixo de **Desafio diário**.
- Cenário lavanda e creme, poções e cristais nas bordas; dragãozinho verde-menta na home, miniatura e canto da partida quando houver espaço.
- Abertura do caldeirão centralizada em relação à roda, com fichas verde-petróleo, letras brancas, contornos dourados e embaralhamento central.
- Respostas sobre superfície clara com contorno lavanda, mantendo células separadas e alinhadas.
- Aplicação imediata e restauração da escolha ao reabrir, com confirmação e tentativa de salvamento existentes.
- Variante discreta do cenário nas telas auxiliares; seletor com seis opções em uma ou duas colunas e rolagem.

O ID estável é `escola_magia`. O **Jardim do Gatinho** permanece padrão e os cinco IDs anteriores continuam válidos. Schema SQLite **6** e payload **2** preservados, sem migração adicional ou nova dependência. Trocar tema não altera partidas, palavras, níveis, moedas ou compras. Geometria e eventos de arraste continuam os existentes. As ilustrações ignoram toque e leitura semântica.

## Validação local

```powershell
dart format --output=none --set-exit-if-changed lib test/themes_test.dart test/themes_widget_test.dart integration_test/themes_flow_test.dart
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
git diff --check
```

- Análise estática sem problemas; formatação e whitespace verificados.
- **222 testes aprovados**, incluindo os seis temas em oito tamanhos/orientações e texto 1×/2×, de celular pequeno a tablet.
- IDs antigos e novo restaurados corretamente; gravações rápidas preservam a última escolha e as demais preferências.
- Migrações legadas para schema 6 preservam partidas, carteira e preferências. Selecionar e restaurar a Escola de magia mantém o snapshot das partidas e os lançamentos de moedas.

## Capturas e validação Android

- [Home da Escola de magia](screenshots/16-home-escola-magia.png).
- [Partida com caldeirão e fichas verde-petróleo](screenshots/17-partida-escola-magia.png).
- [Seletor com Escola de magia em uso](screenshots/15-seletor-escola-magia.png).

```powershell
flutter drive --no-pub --driver=test_driver/themes_driver.dart --target=integration_test/themes_flow_test.dart -d emulator-5554
```

Integração aprovada: selecionar os seis temas; comparar snapshot e lançamentos antes/depois da troca para magia; retomar a campanha preservando as respostas anteriores; formar outra palavra por arraste sobre o caldeirão; embaralhar sem perder respostas; retomar o diário com suas respostas anteriores; reabrir o banco e restaurar tema, snapshot, carteira e rodada da campanha.

As capturas usam dados reais: a partida mostra o nível 2 após a progressão da campanha e duas palavras encontradas. Níveis, saldo e palavras não foram fixados a partir da prévia. Capturas anteriores preservadas em `antes-escola-magia/`.

Inspeção final: abertura do caldeirão, fichas e embaralhamento concêntricos, textos legíveis e dragão de canto afastado dos controles. Na home, o mascote foi baixado ligeiramente para deixar os chifres livres das fichas decorativas; a captura final foi refeita e o fluxo Android passou novamente.

Emulador Android API 35, `emulator-5554`, 1080×2400, build debug. O teste usa exclusivamente `themes_integration.db` e não limpa o banco normal do jogador. Uma tentativa foi interrompida por desconexão do dispositivo; o aplicativo e os bancos foram confirmados presentes, foi guardada uma cópia local em `build/theme-qa-backup/before-magic-android.tar` (ignorada pelo Git), e o fluxo foi repetido com sucesso. Não houve teste em aparelho físico ou medição de desempenho de produção.

## Artes e pacote

Arquivos finais, origem, prompts e pontos de configuração: [escola-magia-recursos.md](escola-magia-recursos.md).

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, entrada `lib/main.dart`. Atualizar com `adb install -r` para preservar dados.

O APK **0.7.0+12** foi compilado, instalado por atualização com sucesso e iniciado no emulador ao concluir esta entrega.
