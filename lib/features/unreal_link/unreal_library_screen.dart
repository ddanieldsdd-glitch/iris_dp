import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'fab_links.dart';
import 'unreal_library.dart';
import 'unreal_link.dart';
import 'unreal_thumbs.dart';

/// La biblioteca de assets de Unreal (F6.20 B5): lo usado y lo encontrado,
/// con miniatura, origen y medidas. Se busca sin Unreal; con Unreal
/// conectado se busca también en su proyecto y se hacen las miniaturas.
class UnrealLibraryScreen extends StatefulWidget {
  /// Proyecto de IRIS: dónde se guardan las miniaturas nuevas.
  final int? projectId;

  /// Desde la planta: poner el asset como elemento.
  final ValueChanged<UnrealAssetRef>? onPlace;
  final UnrealLink link;
  final UnrealLibrary library;

  /// Abre una búsqueda de Fab; en las pruebas no abre nada.
  final Future<void> Function(Uri) openUrl;

  UnrealLibraryScreen({
    super.key,
    this.projectId,
    this.onPlace,
    UnrealLink? link,
    UnrealLibrary? library,
    Future<void> Function(Uri)? openUrl,
  }) : link = link ?? UnrealLink.instance,
       library = library ?? UnrealLibrary.instance,
       openUrl = openUrl ?? _launch;

  static Future<void> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  static Future<void> open(
    BuildContext context, {
    int? projectId,
    ValueChanged<UnrealAssetRef>? onPlace,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          UnrealLibraryScreen(projectId: projectId, onPlace: onPlace),
    ),
  );

  @override
  State<UnrealLibraryScreen> createState() => _UnrealLibraryScreenState();
}

class _UnrealLibraryScreenState extends State<UnrealLibraryScreen>
    with WidgetsBindingObserver {
  final _query = TextEditingController();
  bool _favorites = false;
  bool _searching = false;
  bool _collecting = false;
  String? _status;
  int _rendering = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.library.load();
    // Lo bajado de Fab desde la última vez entra solo (F6.20 D2).
    if (widget.link.isOn) _collectFab(quiet: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _query.dispose();
    super.dispose();
  }

  /// Al volver a IRIS (del navegador o de Unreal), se recoge lo nuevo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.link.isOn) {
      _collectFab(quiet: true);
    }
  }

  /// Mete en la biblioteca lo que hay de Fab y Megascans en el proyecto de
  /// Unreal. [quiet]: sin aviso si no hay nada nuevo.
  Future<void> _collectFab({bool quiet = false}) async {
    if (_collecting) return;
    setState(() => _collecting = true);
    try {
      final found = await widget.link.findFabAssets();
      final added = await widget.library.addFound([
        for (final a in found) a.toRef(),
      ]);
      if (!quiet || added > 0) {
        _status = found.isEmpty
            ? 'Aún no hay nada de Fab ni de Megascans en el proyecto de '
                  'Unreal. Descárgalo con el plugin Fab (Ventana → Fab).'
            : '${found.length} de Fab y Megascans en Unreal, $added nuevos '
                  'en la biblioteca.';
      }
    } catch (e) {
      if (!quiet) _status = UnrealLink.describe(e);
    } finally {
      if (mounted) setState(() => _collecting = false);
    }
  }

  Future<void> _openFab(String query, {bool megascans = false}) async {
    await widget.openUrl(FabLinks.search(query, megascans: megascans));
    if (mounted) {
      setState(
        () => _status =
            'Fab abierto en el navegador. Añade lo que quieras a tu biblioteca '
            'de Fab y descárgalo en Unreal con el plugin Fab (Ventana → Fab); '
            'al volver a IRIS entra solo aquí.',
      );
    }
  }

  Future<void> _searchUnreal() async {
    setState(() {
      _searching = true;
      _status = null;
    });
    try {
      final found = await widget.link.findAssets(_query.text);
      final added = await widget.library.addFound([
        for (final a in found) a.toRef(),
      ]);
      _status = found.isEmpty
          ? 'Nada así en el proyecto de Unreal.'
          : '${found.length} encontrados en Unreal, $added nuevos en la '
                'biblioteca.';
    } catch (e) {
      _status = UnrealLink.describe(e);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Hace en Unreal las miniaturas de lo que no las tiene, una a una.
  Future<void> _renderMissing(List<UnrealLibraryEntry> list) async {
    final projectId = widget.projectId;
    if (projectId == null) return;
    final todo = [
      for (final e in list)
        if (e.ref.thumb34 == null) e,
    ];
    for (final (i, e) in todo.indexed) {
      if (!mounted || !widget.link.isOn) break;
      setState(() {
        _rendering = todo.length - i;
        _status = 'Miniaturas: ${i + 1} de ${todo.length}…';
      });
      try {
        final ref = await UnrealThumbs.render(widget.link, projectId, e.ref);
        await widget.library.remember(ref, projectId: projectId);
      } catch (err) {
        _status = '${e.ref.name}: ${UnrealLink.describe(err)}';
      }
    }
    if (mounted) {
      setState(() {
        _rendering = 0;
        _status ??= 'Miniaturas hechas.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final link = widget.link;
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.library,
        link,
        UnrealThumbs.instance,
      ]),
      builder: (context, _) {
        final list = widget.library.search(
          _query.text,
          favoritesOnly: _favorites,
        );
        final missing = list.where((e) => e.ref.thumb34 == null).length;
        return Scaffold(
          appBar: AppBar(title: const Text('Biblioteca de Unreal')),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _query,
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText: 'Buscar: sofá, Megascans, rock…',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Favoritos'),
                      selected: _favorites,
                      onSelected: (v) => setState(() => _favorites = v),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Buscar en Fab'),
                      onPressed: () => _openFab(_query.text),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.landscape_outlined, size: 18),
                      label: const Text('Megascans'),
                      onPressed: () => _openFab(_query.text, megascans: true),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Packs de partida en Fab',
                      onSelected: _openFab,
                      itemBuilder: (_) => [
                        for (final (label, query) in FabLinks.starterPacks)
                          PopupMenuItem(value: query, child: Text(label)),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 18),
                            SizedBox(width: 6),
                            Text('Packs de partida'),
                            Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                    if (link.isOn) ...[
                      FilledButton.tonalIcon(
                        icon: _collecting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_done, size: 18),
                        label: const Text('Recoger de Fab'),
                        onPressed: _collecting ? null : () => _collectFab(),
                      ),
                      FilledButton.tonalIcon(
                        icon: _searching
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.travel_explore, size: 18),
                        label: const Text('Buscar en Unreal'),
                        onPressed: _searching ? null : _searchUnreal,
                      ),
                      if (missing > 0 && widget.projectId != null)
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: Text('Hacer $missing miniaturas'),
                          onPressed: _rendering > 0
                              ? null
                              : () => _renderMissing(list),
                        ),
                    ] else
                      Text(
                        'Sin Unreal: buscas en lo que ya está en la '
                        'biblioteca.',
                        style: AppTypography.caption(
                          palette,
                        ).copyWith(color: palette.textTertiary),
                      ),
                  ],
                ),
              ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    _status!,
                    style: AppTypography.caption(palette),
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            widget.library.entries.isEmpty
                                ? 'La biblioteca se llena sola con los assets '
                                      'que eliges para los elementos, y con '
                                      '«Buscar en Unreal».'
                                : 'Nada con ese nombre.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium(palette),
                          ),
                        ),
                      )
                    : GridView.extent(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.78,
                        children: [for (final e in list) _card(palette, e)],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(AppPalette palette, UnrealLibraryEntry e) {
    final projectId = e.thumbProjectId ?? widget.projectId;
    final file = projectId == null
        ? null
        : UnrealThumbs.instance.file(projectId, e.ref.thumb34);
    final size = e.ref.sizeCm;
    return Material(
      color: palette.surfaceElevated,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (file != null)
                  Image.file(File(file), fit: BoxFit.contain)
                else
                  Icon(
                    e.ref.kind == UnrealAssetKind.mesh
                        ? Icons.view_in_ar_outlined
                        : Icons.person_outline,
                    size: 40,
                    color: palette.textTertiary,
                  ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: e.favorite ? 'Quitar de favoritos' : 'Favorito',
                    icon: Icon(
                      e.favorite ? Icons.star : Icons.star_border,
                      color: e.favorite
                          ? palette.warning
                          : palette.textSecondary,
                    ),
                    onPressed: () =>
                        widget.library.toggleFavorite(e.ref.path),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
              0,
            ),
            child: Text(
              UnrealLibrary.prettyName(e.ref.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium(palette),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              [
                e.ref.source.label,
                if (size != null) '${size.map((v) => v.round()).join('×')} cm',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
          ),
          Row(
            children: [
              if (widget.onPlace != null)
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      widget.onPlace!(e.ref);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Poner en la planta'),
                  ),
                )
              else
                const Spacer(),
              IconButton(
                tooltip: 'Quitar de la biblioteca',
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: palette.textTertiary,
                ),
                onPressed: () => widget.library.remove(e.ref.path),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
