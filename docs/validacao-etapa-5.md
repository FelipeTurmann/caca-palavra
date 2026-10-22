# Validação — etapa 5: finalizar a experiência

Data: 22/10/2026. Aplicativo 0.2.0+2. Projeto: `C:/Users/felip/Desktop/dev/workspace/caca-palavra`.

## Baseline e preservação

Antes de editar, foram verificados os diretórios e as instruções aplicáveis; não havia AGENTS.md aplicável. Git limpo no commit `10eecaa94d6da9ec37dc19bade5d897093044a52`. Baseline medido nesta etapa: **143 testes aprovados**, análise sem problemas. A etapa 4 estava incorporada nesse commit; não foi recriada ou descartada.

O banco SQLite passa de 3 para **4**, acrescentando `app_settings`. Payload continua em 2. Carteira, ledger, operações preparadas, snapshots, acentos, regras de dicas, recompensas e calendários permanecem na arquitetura existente. Perfis anteriores, inclusive nunca iniciados, são dispensados do tutorial obrigatório. Nenhuma animação, efeito ou ação da demonstração concede moedas.

## Entrega

- Cenário botânico vetorial em camadas, gatinho estático transparente, Nunito local, cartões claros e botões com gradiente e volume.
- Identidade compartilhada na home, partida, diário, resultado, loja, tutorial, configurações e modais. Dicas laterais com preços visíveis e alvos de pelo menos 48 unidades lógicas.
- Seleção com escala visual sem alterar o hit testing; acertos, extras e revelações preservados; vitória inédita com entrada discreta e confetes sem bloquear ações.
- Efeitos WAV locais e haptics independentes. Limitação de seleção a 50 ms, sem fila; prioridade para vitória/revelação, deduplicação por rodada/resultado ou recibo confirmado, até duas vozes nativas.
- Política única de movimento: preferência do aplicativo ou restrição do sistema. Modais, tutorial, extras e conclusão a seguem; redução não desliga som nem vibração.
- Preferências imediatas e persistidas em fila. Falha mantém a escolha na sessão e mostra erro/retry; mídia indisponível não bloqueia o jogo.
- Tutorial isolado de quatro passos, com gesto real, alternativa, voltar, embaralhar, pular e rever. Sem vínculo econômico com campanha/diário.
- Composição em duas áreas em paisagem, limites de largura em tablet e rolagem acessível. Palavras longas com texto ampliado permitem rolagem horizontal preservando o tamanho das letras.

Origem da arte, prompt final, licenças e pontos de configuração: [recursos-etapa-5.md](recursos-etapa-5.md).

## Testes automatizados

**176 testes aprovados** na execução final de `flutter test`. `dart format` aplicado. `flutter analyze` sem problemas.

Testes novos cobrem preferências serializadas, falha de gravação, leitura após reabrir banco, migração real 3 → 4, perfil anterior nunca iniciado, resultado pendente, tutorial incompleto, isolamento de moedas/snapshots, reprodução e revisão da demonstração, seleção e multitouch, prioridade de vitória, deduplicação, mídia indisponível, falha antes do commit e resolução imediata de recibo já confirmado. A escolha da interface só celebra sucesso confirmado; retry não repete o efeito.

A suíte anterior continua exercitando migrações de versões 1/2, operações preparadas, recibos, ledger, dicas, campanha, diário e expiração. O teste que esperava esquema 3 agora usa a versão atual do banco; as verificações de preservação permanecem.

### Matriz de layout realmente exercitada

Todas as combinações abaixo passaram com a fonte Nunito empacotada, em **1× e 2×**:

| Perfil | Retrato | Paisagem | Resultado |
|---|---|---|---|
| Celular pequeno | 320×568 | 568×320 | Aprovado |
| Referência | 360×800 | 800×360 | Aprovado |
| Celular alto | 412×915 | 915×412 | Aprovado |
| Tablet compacto | 600×960 | 960×600 | Aprovado |
| Tablet maior | 800×1280 | 1280×800 | Aprovado |

São 20 combinações de tamanho/texto. Foram montados home, diário, confirmação de dica, loja e compra simulada, configurações, tutorial e resultado, além de extras, mensagem de erro e maior palavra da campanha (seis letras, com acentos). Saldo alto também foi exercitado. Rolagem é permitida onde necessária; esses testes não significam que todo conteúdo caiba simultaneamente sem rolar em texto 2×.

Os cenários específicos de `hint_layout_test.dart` também passaram: 360×800 e 412×869, padding de sistema de 24 em cima e embaixo, quatro respostas diárias totalmente visíveis, dicas alinhadas à direita, preços e áreas de toque sem sobreposição com fichas, sem rolagem nessa composição.

## Integração Android

Emulador `emulator-5554`, Android API 35, x86_64. Instalações por `adb install -r`; bancos de integração têm nomes exclusivos e não abrem o save de produção.

- `integration_test/stage5_flow_test.dart`: tutorial novo, embaralhamento, conclusão da introdução, preferências, revisão isolada, rotação durante gesto sem submissão, retorno, chamadas nativas de áudio/haptic e reabertura do SQLite. Aprovado.
- `integration_test/stage4_flow_test.dart`: loja simulada, carteira, Dica, Super Dica, diário independente, resultado e virada de data. Aprovado.
- `integration_test/game_flow_test.dart`: campanha completa, gestos reais, acentos, dicas e preservação após o último nível. Aprovado.

### Force-stop em processos separados

Fixture: `integration_test/stage5_recovery_app.dart`; comando: `tool/test_stage5_recovery.ps1`. Banco exclusivo `stage5_recovery.db`.

| Fase | Resultado | Saldo | PID observado |
|---|---|---:|---:|
| seed_incomplete | OK | 60 | 5449 |
| verify_incomplete | OK | 60 | 5565 |
| seed_playing | OK | 30 | 5637 |
| verify_playing | OK | 30 | 5702 |
| prepare_hint | OK | 30 | 5764 |
| verify_hint | OK | 0 | 5835 |

O tutorial interrompido permanece incompleto e não muda o perfil. Preferências independentes e decisão de pular sobrevivem à troca de processo. Alvos/revelações e saldo da partida reaparecem. Uma dica preparada antes da interrupção é recuperada uma única vez; ledger fica com welcome e dois débitos de dica.

## Inspeção visual

Inspeção direta das telas renderizadas no emulador, comparadas com o protótipo: tutorial inicial, home com gatinho/cenário, partida com respostas e dicas laterais/preços, configurações, loja com avisos de simulação e confirmação de Dica. Foram observados contraste, legibilidade, cortes, posicionamento e consistência dos controles.

Capturas foram lidas exclusivamente em memória e descartadas. **Nenhum screenshot foi salvo na documentação ou no disco.** A inspeção nativa é uma amostra em retrato; a matriz de tablets e demais orientações foi exercitada por testes automatizados, não por aparelhos físicos de todos esses tamanhos.

## Medição em build de perfil

Fixture isolada `integration_test/stage5_profile_app.dart`, compilada com `flutter build apk --profile`, instalada e executada no emulador. Após aquecimento de dois segundos, 240 movimentos de arraste na geometria atual, com atualização da linha e sem gerar novas entradas dentro da mesma ficha.

Amostra: **250 quadros**. Construção p95: **3,009 ms**, com zero quadros acima de 16,7 ms nessa etapa. Rasterização p95: **15,128 ms**, com **2 quadros acima de 16,7 ms**. O caminho do gesto usa assets pré-carregados e não enfileira efeitos descartados, conforme a implementação e os testes do coordenador. Resultado capturado do marcador `STAGE5_PROFILE` no log do processo.

Isso mede uma amostra sintética de renderização em emulador, não latência percebida nem desempenho de todas as interações em aparelhos reais.

## APK e atualização

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, alvo **lib/main.dart**, versão **0.2.0+2**. Após as fixtures, a versão normal é recompilada, instalada e aberta novamente preservando dados. Não distribuir os APKs cujo alvo seja uma fixture de integração.

SHA-256: `81B977B368C0839CEBE107A4F8E764E779DBBBC4A082BA3231E3F05FF8F75738`.

Para atualizar mantendo dados:

```powershell
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```

Não é necessário desinstalar nem limpar os dados. Este é um APK de teste, assinado para desenvolvimento; publicação e pagamentos reais estão fora do escopo.

## Limitações e próximo ensaio

Não havia Android físico disponível. As chamadas e fluxos de áudio/vibração foram exercitados no emulador e por fakes; volume percebido, suavidade do motor e desempenho físico **não foram verificados**. Ausência de motor ou falha de mídia não impede o jogo.

Não houve sessão com jogadores. O roteiro está preparado em [roteiro-jogadores.md](roteiro-jogadores.md), sem alegar pesquisa já realizada. Não foram acrescentados música, anúncios reais, cobrança real, login, nuvem, telemetria, novos modos ou expansão do catálogo.
