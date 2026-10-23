# Jardim do Gatinho — implementação do visual aprovado

Data: 22/10/2026. Versão: **0.3.3+7**.

O usuário aprovou a [prévia de início e partida](jardim-gatinho-aprovado.png) e autorizou a implementação. O fundo e o gatinho aprovados foram incorporados ao aplicativo, com um canteiro circular preparado no mesmo estilo.

## Resultado

- Jardim florido em cartoon 2D ao fundo da home e da partida.
- Gatinho creme e laranja cartoon na home, miniatura de seleção e canto da partida quando houver espaço.
- Canteiro circular com pedras e flores sob as letras; fichas creme e embaralhamento central com acabamento compatível com a proposta.
- Cartão de progresso com a barra calculada pelos níveis realmente concluídos, dicas e superfícies claras para legibilidade.
- Loja, configurações, tutorial e seletor recebem a variante discreta do fundo ativo.

O ID `jardim_gatinho`, seu papel de tema padrão e as preferências salvas continuam válidos. Não há migração de banco, nova dependência, mudança em regras, moedas, vocabulário ou comandos de partida. A geometria e os eventos de arraste permanecem os existentes; decoração não intercepta toque nem entra na leitura semântica.

## Capturas Android

- [Home do jardim](antes-biblioteca/04-home-jardim.png).
- [Partida no jardim](antes-biblioteca/05-partida-jardim.png).
- [Seletor com as duas miniaturas atualizadas](antes-biblioteca/01-seletor-capivara.png).
- [Jardim anterior](antes-jardim-cartoon/04-home-jardim.png).

As capturas são do aplicativo funcional. Na partida, GATO e GOTA foram formadas por arraste real; os textos e estados usam os dados do jogo, sem valores fixados a partir do protótipo.

## Validação

Comandos executados:

```powershell
dart format --output=none --set-exit-if-changed lib integration_test/themes_flow_test.dart
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter drive --no-pub --driver=test_driver/themes_driver.dart --target=integration_test/themes_flow_test.dart -d emulator-5554
git diff --check
```

Resultados:

- Análise estática sem problemas.
- **221 testes aprovados**, incluindo matriz dos dois temas em celular pequeno, referência, celular alto e tablet, retrato/paisagem e texto 1×/2×.
- Integração Android aprovada: selecionar capivara, formar palavra, retomar diário, reabrir banco, selecionar jardim, conferir preservação do perfil, formar outra palavra, embaralhar sem perder respostas e reabrir novamente restaurando o jardim e o snapshot.
- Inspeção visual das capturas de home, partida e seletor: fundo e mascote coerentes com a proposta, controles legíveis e áreas de toque livres.
- Formatação e whitespace verificados.

Emulador: Android API 35, `emulator-5554`, 1080×2400, build debug. Os testes Android usam exclusivamente `themes_integration.db`; não limpam o banco normal do jogador. Não houve ensaio físico, teste com jogadores ou medição de desempenho de produção.

## Recursos e pacote

Origem, arquivos e prompts completos: [jardim-gatinho-recursos.md](jardim-gatinho-recursos.md).

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, com entrada `lib/main.dart`. Para atualizar preservando dados, usar `adb install -r` após compilar o aplicativo normal.

O APK 0.3.3+7 foi compilado, instalado por atualização com sucesso e iniciado no emulador ao concluir a entrega.
