# Validação da etapa 2

Executada em 19/10/2026, no projeto `C:\Users\felip\Desktop\dev\workspace\caca-palavra`.

## Resultados reais

| Verificação | Resultado |
|---|---|
| Formatação Dart em `lib`, `test` e `integration_test` | Aplicada |
| `flutter analyze --no-pub` | Aprovado: `No issues found!` |
| `flutter test --reporter expanded` | Aprovado: 35 testes |
| `flutter test integration_test/game_flow_test.dart -d emulator-5554 --reporter expanded` | Aprovado: 1 teste de integração, percorrendo os dez níveis |
| `flutter build apk --debug` | Aprovado, APK normal gerado |
| Instalação e abertura do APK normal | Aprovadas no emulador Android |
| Gesto no aplicativo normal, fora do driver de testes Flutter | Toques injetados via ADB e capturas inspecionadas visualmente |

Ambiente: Flutter estável 3.44.9, Dart 3.12.2, Windows 11 e emulador `Medium_Phone_API_35`, Android 15/API 35, x86_64.

## Cobertura

- Dez níveis, 39 alvos e 61 entradas do léxico; IDs, tamanhos, multiplicidades e presença dos alvos no léxico.
- Normalização de maiúsculas/minúsculas, acentos, cedilha e Unicode decomposto; rejeição de símbolos, dados impossíveis e alvos ambíguos como AVÓ/AVÔ.
- Acertos, repetições, extras separados, prioridade de alvo, IDs inválidos, ficha repetida e sessão antiga.
- Embaralhamento com aleatoriedade determinística e fallback, incluindo letras repetidas, preservando descobertas e identidades.
- Arrastes reais em widgets, desfazer, fichas distintas com a mesma letra, movimentos rápidos, cruzamento de linhas, liberação fora do círculo, cancelamento e segundo dedo.
- Bloqueio de embaralhamento durante arraste/transição/conclusão, rolagem das respostas, perda de foco, botão voltar e mudança de tamanho.
- Layouts 320×568, 412×915 e 915×412, texto em escala 1 e 2, além de prévia de seis letras com fonte ampliada.
- Timers de feedback, cancelamento ao descartar a tela, conclusão única, próximos níveis e reinício limpo.

No Android, o teste de integração usou o aplicativo e os assets reais, encontrou TOGA, abriu a lista de extras, formou todas as respostas dos dez níveis, conferiu Ç/Ã em AÇÃO, avançou pelas conclusões e reiniciou no nível 1.

Na conferência adicional do APK normal, foram injetados os movimentos G → A → T → A. A tela mostrou GA, dois tokens selecionados e uma conexão, confirmando o desfazer. Em seguida, T → O e liberação fora do círculo preencheram GATO e atualizaram o contador para 1 de 3. Não houve teste por jogador humano nem em aparelho físico; essa conferência usou comandos ADB e inspeção das imagens.

Capturas do aplicativo normal:

- [Partida inicialmente vazia](docs/validacao/android-inicio.png).
- [Desfazer durante o arraste](docs/validacao/android-desfazer.png).
- [GATO reconhecido após soltar fora do círculo](docs/validacao/android-acerto.png).

APK: `build/app/outputs/flutter-apk/app-debug.apk`.

## Limites e ambiente Android

O léxico é reduzido e curado para esta etapa. Palavras portuguesas ausentes recebem a mensagem de não reconhecimento nesta versão. O progresso existe somente em memória. Não há anúncios, moedas, dicas, persistência ou serviços externos, conforme o escopo.

O diagnóstico inicial do Flutter apontou ausência de Android SDK Command-line Tools e não conseguiu determinar o estado das licenças. A compilação utilizou licenças que já estavam registradas na máquina e instalou NDK 28.2.13676358, Build Tools 36, plataforma Android 36 e CMake 3.22.1. O APK e o teste Android passaram. Para manutenção do SDK por linha de comando, continua recomendável instalar Command-line Tools pelo SDK Manager; o README contém o procedimento.

O Gradle/JVM emitiu avisos de acesso nativo durante a compilação, sem impedir o resultado. Não restaram avisos do analisador Flutter.

Os arquivos originais em `docs` e `especificacao` foram preservados. A implementação inclui a base Android gerada pelo Flutter, motor Dart, interface, assets, testes, README e este relatório.
