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
- `cartoondb`: `id_jogo UUID NOT NULL` nas oito tabelas de negócio, com chaves e consultas por jogo. A tabela técnica `flyway_schema_history` é a exceção em ambos os bancos.
- DTOs, repositórios e configurações Java: `UUID`, sem conversão para número.
- JWT: claim `idJogo` como string UUID; audience `game-api:2e4ffdce-36d4-4461-856c-b00f083fed48`.
- Configurações da chave entre APIs e dos Client IDs Google: mapa indexado pelo UUID do jogo. O Client ID OAuth Google permanece o mesmo.
- Flutter: `ApiConfig.gameId`, enviado na criação/refresh, validado nas respostas e incluído no escopo do cache e das credenciais.
- Contratos OpenAPI, coleções Postman e exemplos atualizados.

## Banco existente e ativação

A migração **V3 do auth-service** converte os IDs antigos e mantém usuários, hashes de refresh e vínculos Google. O jogo antigo `1` sempre recebe o UUID fixo acima. Se existirem outros jogos, cada um recebe um UUID próprio na migração, persistido na base. Reexecutar o serviço não gera outros IDs. As migrações V1/V2 não foram editadas.

A migração **V7 da API do jogo** adiciona `id_jogo` nas tabelas `jogador`, `moeda_jogador`, `movimento_moeda`, `conclusao_nivel`, `tema`, `tema_jogador`, `pacote` e `vinculo_google_operacao`. Preenche os registros existentes com o UUID fixo, preservando o conteúdo anterior, e inclui o jogo nas chaves, relacionamentos, unicidades, índices e filtros dos repositórios. Não há necessidade de apagar o `cartoondb`. Depois de aplicar V7, use a API atualizada, pois o binário anterior gravava sem `id_jogo`.

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

Na validação inicial da conversão do ID, os serviços locais não foram reiniciados; a atualização efetiva do `authdb` dependia do próximo início do auth-service atualizado.

## Aplicação posterior do escopo no cartoondb

A V7 foi aplicada ao `cartoondb` local em 02/11/2026, depois de 111 testes aprovados na API, incluindo PostgreSQL real e três coleções HTTP executadas duas vezes. O teste V6→V7 compara todas as linhas de negócio, e outro teste exercita dois jogos com os mesmos IDs de usuário, catálogo, movimento e operação Google.

Antes da aplicação foi salvo um backup em `../caca-palavra-cartoon-api/secrets/backups/cartoondb-before-id-jogo-20261102-132257.dump`. A API do jogo foi reiniciada, ficou com readiness `UP` e respondeu às consultas do aplicativo. Os snapshots reais antes/depois, desconsiderando apenas a nova coluna, foram iguais: os dois jogadores existentes e todos os demais registros foram preservados. O auth-service não foi alterado nesta etapa.
