# Refinamento visual — Capivara na lagoa

Data: 22/10/2026. Versão: **0.3.1+5**.

Relatório histórico. A atualização para um traço mais cartoon está em [cartoon.md](cartoon.md).

Objetivo: aproximar o tema do protótipo sem alterar regras, navegação, persistência, economia ou geometria dos gestos. A implementação inicial de temas e as alterações locais anteriores foram preservadas.

## Alterações

- Cenário ilustrado local com céu de pôr do sol, reflexos na lagoa, vegetação nas margens e vitórias-régias; substitui o cenário simplificado no tema da capivara.
- Ilha local transparente com grama, pedras, flores e borda de água, desenhada sob as fichas na mesma área anterior.
- Fichas creme com sombra discreta e botão de embaralhar verde-oliva com contorno claro.
- Cartões da home com ícones circulares, estrela dourada e barra de progresso derivada dos níveis realmente concluídos. Os estados Jogar/Continuar/Ver resultado permanecem os existentes.
- Engrenagem em superfície creme, saldo com símbolo dourado, botão principal com gradiente verde-petróleo e ajudas com acabamento creme.
- Células vazias mais opacas e instrução com superfície clara para conservar leitura sobre a paisagem. Telas auxiliares usam a mesma arte com um véu creme mais forte.
- Pequena capivara na água, ao fundo do canto inferior da partida, somente em retrato com espaço e texto padrão. A decoração não recebe eventos nem entra na leitura de acessibilidade.

As novas imagens contêm apenas arte. Botões, textos, letras, preços e estado de jogo continuam sendo widgets reais. Não há nova dependência, alteração de schema, novo comando de jogo ou mudança no cálculo de toque. O Jardim do Gatinho conserva sua apresentação.

Arquivos visuais principais: `lib/core/widgets/lagoon.dart`, `lib/core/widgets/garden.dart` e as telas/componentes em `lib/features/game/presentation/`: `home_screen.dart`, `settings_screen.dart`, `game_screen.dart`, `widgets/home_art.dart`, `widgets/letter_wheel.dart` e `widgets/word_slots.dart`.

## Comparação visual

| Tela | Antes | Refinamento |
|---|---|---|
| Início | [Cenário simplificado](antes-refinamento/02-home-capivara.png) | [Cenário ilustrado](antes-cartoon/02-home-capivara.png) |
| Partida | [Ilha simplificada](antes-refinamento/03-partida-capivara.png) | [Ilha ilustrada e lagoa](antes-cartoon/03-partida-capivara.png) |

Também disponíveis: [seletor](antes-cartoon/01-seletor-capivara.png) e [retorno ao jardim](antes-cartoon/04-home-jardim.png). As capturas foram obtidas no emulador, usando o aplicativo funcional.

## Validação

- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --reporter expanded`: **221 testes aprovados**, incluindo persistência, carteira, campanha, diário, gestos e matriz de temas em celular/tablet, retrato/paisagem e texto 1×/2×.
- `flutter drive --no-pub --driver=test_driver/themes_driver.dart --target=integration_test/themes_flow_test.dart -d emulator-5554`: aprovado; seleção, arraste real, retomada do diário, reabertura de banco e retorno ao jardim, usando banco exclusivo de teste.
- Inspeção das capturas Android para verificar legibilidade, composição e ausência de decoração sobre as letras e ações.
- Formatação dos arquivos alterados e `git diff --check`.

Ambiente Android: emulador API 35, 1080×2400, build debug. A validação visual não representa teste com aparelho físico ou medição de desempenho em produção.

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, com entrada `lib/main.dart`. Atualizar com `adb install -r`, preservando dados, após executar a fixture de integração.

O APK 0.3.1+5 foi compilado, instalado por atualização com sucesso e iniciado no emulador ao concluir esta validação.

Origem dos arquivos finais e prompts da ferramenta integrada estão em [recursos.md](recursos.md). A [validação inicial](validacao.md) permanece como histórico da implementação de temas.
