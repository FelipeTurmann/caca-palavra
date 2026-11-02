import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

import '../../../core/api/google_link.dart';
import '../../../core/theme/game_theme.dart';
import '../../../core/widgets/garden.dart';
import '../data/api_progress_repository.dart';
import 'game_controller.dart';

Future<void> openAccount(
  BuildContext context,
  GameController controller, {
  bool startGoogle = false,
}) async {
  if (controller.coordinator?.online == null) return;
  final changed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) =>
          AccountScreen(controller: controller, startGoogle: startGoogle),
    ),
  );
  if (changed == true && context.mounted) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await controller.onSessionChanged?.call();
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.controller,
    this.startGoogle = false,
  });
  final GameController controller;
  final bool startGoogle;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final started =
        widget
            .controller
            .coordinator!
            .online!
            .session
            .googleOperation?['started'] ==
        true;
    return PopScope(
      canPop: !busy && !started,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Minha conta'),
          automaticallyImplyLeading: !busy && !started,
        ),
        body: Garden(
          quiet: true,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    PlayerAccountCard(
                      controller: widget.controller,
                      startGoogle: widget.startGoogle,
                      onBusyChanged: (value) => setState(() => busy = value),
                      onSessionChanged: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerAccountCard extends StatefulWidget {
  const PlayerAccountCard({
    super.key,
    required this.controller,
    required this.onSessionChanged,
    required this.onBusyChanged,
    this.startGoogle = false,
  });

  final GameController controller;
  final VoidCallback onSessionChanged;
  final ValueChanged<bool> onBusyChanged;
  final bool startGoogle;

  @override
  State<PlayerAccountCard> createState() => _PlayerAccountCardState();
}

class _PlayerAccountCardState extends State<PlayerAccountCard> {
  GameController get controller => widget.controller;
  ApiProgressRepository get repo => controller.coordinator!.online!;
  late final google = GoogleLink(
    repo.session,
    GoogleSdkIdentityProvider(repo.session.api.config.googleClientId),
  );
  bool busy = false;
  String? notice;
  @override
  void initState() {
    super.initState();
    if (widget.startGoogle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _google(recover: true);
      });
    }
  }

  Future<T?> _work<T>(Future<T> Function() action) async {
    if (busy || controller.busy) return null;
    setState(() {
      busy = true;
      notice = null;
    });
    widget.onBusyChanged(true);
    final result = await controller.run(action);
    final message = controller.saveError;
    if (!controller.coordinator!.hasFailedCommand &&
        repo.session.googleOperation?['started'] != true) {
      controller.saveError = null;
      controller.refresh();
    }
    if (mounted) {
      setState(() {
        busy = false;
        notice = message;
      });
      widget.onBusyChanged(false);
    }
    return result;
  }

  Future<void> _rename() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditPlayerNameDialog(
        initialName: repo.name,
        onSave: (value) async {
          final result = await _work(() async {
            final me = await repo.session.authorized(
              'PATCH',
              '/api/v1/auth/me/nome',
              authService: true,
              body: {'nomeUsuario': value},
            );
            repo.identity = me;
            repo.state = {...repo.state, 'nomeUsuario': me['nomeUsuario']};
            controller.refresh();
            return true;
          });
          return result == true
              ? null
              : notice ?? 'Não foi possível salvar o nome. Tente novamente.';
        },
      ),
    );
    if (saved == true && mounted) setState(() => notice = 'Nome atualizado.');
  }

  String _preview(Map account) {
    final state = account['estadoJogo'] as Map?;
    if (state == null) {
      return '${account['nomeUsuario']}\nEsta conta ainda não começou o jogo.';
    }
    final progress = state['progresso'] as Map;
    return '${account['nomeUsuario']}\n${(state['moedas'] as Map)['qtdMoedas']} moedas · ${progress['ultimoNivelConcluido']} níveis concluídos\n'
        '${(account['temas'] as List).length} temas · ${(state['beneficios'] as Map)['semAnuncios'] == true ? 'Plano sem anúncios ativo' : 'Sem plano'}';
  }

  Future<void> _google({bool recover = false}) async {
    if (controller.coordinator!.hasFailedCommand) {
      setState(
        () => notice =
            'Resolva o salvamento pendente antes de vincular uma conta.',
      );
      return;
    }
    final changed = await _work(() async {
      final lookup = await google.consult();
      if (!mounted) return false;
      final conflict = lookup['escolhaNecessaria'] == true;
      final keep = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(
            conflict
                ? 'Qual conta deseja manter?'
                : lookup['jaVinculado'] == true
                ? 'Conta já vinculada'
                : recover
                ? 'Conta Google ainda não vinculada'
                : 'Vincular ao Google?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_preview(lookup['usuarioAtual'] as Map)),
              if (conflict) ...[
                const Divider(),
                Text(_preview(lookup['usuarioExistente'] as Map)),
                const SizedBox(height: 16),
                const Text(
                  'Será mantida apenas a conta escolhida. A outra será desativada. Moedas, progresso, temas e benefícios não serão somados.',
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Seu progresso será mantido nesta conta.'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancelar'),
            ),
            if (conflict)
              TextButton(
                onPressed: () => Navigator.pop(dialog, 'GOOGLE'),
                child: const Text('Manter conta Google'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, 'ANONIMO'),
              child: Text(
                conflict ? 'Manter conta atual' : 'Confirmar vínculo',
              ),
            ),
          ],
        ),
      );
      if (keep == null) {
        await repo.session.clearGoogle();
        return false;
      }
      await google.confirm(keep);
      return true;
    });
    if (changed == true && mounted) widget.onSessionChanged();
  }

  Future<void> _resume() async {
    final changed = await _work(() async {
      try {
        await google.resume();
      } on ApiFailure catch (e) {
        if ({
          'GOOGLE_OPERATION_EXPIRED',
          'GOOGLE_ACCOUNT_EXISTS',
          'GOOGLE_LINK_CHANGED',
          'ACCOUNT_CONFLICT',
          'GOOGLE_TOKEN_MISMATCH',
        }.contains(e.code)) {
          await repo.session.clearGoogle();
        }
        rethrow;
      }
      return true;
    });
    if (changed == true && mounted) widget.onSessionChanged();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final started = repo.session.googleOperation?['started'] == true;
      final enabled = !busy && !controller.busy && !started;
      final email = repo.identity['emailVinculado'] as String?;
      final linked = email != null && email.isNotEmpty;
      return GardenCard(
        key: const ValueKey('player-account-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: GameTheme.teal,
                  foregroundColor: GameTheme.cream,
                  child: Icon(Icons.person_rounded, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Minha conta',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Material(
              color: const Color(0xFFE8F0E7),
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                title: Text(
                  repo.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: const Text('Toque para editar seu nome'),
                onTap: enabled ? _rename : null,
                trailing: IconButton(
                  key: const ValueKey('edit-player-name'),
                  tooltip: 'Editar nome do jogador',
                  onPressed: enabled ? _rename : null,
                  icon: const Icon(Icons.edit_rounded),
                  style: IconButton.styleFrom(foregroundColor: GameTheme.teal),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  linked ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                  color: GameTheme.teal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        linked
                            ? 'Google vinculado'
                            : 'Conta ainda não vinculada',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        linked
                            ? email
                            : 'Conecte com o Google para vincular seu jogo ou recuperar uma conta existente.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (started) ...[
              const Text(
                'Uma confirmação Google ficou pendente. Retome para concluir o acesso à sua conta.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy || controller.busy ? null : _resume,
                child: const Text('Retomar confirmação Google'),
              ),
            ] else if (!linked)
              FilledButton.icon(
                key: const ValueKey('connect-google-account'),
                onPressed: enabled ? () => _google() : null,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Conectar com Google'),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(liveRegion: true, child: Text(notice!)),
              ),
          ],
        ),
      );
    },
  );
}

class _EditPlayerNameDialog extends StatefulWidget {
  const _EditPlayerNameDialog({
    required this.initialName,
    required this.onSave,
  });
  final String initialName;
  final Future<String?> Function(String value) onSave;
  @override
  State<_EditPlayerNameDialog> createState() => _EditPlayerNameDialogState();
}

class _EditPlayerNameDialogState extends State<_EditPlayerNameDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.initialName);
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    final failure = await widget.onSave(name.text.trim());
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        saving = false;
        error = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Como você quer ser chamado?'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: const ValueKey('player-name-field'),
              controller: name,
              autofocus: true,
              enabled: !saving,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Nome do jogador',
                helperText: 'De 2 a 30 caracteres.',
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.runes.length < 2 || text.runes.length > 30) {
                  return 'Use um nome de 2 a 30 caracteres.';
                }
                if (text.runes.any(
                  (rune) => rune <= 31 || rune >= 127 && rune <= 159,
                )) {
                  return 'Use um nome sem caracteres de controle.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Salvando…' : 'Salvar'),
        ),
      ],
    ),
  );
}
