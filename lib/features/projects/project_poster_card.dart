import 'dart:io';

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
    final color = syncColor(palette, widget.syncState);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        offset: _hover ? const Offset(0, -0.012) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        child: GestureDetector(
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasCover)
                  Image.file(File(coverPath), fit: BoxFit.cover)
                else
                  ColoredBox(
                    color: palette.surfaceOverlay,
                    child: Center(
                      child: Icon(
                        IconData(project.iconCode, fontFamily: 'MaterialIcons'),
                        size: 64,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                // Oscurece la parte baja para que el texto se lea sobre
                // cualquier portada.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Colors.transparent, Color(0xE6000000)],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 4,
                  child: _menu(palette),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Tooltip(
                    message: widget.syncState?.label ?? '',
                    child: _Ring(
                      percent: stats?.preparationPercent(widget.metrics) ?? 0,
                      color: color,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stats != null) ...[
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
                        const SizedBox(height: 10),
                      ],
                      Text(
                        project.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (stats != null &&
                              !widget.metrics.contains(ProjectCardMetric.scenes))
                            '${stats.scenes} escenas',
                          if (widget.syncState != null)
                            widget.syncState!.label.toLowerCase(),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.5,
                        ),
                      ),
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
    width: 46,
    height: 46,
    decoration: const BoxDecoration(
      color: Color(0x8C000000),
      shape: BoxShape.circle,
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            value: percent / 100,
            strokeWidth: 3,
            color: color,
            backgroundColor: color.withValues(alpha: 0.25),
          ),
        ),
        Text(
          '$percent%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
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
    const style = TextStyle(color: Colors.white, fontSize: 11);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 68, child: Text(label, style: style)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 4,
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
    const style = TextStyle(color: Colors.white, fontSize: 11);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
