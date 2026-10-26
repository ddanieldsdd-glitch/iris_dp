import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'unreal_link.dart';
import 'unreal_stage_launcher.dart';
import 'unreal_tutorial_screen.dart';

/// Botón de la barra del 3D: dice si IRIS está conectado con Unreal y abre
/// el diálogo para conectar.
class UnrealLinkButton extends StatelessWidget {
  final UnrealLink link;

  /// «Abrir en Unreal» del proyecto de esta planta (solo en el PC).
  final Future<void> Function()? onOpenUnreal;

  const UnrealLinkButton({super.key, required this.link, this.onOpenUnreal});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: link,
      builder: (context, _) {
        final (color, text) = switch (link.state) {
          UnrealLinkState.on => (palette.success, 'Conectado con Unreal'),
          UnrealLinkState.connecting => (palette.warning, 'Conectando con Unreal…'),
          UnrealLinkState.error => (palette.error, link.error ?? 'Error'),
          UnrealLinkState.off => (palette.textSecondary, 'Conectar con Unreal'),
        };
        return IconButton(
          tooltip: text,
          icon: Icon(Icons.cast_connected_outlined, size: 18, color: color),
          onPressed: () =>
              showUnrealLinkDialog(context, link, onOpenUnreal: onOpenUnreal),
        );
      },
    );
  }
}

Future<void> showUnrealLinkDialog(
  BuildContext context,
  UnrealLink link, {
  Future<void> Function()? onOpenUnreal,
}) {
  if (link.state == UnrealLinkState.off) link.loadPrefs();
  return showDialog<void>(
    context: context,
    builder: (_) => _UnrealLinkDialog(link: link, onOpenUnreal: onOpenUnreal),
  );
}

class _UnrealLinkDialog extends StatefulWidget {
  final UnrealLink link;
  final Future<void> Function()? onOpenUnreal;
  const _UnrealLinkDialog({required this.link, this.onOpenUnreal});

  @override
  State<_UnrealLinkDialog> createState() => _UnrealLinkDialogState();
}

class _UnrealLinkDialogState extends State<_UnrealLinkDialog> {
  late final _host = TextEditingController(text: widget.link.host);
  late final _port = TextEditingController(text: '${widget.link.port}');
  late final _pass = TextEditingController(text: widget.link.passphrase ?? '');

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _connect() => widget.link.connect(
    host: _host.text,
    port: int.tryParse(_port.text.trim()) ?? 30010,
    passphrase: _pass.text,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final link = widget.link;
    final launcher = UnrealStageLauncher.instance;
    final canOpen =
        widget.onOpenUnreal != null && UnrealStageLauncher.supported;
    return ListenableBuilder(
      listenable: Listenable.merge([link, launcher]),
      builder: (context, _) {
        final busy =
            link.state == UnrealLinkState.connecting || launcher.busy;
        final ms = link.lastRoundTrip?.inMilliseconds;
        return AlertDialog(
          title: const Text('IRIS Stage Link · Unreal'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  canOpen
                      ? 'Lo que cambias en la planta se aplica al momento en '
                            'Unreal, y al revés. «Abrir en Unreal» lo deja todo '
                            'listo: crea el proyecto de Unreal si no existe, lo '
                            'prepara, abre Unreal y se conecta.'
                      : 'Lo que cambias en la planta se aplica al momento en '
                            'Unreal, y al revés. Unreal tiene que estar abierto '
                            'desde IRIS en el PC.',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textSecondary),
                ),
                if (canOpen && !link.isOn) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    icon: launcher.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rocket_launch_outlined),
                    label: const Text('Abrir en Unreal'),
                    onPressed: busy ? null : widget.onOpenUnreal,
                  ),
                  if (launcher.message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        launcher.message!,
                        style: AppTypography.caption(palette),
                      ),
                    ),
                  if (launcher.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        launcher.error!,
                        style: AppTypography.caption(
                          palette,
                        ).copyWith(color: palette.error),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'O conecta con un Unreal ya abierto:',
                    style: AppTypography.label(palette),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _host,
                        enabled: !link.isOn,
                        decoration: const InputDecoration(
                          labelText: 'Equipo con Unreal',
                          helperText: '127.0.0.1 si es este mismo',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _port,
                        enabled: !link.isOn,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Puerto'),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _pass,
                  enabled: !link.isOn,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña de Remote Control (si la tiene)',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (link.isOn)
                  Text(
                    'Conectado${link.engine == null ? '' : ' con Unreal ${link.engine!.split('-').first}'}.'
                    '${ms == null ? '' : ' Último cambio: $ms ms.'}',
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.success),
                  ),
                if (link.state == UnrealLinkState.error && link.error != null)
                  Text(
                    link.error!,
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.school_outlined, size: 18),
              label: const Text('Tutorial: cómo prepararlo'),
              onPressed: () {
                Navigator.of(context).pop();
                UnrealTutorialScreen.open(context, link: link);
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            if (link.isOn)
              FilledButton.tonal(
                onPressed: link.disconnect,
                child: const Text('Desconectar'),
              )
            else
              FilledButton(
                onPressed: busy ? null : _connect,
                child: Text(busy ? 'Conectando…' : 'Conectar'),
              ),
          ],
        );
      },
    );
  }
}
