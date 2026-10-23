# Capivara na lagoa — estilo cartoon

Data: 22/10/2026. Versão: **0.3.2+6**.

Relatório histórico da capivara cartoon. A atualização posterior do jardim está em [jardim-gatinho-cartoon.md](jardim-gatinho-cartoon.md).

Atualização visual solicitada após a aprovação da composição anterior. Cenário, ilha e capivara foram redesenhados em cartoon 2D, com formas mais arredondadas, contornos definidos, sombras simples e menos textura realista.

A composição aprovada foi mantida: pôr do sol e lagoa ao fundo, mascote na home e no canto inferior da partida, ilha sob as letras e controles reais sobre a decoração. A mudança no código do aplicativo se limita aos caminhos das três artes e ao manifesto de recursos/versão. Não altera navegação, tamanhos dos alvos de toque, regras, preferências, dados de progresso ou moedas.

## Comparação

| Tela | Anterior | Cartoon |
|---|---|---|
| Início | [Versão ilustrada](antes-cartoon/02-home-capivara.png) | [Home cartoon](antes-jardim-cartoon/02-home-capivara.png) |
| Partida | [Versão ilustrada](antes-cartoon/03-partida-capivara.png) | [Partida cartoon](antes-jardim-cartoon/03-partida-capivara.png) |

[Seletor atualizado](antes-jardim-cartoon/01-seletor-capivara.png) e [retorno ao Jardim do Gatinho](antes-jardim-cartoon/04-home-jardim.png).

Os originais das artes e as capturas anteriores foram preservados. Apenas as variantes `*-cartoon.png` são empacotadas para a capivara nesta versão. Os três arquivos finais, origem e prompts completos estão em [recursos-cartoon.md](recursos-cartoon.md).

## Validação

- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --reporter expanded`: **221 testes aprovados**, incluindo gestos, persistência, campanha, diário e layout dos temas em retrato, paisagem e texto ampliado.
- Fluxo Android com `integration_test/themes_flow_test.dart` e `test_driver/themes_driver.dart`: aprovado; seleção, formação real de uma palavra, retomada do diário, reabertura do banco e retorno ao jardim. As capturas foram geradas pelo app funcional e inspecionadas visualmente, conferindo a aplicação das três artes, contraste e preservação da composição.
- `git diff --check` e verificação de formatação dos arquivos Dart alterados.

O fluxo usa exclusivamente `themes_integration.db`, no emulador Android API 35, resolução 1080×2400. Não apaga o banco normal do jogador.

APK de teste: `build/app/outputs/flutter-apk/app-debug.apk`, entrada `lib/main.dart`. Atualizar com `adb install -r` para preservar os dados. Não houve teste com aparelho físico ou medição de desempenho em produção.

Ao concluir a validação, o APK normal 0.3.2+6 foi compilado, instalado por atualização com sucesso e iniciado no emulador.
