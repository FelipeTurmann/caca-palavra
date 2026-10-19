# Conecte palavras — etapa 2

Aplicativo Flutter/Dart para validar a mecânica local de conectar letras em português brasileiro. Abre diretamente no nível 1; contém dez níveis, palavras acentuadas, extras, embaralhamento e conclusão. As extras têm coleta animada, meta opcional e selo visual Explorador. Todo o progresso fica em memória.

## Extras e selo Explorador

Cada extra nova mostra sua grafia, revela uma letra, envia uma estrela até o botão Extras e produz um pulso no contador. O jogo sorteia uma resposta ainda não acertada que tenha pelo menos dois quadrados escondidos e, depois, um desses quadrados. A letra revelada pode ser qualquer uma da resposta, mesmo que não exista na extra formada. Ela aparece em dourado com uma estrela, usando a grafia canônica e os acentos da resposta. A palavra só é considerada encontrada quando o jogador a forma no círculo.

Pelo menos um quadrado de cada resposta permanece escondido. Quadrados já revelados e respostas acertadas ficam fora do sorteio. Se todos os quadrados elegíveis acabarem, as extras continuam sendo registradas e contando para o selo, sem revelar outra letra. A mensagem informa “Extras continuam contando.” As revelações sobrevivem ao embaralhamento e ao redimensionamento; são limpas no próximo nível ou reinício.

A meta aparece junto do contador. Ao alcançá-la, aparece “Explorador conquistado!”. A lista destaca a descoberta mais recente, explica a meta e mostra somente palavras já encontradas. Na conclusão, aparecem as extras descobertas e o selo, quando conquistado.

O selo é apenas visual e vale para a rodada atual. Extras são opcionais para avançar. Uma repetição não soma progresso, revela letras ou dispara coleta; depois de conquistar o selo, novas extras continuam contando e revelando letras enquanto houver quadrados elegíveis. Novos gestos não esperam a animação e têm prioridade sobre mensagens antigas. Com redução de movimento, o registro, as letras e o selo funcionam sem o voo da estrela ou pulsos.

O campo `extraGoal` de cada nível em `assets/data/levels.json` define a meta: 1 no nível 1, 2 nos níveis 2–4 e 3 nos níveis 5–10. O carregamento rejeita metas não positivas ou maiores que a quantidade de extras distintas que podem ser formadas com as fichas e o léxico. Se o campo estiver ausente, o padrão é 1. Ajustar o léxico pode exigir rever essas metas.

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
dart format lib test integration_test
flutter analyze
flutter test
flutter test integration_test/game_flow_test.dart -d emulator-5554
flutter build apk --debug
```

## Onde ajustar

| Conteúdo | Arquivo |
|---|---|
| Dez níveis, fichas, grafia das respostas e meta `extraGoal` | `assets/data/levels.json` |
| Palavras válidas e grafia canônica dos extras | `assets/data/lexicon_pt_br.json` |
| Cores, tema e tipografia | `lib/core/theme/game_theme.dart` |
| Regras, resultados tipados e eventos | `lib/features/game/domain/game_engine.dart` |
| Normalização compartilhada e letras visuais | `lib/features/game/domain/word_normalizer.dart` |
| Validação dos arquivos | `lib/features/game/data/game_data.dart` |
| Durações de feedback, pulso, conclusão, embaralhamento, coleta (800 ms) e celebração (1800 ms) | `GameTiming` em `lib/features/game/presentation/game_controller.dart` |
| Botão Extras, meta, lista, selo e resumo de descobertas | `lib/features/game/presentation/widgets/explorer_progress.dart` |
| Trajeto e aparência da estrela de coleta | `lib/features/game/presentation/widgets/extra_collection_layer.dart` |
| Diâmetro das fichas, raio de toque e geometria | `lib/features/game/presentation/wheel_gesture.dart` |
| Tamanho do círculo e layout adaptável | `lib/features/game/presentation/game_screen.dart` |
| Traço de conexão (6 px) e fichas | `lib/features/game/presentation/widgets/letter_wheel.dart` |
| Aparência dos quadrados revelados | `lib/features/game/presentation/widgets/word_slots.dart` |

O motor Dart não depende de Flutter. `GameEngine.submit` exige a sessão atual e IDs únicos de fichas existentes. Estado exposto é imutável, incluindo o mapa de posições reveladas por resposta. O callback opcional `onEvent` oferece eventos de submissão, conclusão e conquista do selo para futuras integrações. `SubmissionResult.revealedLetter` informa a resposta, índice e grafia da letra concedida. O sorteio usa o gerador aleatório injetável do motor. A conquista é derivada de extras distintas e emite evento uma única vez por rodada. O controlador cuida dos timers, ponteiros, prévia e bloqueios; não concede moedas.

O léxico contém somente 61 entradas curadas, não um dicionário completo. Uma palavra portuguesa ausente recebe “Palavra não reconhecida nesta versão.” Variantes normalizadas usam a primeira grafia do léxico para extras; alvos têm prioridade e preservam a grafia definida no nível. Dados impossíveis ou ambíguos bloqueiam o carregamento com erro legível.

Não há fontes remotas, API, anúncios, moedas, login, persistência, vidas ou cronômetro. O projeto não inclui ilustrações do protótipo. Os JSON foram copiados dos arquivos produzidos na conversa de especificação, preservando a origem dos dados.

Os testes cobrem dados, motor, identidade das fichas, normalização Unicode, gestos reais em widgets, segmentos rápidos, desfazer, multitouch, cancelamento, mudança de tamanho, layouts 320×568 e 412×915, paisagem, texto ampliado e o fluxo completo dos dez níveis. Também verificam metas possíveis, conquista única, extras após o selo, coleta sem bloquear novos gestos, redução de movimento, resumo, reinício e cancelamento de efeitos. As revelações têm testes de sorteio, acentos, exclusão de respostas encontradas, saturação com uma letra escondida por palavra, repetição, imutabilidade e limpeza entre rodadas. Resultados reais da base estão em `VALIDACAO.md`; as validações das features estão em `docs/validacao-extras.md` e `docs/validacao-revelacao-extras.md`.
