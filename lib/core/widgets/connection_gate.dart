import 'package:flutter/material.dart';

import '../api/connection_monitor.dart';
import '../theme/game_theme.dart';
import 'garden.dart';

class ConnectionNotice extends StatelessWidget {
  const ConnectionNotice({
    super.key,
    required this.offline,
    required this.checking,
    required this.onRetry,
    this.autoRetry = false,
  });

  final bool offline, checking, autoRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: GameTheme.cream,
    child: Garden(
      quiet: true,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GardenCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      offline
                          ? Icons.wifi_off_rounded
                          : Icons.cloud_off_rounded,
                      size: 52,
                      color: GameTheme.teal,
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      header: true,
                      child: Text(
                        offline
                            ? 'Sem conexão com a internet'
                            : 'Não foi possível conectar ao jogo',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      autoRetry
                          ? offline
                                ? 'Quando a internet voltar, o jogo vai tentar reconectar automaticamente.'
                                : 'O jogo vai tentar reconectar automaticamente em instantes.'
                          : 'Verifique sua conexão e tente novamente.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sua conta e a rodada em andamento serão mantidas.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('retry-connection'),
                      onPressed: checking ? null : onRetry,
                      child: Text(
                        checking ? 'Verificando conexão…' : 'Tentar novamente',
                      ),
                    ),
                    if (checking) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ConnectionGate extends StatelessWidget {
  const ConnectionGate({
    super.key,
    required this.connection,
    required this.onRetry,
    required this.child,
  });
  final ConnectionMonitor connection;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: connection,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: connection.blocked,
          child: ExcludeSemantics(
            excluding: connection.blocked,
            child: AbsorbPointer(absorbing: connection.blocked, child: child),
          ),
        ),
        if (connection.blocked)
          Positioned.fill(
            child: ConnectionNotice(
              offline: connection.problem == ConnectionProblem.offline,
              checking: connection.checking,
              onRetry: onRetry,
              autoRetry: true,
            ),
          ),
      ],
    ),
  );
}
