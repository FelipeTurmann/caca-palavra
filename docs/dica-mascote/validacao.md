# Dica do mascote — implementação e validação

Data: 23/10/2026. Versão: **0.10.2+18**.

Implementação baseada na especificação **Dica do mascote e reajuste das ajudas**, autorizada pelo usuário.

## Experiência entregue

1. O jogador toca no mascote da partida.
2. O personagem mostra o balão **Vou te ajudar! Escolha uma palavra para receber uma dica.**
3. Os campos das palavras ainda não encontradas e sem dica comprada pulsam suavemente, sem contorno ao redor da linha. Palavras com dica já comprada ficam estáticas, mantendo o ícone de reconsulta. O jogador escolhe uma linha; a confirmação identifica seu número e a quantidade de letras, sem mostrar a resposta.
4. **Receber dica · 70 moedas** confirma a compra.
5. A frase aparece em um balão ligado ao mascote, sobreposto ao jogo.

**Escolher outra palavra** volta à seleção. **Fechar** ou tocar fora do balão recolhe a fala. Tocar no texto mantém o balão aberto. Na escolha, tocar numa linha disponível continua abrindo sua confirmação. Somente o ícone de balão identifica compras anteriores; tocá-lo abre diretamente a mesma frase. Consultar novamente é gratuito, inclusive sem saldo e depois de reiniciar o aplicativo.

A frase não revela letras nem resolve a palavra. Os sete mascotes são interativos na partida. Em telas menores e paisagem, o acesso usa uma versão compacta. Abrir e fechar a fala não reserva espaço, não redimensiona o tabuleiro e não desloca seus controles: o balão pode cobrir parte do jogo. Iniciar um arraste recolhe a fala. Linhas fora da área de respostas podem ser alcançadas por rolagem. A pulsação respeita a preferência de reduzir animações; o ícone mantém um rótulo acessível sem texto visível ao lado.

## Conteúdo e persistência

- As **61 palavras** de `assets/data/lexicon_pt_br.json` receberam as frases do catálogo editorial da especificação.
- Conteúdo local, sem rede ou geração durante a partida.
- A compra é vinculada a rodada e palavra, independentemente do tema.
- Campanha e diário possuem compras separadas.
- `mascotHints` é um campo opcional do snapshot, vazio para saves antigos. Mantidos SQLite **6** e payload **2**.
- Texto e versão da frase são salvos na compra; futuras edições do catálogo não mudam uma frase já paga.
- Diários novos preservam o catálogo de frases. Diários legados podem consultar o catálogo local por grafia compatível.
- Uma palavra resolvida com dica comprada continua disponível para reconsulta durante a rodada; palavra resolvida sem compra não permite nova aquisição.

## Preços

| Ajuda | Preço novo |
|---|---:|
| Dica de letra | 50 moedas |
| Dica do mascote | 70 moedas |
| Super Dica | 120 moedas |

Botões, confirmações, tutorial e cobranças usam os preços centralizados. Saldo inicial e recompensas permanecem os existentes. Extras continuam gratuitas; letra final continua podendo completar palavra e rodada.

Pedidos novos registram `pricingVersion=2`. Registros legados sem essa versão mantêm dica de 30 e Super Dica de 100. A validação do histórico e do saldo anterior usa o preço confirmado do pedido. Propostas antigas pendentes são recuperadas com seu preço original. Não há cobrança de diferença.

Débito e liberação da frase são atômicos. Repetir um recibo ou enviar IDs diferentes para a mesma palavra cobra uma vez. Reconsulta não cria operação financeira. Expiração do diário impede uma compra pendente inválida sem apagar créditos confirmados.

## Verificação local

- Análise estática: sem problemas.
- Última execução da suíte completa: **286 testes aprovados** na versão 0.10.1+17.
- Ajuste 0.10.2+18: **30 testes de interface aprovados**, incluindo fechar convite/frase por toque fora, manter a fala ao tocar no texto e reconsultar sem nova cobrança. Os testes existentes também conferem seleção, confirmação e gesto de letras.
- Ajuste 0.10.3+19: **30 testes de interface aprovados** e análise estática sem problemas. Nos sete temas, campos com dica comprada permanecem estáticos enquanto os campos sem dica continuam pulsando; a reconsulta gratuita continua disponível.
- Domínio, SQLite real, interface e regressões da economia.
- Sete temas no fluxo de compra, cancelamento, fala e reconsulta.
- Oito tamanhos/orientações e texto 1×/2× para o acesso, seleção e frase.
- Posição e tamanho da roda e campos mantidos ao abrir a fala; compra não redimensiona a roda.
- Pulsação contínua somente nos campos selecionáveis, sem borda de linha, com respeito à redução de animações.
- Reconsulta direta pelo ícone, sem confirmação, débito ou necessidade de abrir antes o convite.
- Saldo 69/70, compra com saldo exato, reconsulta a zero e compras concorrentes.
- Palavras de mesmo tamanho recebem suas frases corretas.
- Campanha/diário independentes, retomada, frase congelada e diário legado.
- Falhas de gravação, resposta de commit perdida e recuperação da proposta.
- Recibos antigos de 30/100, novas cobranças e rejeição de preço incompatível.
- Arraste após fala: balão recolhido, coordenadas mantidas durante o gesto e palavra formada corretamente.
- Rotação durante uma confirmação fecha o diálogo sem cobrar nem reabrir a fala.
- Formatação e whitespace verificados.

Os testes antigos de compras e as fixtures de integração foram ajustados aos novos preços. As fixtures antigas de recuperação entre processos foram atualizadas, mas não executadas nesta entrega; recuperação e preços legados foram exercitados com SQLite nos testes de host.

## Android e capturas

Fluxo dedicado aprovado no emulador Android API 35, 1080×2400, build debug, incluindo a versão 0.10.2+18 com fechamento por toque fora e reabertura gratuita pelo ícone:

```powershell
flutter drive --no-pub --driver=test_driver/mascot_hint_driver.dart --target=integration_test/mascot_hint_flow_test.dart -d emulator-5554
```

- [Convite no balão do gatinho](screenshots/01-convite-mascote.png).
- [Confirmação da segunda linha](screenshots/02-confirmacao-linha-escolhida.png).
- [Frase comprada no Jardim do Gatinho](screenshots/03-frase-jardim.png).
- [Reconsulta no Refúgio na neve com saldo zero](screenshots/04-reconsulta-neve-saldo-zero.png).
- [Frase restaurada após reabrir o banco](screenshots/05-reconsulta-apos-reabrir.png).
- [Palavra formada depois de consultar a dica](screenshots/06-palavra-formada-apos-dica.png).

A fixture começa com 140 moedas para permitir duas compras de 70; esse saldo não altera as 60 moedas iniciais do aplicativo normal. Os valores e estados das capturas são reais do teste.

Inspeção visual: convite e frase saem do personagem por uma ponta de balão, com texto legível e sobreposto à partida. Campos pulsam durante a seleção, sem contorno externo na linha. Compras são identificadas só pelo ícone de balão na lateral; o ícone não acrescenta altura à linha.

O teste usa somente `mascot_hint_integration.db`, preservando o banco normal do jogador. Cópia preventiva dos bancos do emulador: `build/theme-qa-backup/before-mascot-hint-android.tar`, ignorada pelo Git.

Não houve teste em aparelho físico ou medição de desempenho de produção.

## Pacote

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, entrada `lib/main.dart`, versão `0.10.2+18`.

O pacote final 0.10.2+18 foi compilado, instalado no emulador com `adb install -r` e iniciado com sucesso, preservando os dados existentes. A abertura da atividade foi confirmada pelo ADB. A captura `build/mascot-main-installed.png`, ignorada pelo Git, corresponde à conferência visual anterior da versão 0.10.1+17; as capturas do fluxo de integração acima foram atualizadas na 0.10.2+18.

