import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/shot_reference_import.dart';
import '../utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';

/// Abre el visor a pantalla completa; si hay varias referencias, permite deslizar entre ellas.
Future<void> showShotReferenceViewer(
  BuildContext context, {
  required WidgetRef ref,
  required Scene scene,
  required Shot shot,
  required ShotReference initialReference,
  void Function(String source)? onImport,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _ShotReferenceViewerPage(
        scene: scene,
        shot: shot,
        initialReferenceId: initialReference.id,
        onImport: onImport,
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

/// Galería compacta de referencias de un plano.
class ShotReferenceGallery extends ConsumerWidget {
  final int shotId;
  final int sceneId;
  final Scene scene;
  final Shot shot;
  final void Function(String source)? onImport;

  const ShotReferenceGallery({
    super.key,
    required this.shotId,
    required this.sceneId,
    required this.scene,
    required this.shot,
    this.onImport,
  });

  void _openViewer(
    BuildContext context,
    WidgetRef ref,
    Shot currentShot,
    ShotReference reference,
  ) async {
    final db = ref.read(databaseProvider);
    try {
      final synced = await ensureShotReferencesSynced(db: db, shot: currentShot);
      if (synced.isEmpty || !context.mounted) return;
      final initial = synced.any((r) => r.id == reference.id)
          ? synced.firstWhere((r) => r.id == reference.id)
          : synced.first;
      await showShotReferenceViewer(
        context,
        ref: ref,
        scene: scene,
        shot: currentShot,
        initialReference: initial,
        onImport: onImport,
      );
    } catch (_) {
      if (!context.mounted) return;
      await showShotReferenceViewer(
        context,
        ref: ref,
        scene: scene,
        shot: currentShot,
        initialReference: reference,
        onImport: onImport,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<Shot>>(
      stream: db.watchShotsForScene(sceneId),
      builder: (context, shotSnap) {
        final currentShot = _findShot(shotSnap.data, shotId) ?? shot;
        final primary = currentShot.referenceImagePath;

        return StreamBuilder<List<ShotReference>>(
          stream: db.watchReferencesForShot(shotId),
          builder: (context, refSnap) {
            final refs = refSnap.data ?? [];
            if (refs.isEmpty) {
              return Text(
                'Aún no hay referencias para este plano.',
                style: AppTypography.bodyMedium(palette),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        refs.length > 1
                            ? '${refs.length} referencias · toca para ampliar'
                            : 'Toca para ver en grande',
                        style: AppTypography.caption(palette),
                      ),
                    ),
                    if (refs.length > 1)
                      TextButton.icon(
                        onPressed: () => _openViewer(
                          context,
                          ref,
                          currentShot,
                          _initialReference(refs, primary),
                        ),
                        icon: Icon(Icons.view_carousel_outlined,
                            size: 16, color: palette.accent),
                        label: Text(
                          'Ver todas',
                          style: AppTypography.caption(palette).copyWith(
                            color: palette.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: refs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final reference = refs[index];
                      final isPrimary = reference.imagePath == primary;
                      return _ReferenceTile(
                        reference: reference,
                        index: index,
                        isPrimary: isPrimary,
                        onTap: () => _openViewer(
                          context,
                          ref,
                          currentShot,
                          reference,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

ShotReference _initialReference(List<ShotReference> refs, String? primaryPath) {
  if (primaryPath != null) {
    for (final r in refs) {
      if (r.imagePath == primaryPath) return r;
    }
  }
  return refs.first;
}

class _ShotReferenceViewerPage extends ConsumerStatefulWidget {
  final Scene scene;
  final Shot shot;
  final int initialReferenceId;
  final void Function(String source)? onImport;

  const _ShotReferenceViewerPage({
    required this.scene,
    required this.shot,
    required this.initialReferenceId,
    this.onImport,
  });

  @override
  ConsumerState<_ShotReferenceViewerPage> createState() =>
      _ShotReferenceViewerPageState();
}

class _ShotReferenceViewerPageState
    extends ConsumerState<_ShotReferenceViewerPage> {
  PageController? _pageController;
  int _currentIndex = 0;
  final _filmstripController = ScrollController();
  bool _controllerReady = false;

  @override
  void dispose() {
    _pageController?.dispose();
    _filmstripController.dispose();
    super.dispose();
  }

  int _indexForReference(List<ShotReference> refs) {
    final idx = refs.indexWhere((r) => r.id == widget.initialReferenceId);
    return idx >= 0 ? idx : 0;
  }

  void _initPageController(List<ShotReference> refs) {
    if (_controllerReady || refs.isEmpty) return;
    final index = _indexForReference(refs);
    _currentIndex = index;
    _pageController = PageController(initialPage: index);
    _controllerReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFilmstripTo(index);
    });
  }

  void _scrollFilmstripTo(int index) {
    if (!_filmstripController.hasClients) return;
    const itemWidth = 88.0;
    const spacing = AppSpacing.sm;
    final offset = index * (itemWidth + spacing) - 40;
    _filmstripController.animateTo(
      offset.clamp(0.0, _filmstripController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  String _sourceLabel(String source) => switch (source) {
        ShotReferenceSource.artemisCapture => 'Artemis',
        ShotReferenceSource.unrealRender => 'Render UE',
        _ => 'Manual',
      };

  ShotReference? _currentRef(List<ShotReference> refs) {
    if (refs.isEmpty || _currentIndex >= refs.length) return null;
    return refs[_currentIndex];
  }

  Future<void> _setPrimary(ShotReference reference) async {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    try {
      final current = await db.getShotById(widget.shot.id) ?? widget.shot;
      await setPrimaryShotReference(
        db: db,
        shot: current,
        imagePath: reference.imagePath,
      );
      if (!mounted) return;
      AppSnackBar.show(context, 'Imagen principal actualizada.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }

  Future<void> _confirmDelete(ShotReference reference) async {
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Eliminar referencia', style: AppTypography.titleMedium(palette)),
        content: Text(
          '¿Quieres eliminar esta imagen del plano?',
          style: AppTypography.bodyMedium(palette),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppTypography.label(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: AppTypography.label(palette).copyWith(color: palette.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = ref.read(databaseProvider);
    final deletedIndex = _currentIndex;
    try {
      final current = await db.getShotById(widget.shot.id) ?? widget.shot;
      await deleteShotReferenceEntry(
        db: db,
        shot: current,
        reference: reference,
      );

      final remaining = await db.watchReferencesForShot(widget.shot.id).first;
      if (!mounted) return;
      if (remaining.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      final nextIndex = deletedIndex.clamp(0, remaining.length - 1);
      setState(() => _currentIndex = nextIndex);
      _pageController?.jumpToPage(nextIndex);
      _scrollFilmstripTo(nextIndex);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }

  void _showOptions({
    required ShotReference reference,
    required bool isPrimary,
  }) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(
                  'Esc ${widget.scene.number} · Plano ${widget.shot.number}',
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              if (!isPrimary)
                ListTile(
                  leading: Icon(Icons.star_outline, color: palette.accent),
                  title: Text(
                    'Usar como principal',
                    style: AppTypography.bodyLarge(palette),
                  ),
                  subtitle: Text(
                    'Visible en el storyboard y el PDF',
                    style: AppTypography.caption(palette),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setPrimary(reference);
                  },
                ),
              if (widget.onImport != null) ...[
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: palette.accent),
                  title: Text(
                    'Añadir captura Artemis',
                    style: AppTypography.bodyLarge(palette),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pop();
                    widget.onImport!(ShotReferenceSource.artemisCapture);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.add_photo_alternate_outlined,
                      color: palette.textSecondary),
                  title: Text(
                    'Añadir imagen manual',
                    style: AppTypography.bodyLarge(palette),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pop();
                    widget.onImport!(ShotReferenceSource.manual);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.view_in_ar_outlined, color: palette.accent),
                  title: Text(
                    'Importar render Unreal',
                    style: AppTypography.bodyLarge(palette),
                  ),
                  subtitle: Text(
                    'Frame del Movie Render Queue',
                    style: AppTypography.caption(palette),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pop();
                    widget.onImport!(ShotReferenceSource.unrealRender);
                  },
                ),
              ],
              ListTile(
                leading: Icon(Icons.delete_outline, color: palette.error),
                title: Text(
                  'Eliminar esta referencia',
                  style: AppTypography.bodyLarge(palette)
                      .copyWith(color: palette.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(reference);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToPage(int index, int total) {
    if (index < 0 || index >= total || _pageController == null) return;
    _pageController!.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<Shot>>(
      stream: db.watchShotsForScene(widget.scene.id),
      builder: (context, shotSnap) {
        final currentShot = _findShot(shotSnap.data, widget.shot.id) ?? widget.shot;
        final primaryPath = currentShot.referenceImagePath;

        return StreamBuilder<List<ShotReference>>(
          stream: db.watchReferencesForShot(widget.shot.id),
          builder: (context, refSnap) {
            if (!refSnap.hasData) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final refs = refSnap.data!;
            if (refs.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop();
              });
              return const Scaffold(backgroundColor: Colors.black);
            }

            if (!_controllerReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _controllerReady) return;
                setState(() => _initPageController(refs));
              });
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (_currentIndex >= refs.length) {
              _currentIndex = refs.length - 1;
            }

            final pageController = _pageController!;
            final currentRef = _currentRef(refs)!;
            final isPrimary = currentRef.imagePath == primaryPath;
            final hasMultiple = refs.length > 1;

            return Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: refs.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                      _scrollFilmstripTo(index);
                    },
                    itemBuilder: (context, index) {
                      final reference = refs[index];
                      final exists = File(reference.imagePath).existsSync();
                      if (!exists) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_outlined,
                                  size: 48, color: palette.textTertiary),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Archivo no encontrado',
                                style: AppTypography.bodyMedium(palette),
                              ),
                            ],
                          ),
                        );
                      }
                      return InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        panEnabled: true,
                        child: Center(
                          child: Image.file(
                            File(reference.imagePath),
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                  const _ViewerGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    height: 120,
                  ),
                  if (hasMultiple)
                    const _ViewerGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      height: 160,
                    ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          _ViewerIconButton(
                            icon: Icons.close,
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Esc ${widget.scene.number} · Plano ${widget.shot.number}',
                                  style: AppTypography.label(palette).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasMultiple
                                      ? '${_currentIndex + 1} de ${refs.length} · '
                                          '${_sourceLabel(currentRef.source)}'
                                      : _sourceLabel(currentRef.source),
                                  style: AppTypography.caption(palette).copyWith(
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          _ViewerIconButton(
                            icon: isPrimary ? Icons.star : Icons.star_border,
                            tooltip: isPrimary
                                ? 'Imagen principal'
                                : 'Marcar como principal',
                            color: isPrimary ? palette.accent : Colors.white,
                            onPressed: isPrimary
                                ? null
                                : () => _setPrimary(currentRef),
                          ),
                          _ViewerIconButton(
                            icon: Icons.more_vert,
                            tooltip: 'Opciones',
                            onPressed: () => _showOptions(
                              reference: currentRef,
                              isPrimary: isPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasMultiple) ...[
                    Positioned(
                      left: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _ViewerNavButton(
                          icon: Icons.chevron_left,
                          enabled: _currentIndex > 0,
                          onPressed: () => _goToPage(_currentIndex - 1, refs.length),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _ViewerNavButton(
                          icon: Icons.chevron_right,
                          enabled: _currentIndex < refs.length - 1,
                          onPressed: () => _goToPage(_currentIndex + 1, refs.length),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPrimary)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.accent.withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star,
                                            size: 14, color: Colors.white),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Imagen principal del plano',
                                          style: AppTypography.caption(palette)
                                              .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              SizedBox(
                                height: 64,
                                child: ListView.separated(
                                  controller: _filmstripController,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: refs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: AppSpacing.sm),
                                  itemBuilder: (context, index) {
                                    final reference = refs[index];
                                    final selected = index == _currentIndex;
                                    final thumbPrimary =
                                        reference.imagePath == primaryPath;
                                    return _FilmstripThumb(
                                      reference: reference,
                                      selected: selected,
                                      isPrimary: thumbPrimary,
                                      onTap: () => _goToPage(index, refs.length),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else if (isPrimary)
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 56),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accent.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Imagen principal',
                                  style: AppTypography.caption(palette).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ViewerGradient extends StatelessWidget {
  final Alignment begin;
  final Alignment end;
  final double height;

  const _ViewerGradient({
    required this.begin,
    required this.end,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: begin,
      child: IgnorePointer(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [
                Colors.black.withValues(alpha: 0.72),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const _ViewerIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color ?? Colors.white),
    );
  }
}

class _ViewerNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _ViewerNavButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: enabled ? 0.45 : 0.15),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _FilmstripThumb extends StatelessWidget {
  final ShotReference reference;
  final bool selected;
  final bool isPrimary;
  final VoidCallback onTap;

  const _FilmstripThumb({
    required this.reference,
    required this.selected,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final exists = File(reference.imagePath).existsSync();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: selected ? 96 : 80,
        height: selected ? 54 : 45,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? palette.accent : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (exists)
              Image.file(File(reference.imagePath), fit: BoxFit.cover)
            else
              ColoredBox(color: palette.surfaceOverlay),
            if (isPrimary)
              Positioned(
                right: 4,
                top: 4,
                child: Icon(Icons.star, size: 12, color: palette.accent),
              ),
          ],
        ),
      ),
    );
  }
}

Shot? _findShot(List<Shot>? shots, int shotId) {
  if (shots == null) return null;
  for (final shot in shots) {
    if (shot.id == shotId) return shot;
  }
  return null;
}

class _ReferenceTile extends StatelessWidget {
  final ShotReference reference;
  final int index;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ReferenceTile({
    required this.reference,
    required this.index,
    required this.isPrimary,
    required this.onTap,
  });

  String _sourceLabel(String source) => switch (source) {
        ShotReferenceSource.artemisCapture => 'Artemis',
        ShotReferenceSource.unrealRender => 'Render UE',
        _ => 'Manual',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final exists = File(reference.imagePath).existsSync();

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPrimary ? palette.accent : palette.divider,
                      width: isPrimary ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: exists
                            ? Image.file(
                                File(reference.imagePath),
                                fit: BoxFit.cover,
                              )
                            : ColoredBox(
                                color: palette.surfaceOverlay,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: palette.textTertiary,
                                ),
                              ),
                      ),
                      if (isPrimary)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: _MiniBadge(
                            label: 'Principal',
                            color: palette.accent,
                          ),
                        ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _MiniBadge(
                          label: '${index + 1}',
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _sourceLabel(reference.source),
            style: AppTypography.caption(palette),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: label == 'Principal' ? 0.92 : 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.caption(context.palette).copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
