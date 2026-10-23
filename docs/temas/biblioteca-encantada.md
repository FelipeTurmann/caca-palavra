# Biblioteca encantada — implementação aprovada

Data: 22/10/2026. Versão: **0.4.0+8**.

O usuário aprovou as [imagens cartoon](biblioteca-encantada-aprovado.png) e autorizou adicionar o terceiro tema. O fundo e a coruja aprovados foram incorporados, com a base de livro e selo preparada no mesmo estilo.

## Resultado

- **Biblioteca encantada** disponível gratuitamente em **Temas**, abaixo de **Desafio diário**.
- Fundo de estantes e janela iluminada, coruja de óculos junto de livro aberto e fichas decorativas creme na home.
- Respostas sobre superfície clara, roda com selo verde-petróleo e dourado sobre livro aberto, mantendo fichas e botão de embaralhar reais.
- Miniatura composta das artes locais; cenário discreto em loja, configurações, tutorial e seletor.
- Seletor com todas as opções em uma coluna, ou duas quando há largura e escala de texto compatíveis. A terceira opção permanece acessível por rolagem.
- Aplicação imediata, confirmação de salvamento e restauração da escolha ao reabrir o aplicativo, usando o fluxo existente.

O novo ID estável é `biblioteca_encantada`. Os IDs anteriores continuam válidos e o **Jardim do Gatinho** permanece padrão. Schema SQLite **6** e payload **2** preservados, sem migração adicional. A escolha não altera campanha, diário, moedas, compras ou outras preferências. Não foram mudadas regras, vocabulário, geometria ou eventos de arraste. As ilustrações ignoram toque e leitura semântica.

## Capturas do aplicativo Android

- [Home da Biblioteca](screenshots/07-home-biblioteca.png).
- [Partida diária com palavra formada por arraste](screenshots/08-partida-biblioteca.png).
- [Seleção da Biblioteca com confirmação](screenshots/06-seletor-biblioteca.png).
- [Home do jardim](screenshots/04-home-jardim.png) e [home da capivara](screenshots/02-home-capivara.png).

As capturas usam o estado real do jogo. O nível, saldo, palavras e progresso da prévia aprovada são ilustrativos e não foram fixados no aplicativo. As capturas anteriores estão preservadas em `antes-biblioteca/`.

## Validação

Comandos executados:

```powershell
dart format --output=none --set-exit-if-changed lib test/themes_test.dart test/themes_widget_test.dart integration_test/themes_flow_test.dart
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter drive --no-pub --driver=test_driver/themes_driver.dart --target=integration_test/themes_flow_test.dart -d emulator-5554
git diff --check
```

Resultados:

- Análise estática sem problemas e formatação verificada.
- **222 testes aprovados**. Matriz com os três temas em oito tamanhos/orientações e texto 1×/2×, da tela pequena ao tablet.
- Persistência de todos os IDs e das outras preferências; gravações rápidas preservam a escolha final da Biblioteca.
- Migrações legadas para schema 6 preservam partidas, carteira e preferências; selecionar e restaurar a Biblioteca mantém o snapshot e os lançamentos de moedas.
- Integração Android aprovada: selecionar capivara e jardim, formar palavras, retomar diário e reabrir banco; selecionar Biblioteca, comparar perfil/carteira antes e depois da troca, formar palavra por arraste, embaralhar e reabrir novamente com tema, snapshot e ledger preservados.
- Inspeção visual da home, partida e seletor da Biblioteca: textos legíveis, artes coerentes com a proposta e controles livres de sobreposição.

Emulador Android API 35, `emulator-5554`, 1080×2400, build debug. A integração usa exclusivamente `themes_integration.db`; não limpa o banco normal do jogador. Não houve ensaio em aparelho físico ou medição de desempenho de produção.

## Recursos e pacote

Arquivos finais, origem, prompts e pontos de configuração: [biblioteca-encantada-recursos.md](biblioteca-encantada-recursos.md).

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, entrada `lib/main.dart`. A instalação de atualização deve usar `adb install -r` para preservar dados.

O APK **0.4.0+8** foi compilado, instalado por atualização com sucesso e iniciado no emulador ao concluir esta entrega.
