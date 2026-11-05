# Integração do aplicativo com as APIs

Implementação de 30/10/2026. O fluxo normal do app usa `auth-service` e `caca-palavra-cartoon-api`. O perfil local antigo não é importado nem oferecido como alternativa. Uma identidade nova começa no nível 1, com as 60 moedas concedidas uma única vez pelo servidor.

Atualização de 02/11/2026: `idJogo` passou a ser o UUID fixo `2e4ffdce-36d4-4461-856c-b00f083fed48`, compartilhado pelas duas APIs e pelo Flutter. Consulte `GAME_ID.md` para a migração e a ordem de reinício.

## Escopo desta etapa

Na versão 0.14.3+30, a tela inicial mostra a saudação “Olá, Nome!”, acima do logo. O nome aparece em negrito e acompanha a edição feita nas configurações. O texto permite quebra de linha, sem limite fixo de altura ou corte do nome.

- Anônimo, renovação de tokens, consulta de perfil e alteração do nome.
- Inicialização do jogador, saldo, progresso e benefício sem anúncios do servidor.
- Dicas LETRA, MASCOTE e SUPER, com revelações locais e cobrança remota.
- Conclusão da campanha, com Explorador pago na conclusão; conclusão do diário.
- Diário escolhido pela data/ID/versão informados pelo servidor.
- Catálogo, disponibilidade e compra de temas em moedas.
- Card Minha conta em destaque nas configurações, com edição de nome de 2 a 30 caracteres e ações de vínculo/recuperação Google. O histórico financeiro foi retirado da interface.
- Obtenção de Google ID token, consulta/comparação das contas, confirmação e retomada.

**Loja Android.** Os produtos são filtrados pelo catálogo da API e mostram o preço informado pelo Google Play. Moedas e o benefício sem anúncios vêm do servidor após validar a compra. Os providers de simulação são usados no modo local.

### Configurar compras do Google Play no ambiente de teste

1. Use a faixa de teste interno e a conta de teste de licença na Play Store. Cadastre os pacotes de moedas e o benefício permanente como produtos de compra única. Use uma opção de compra por produto e mantenha a compra de múltiplas unidades desativada.
2. No Google Cloud, ative a **Google Play Developer API** e crie uma conta de serviço. Na Play Console, convide o e-mail da conta de serviço e conceda acesso a dados financeiros/pedidos e a gerenciamento de pedidos e assinaturas. Guarde o JSON da conta de serviço somente no servidor. [Configuração da API do Google](https://developers.google.com/android-publisher/getting_started)
3. Ao iniciar a API, o Flyway aplica a migração V9. Ela vincula `coins_500` ao produto de mesmo ID no Google Play e retira `coins_100` do catálogo ativo. Para os próximos produtos, associe o ID cadastrado no Google Play ao pacote correspondente em `jogo.pacote.codigo_produto_loja`.

4. No YAML local da API do jogo, configure o caminho da conta de serviço e habilite a integração. O Flyway cria a tabela de recibos com a migração V8 ao iniciar a API.

   ```yaml
   compras:
     google-play:
       habilitado: true
       nome-pacote: br.com.conectepalavras.caca_palavra
       credenciais: secrets/google-play-service-account.json
   ```

5. Abra **Loja** no Android com a conta testadora e selecione um produto. Confira a indicação de compra de teste no diálogo do Google Play. Após a aprovação, o servidor atualiza a carteira ou o benefício. Se perder a resposta, use **Verificar compras** ou reabra o app. Se a loja estiver indisponível, confira se a API está habilitada e se o ID do produto está cadastrado e ativo na Play Console.

O Flutter envia somente o token da compra ao endpoint autenticado `POST /api/v1/compras/google-play/validar`. A API consulta o Google, confere o perfil associado, grava um recibo único e entrega o benefício na mesma transação. A confirmação ou o consumo no Google ocorre depois, com novas tentativas quando necessário. Um token de outro perfil não transfere o benefício. O servidor mantém o hash do token para identificar repetições.

Use esta versão para validar compras de teste. A reconciliação automática de estornos e a exibição de anúncios automáticos ainda precisam ser integradas antes de abrir as vendas ao público.

## Conexão obrigatória — 0.15.0+32

O app observa a rede do Android com `ConnectivityManager` e acesso validado à internet, sem adicionar pacote Flutter. A permissão `ACCESS_NETWORK_STATE` não solicita confirmação ao jogador. Referência: [estado da rede no Android](https://developer.android.com/develop/connectivity/network-ops/reading-network-state).

- Sem internet: aviso “Sem conexão com a internet”, explicação e Tentar novamente. Aparece na abertura e sobre as telas/diálogos já abertos; bloqueia toques, foco e gestos sem descartar a rodada.
- Falha de transporte/timeout ou HTTP 5xx com rede disponível: aviso separado “Não foi possível conectar ao jogo”. Quando o estado da rede é desconhecido, o app usa esse aviso sem afirmar que não há internet.
- O retorno do Wi-Fi/dados não libera ações sozinho. Tentar novamente verifica perfil no auth-service, estado na API do jogo e sincroniza a conta existente. Uma tentativa por vez; o botão fica desabilitado durante a verificação.
- A verificação de uma sessão carregada usa consultas. Dicas/compras/conclusões pendentes não são reenviadas automaticamente; continuam no fluxo específico de recuperação.
- Uma falha comprovadamente anterior ao envio não marca refresh ou dica como resposta perdida. Se a requisição pode ter sido enviada, as proteções anteriores de incerteza permanecem.

Validação: análise sem pendências; suíte completa com **357 testes aprovados e 1 teste opt-in pulado**. No `emulator-5554`, foram conferidos o aviso ao desativar Wi-Fi/dados móveis e o aviso de serviço indisponível ao interromper apenas o encaminhamento da API. Após Tentar novamente, ambos retornaram ao nível 4 com 70 moedas e 0/4 palavras, sem alterar o perfil. Wi-Fi/dados e encaminhamentos foram restaurados. APK instalado por atualização: `build/app/outputs/flutter-apk/Conecte-palavras-online-32.apk`.

## Executar localmente no Android

Deixe os dois backends e seus bancos iniciados. Endereços locais:

| Serviço | API | Readiness |
|---|---|---|
| Auth | http://127.0.0.1:8081 | http://127.0.0.1:9081/actuator/health/readiness |
| Jogo | http://127.0.0.1:8082 | http://127.0.0.1:9082/actuator/health/readiness |

Para preparar a conexão e instalar/executar a versão atual no emulador conectado:

```powershell
.\tool\run_online_android.ps1 -DeviceId emulator-5554
```

O script encontra o ADB, verifica a disponibilidade das duas APIs e encaminha as portas antes de executar o Flutter. Sem `-DeviceId`, ele seleciona automaticamente o único dispositivo conectado. APKs antigos, como `0.13.2-compat+26` de 24/10, executam o protótipo local e não contêm esta integração.

Para executar os passos manualmente, substitua `ID_DO_DISPOSITIVO` pelo ID mostrado em `adb devices -l`:

```powershell
adb -s ID_DO_DISPOSITIVO reverse tcp:8081 tcp:8081
adb -s ID_DO_DISPOSITIVO reverse tcp:8082 tcp:8082
flutter run --debug -d ID_DO_DISPOSITIVO
```

Se `adb` não estiver no PATH, use o executável em `%LOCALAPPDATA%/Android/sdk/platform-tools/adb.exe`. O encaminhamento deve ser refeito depois de desconectar/reiniciar o dispositivo. Não é necessário expor as APIs na rede local nem mudar seu bind de loopback.

O manifesto de debug permite HTTP somente para loopback/local do emulador. Builds de release exigem URLs HTTPS; o app rejeita configuração HTTP em release. Exemplo de configuração para outro ambiente:

```powershell
flutter build apk --release --dart-define=API_ENVIRONMENT=homologacao --dart-define=AUTH_API_URL=https://auth.exemplo.com --dart-define=GAME_API_URL=https://jogo.exemplo.com --dart-define=GOOGLE_WEB_CLIENT_ID=CLIENT_ID_WEB.apps.googleusercontent.com
```

Os domínios acima são exemplos; nenhum ambiente remoto foi configurado/publicado. Não é necessário enviar `X-Game-Api-Key`, chave privada JWT ou Client Secret ao aplicativo.

## Login Google

Na versão 0.14.2+29, um único botão **Conectar com Google** inicia tanto o vínculo quanto a recuperação de conta. Se existir progresso em duas contas, o usuário continua escolhendo qual preservar. Após o vínculo, o card mostra o e-mail e a situação Google vinculado. O botão separado de recuperação foi removido.

O card Minha conta, no topo das configurações, permite editar o nome pelo lápis e vincular/recuperar Google. A edição abre uma janela com o nome atual, contador até 30 caracteres e ações Cancelar/Salvar. O salvamento usa `PATCH /api/v1/auth/me/nome` e atualiza o nome exibido no app. O limite do auth-service permanece em 30; nenhuma migração de banco é necessária. O Client ID Web local padrão corresponde ao configurado no auth-service; `GOOGLE_WEB_CLIENT_ID` permite alterá-lo no build. A audiência do backend deve acompanhar essa configuração.

O projeto Google precisa ter o cliente Android para `br.com.conectepalavras.caca_palavra` e o certificado que assina o APK instalado. Confira as instruções já existentes na API em `docs/google/configuracao-local.md`. A implementação usa `google_sign_in` 7.2.0, inicialização única e `authentication.idToken`; a integração Android sem `google-services.json` usa o `serverClientId` Web. Referência do plugin: [configuração Android](https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in_android/README.md).

Com duas contas, a tela mostra seus dados e exige uma escolha explícita. A conta descartada é desativada pelo backend; progresso, moedas, temas e benefícios não são somados. Uma confirmação iniciada guarda código, escolha e a prova original no armazenamento seguro. Se sua resposta se perder, a retomada usa a mesma prova, sem `Authorization`.

Ao mudar `idUsuario`, o app fecha a sessão de jogo anterior e recarrega o estado da conta escolhida. Pendências e snapshots de outra identidade não podem executar com o novo Bearer. Em recuperação de sessão sem refresh utilizável, uma ação explícita do usuário cria uma identidade temporária e abre o fluxo Google. Uma falha de rede não cria silenciosamente outro anônimo.

## Persistência e recuperação

O app usa um banco novo, `conecte_palavras_online_v1.db`, com schema 7. Não lê o perfil de jogo do antigo `conecte_palavras_v1.db` no fluxo normal. Os testes locais continuam usando os repositórios de fixture anteriores.

`online_profiles` e `online_operations` têm escopo de ambiente/serviços, jogo e usuário. Guardam cache remoto, snapshots de rodada, propostas locais e recibos conhecidos. O app não exige reconstruir o histórico inteiro do SQLite para autenticar uma conta já avançada.

Tokens e contexto temporário Google são armazenados juntos por `flutter_secure_storage`, separados por ambiente. O backup Android foi desabilitado para não restaurar credenciais criptografadas com chaves de outra instalação. Referência: [armazenamento seguro](https://pub.dev/packages/flutter_secure_storage).

| Situação | Comportamento |
|---|---|
| Várias chamadas precisam renovar | Compartilham uma única renovação |
| Resposta do refresh se perde | Marca a sessão como necessitando recuperação; não reenvia o token consumido |
| Falha de resposta de dica | Não repete cobrança; informa incerteza e exige atualizar saldo antes de continuar |
| Dica confirmada, falha posterior | Reutiliza o recibo guardado e aplica o mesmo efeito local sem outra cobrança |
| Dica completa a fase | Compra e conclusão são operações separadas; retomar conclusão não recompra a dica |
| Resposta de conclusão se perde | Reenvia a mesma conta/fase e o payload congelado |
| Recibo histórico repetido | Reconsulta estado atual; saldo antigo do recibo não sobrescreve a carteira |
| Compra de tema repetida | Reutiliza resultado/ownership sem nova cobrança |
| Sem rede durante a rodada | O aviso pausa as ações, mantendo a rodada. Tentar novamente verifica as duas APIs e sincroniza a conta. Operações econômicas pendentes continuam no fluxo próprio de recuperação, sem repetição automática |
| Retorno do segundo plano | Reconsulta estado, diário e temas; reconcilia eventual avanço de outro aparelho |

Uma dica com resposta perdida pode ter sido cobrada sem entregar a revelação: o backend atual não possui recuperação por identificador do cliente. Uma conclusão inédita do diário é recusada após a virada do dia em São Paulo; apenas recibos já confirmados podem ser repetidos depois. O Flutter não pode eliminar essas limitações do contrato.

## Verificações

Suíte normal (usa respostas HTTP simuladas e bancos SQLite descartáveis; o teste real fica desabilitado):

```powershell
flutter test --reporter expanded
dart analyze lib test
flutter build apk --debug
```

Teste real local, opt-in:

```powershell
flutter test test/live_api_test.dart --dart-define=LIVE_API_CHECK=true --reporter expanded
```

Esse comando cria uma identidade de teste nova nos bancos locais, renova tokens, altera nome, usa uma dica, conclui 25 níveis, compra um tema e repete a compra, conclui o diário e consulta o histórico. Não usa conta existente, Google ou dinheiro, nem grava tokens em arquivo. Os registros da conta de teste permanecem nos bancos locais para inspeção.

O teste real passou em 30/10/2026 contra os serviços locais iniciados. Testes de recuperação HTTP simulada cobrem renovação concorrente, respostas perdidas, reabertura, isolamento entre usuários, bônus, diário, loja oculta, edição de nome, histórico e retomada Google sem Bearer. A validação interativa do SDK Google em um Android conectado ainda deve ser feita com a conta/certificado de teste apropriados.

Resultado final desta implementação:

- `dart analyze lib test`: sem pendências.
- Suíte completa após a alteração para UUID: 349 testes passaram; um teste opt-in foi pulado conforme previsto.
- Teste opt-in contra as duas APIs reais: passou, incluindo conta nova, refresh, nome, dica, 25 níveis, compra/repetição de tema, diário e histórico.
- APK debug gerado em `build/app/outputs/flutter-apk/app-debug.apk` com os fontes finais.
- `git diff --check`: passou.
- A validação inicial de 30/10 ocorreu sem aparelho/emulador conectado. Login Google interativo ainda não foi validado.

### Verificação no emulador em 02/11/2026

O emulador `emulator-5554` estava com `0.13.2-compat+26`, atualizado em 24/10, e sem encaminhamento ADB. Foi instalado o debug **0.14.0+27**, gerado dos fontes atuais, e foram encaminhadas as portas 8081/8082. O APK usado está em `build/app/outputs/flutter-apk/Conecte-palavras-online-27.apk`.

Ao abrir o aplicativo, os bancos passaram de zero para um usuário em `auth.usuario` e um jogador em `jogo.jogador`, com o mesmo `id_usuario`. A carteira contém 60 moedas e existe um único movimento `SALDO_INICIAL` de 0 para 60, além de um refresh token no authdb. A tela inicial exibiu o nome retornado pelo servidor e esse saldo. A instalação foi feita por atualização, sem limpar dados.

### Ajuste da conta nas configurações — 0.14.1+28

O card Minha conta aparece diretamente no topo das configurações, com nome destacado, lápis, situação do vínculo Google e ações para vincular/recuperar. O nome é editado em uma janela com limite de 30 caracteres. O histórico de moedas foi removido dessa interface; os endpoints das APIs permanecem disponíveis.

- Análise de `lib`/`test`: sem pendências.
- Testes de integração e experiência: 41 passaram, incluindo validação do nome, limite de 30, salvamento na API simulada e cancelamento sem PATCH adicional.
- APK debug gerado e instalado por atualização no `emulator-5554`: `build/app/outputs/flutter-apk/Conecte-palavras-online-28.apk`.
- Conferência visual no Android: card, ações Google, lápis e janela com nome atual/contador `6/30`/Cancelar/Salvar. A edição foi cancelada, preservando o perfil existente. O fluxo Google com conta real não foi executado nesta verificação.
