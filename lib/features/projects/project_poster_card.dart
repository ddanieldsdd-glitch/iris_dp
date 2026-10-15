import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import 'project_card_stats.dart';

/// Tarjeta de proyecto: la portada a sangre, el anillo de preparación arriba
/// a la derecha (su color es el estado de la nube) y, sobre el título, los
/// datos elegidos para el proyecto (barras de avance o cifras). Diseño «J2»
/// elegido por Daniel el 2026-10-16, en apaisado (4:3) a petición suya.
class ProjectPosterCard extends StatefulWidget {
  final Project project;
  final ProjectCardStats? stats;
  final ProjectSyncState? syncState;
  final List<ProjectCardMetric> metrics;
  final VoidCallback onTap;
  final VoidCallback onChangeImage;
  final VoidCallback onChooseData;
  final VoidCallback onChooseColor;
  final ValueChanged<ProjectCardSize> onSetSize;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const ProjectPosterCard({
    super.key,
    required this.project,
    required this.stats,
    required this.syncState,
    required this.metrics,
    required this.onTap,
    required this.onChangeImage,
    required this.onChooseData,
    required this.onChooseColor,
    required this.onSetSize,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  State<ProjectPosterCard> createState() => _ProjectPosterCardState();
}

class _ProjectPosterCardState extends State<ProjectPosterCard> {
  bool _hover = false;

  static Color syncColor(AppPalette palette, ProjectSyncState? state) =>
      switch (state) {
        ProjectSyncState.upToDate => palette.success,
        ProjectSyncState.toUpload || ProjectSyncState.toDownload =>
          palette.accent,
        ProjectSyncState.conflict || ProjectSyncState.imagesFailed =>
          palette.error,
        ProjectSyncState.imagesPending => palette.warning,
        ProjectSyncState.localOnly || null => palette.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final project = widget.project;
    final stats = widget.stats;
    final coverPath = project.coverImagePath;
    final hasCover =
        coverPath != null &&
        coverPath.isNotEmpty &&
        File(coverPath).existsSync();
    // El color de la tarjeta lo elige el usuario; el estado de la nube va
    // en la pastilla.
    final color = project.cardColor != null
        ? Color(project.cardColor!)
        : palette.accent;
    final stateColor = syncColor(palette, widget.syncState);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: _hover ? 0.85 : 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (_hover ? color : Colors.black).withValues(
                  alpha: _hover ? 0.28 : 0.45,
                ),
                blurRadius: _hover ? 32 : 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // La imagen se acerca al pasar el ratón.
                AnimatedScale(
                  scale: _hover ? 1.05 : 1,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  child: hasCover
                      ? Image.file(File(coverPath), fit: BoxFit.cover)
                      : ColoredBox(
                          color: palette.surfaceOverlay,
                          child: Center(
                            child: Icon(
                              IconData(
                                project.iconCode,
                                fontFamily: 'MaterialIcons',
                              ),
                              size: 96,
                              color: palette.textTertiary,
                            ),
                          ),
                        ),
                ),
                // Oscurece arriba (menú y anillo) y sobre todo abajo (texto).
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.22, 0.5, 1],
                      colors: [
                        Color(0x66000000),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xF2000000),
                      ],
                    ),
                  ),
                ),
                Positioned(top: 10, left: 8, child: _menu(palette)),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Tooltip(
                    message: widget.syncState?.label ?? '',
                    child: _Ring(
                      percent: stats?.preparationPercent(widget.metrics) ?? 0,
                      color: color,
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 20,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 11,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.syncState != null)
                              _SyncPill(
                                label: widget.syncState!.label,
                                color: stateColor,
                              ),
                            const SizedBox(height: 10),
                            Text(
                              project.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 12),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (project.director?.trim().isNotEmpty ??
                                    false)
                                  project.director!.trim(),
                                if (stats != null &&
                                    !widget.metrics.contains(
                                      ProjectCardMetric.scenes,
                                    ))
                                  '${stats.scenes} escenas',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (stats != null) ...[
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 9,
                          child: _GlassPanel(
                            children: [
                              for (final metric in widget.metrics)
                                metric.isProgress
                                    ? _Bar(
                                        label: metric.label,
                                        done: metric.done(stats),
                                        total: metric.total(stats),
                                      )
                                    : _Count(
                                        label: metric.label,
                                        icon: metric.icon,
                                        value: metric.done(stats),
                                      ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(AppPalette palette) => PopupMenuButton<String>(
    color: palette.surfaceElevated,
    icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 18),
    onSelected: (v) {
      if (v == 'image') widget.onChangeImage();
      if (v == 'data') widget.onChooseData();
      if (v == 'color') widget.onChooseColor();
      for (final size in ProjectCardSize.values) {
        if (v == 'size_${size.name}') widget.onSetSize(size);
      }
      if (v == 'edit') widget.onEdit();
      if (v == 'duplicate') widget.onDuplicate();
      if (v == 'delete') widget.onDelete();
    },
    itemBuilder: (_) => [
      _item(
        'image',
        Icons.image_outlined,
        'Imagen de la tarjeta',
        palette.textSecondary,
      ),
      _item(
        'data',
        Icons.tune_outlined,
        'Datos de la tarjeta',
        palette.textSecondary,
      ),
      _item(
        'color',
        Icons.palette_outlined,
        'Color de la tarjeta',
        palette.textSecondary,
      ),
      const PopupMenuDivider(),
      for (final size in ProjectCardSize.values)
        CheckedPopupMenuItem(
          value: 'size_${size.name}',
          checked: ProjectCardSize.of(widget.project.cardSize) == size,
          child: Text('Tamaño ${size.label}'),
        ),
      const PopupMenuDivider(),
      _item('edit', Icons.edit_outlined, 'Editar', palette.textSecondary),
      _item('duplicate', Icons.copy_outlined, 'Duplicar', palette.textSecondary),
      _item('delete', Icons.delete_outline, 'Eliminar', palette.error),
    ],
  );

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label,
    Color color,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: value == 'delete' ? color : null)),
      ],
    ),
  );
}

/// Anillo del avance de preparación; su color dice cómo está con la nube.
class _Ring extends StatelessWidget {
  final int percent;
  final Color color;

  const _Ring({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: const BoxDecoration(
      color: Color(0x8C000000),
      shape: BoxShape.circle,
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            value: percent / 100,
            strokeWidth: 4.5,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: color.withValues(alpha: 0.25),
          ),
        ),
        Text(
          '$percent%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Una línea de avance: etiqueta, barra fina y «hechos/total».
class _Bar extends StatelessWidget {
  final String label;
  final int done;
  final int total;

  const _Bar({required this.label, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white, fontSize: 12.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label, style: style)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 5,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              total == 0 ? '—' : '$done/$total',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una cifra: icono, etiqueta y número.
class _Count extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;

  const _Count({required this.label, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white, fontSize: 12.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: style)),
          Text('$value', style: style.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Panel de cristal esmerilado para los datos: se leen sobre cualquier imagen
/// sin taparla del todo.
class _GlassPanel extends StatelessWidget {
  final List<Widget> children;

  const _GlassPanel({required this.children});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}

/// El estado de la nube como pastilla, con el mismo color que el anillo.
class _SyncPill extends StatelessWidget {
  final String label;
  final Color color;

  const _SyncPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  );
}

