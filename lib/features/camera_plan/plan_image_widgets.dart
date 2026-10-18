import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'plan_images.dart';

/// Un plano al que se puede unir una imagen (su cámara la enseña).
class PlanImageShotOption {
  final int shotId;
  final String label;

  const PlanImageShotOption(this.shotId, this.label);
}

/// Barra de la imagen elegida: debajo o encima de los elementos, opacidad,
/// candado, unir a una cámara, comentar, terreno, al frente y borrar.
class PlanImageToolbar extends StatelessWidget {
  final PlanImage image;
  final List<PlanImageShotOption> shots;
  final ValueChanged<bool> onAbove;
  final ValueChanged<double> onOpacity;
  final ValueChanged<bool> onLocked;
  final ValueChanged<int?> onLink;
  final VoidCallback onComments;
  final VoidCallback onTerrain;
  final VoidCallback onRotate;
  final VoidCallback onFront;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const PlanImageToolbar({
    super.key,
    required this.image,
    required this.shots,
    required this.onAbove,
    required this.onOpacity,
    required this.onLocked,
    required this.onLink,
    required this.onComments,
    required this.onTerrain,
    required this.onRotate,
    required this.onFront,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final comments = PlanImageComment.decode(image.commentsJson).length;
    final linked = shots
        .where((s) => s.shotId == image.linkedShotId)
        .firstOrNull;
    Widget tool({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      bool on = false,
      String? text,
    }) => Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: on ? palette.accent : palette.textSecondary,
              ),
              if (text != null) ...[
                const SizedBox(width: 4),
                Text(
                  text,
                  style: AppTypography.caption(palette).copyWith(
                    color: on ? palette.accent : palette.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Material(
      color: palette.surfaceElevated,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Lo que decide si se mueven cosas encima o se ve por encima.
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Debajo'),
                  tooltip: 'Debajo de cámaras, personajes y luces',
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Encima'),
                  tooltip: 'Encima de todo',
                ),
              ],
              selected: {image.above},
              onSelectionChanged: (v) => onAbove(v.first),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 110,
              child: Tooltip(
                message: 'Opacidad',
                child: Slider(
                  value: image.opacity.clamp(0.1, 1),
                  min: 0.1,
                  max: 1,
                  onChanged: onOpacity,
                ),
              ),
            ),
            tool(
              icon: image.locked ? Icons.lock : Icons.lock_open,
              tooltip: image.locked
                  ? 'Bloqueada: no se mueve al tocar'
                  : 'Bloquear en su sitio',
              on: image.locked,
              onPressed: () => onLocked(!image.locked),
            ),
            PopupMenuButton<int>(
              tooltip: 'Unir a la cámara de un plano',
              onSelected: (id) => onLink(id < 0 ? null : id),
              itemBuilder: (_) => [
                for (final s in shots)
                  CheckedPopupMenuItem(
                    value: s.shotId,
                    checked: s.shotId == image.linkedShotId,
                    child: Text(s.label),
                  ),
                if (shots.isEmpty)
                  const PopupMenuItem(
                    enabled: false,
                    value: -2,
                    child: Text('No hay cámaras de planos a la vista'),
                  ),
                if (image.linkedShotId != null)
                  const PopupMenuItem(value: -1, child: Text('Quitar unión')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_outlined,
                      size: 18,
                      color: linked != null
                          ? palette.accent
                          : palette.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      linked?.label ?? 'Unir a cámara',
                      style: AppTypography.caption(palette).copyWith(
                        color: linked != null
                            ? palette.accent
                            : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            tool(
              icon: Icons.mode_comment_outlined,
              tooltip: 'Comentarios',
              text: comments == 0 ? 'Comentar' : '$comments',
              on: comments > 0,
              onPressed: onComments,
            ),
            tool(
              icon: Icons.terrain_outlined,
              tooltip:
                  'Usar como terreno: debajo, bloqueada y a escala con dos '
                  'puntos de medida conocida',
              on: image.terrain,
              text: 'Terreno',
              onPressed: onTerrain,
            ),
            tool(
              icon: Icons.rotate_90_degrees_cw_outlined,
              tooltip: 'Girar 90°',
              onPressed: onRotate,
            ),
            tool(
              icon: Icons.flip_to_front_outlined,
              tooltip: 'Traer al frente',
              onPressed: onFront,
            ),
            tool(
              icon: Icons.delete_outline,
              tooltip: 'Quitar la imagen',
              onPressed: onDelete,
            ),
            tool(icon: Icons.close, tooltip: 'Listo', onPressed: onClose),
          ],
        ),
      ),
    );
  }
}

/// Hilo de comentarios de una imagen. Devuelve la imagen como quede.
Future<PlanImage> showPlanImageComments(
  BuildContext context,
  PlanImageStore store,
  PlanImage image,
) async {
  var current = image;
  var author = 'dp';
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final palette = ctx.palette;
        final comments = PlanImageComment.decode(current.commentsJson);
        Future<void> send() async {
          final text = controller.text.trim();
          if (text.isEmpty) return;
          current = await store.addComment(current, author: author, text: text);
          controller.clear();
          setState(() {});
        }

        return AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text(
            current.caption?.isNotEmpty == true
                ? 'Comentarios · ${current.caption}'
                : 'Comentarios de la imagen',
            style: AppTypography.titleMedium(palette),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (current.path != null && File(current.path!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 120,
                      child: Image.file(
                        File(current.path!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (comments.isEmpty)
                  Text(
                    'Sin comentarios todavía.',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.textTertiary),
                  ),
                for (final (i, c) in comments.indexed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.text),
                    subtitle: Text(
                      '${kPlanImageAuthors[c.author] ?? c.author} · '
                      '${c.at.day}/${c.at.month}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Borrar comentario',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () async {
                        current = await store.removeComment(current, i);
                        setState(() {});
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: author,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final e in kPlanImageAuthors.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => author = v ?? author),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Contra desde la ventana, que recorte…',
                        ),
                        onSubmitted: (_) => send(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Enviar',
                      icon: const Icon(Icons.send),
                      onPressed: send,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return current;
}

/// Elige una imagen del moodboard del proyecto. Nula si se cancela.
Future<MoodboardImage?> pickMoodboardImage(
  BuildContext context,
  AppDatabase db,
  int projectId,
) async {
  final images = await db.watchMoodboardImages(projectId).first;
  if (!context.mounted) return null;
  final palette = context.palette;
  return showDialog<MoodboardImage>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text('Del moodboard', style: AppTypography.titleMedium(palette)),
      content: SizedBox(
        width: 560,
        height: 420,
        child: images.isEmpty
            ? Center(
                child: Text(
                  'El moodboard del proyecto está vacío.',
                  style: AppTypography.bodyMedium(palette),
                ),
              )
            : GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (final image in images)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, image),
                      child: Tooltip(
                        message: image.caption ?? '',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: File(image.imagePath).existsSync()
                              ? Image.file(
                                  File(image.imagePath),
                                  fit: BoxFit.cover,
                                  cacheWidth: 240,
                                )
                              : ColoredBox(
                                  color: palette.surfaceOverlay,
                                  child: const Icon(Icons.broken_image),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
}

/// ¿Cuántos metros hay entre los dos puntos marcados? Nulo si se cancela.
Future<double?> askCalibrationMeters(BuildContext context) async {
  final controller = TextEditingController();
  final palette = context.palette;
  final result = await showDialog<double>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = double.tryParse(controller.text.replaceAll(',', '.'));
        if (v != null && v > 0) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(
          '¿Cuánto mide?',
          style: AppTypography.titleMedium(palette),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '32',
            suffixText: 'm',
            helperText: 'La distancia real entre los dos puntos',
          ),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(onPressed: submit, child: const Text('Poner a escala')),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}
