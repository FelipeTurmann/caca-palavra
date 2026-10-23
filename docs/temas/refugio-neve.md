# Refúgio na neve — implementação e validação

Data: 23/10/2026. Versão: **0.8.0+13**.

O usuário aprovou a [prévia cartoon](refugio-neve-aprovado.png) e autorizou integrar o novo tema.

## Entrega

- **Refúgio na neve** como sétima opção gratuita em **Temas**, abaixo de **Desafio diário** na home.
- Cenário nevado com pinheiros e cabana iluminada, pinguim de cachecol coral e disco de gelo aprovados.
- Fichas azul-gelo com letras em petróleo escuro, embaralhamento menta e painel de respostas creme com contorno azul suave.
- Cenário discreto nas telas auxiliares e miniatura com as mesmas artes locais.
- ID estável `refugio_neve`, restaurado pelo salvamento local existente.

O Jardim do Gatinho permanece padrão; os seis temas anteriores continuam disponíveis. Schema SQLite **6** e payload **2** mantidos, sem nova migração ou dependência. Trocar o tema preserva campanha, diário, moedas e demais preferências. A compensação de escala atua somente no PNG da base, mantendo fichas, traço de conexão e áreas de toque nas coordenadas existentes.

## Validação local

- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --reporter expanded`: **222 testes aprovados**.
- A matriz de interface inclui os sete temas em oito tamanhos/orientações e texto 1×/2×, de 320×568 a tablet.
- Todos os IDs restaurados; fallback para IDs desconhecidos preservado.
- Mudanças rápidas mantêm a última escolha e as demais preferências.
- Migrações legadas para schema 6 preservam partidas, carteira e preferências. Selecionar e restaurar o novo tema mantém snapshot e lançamentos.
- PNGs integrados idênticos aos aprovados, verificados por SHA-256.
- Formatação Dart verificada sem alterações e `git diff --check` aprovado.

## Android

Integração aprovada no emulador Android API 35, `emulator-5554`, 1080×2400, build debug. O fluxo usa exclusivamente `themes_integration.db`; não limpa o banco normal do jogador.

```powershell
flutter drive --no-pub --driver=test_driver/themes_driver.dart --target=integration_test/themes_flow_test.dart -d emulator-5554
```

O fluxo selecionou os sete temas, comparou snapshot e lançamentos antes/depois da troca para neve, retomou campanha e diário, concluiu a rodada já iniciada e formou outra palavra por arraste no disco de gelo. Embaralhar preservou as respostas; reabrir o banco restaurou o tema, snapshot, carteira e rodada da campanha.

- [Seletor com Refúgio na neve em uso](screenshots/18-seletor-refugio-neve.png).
- [Home do Refúgio na neve](screenshots/19-home-refugio-neve.png).
- [Partida sobre o disco de gelo](screenshots/20-partida-refugio-neve.png).

Inspeção visual: disco, fichas e embaralhamento concêntricos, letras legíveis e pinguim afastado dos controles da partida. A home mostra o nível 2 com 80 moedas; após concluir a rodada, a captura da partida mostra o nível 3, 100 moedas e BOLA encontrada. São dados reais do fluxo de teste, não valores fixados a partir da prévia. A base aceita as letras reais e sua ordem, inclusive após embaralhar.

Não houve teste em aparelho físico nem medição de desempenho de produção.

Capturas anteriores preservadas em `antes-refugio-neve/`. Uma cópia preventiva dos bancos do emulador foi guardada em `build/theme-qa-backup/before-snow-android.tar`, fora do controle de versão.

## Artes e pacote

Arquivos finais, prompts, origem e pontos de configuração: [refugio-neve-recursos.md](refugio-neve-recursos.md).

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, entrada `lib/main.dart`. Atualizar com `adb install -r` para preservar os dados.

O APK normal **0.8.0+13** foi compilado, instalado por atualização e iniciado com sucesso no emulador. O Android confirmou `versionName=0.8.0`, `versionCode=13` e a presença do banco normal do jogador após a atualização.

