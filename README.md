# Conecte palavras (0.15.1+33)

Aplicativo Flutter/Dart para Android, com palavras em português brasileiro, campanha e desafio diário. O fluxo normal agora integra `auth-service` e `caca-palavra-cartoon-api`: identidade, carteira, conclusões e temas vêm do servidor; a rodada parcial fica no SQLite. A loja está oculta nesta etapa. O perfil local antigo não é importado: uma nova conta começa no nível 1 com 60 moedas.

Veja [configuração e validação da integração](INTEGRACAO-APIS.md), incluindo encaminhamento de portas no Android e login Google. As descrições abaixo de migrações/entregas locais anteriores são histórico; as regras de sessão, confirmação financeira e recuperação do modo online estão nesse guia.

O `idJogo` é o UUID fixo `2e4ffdce-36d4-4461-856c-b00f083fed48`, compartilhado pelas APIs e pelo app. Veja [identidade do jogo e migração](GAME_ID.md) para a atualização do banco e a ordem de reinício.

Para executar a versão online no Android conectado, use `./tool/run_online_android.ps1`. O script verifica as APIs, encaminha as portas e instala/executa `lib/main.dart`. APKs de 24/10, como `0.13.2-compat+26`, ainda são do protótipo local.

## Campanha de 2.500 níveis

A campanha contém **2.500 níveis**, com **3 a 6 respostas obrigatórias**, **4 a 6 fichas** e extras separadas. A dificuldade cresce em cinco faixas, com um nível mais leve a cada cinco. Um mesmo conjunto de letras só reaparece após pelo menos 100 posições e sempre com respostas diferentes. O catálogo usa 1.639 conjuntos de letras distintos.

O léxico contém **1.379 entradas**, todas com frases locais do mascote: palavras comuns, plurais explicitamente aprovados e verbos no infinitivo. Respostas mantêm os acentos e a cedilha; a formação usa A–Z. Nomes próprios, siglas, abreviações e conjugações exclusivamente verbais ficam excluídos. Colisões como AVÓ/AVÔ têm uma única grafia canônica; não há descarte silencioso de variantes. Os sete desafios diários também foram revistos, mantendo a rotação e a data-base.

Gerador reproduzível em `tool/content/`, validação compartilhada com o aplicativo e relatórios em [docs/niveis/validacao.md](docs/niveis/validacao.md). Para validar: `dart run tool/validate_catalog.dart`. A análise completa ocorre em isolate no Android durante a carga. O conjunto antigo continua apenas como fixture dos testes de mecânica.

Os níveis 1–10 também foram revisados. Conforme o escopo escolhido, não há migração de partidas antigas: perfis incompatíveis são preservados e apresentam erro de carga. Esta versão deve ser testada com uma campanha nova; não limpa automaticamente carteira, compras ou temas. A curva de dificuldade é uma classificação editorial e técnica, ainda sem validação com jogadores.

## Temas

Na home, **Temas**, logo abaixo de **Desafio diário**, abre os sete visuais com miniaturas, cadeados e saldo. **Jardim do Gatinho** é gratuito; **Capivara na lagoa** custa **500 moedas**, **Biblioteca encantada** custa **750**, **Fundo do mar** custa **1000** e **Jardim das abelhas** custa **1200**. A compra exige confirmação, desconta as moedas uma única vez e desbloqueia o tema permanentemente, aplicando-o após a compra. Temas já liberados usam **Usar tema** gratuitamente, com o painel permanecendo aberto.

**Escola de magia** libera automaticamente ao alcançar o **nível 50 da campanha** e **Refúgio na neve**, o **nível 100**, sem cobrança. Ambos os marcos estão disponíveis no catálogo de 2.500 níveis. O diário compartilha os temas comprados, mas não conta como nível da campanha. Na atualização, uma seleção antiga ainda bloqueada retorna ao Jardim do Gatinho, sem cobrar ou alterar as partidas. A escolha visual vale para campanha, diário, loja, configurações, tutorial e resultado.

No modo online, as compras de temas são confirmadas na API e seus recibos ficam associados à conta no SQLite. Pedidos repetidos não cobram novamente. A seleção visual continua local. [Regras e capturas da entrega local anterior](docs/temas/desbloqueio.md).

O Jardim do Gatinho continua como padrão de instalações novas e perfis anteriores e agora usa o visual cartoon aprovado: fundo de jardim florido, gatinho 2D e canteiro circular com pedras e flores sob as letras. A capivara mantém seu mascote e artes cartoon: pôr do sol, lagoa com reflexos, vitórias-régias e ilha. As artes são camadas decorativas; controles, textos e fichas continuam reais e usam a mesma geometria de toque. As miniaturas reutilizam as mesmas artes locais, sem captura de telas embutida.

A migração **SQLite 5 → 6** acrescenta `app_settings.visual_theme_id`; mantém carteira, rodadas, pedidos, plano sem anúncios e outras preferências. Se salvar falhar, a escolha fica ativa na sessão, com aviso e **Tentar novamente** na home e no seletor. Após encerrar o processo, restaura-se a última escolha confirmada.

A **Biblioteca encantada** usa o fundo e a coruja cartoon aprovados, com estantes, luz dourada, painel claro para as respostas e selo verde-petróleo sobre livro aberto sob as letras. O seletor acomoda todas as opções com rolagem e duas colunas quando há espaço. O ID `biblioteca_encantada` usa a persistência existente; não exige outra migração.

O **Fundo do mar** usa as artes cartoon aprovadas: cenário em aqua e turquesa, tartaruguinha verde e concha perolada centralizada sob as fichas creme. As respostas continuam sobre superfície clara, e o botão de embaralhar tem acabamento verde-petróleo. O ID `fundo_mar` usa a mesma persistência, sem alterar a geometria das letras ou criar migração de banco.

O **Jardim das abelhas** usa o cenário ensolarado, a abelhinha e a base de margarida aprovados. Fichas verde-petróleo com letras brancas ficam sobre a flor centralizada; respostas e superfície de leitura têm contornos em tons de mel. O ID `jardim_abelhas` usa o mesmo salvamento local, preservando os quatro temas anteriores e as partidas existentes.

A **Escola de magia** usa o cenário lavanda e creme, o dragãozinho verde-menta de asas recolhidas e o caldeirão aprovados. A abertura do caldeirão fica alinhada ao centro da roda, com fichas verde-petróleo, letras brancas e contornos dourados. O ID `escola_magia` usa a persistência existente; os cinco temas anteriores e as partidas salvas continuam válidos, sem nova migração de banco.

O **Refúgio na neve** usa o cenário com pinheiros nevados e cabana iluminada, o pinguim de cachecol coral e o disco de gelo aprovados. As fichas azul-gelo têm letras em petróleo escuro e o embaralhamento é menta. A base fica concêntrica à roda existente, preservando posições e áreas de toque. O ID `refugio_neve` usa o mesmo salvamento local, sem nova migração.

- [Validação de temas e capturas Android](docs/temas/validacao.md).
- [Refinamento visual para aproximar do protótipo](docs/temas/refinamento-visual.md).
- [Versão cartoon: comparação, recursos e validação](docs/temas/cartoon.md).
- [Jardim do Gatinho aprovado: implementação e capturas](docs/temas/jardim-gatinho-cartoon.md).
- [Biblioteca encantada aprovada: implementação e capturas](docs/temas/biblioteca-encantada.md).
- [Correção do alinhamento do círculo da Biblioteca](docs/temas/biblioteca-alinhamento.md).
- [Fundo do mar aprovado: implementação e capturas](docs/temas/fundo-mar.md).
- [Jardim das abelhas aprovado: implementação e capturas](docs/temas/jardim-abelhas.md).
- [Escola de magia aprovada: implementação e capturas](docs/temas/escola-magia.md).
- [Refúgio na neve aprovado: implementação e capturas](docs/temas/refugio-neve.md).
- [Recursos, prompt e pontos de configuração](docs/temas/recursos.md).

Para repetir o fluxo Android com capturas locais:

```powershell
flutter drive --no-pub --driver=test_driver/themes_driver.dart --target=integration_test/themes_flow_test.dart -d emulator-5554
# Restaurar o aplicativo normal depois da integração:
flutter build apk --debug -t lib/main.dart
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

O teste usa exclusivamente `themes_integration.db`. As imagens ficam em `docs/temas/screenshots/`; a recuperação entre processos usa a fixture existente `stage4_recovery.db`, que agora também verifica o tema.

## Experiência e apresentação (0.2.0+2)

Visual com cenário botânico desenhado pelo aplicativo, gatinho estático original, fonte Nunito local e botões com volume. As dicas continuam laterais nos celulares validados e agora exibem seus preços; paisagem usa respostas e círculo em duas áreas. Texto ampliado mantém a preferência do usuário, com rolagem quando necessária, inclusive horizontal na grade de palavras longas.

A engrenagem na home e na partida abre **Configurações**: efeitos sonoros, vibração e redução de animações independentes. A redução do sistema prevalece. São nove efeitos WAV curtos, sem música, com reprodução nativa Android pré-carregada e falha de mídia tolerada. O gesto não espera o áudio. Preferências são carregadas antes de qualquer efeito e gravadas em fila; uma falha mantém a escolha na sessão e oferece nova tentativa.

O tutorial de quatro passos usa G, A, T e O numa sessão isolada: arrastar, soltar, embaralhar e conhecer as ajudas. Tem pular, voltar, experimentar novamente e alternativa sem gesto. O aplicativo abre diretamente na tela inicial, inclusive em perfis novos ou com uma introdução antiga incompleta. A demonstração fica disponível somente em **Configurações → Como jogar**, sem alterar progresso, moedas ou o estado de introdução já armazenado.

A migração SQLite **3 → 4** adiciona somente `app_settings`, com preferências e estado da introdução. Preserva payload 2, ledger, operações preparadas, carteira, campanha e diário. Não reinstale limpando dados; atualize com `adb install -r`.

Documentação desta entrega:

- [Validação e limites da etapa 5](docs/validacao-etapa-5.md).
- [Origem, licenças, prompt da arte e pontos de configuração](docs/recursos-etapa-5.md).
- [Roteiro de teste com jogadores](docs/roteiro-jogadores.md).

## Loja simulada

Tocar no saldo da home, campanha, diário ou resultado abre a **Loja**. A rodada é preservada ao abrir e fechar. O painel identifica permanentemente: **Loja em teste: compras simuladas, sem cobrança real.**

| Pacote | Moedas | Preço de referência |
|---|---:|---:|
| `coins_500` | 500 | R$ 3,99 |
| `coins_1000` | 1.000 | R$ 5,99 |
| `coins_2500` | 2.500 | R$ 10,99 |
| `coins_5000` | 5.000 | R$ 18,99 |

Selecionar um pacote exige **Simular compra**. Cancelar não credita. Uma nova compra confirmada pode repetir o pacote; retentar o mesmo pedido não repete o crédito.

**Assistir anúncio · +15 moedas** usa o SDK oficial Google Mobile Ads no aplicativo Android normal, com o App ID de demonstração e o bloco recompensado de teste do Google. O anúncio não gera receita. As 15 moedas são concedidas somente após o callback de recompensa e o fechamento do anúncio; carregar, clicar ou fechar sem recompensa não credita. O botão fica bloqueado durante a operação. Falhas e cancelamento mostram uma mensagem na loja e permitem nova tentativa.

Não há cobrança real, SDK de pagamentos, credenciais privadas ou backend. Compras de pacotes e plano sem anúncios continuam simuladas. Recompensas do SDK usam `admob_test`, `simulated: false` e `testAd: true`, separadas dos recibos antigos `simulated_ad`, que continuam compatíveis. Nenhum desses registros comprova pagamento ou receita publicitária real. Fixtures e testes existentes mantêm o provedor simulado por injeção; o carregador normal do app injeta o AdMob de teste.

[Integração AdMob: IDs, fluxo, testes e limites](docs/admob-teste.md).

Moedas de recompensas voam até o saldo, no estilo da coleta de extras: selo Explorador (+10), conclusão da campanha (+20 por nível) e conclusão diária (+50). A subida dura 1,1 segundo, configurada em `GameTiming.coinCollect`, independente dos 800 ms da estrela extra. O crédito já está confirmado antes do voo; concluir a animação não altera o saldo. Reabrir resultado, repetir resposta ou retentar o mesmo recibo não repete o efeito. A redução de movimento mantém a atualização do saldo sem voo.

Uma resposta inédita formada pelo jogador recebe um “Muito bem!” animado com a palavra encontrada e brilho somente na sua linha. Extras e Super Dica mantêm seus retornos específicos; a última resposta usa a comemoração de conclusão. A opção de reduzir animações preserva a mensagem estática, sem brilho ou movimento. O tempo fica em `GameTiming.wordCelebration`.

## Dica do mascote

Na seleção, somente palavras ainda não encontradas e sem dica comprada pulsam. O efeito amplia os campos em até 10%, varia sua opacidade entre 100% e 50% e leva 650 ms por sentido, mantendo o espaço de layout e sem contorno externo na linha. Palavras com dica já comprada permanecem estáticas, com o ícone de reconsulta disponível.

Toque no botão quadrado de balão entre **Dica** e **Super Dica** para chamar a ajuda. O mascote da partida é decorativo e não recebe toques. Ao abrir, ele aparece maior com uma animação suave e pergunta **Quer uma dica? Escolha uma palavra para eu te ajudar.** Os campos disponíveis pulsam suavemente, sem contorno ao redor da linha. Confirmar **Receber dica · 70 moedas** libera uma frase sobre aquela palavra; o personagem permanece ampliado junto do balão, sobre a mesma partida. A frase não revela células nem resolve a palavra. **Escolher outra palavra** volta à seleção; **Fechar** ou tocar fora do balão recolhe a fala. Durante a escolha, tocar numa linha disponível continua abrindo sua confirmação; tocar no texto não fecha o balão. A animação de entrada respeita a redução de movimento.

Cada uma das 1.379 palavras do léxico possui uma frase local. A compra vale para uma palavra naquela rodada; reler é gratuito, inclusive com saldo zero e após reabrir o aplicativo. Somente o ícone de balão identifica a linha com dica comprada; tocar nele reabre diretamente a mesma frase. Trocar tema preserva a compra e usa o mascote correspondente. Campanha e diário mantêm direitos independentes. A fala fica sobreposta ao jogo, sem redimensionar ou deslocar a roda e os campos. Balões adaptam-se a telas compactas, paisagem e texto ampliado; arrastar recolhe a fala. A pulsação respeita a opção de reduzir animações.

Revelação de letra: **50 moedas**; frase do mascote: **70**; Super Dica: **120**. O histórico mantém os preços de 30/100 para recibos e pedidos antigos. O reajuste não debita diferenças nem reinicia o progresso. O schema SQLite 6 e o payload 2 continuam com leitura compatível; frases compradas e preços são registrados junto às operações existentes.

[Validação, fluxo e capturas da Dica do mascote](docs/dica-mascote/validacao.md).

## Dicas e recompensas

- **60 moedas iniciais**, concedidas uma única vez por perfil.
- Campanha: **+20 por primeira conclusão de nível** e **+10 por selo Explorador inédito**. Selos de versões anteriores continuam preservados sem crédito retroativo.
- **Dica · 50 moedas** revela uma posição inédita de uma palavra ainda não encontrada.
- **Dica do mascote · 70 moedas** libera a frase da linha escolhida; consultas posteriores são gratuitas na mesma rodada.
- Cada extra inédita continua revelando uma posição gratuitamente e contando para o selo.
- Tanto a dica comum quanto o bônus de uma extra podem revelar a última letra: a palavra passa a encontrada automaticamente e, se for a última resposta, a rodada é concluída. Sem posições elegíveis não há nova cobrança ou revelação.
- **Super Dica · 120 moedas** resolve uma palavra inteira. Prioriza a maior quantidade de posições escondidas, descontando revelações anteriores; sorteia apenas entre empatadas. A confirmação não mostra antecipadamente a resposta.
- A Super Dica continua resolvendo a palavra inteira de uma vez, com origem assistida persistida. Cada operação conta como um uso, independentemente da quantidade de letras.
- Uma Super Dica final gera débito e prêmio separados na mesma transação: **120 → 20** na campanha ou **120 → 50** no diário. Saldo 119 não permite antecipar o prêmio para financiar a compra.
- Uma dica comum final também confirma débito e prêmio juntos: **50 → 20** na campanha ou **50 → 50** no diário. É preciso ter as 50 moedas antes da compra. Se uma extra conquistar o selo Explorador e concluir a campanha ao mesmo tempo, ambos os bônus são creditados uma única vez.
- Insuficiência de moedas oferece **Ir à loja**. Voltar exige nova confirmação da dica; nenhuma compra é acionada automaticamente.

## Desafio diário

Regra de conclusão por revelação, validação e capturas: [revelacao-completa/validacao.md](docs/revelacao-completa/validacao.md).

O diário usa o calendário e o fuso local do aparelho, sem cronômetro de partida. A conclusão rende **50 moedas uma única vez por data**. Extras mantêm revelações gratuitas e selo visual; o diário não soma +20 da campanha nem +10 do selo.

Campanha e diário possuem rodadas e resultados pendentes independentes, com carteira compartilhada. O diário continua disponível depois de concluir toda a campanha. Sair e entrar no mesmo dia retoma alvos, extras, ordem, dicas e resoluções assistidas; não há replay depois de reconhecer a conclusão.

O catálogo local separado contém sete definições curadas, em rotação determinística com data-base. Mesma data e versão produzem o mesmo conteúdo, independentemente do progresso da campanha. Não há repetição em dias consecutivos, inclusive entre ciclos. Conteúdo pode reaparecer após o ciclo. A definição e o léxico usados ficam incorporados no diário iniciado para preservar a rodada após atualização do catálogo.

À meia-noite local, a rodada incompleta expira sem reembolso de dicas. A data é conferida ao iniciar, em cada comando, ao retomar o aplicativo e ao abrir/fechar a loja. Um agendamento renovável também verifica a virada enquanto o aplicativo está ativo. A próxima meia-noite é calculada por calendário, sem somar 24 horas.

Confirmações não efetivadas de uma data expirada são rejeitadas sem débito. Operações já confirmadas conservam recibo e prêmio, mesmo quando a resposta chega depois da virada. Créditos da loja pertencem à carteira e sobrevivem à expiração. Pular dias não cria desafios retroativos nem moedas. Retornar o relógio antes da última data diária aceita bloqueia o diário com uma mensagem; campanha e loja continuam disponíveis.

O relógio é local, sem fonte de tempo confiável externa. Um avanço artificial pode antecipar desafios. Não há proteção completa contra manipulação de relógio nesta etapa.

## Persistência e migração

O banco privado continua em `conecte_palavras_v1.db`. A versão SQLite atual é **6** e o payload atual é **2**, com leitura compatível do payload 1. As versões do catálogo da campanha e do diário são independentes.

- `app_settings`: preferências, tema visual e introdução, independentes de rodadas e moedas.
- `profiles`: saldo, revisão e payload. Não há carteira duplicada nos snapshots.
- `coin_transactions`: lançamentos com IDs próprios e `parent_operation_id` vinculando os lançamentos a um pedido.
- `operation_requests`: propostas preparadas e recibos confirmados. A escolha de letra/palavra está na proposta antes do commit.

O coordenador serializa mutações de campanha, diário e loja. Estado e efeitos visuais só são publicados após commit. Uma Super Dica final pode gravar débito e recompensa num único commit com lançamentos auditáveis separados. O saldo é validado contra a soma do ledger e contra o saldo anterior necessário à compra.

Recompensas preservam suas chaves: `level-completion:<levelId>`, `explorer-reward:<levelId>` e `daily-completion:YYYY-MM-DD`. A identidade econômica do diário não inclui a versão do catálogo. Migração não reemite welcome, recompensas ou selos anteriores. Dados incompatíveis não são apagados: a carga apresenta erro e nova tentativa.

Em falhas, a interface mantém o último estado confirmado e oferece retry com o mesmo pedido. A recuperação resolve recibos antes de efetivar propostas. Propostas diárias ainda não confirmadas revalidam a data; as expiradas são rejeitadas.

O progresso é local. Desinstalar ou limpar os dados do Android pode removê-lo. O ledger assegura consistência operacional; não é proteção absoluta contra alteração manual de arquivos num aparelho comprometido.

## Executar e validar

Na pasta `C:\Users\felip\Desktop\dev\workspace\caca-palavra`:

```powershell
flutter pub get
flutter run -d emulator-5554
dart format lib test integration_test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test integration_test/stage4_flow_test.dart -d emulator-5554 --reporter expanded
flutter test integration_test/stage5_flow_test.dart -d emulator-5554 --reporter expanded
flutter build apk --debug
```

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`.

Recuperação em processos separados, com banco exclusivo de teste:

```powershell
flutter build apk --debug -t integration_test/stage4_recovery_app.dart
./tool/test_stage4_recovery.ps1
# Restaurar a versão normal, mantendo os dados:
flutter build apk --debug -t lib/main.dart
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

A integração nova usa `stage4_integration.db`; a fixture de recuperação usa `stage4_recovery.db`. Os testes antigos usam seus próprios bancos `stage3_*`. Nenhum teste limpa o banco normal. Os testes de host usam SQLite real em arquivos temporários. Os testes de widgets usam um repositório de resposta imediata para controlar o relógio simulado. Não são salvos prints.

## Configuração

| Item | Local |
|---|---|
| Valores 60 / 20 / 10 / 30 / 100 / 50 / 15 | `Economy` em `lib/features/game/application/campaign_models.dart` |
| Pacotes e preços de referência | `lib/features/game/application/shop_models.dart` |
| Interfaces e provedores simulados | `lib/features/game/application/shop_models.dart` |
| Catálogo da campanha e metas de extras | `assets/data/levels.json` |
| Léxico curado | `assets/data/lexicon_pt_br.json` |
| Catálogo diário, versão e data-base | `assets/data/daily_levels.json` |
| Agendamento determinístico | `lib/features/game/data/daily_catalog.dart` |
| Calendário, contexto e snapshots diários | `lib/features/game/application/daily_models.dart` |
| Comandos, datas, recibos e retomada | `lib/features/game/application/game_session_coordinator.dart` |
| SQLite, migrações e validações | `lib/features/game/data/progress_repository.dart` |
| Seleção de palavra e posições assistidas | `lib/features/game/domain/game_engine.dart` |
| Tema e cores | `lib/core/theme/game_theme.dart` |
| Durações das animações e agendamento da verificação de data | `lib/features/game/presentation/game_controller.dart` |
| Home e saldo | `lib/features/game/presentation/home_screen.dart` |
| Loja | `lib/features/game/presentation/shop_screen.dart` |
| Partida, confirmações e resultado | `lib/features/game/presentation/game_screen.dart` |

A campanha usa o catálogo **2**, com 2.500 níveis e 1.379 entradas no léxico. O fingerprint continua detectando conteúdo incompatível; esta revisão integral não migra partidas do catálogo 1. Atualizações do catálogo diário incrementam sua versão; rodadas iniciadas conservam a definição salva quando compatíveis com as regras de leitura.

Gestos, acentos/cedilha, fichas repetidas, segmentos rápidos, desfazer, multitouch, redução de movimento e selo Explorador foram preservados. Há conta anônima, vínculo Google e estado remoto; partidas parciais continuam locais. Não há ranking ou cronômetro. O léxico é curado e limitado, não um dicionário completo.

Resultados desta entrega: `docs/validacao-etapa-4.md`. Relatórios anteriores permanecem como histórico.


## Plano sem anúncios (protótipo local histórico, fora do fluxo online)

O botão redondo AD com bloqueio à esquerda da seleção abre a Loja. Dica e Super Dica permanecem à direita; a seleção e os parabéns têm margens iguais e ficam alinhados ao centro do círculo. No texto ampliado, os controles usam uma faixa própria.

O plano de R$ 15,00 é uma compra única **simulada**, com confirmação explícita, sem cobrança. A ativação fica na tabela SQLite `simulated_entitlements` (schema 5), independente das moedas e das preferências. Ativações repetidas não duplicam o registro. Falha de gravação permite tentar novamente e não confirma a ativação. Os anúncios opcionais de recompensa continuam disponíveis. Ainda não há anúncios automáticos nem integração de pagamento real: esta ativação serve para validar a experiência e não representa recibo de compra real.
