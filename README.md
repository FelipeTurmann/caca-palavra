# Conecte palavras — etapa 2

Aplicativo Flutter/Dart para validar a mecânica local de conectar letras em português brasileiro. Abre diretamente no nível 1; contém dez níveis, palavras acentuadas, extras, embaralhamento e conclusão. Todo o progresso fica em memória.

## Executar

Na pasta `C:\Users\felip\Desktop\dev\workspace\caca-palavra`:

```powershell
flutter pub get
flutter devices
flutter run -d <id-do-Android>
```

Para iniciar o emulador existente: `flutter emulators --launch Medium_Phone_API_35`.
Se o SDK estiver incompleto, no Android Studio, abra SDK Manager > SDK Tools e instale Android SDK Command-line Tools (latest). Depois execute `flutter doctor --android-licenses` e aceite os termos que você revisar. Execute `flutter doctor -v` para conferir. A compilação pode solicitar uma plataforma/build tools adicional usada pelo Flutter instalado.

```powershell
dart format lib test
flutter analyze
flutter test
flutter test integration_test/game_flow_test.dart -d emulator-5554
flutter build apk --debug
```

## Onde ajustar

| Conteúdo | Arquivo |
|---|---|
| Dez níveis, fichas e grafia das respostas | `assets/data/levels.json` |
| Palavras válidas e grafia canônica dos extras | `assets/data/lexicon_pt_br.json` |
| Cores, tema e tipografia | `lib/core/theme/game_theme.dart` |
| Regras, resultados tipados e eventos | `lib/features/game/domain/game_engine.dart` |
| Normalização compartilhada e letras visuais | `lib/features/game/domain/word_normalizer.dart` |
| Validação dos arquivos | `lib/features/game/data/game_data.dart` |
| Durações de feedback, pulso, conclusão e embaralhamento | `GameTiming` em `lib/features/game/presentation/game_controller.dart` |
| Diâmetro das fichas, raio de toque e geometria | `lib/features/game/presentation/wheel_gesture.dart` |
| Tamanho do círculo e layout adaptável | `lib/features/game/presentation/game_screen.dart` |
| Traço de conexão (6 px) e fichas | `lib/features/game/presentation/widgets/letter_wheel.dart` |

O motor Dart não depende de Flutter. `GameEngine.submit` exige a sessão atual e IDs únicos de fichas existentes. Estado exposto é imutável. O callback opcional `onEvent` oferece eventos de submissão e conclusão para futuras integrações. O controlador cuida dos timers, ponteiros, prévia e bloqueios; não concede moedas.

O léxico contém somente 61 entradas curadas, não um dicionário completo. Uma palavra portuguesa ausente recebe “Palavra não reconhecida nesta versão.” Variantes normalizadas usam a primeira grafia do léxico para extras; alvos têm prioridade e preservam a grafia definida no nível. Dados impossíveis ou ambíguos bloqueiam o carregamento com erro legível.

Não há fontes remotas, API, anúncios, moedas, dicas, login, persistência, vidas ou cronômetro. O projeto não inclui ilustrações do protótipo. Os JSON foram copiados dos arquivos produzidos na conversa de especificação, preservando a origem dos dados.

Os testes cobrem dados, motor, identidade das fichas, normalização Unicode, gestos reais em widgets, segmentos rápidos, desfazer, multitouch, cancelamento, mudança de tamanho, layouts 320×568 e 412×915, paisagem, texto ampliado e o fluxo completo dos dez níveis. Resultados reais da execução e limitações do Android estão em `VALIDACAO.md`.
