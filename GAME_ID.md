# Identificador fixo do jogo

O jogo Caça Palavra usa o UUID **`2e4ffdce-36d4-4461-856c-b00f083fed48`**.

Esse valor foi gerado uma única vez em 02/11/2026 e permanece o mesmo entre reinícios, instalações, ambientes e recriações do banco. Novos usuários continuam recebendo seus próprios UUIDs; o UUID do jogo é independente deles.

O contrato agora envia `idJogo` como string UUID:

```json
{
  "idJogo": "2e4ffdce-36d4-4461-856c-b00f083fed48",
  "installationId": "UUID_DA_INSTALACAO"
}
```

Pontos alinhados:

- `auth.jogo.id_jogo`, `auth.usuario.id_jogo` e `auth.refresh_token.id_jogo`: tipo PostgreSQL `uuid`.
- DTOs, repositórios e configurações Java: `UUID`, sem conversão para número.
- JWT: claim `idJogo` como string UUID; audience `game-api:2e4ffdce-36d4-4461-856c-b00f083fed48`.
- Configurações da chave entre APIs e dos Client IDs Google: mapa indexado pelo UUID do jogo. O Client ID OAuth Google permanece o mesmo.
- Flutter: `ApiConfig.gameId`, enviado na criação/refresh, validado nas respostas e incluído no escopo do cache e das credenciais.
- Contratos OpenAPI, coleções Postman e exemplos atualizados.

## Banco existente e ativação

A migração **V3 do auth-service** converte os IDs antigos e mantém usuários, hashes de refresh e vínculos Google. O jogo antigo `1` sempre recebe o UUID fixo acima. Se existirem outros jogos, cada um recebe um UUID próprio na migração, persistido na base. Reexecutar o serviço não gera outros IDs. As migrações V1/V2 não foram editadas.

A API do jogo não armazena o antigo ID numérico em suas tabelas de progresso; seus DTOs, validação de JWT e configuração passam a usar o UUID. Não há necessidade de apagar o `cartoondb` para esta alteração.

Pare as duas APIs antes da atualização. Inicie primeiro o auth-service para aplicar a V3 e depois a API do jogo, ambos com os fontes/configurações atualizados. O Flutter deve usar o build atualizado também.

Access tokens antigos, com claim numérica, deixam de ser aceitos. Um refresh existente pode renovar a mesma identidade quando enviado com o novo UUID. O app usa um novo escopo de credenciais/cache para o UUID, evitando reaplicar pedidos ou tokens guardados sob o antigo ID `1`; na primeira abertura desse build, inicia uma sessão nova. Contas vinculadas podem ser recuperadas pelo fluxo Google.

Não use `UUID.randomUUID()`, `gen_random_uuid()` ou `NewGuid()` para gerar o ID deste jogo a cada início. A geração aleatória já foi feita; o valor literal acima é a identidade persistente do produto.

## Validação de 02/11/2026

- Flutter: 349 testes passaram; o teste opt-in contra serviços locais em execução permaneceu desabilitado nessa regressão.
- Análise estática de `lib` e `test`: sem pendências.
- auth-service: testes unitários, integração com PostgreSQL e migração V2 → V3 passaram. O teste específico preserva usuário, nome, vínculo Google e hash de refresh, verifica as FKs e confirma a estabilidade do UUID depois de reexecutar o Flyway.
- API do jogo: testes unitários e de integração passaram com JWTs usando UUID; tokens com a antiga claim numérica são recusados.
- As cinco coleções Postman passaram, cada uma executada duas vezes em serviços/bancos de teste.
- APK debug atualizado em `build/app/outputs/flutter-apk/app-debug.apk`.
- A aplicação nos dois projetos originais foi conferida por SHA-256 contra os arquivos testados.

Os serviços locais já em execução não foram reiniciados nem tiveram seus bancos alterados nesta validação; a atualização efetiva do `authdb` ocorre no próximo início do auth-service atualizado.
