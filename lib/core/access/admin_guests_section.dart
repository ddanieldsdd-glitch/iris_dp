import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_usage_service.dart' show formatBytes;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_snackbar.dart';
import 'admin_service.dart';
import 'app_access.dart';
import 'guest_projects_screen.dart';

/// Ajustes → Invitados (solo administrador): quién entra, cuánto ocupa cada
/// cuenta, su tope y el mantenimiento de toda la app.
class AdminGuestsSection extends ConsumerWidget {
  const AdminGuestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final accounts = ref.watch(adminAccountsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Cuentas', style: AppTypography.titleMedium(palette)),
            ),
            TextButton.icon(
              onPressed: () => GuestProjectsScreen.open(context),
              icon: const Icon(Icons.folder_shared_outlined, size: 18),
              label: const Text('Ver sus proyectos'),
            ),
            IconButton(
              tooltip: 'Volver a mirar',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => ref.invalidate(adminAccountsProvider),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        accounts.when(
          loading: () =>
              Text('Cargando…', style: AppTypography.caption(palette)),
          error: (e, _) => Text(
            'No se pudieron leer las cuentas (¿hay conexión y está aplicada '
            'la migración 016?).',
            style: AppTypography.caption(palette),
          ),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final a in list) _AccountCard(account: a)],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _MaintenanceCard(),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});

  final AdminAccount account;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(AdminService s) action,
    String done,
  ) async {
    final service = ref.read(adminServiceProvider);
    if (service == null) return;
    try {
      await action(service);
      ref.invalidate(adminAccountsProvider);
      if (context.mounted) AppSnackBar.show(context, done);
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, 'No se pudo: $e');
    }
  }

  Future<void> _editMessage(BuildContext context, WidgetRef ref) async {
    final text = await _askText(
      context,
      title: 'Mensaje para ${account.label}',
      hint: 'Lo verá si su acceso está cerrado o pendiente.',
      initial: account.message ?? '',
    );
    if (text == null || !context.mounted) return;
    await _act(
      context,
      ref,
      (s) => s.setMessage(account.userId, text),
      'Mensaje guardado.',
    );
  }

  Future<void> _editLimit(BuildContext context, WidgetRef ref) async {
    final current = account.storageLimitBytes;
    final text = await _askText(
      context,
      title: 'Tope de espacio de ${account.label}',
      hint: 'En MB. Vacío: sin tope.',
      initial: current == null ? '' : '${current ~/ (1024 * 1024)}',
      numeric: true,
    );
    if (text == null || !context.mounted) return;
    final mb = int.tryParse(text.trim());
    await _act(
      context,
      ref,
      (s) => s.setLimit(account.userId, mb == null ? null : mb * 1024 * 1024),
      mb == null ? 'Tope quitado.' : 'Tope: $mb MB.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final a = account;
    final (statusLabel, statusColor) = switch (a.status) {
      AccessStatus.active => ('Activa', palette.success),
      AccessStatus.pending => ('Pendiente', palette.warning),
      AccessStatus.suspended => ('Cerrada', palette.error),
    };
    final limit = a.storageLimitBytes;
    final usage =
        '${a.projectCount} proyectos · ${formatBytes(a.totalBytes)}'
        '${limit == null ? '' : ' de ${formatBytes(limit)}'}'
        ' (contenido ${formatBytes(a.contentBytes)}, historial '
        '${formatBytes(a.historyBytes)}, imágenes ${formatBytes(a.mediaBytes)})';

    return Card(
      color: palette.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.isAdmin ? '${a.label} · administrador' : a.label,
                    style: AppTypography.bodyLarge(palette),
                  ),
                ),
                Text(
                  statusLabel,
                  style: AppTypography.label(
                    palette,
                  ).copyWith(color: statusColor),
                ),
              ],
            ),
            if (a.displayName.isNotEmpty)
              Text(a.email, style: AppTypography.caption(palette)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              usage,
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textSecondary),
            ),
            if (a.message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('«${a.message}»', style: AppTypography.caption(palette)),
            ],
            if (!a.isAdmin) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (a.status != AccessStatus.active)
                    FilledButton.tonal(
                      onPressed: () => _act(
                        context,
                        ref,
                        (s) => s.setStatus(a.userId, AccessStatus.active),
                        a.status == AccessStatus.pending
                            ? 'Cuenta aprobada.'
                            : 'Acceso abierto de nuevo.',
                      ),
                      child: Text(
                        a.status == AccessStatus.pending
                            ? 'Aprobar'
                            : 'Reabrir acceso',
                      ),
                    ),
                  if (a.status == AccessStatus.active)
                    OutlinedButton(
                      onPressed: () async {
                        final ok = await _confirm(
                          context,
                          '¿Cerrar el acceso de ${a.label}?',
                          'La app dejará de abrirse en su equipo en cuanto '
                              'compruebe el acceso (al abrirla, al volver a '
                              'ella o en una hora). Sus proyectos no se '
                              'borran y puedes reabrirlo cuando quieras.',
                        );
                        if (ok && context.mounted) {
                          await _act(
                            context,
                            ref,
                            (s) =>
                                s.setStatus(a.userId, AccessStatus.suspended),
                            'Acceso cerrado.',
                          );
                        }
                      },
                      child: const Text('Cerrar acceso'),
                    ),
                  TextButton(
                    onPressed: () => _editMessage(context, ref),
                    child: const Text('Mensaje'),
                  ),
                  TextButton(
                    onPressed: () => _editLimit(context, ref),
                    child: const Text('Tope de espacio'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends ConsumerStatefulWidget {
  const _MaintenanceCard();

  @override
  ConsumerState<_MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends ConsumerState<_MaintenanceCard> {
  final _message = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _set(bool maintenance) async {
    final service = ref.read(adminServiceProvider);
    if (service == null) return;
    if (maintenance) {
      final ok = await _confirm(
        context,
        '¿Poner IRIS en mantenimiento?',
        'Los invitados no podrán abrir la app hasta que lo quites. A ti no '
            'te afecta.',
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await service.setAppState(
        maintenance: maintenance,
        message: _message.text,
      );
      ref.invalidate(adminAppStateProvider);
      if (mounted) {
        AppSnackBar.show(
          context,
          maintenance ? 'Mantenimiento activado.' : 'Mantenimiento quitado.',
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'No se pudo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(adminAppStateProvider);
    final row = state.valueOrNull;
    if (row != null && !_loaded) {
      _loaded = true;
      _message.text = row.message ?? '';
    }
    final on = row?.maintenance ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Mantenimiento', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Cierra la app a todos los invitados a la vez, por ejemplo mientras '
          'publicas una versión.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _message,
          decoration: const InputDecoration(
            labelText: 'Mensaje para los invitados',
            hintText: 'Volvemos mañana con la versión nueva.',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            on ? 'En mantenimiento' : 'Abierta',
            style: AppTypography.bodyMedium(palette),
          ),
          value: on,
          onChanged: _busy || row == null ? null : _set,
        ),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String hint,
  required String initial,
  bool numeric = false,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: numeric ? TextInputType.number : TextInputType.multiline,
        maxLines: numeric ? 1 : 3,
        decoration: InputDecoration(helperText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
