import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/project_hub/project_hub_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_snackbar.dart';
import 'admin_service.dart';
import 'guest_mirror_service.dart';

/// Proyectos de las cuentas invitadas, para el administrador. Se abren como
/// copia de consulta en este equipo: lo que se toque no llega al invitado.
class GuestProjectsScreen extends ConsumerWidget {
  const GuestProjectsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const GuestProjectsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final projects = ref.watch(guestProjectsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          'Proyectos de invitados',
          style: AppTypography.titleMedium(palette),
        ),
        actions: [
          IconButton(
            tooltip: 'Volver a mirar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(guestProjectsProvider),
          ),
        ],
      ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const _Message(
          'No se pudieron leer (¿hay conexión y está aplicada la migración '
          '016?).',
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _Message('Los invitados aún no tienen proyectos.');
          }
          final byOwner = <String, List<GuestProject>>{};
          for (final p in list) {
            byOwner.putIfAbsent(p.ownerName, () => []).add(p);
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Se abren en solo consulta: es una copia en este equipo y '
                'nada de lo que cambies llega al invitado.',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textSecondary),
              ),
              for (final entry in byOwner.entries) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  entry.key.isEmpty ? 'Sin nombre' : entry.key,
                  style: AppTypography.titleMedium(palette),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final p in entry.value) _GuestProjectTile(project: p),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GuestProjectTile extends ConsumerStatefulWidget {
  const _GuestProjectTile({required this.project});

  final GuestProject project;

  @override
  ConsumerState<_GuestProjectTile> createState() => _GuestProjectTileState();
}

class _GuestProjectTileState extends ConsumerState<_GuestProjectTile> {
  String? _step;

  Future<void> _open({required bool refresh}) async {
    final service = ref.read(guestMirrorServiceProvider);
    if (service == null || _step != null) return;
    try {
      var copy = await service.localCopy(widget.project.cloudId);
      if (copy == null || refresh) {
        await service.refresh(
          widget.project,
          onStep: (s) {
            if (mounted) setState(() => _step = s);
          },
        );
        copy = await service.localCopy(widget.project.cloudId);
      }
      if (copy == null || !mounted) return;
      setState(() => _step = null);
      final project = copy;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ProjectHubScreen(project: project)),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'No se pudo bajar el proyecto: $e');
      }
    } finally {
      if (mounted) setState(() => _step = null);
    }
  }

  Future<void> _remove() async {
    await ref.read(guestMirrorServiceProvider)?.remove(widget.project.cloudId);
    if (mounted) {
      AppSnackBar.show(context, 'Copia borrada de este equipo.');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = widget.project;
    final updated = p.contentUpdatedAt?.toLocal();
    final subtitle = [
      '${p.sceneCount} escenas · ${p.shotCount} planos',
      if (updated != null)
        'cambiado el ${updated.day}/${updated.month} a las '
            '${updated.hour.toString().padLeft(2, '0')}:'
            '${updated.minute.toString().padLeft(2, '0')}',
    ].join(' · ');
    return Card(
      color: palette.surface,
      child: ListTile(
        leading: Icon(
          IconData(p.iconCode, fontFamily: 'MaterialIcons'),
          color: palette.accent,
        ),
        title: Text(p.name, style: AppTypography.bodyLarge(palette)),
        subtitle: Text(
          _step ?? subtitle,
          style: AppTypography.caption(palette),
        ),
        onTap: () => _open(refresh: false),
        trailing: _step != null
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                onSelected: (v) =>
                    v == 'refresh' ? _open(refresh: true) : _remove(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Text('Actualizar la copia'),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Borrar la copia de este equipo'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium(context.palette),
      ),
    ),
  );
}
