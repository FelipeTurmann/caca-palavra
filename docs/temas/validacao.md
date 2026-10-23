# Validação — seleção de temas

Data: 22/10/2026. Versão: **0.3.0+4**. Base: commit `2f87ba7`, sem alterações locais ao iniciar a implementação.

Este é o relatório da entrega inicial. O acabamento posterior está documentado no [refinamento visual 0.3.1+5](refinamento-visual.md).

## Entrega

- Cartão **Temas** imediatamente abaixo do diário na home.
- Jardim do Gatinho e Capivara na lagoa gratuitos, com miniaturas, estado **Em uso** e botão **Usar tema**.
- Aplicação global imediata, sem recriar a sessão; persistência em `app_settings.visual_theme_id`, schema SQLite 6.
- Avisos de salvamento e falha, com retry no seletor e na home; última escolha prevalece nas gravações serializadas.
- Lagoa e ilha desenhadas nativamente, capivara estática local e geometria original das fichas preservada.
- Jardim padrão em perfis antigos/novos e alternativa segura para IDs desconhecidos.

## Testes automatizados de host

Comandos:

```powershell
dart format lib test/themes_test.dart test/themes_widget_test.dart integration_test/themes_flow_test.dart integration_test/stage4_recovery_app.dart test_driver/themes_driver.dart
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
git diff --check
```

Resultado: análise sem problemas; **221 testes aprovados**, incluindo **26 novos testes** de temas. Formatação e verificação de whitespace concluídas.

Cobertura nova:

- IDs ausentes/desconhecidos, fila de alterações rápidas, preservação das outras preferências e falha/retry sem falso sucesso.
- Banco SQLite real temporário: criação, migrações de versões 1, 3, 4 e 5 para 6 e reabertura. O caso 5 usa a tabela de configurações sem a coluna nova; não depende apenas de reduzir a versão de um banco atual.
- Comparação de snapshots da campanha e diário, histórico de moedas, pedidos e plano simulado após migração e seleção.
- Seletor mantém a rota aberta, confirma a escolha e permite voltar sem alterar novamente. A mesma instância de controller é preservada.
- Escopo visual na campanha, diário, configurações, tutorial isolado e loja.
- Retry na home após fechar o seletor com falha e acesso com diário bloqueado por data.

Matriz automatizada, em unidades lógicas, com ambos os temas e texto **1× e 2×**:

| Perfil | Retrato | Paisagem |
|---|---|---|
| Celular pequeno | 320×568 | 568×320 |
| Celular de referência | 360×800 | 800×360 |
| Celular alto | 412×915 | 915×412 |
| Tablet | 800×1280 | 1280×800 |

Home, seletor e partida não apresentaram overflow nessa matriz. A suíte existente de dicas, gestos, economia, persistência e layouts também passou.

## Integração Android

Ambiente: `emulator-5554`, Android API 35, resolução física 1080×2400, build debug.

```powershell
flutter drive --no-pub --driver=test_driver/themes_driver.dart --target=integration_test/themes_flow_test.dart -d emulator-5554
```

Resultado: aprovado. Exercitado com banco exclusivo `themes_integration.db`:

1. Selecionar capivara, confirmar a gravação e fechar o painel.
2. Comparar perfil e histórico para verificar que a troca não alterou a economia.
3. Arrastar uma palavra real com as fichas do novo tema e confirmar o preenchimento.
4. Abrir o diário com o tema global.
5. Desmontar o app, fechar/reabrir o banco e remontar: tema, campanha, diário e histórico mantidos.
6. Voltar para o jardim, preservando os snapshots.

## Recuperação entre processos Android

```powershell
flutter build apk --debug -t integration_test/stage4_recovery_app.dart
./tool/test_stage4_recovery.ps1
```

Resultado: seis fases aprovadas com encerramento por `am force-stop` e PIDs diferentes. A fixture agora salva Capivara na lagoa e verifica sua restauração no processo seguinte, além das verificações existentes de recuperação econômica.

| Fase | PID | Resultado |
|---|---:|---|
| seed | 7038 | Saldo 355; capivara salva |
| verify_partial | 7140 | Tema e snapshot preservados; saldo 355 |
| complete | 7211 | Conclusão confirmada; saldo 305 |
| verify_completed | 7282 | Resultado restaurado sem crédito duplicado |
| prepare_uncommitted | 7356 | Pedido preparado, sem commit e sem débito |
| verify_expired | 7435 | Pedido expirado rejeitado; saldo 305 |

Somente `stage4_recovery.db` e arquivos de controle dessa fixture são manipulados. O banco normal do jogador não é apagado pelos testes.

## Inspeção visual

Capturas Android reais produzidas pelo teste e inspecionadas:

- [Seletor com capivara ativa](antes-refinamento/01-seletor-capivara.png).
- [Home da capivara](antes-refinamento/02-home-capivara.png).
- [Partida com ilha e palavra preenchida](antes-refinamento/03-partida-capivara.png).
- [Home do jardim após retornar](antes-refinamento/04-home-jardim.png).

Verificados: posição do cartão, nomes e estados legíveis, miniaturas coerentes, superfícies creme, distinção das fichas, controles livres e identidade preservada do jardim. A posição da ficha decorativa e o tamanho da capivara na home foram ajustados após a primeira inspeção; as capturas acima correspondem à repetição aprovada.

A arte usa o protótipo como direção visual, com cenário simplificado em desenho nativo. Não copia a captura como interface. O mascote da partida é opcional na especificação; a implementação mantém a roda e as ajudas livres, com a capivara na home e na miniatura.

## Pacote e limites

APK normal: `build/app/outputs/flutter-apk/app-debug.apk`, compilado com `lib/main.dart`. Após as fixtures, restaurar por atualização:

```powershell
flutter build apk --debug -t lib/main.dart
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Nesta validação, o APK normal foi recompilado, instalado com `install -r` com sucesso e iniciado no emulador após a recuperação entre processos.

Sem instalação limpa, mudança de catálogos, alteração econômica ou nova dependência de runtime. Não houve teste com jogadores ou aparelho físico, nem medição de desempenho de produção. O emulador em debug valida fluxo e renderização, sem comprovar desempenho de todos os dispositivos.

Origem da arte, prompt e pontos de configuração estão em [recursos.md](recursos.md).
