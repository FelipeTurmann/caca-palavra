# Conecte palavras — etapa 3

Aplicativo Flutter/Dart para Android, com palavras em português brasileiro e progresso local em SQLite. A entrada é a tela inicial: **Jogar**, **Continuar · Nível N** ou **Ver resultado · Nível N**, conforme o progresso. Ao terminar a coleção, a campanha e o saldo são preservados.

## Moedas, dicas e extras

- O perfil recebe **60 moedas uma única vez**.
- A primeira conclusão de cada nível rende **20 moedas**.
- Conquistar o selo Explorador rende **10 moedas uma única vez por nível**, além da revelação gratuita da extra. O saldo e o selo são confirmados na mesma transação. Selos já conquistados em versões anteriores permanecem válidos; o bônus vale para novas conquistas.
- A dica custa **30 moedas** e exige confirmação. Abrir ou cancelar o diálogo não cobra.
- Saldo insuficiente informa quanto falta. Não há botão de anúncio.
- Cada extra inédita continua revelando uma letra gratuitamente e contando para a meta e o selo Explorador.
- Dicas gratuitas e pagas usam a mesma política: sorteiam uma resposta ainda não encontrada e depois uma posição inédita. Pelo menos um quadrado permanece escondido por palavra; a resposta precisa ser formada no círculo.
- Letras reveladas preservam acentos e cedilha. Respostas encontradas, posições já reveladas e palavras com apenas uma posição escondida ficam fora do sorteio.
- Quando as posições elegíveis acabam, não há cobrança. Novas extras continuam contando para o selo.

## Progresso e dados locais

O banco `conecte_palavras_v1.db` fica no diretório privado do aplicativo. `profiles` contém saldo, revisão e payload do progresso; `coin_transactions` registra os créditos e débitos; `operation_requests` guarda operações preparadas e seus resultados. O payload do progresso não duplica saldo ou revisão.

Submissões válidas, extras, revelações, embaralhamento, dicas, conclusão e avanço são persistidos. O coordenador serializa os comandos; saldo e progresso são publicados após o commit. A última resposta, a recompensa e a liberação do próximo nível são uma transação. Cada recompensa usa `level-completion:<levelId>`, independente da versão do catálogo. Dicas têm identificador e proposta persistidos, inclusive a posição sorteada, para retomar sem duplicar o débito ou sortear outra letra.

Ao encerrar o processo depois de uma conclusão, a home oferece **Ver resultado**. A tela informa que a recompensa já foi recebida. Avançar reconhece o resultado e cria a próxima rodada; o último resultado volta à home com a campanha concluída. Não há opção de reiniciar ou apagar a campanha nesta etapa.

Um erro de leitura não cria outro perfil nem concede moedas novamente. Um erro de gravação mantém o último estado confirmado e apresenta **Tentar novamente**. A navegação aguarda operações pendentes. O botão voltar primeiro cancela um gesto ativo; fora do gesto, retorna ao início.

Não há sincronização, login ou serviço remoto. Desinstalar ou limpar os dados do Android pode remover o progresso. O ledger e a revisão garantem consistência local; não representam proteção absoluta contra alteração manual em um aparelho comprometido.

## Executar e validar

Na pasta `C:\Users\felip\Desktop\dev\workspace\caca-palavra`:

```powershell
flutter pub get
flutter devices
flutter run -d emulator-5554
```

Para iniciar o emulador existente: `flutter emulators --launch Medium_Phone_API_35`.

```powershell
dart format lib test integration_test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test integration_test/game_flow_test.dart -d emulator-5554 --reporter expanded
flutter build apk --debug
```

O APK normal é gerado em `build/app/outputs/flutter-apk/app-debug.apk`.

Os testes de persistência usam SQLite real em arquivos temporários por meio de `sqflite_common_ffi`. Os testes de widgets usam um repositório de resposta imediata para evitar misturar I/O nativo com o relógio simulado do Flutter. A integração Android usa exclusivamente `stage3_integration.db`; a fixture de recuperação usa `stage3_recovery.db`. Nenhum desses testes limpa o banco de produção.

Para reproduzir o teste de encerramento real do processo, compile a fixture e execute o roteiro PowerShell em `tool/test_android_recovery.ps1`:

```powershell
flutter build apk --debug -t integration_test/recovery_app.dart
./tool/test_android_recovery.ps1
# Restaurar o aplicativo normal após testar:
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

O roteiro usa `adb install -r`, `am force-stop` e novas aberturas, sem desinstalar. Ele verifica a mesma posição revelada, saldo e extras após uma compra, resultado pendente após o commit antes da animação, avanço e campanha final. Os marcadores de teste são texto; não são gerados prints.

## Onde ajustar

| Configuração | Arquivo |
|---|---|
| Valores 60 / 20 / 10 / 30 | `Economy` em `lib/features/game/application/campaign_models.dart` |
| Catálogo, fichas, respostas e meta `extraGoal` | `assets/data/levels.json` |
| Léxico e grafia canônica de extras | `assets/data/lexicon_pt_br.json` |
| Versão SQLite, migrações e transações | `lib/features/game/data/progress_repository.dart` |
| Versão e estrutura do save | `CampaignProfile` em `lib/features/game/application/campaign_models.dart` |
| Coordenação, operações e retomada | `lib/features/game/application/game_session_coordinator.dart` |
| Restauração e sorteio de posições | `lib/features/game/domain/game_engine.dart` |
| Cores, tipografia e tema | `lib/core/theme/game_theme.dart` |
| Durações de feedback, conclusão, pulso, embaralhamento e coleta | `GameTiming` em `lib/features/game/presentation/game_controller.dart` |
| Aparência dos quadrados revelados e estrela | `lib/features/game/presentation/widgets/word_slots.dart` |
| Home, carteira e mensagens de salvamento | `lib/features/game/presentation/home_screen.dart` |
| Partida, dicas e resultado | `lib/features/game/presentation/game_screen.dart` |

O catálogo atual tem 10 níveis, 39 respostas e 61 entradas no léxico. O tamanho da campanha não é fixo no código. É permitido anexar novos IDs ao final mantendo a ordem e os IDs existentes. Níveis anteriores não recebem recompensa novamente. O fingerprint detecta mudanças em fichas, respostas e meta de níveis já jogados; essas alterações exigem migração explícita. Versão SQLite, schema do payload e versão do catálogo são independentes.

O motor continua sem dependência de Flutter. A identidade das fichas, normalização Unicode, gestos rápidos, desfazer, multitouch, redução de movimento e selo Explorador foram preservados. O callback de evento observa submissões e conclusões confirmadas; ele não é a origem dos lançamentos financeiros.

O léxico é uma coleção curada pequena, não um dicionário completo. Uma palavra ausente recebe “Palavra não reconhecida nesta versão.” Não há anúncios, vidas ou cronômetro.

A validação desta entrega está em `docs/validacao-etapa-3.md`. Relatórios anteriores continuam disponíveis para histórico.

Validação da recompensa de 10 moedas por selo: [docs/validacao-bonus-explorador.md](docs/validacao-bonus-explorador.md).
