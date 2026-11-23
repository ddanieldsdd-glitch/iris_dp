import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../camera_plan/arch/arch_material.dart';
import 'unreal_library.dart';
import 'unreal_link.dart';

/// Con qué material de Unreal se hace un material de IRIS (AM.U2): un
/// ladrillo de Megascans, una madera de Fab o uno del proyecto. En IRIS se
/// sigue viendo la textura CC0; en Unreal, el vinculado. Vale para todas
/// las plantas y viaja con la biblioteca de Unreal.
class UnrealMaterialLinkRow extends StatelessWidget {
  final ArchMaterial material;

  /// Después de cambiar el vínculo, para que la planta lo mande a Unreal.
  final VoidCallback? onChanged;

  const UnrealMaterialLinkRow({
    super.key,
    required this.material,
    this.onChanged,
  });

  /// Lo que se busca en Unreal para un material: su familia en inglés, que
  /// es como se llaman los de Fab y Megascans.
  static String queryFor(ArchMaterial m) => switch (m.family) {
    ArchFamily.plaster => 'plaster',
    ArchFamily.concrete => 'concrete',
    ArchFamily.brick => 'brick',
    ArchFamily.stone => 'stone',
    ArchFamily.tile => 'tile',
    ArchFamily.wood => 'wood',
    ArchFamily.metal => 'metal',
    ArchFamily.glass => 'glass',
    ArchFamily.fabric => 'fabric',
    ArchFamily.asphalt => 'asphalt',
    ArchFamily.earth => 'soil',
    ArchFamily.sand => 'sand',
    ArchFamily.grass => 'grass',
    ArchFamily.water => 'water',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final library = UnrealLibrary.instance;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final linked = library.materialLinkOf(material.id);
        return InkWell(
          key: ValueKey('unreal-material-link-${material.id}'),
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            final picked = await showDialog<_MaterialPick>(
              context: context,
              builder: (_) => _MaterialDialog(
                link: UnrealLink.instance,
                initialQuery: queryFor(material),
                current: linked,
              ),
            );
            if (picked == null) return;
            await library.linkMaterial(material.id, picked.ref);
            onChanged?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 14,
                  color: linked == null ? palette.textTertiary : palette.accent,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    linked == null
                        ? 'En Unreal: el mismo (sin vincular)'
                        : 'En Unreal: ${linked.name} · ${linked.source.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(palette).copyWith(
                      color: linked == null
                          ? palette.textTertiary
                          : palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MaterialPick {
  final UnrealAssetRef? ref;
  const _MaterialPick(this.ref);
}

/// Buscar el material: los ya vinculados a otros materiales de IRIS (sin
/// Unreal) y, con Unreal conectado, los del proyecto.
class _MaterialDialog extends StatefulWidget {
  final UnrealLink link;
  final String initialQuery;
  final UnrealAssetRef? current;

  const _MaterialDialog({
    required this.link,
    required this.initialQuery,
    this.current,
  });

  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<_MaterialDialog> {
  late final _query = TextEditingController(text: widget.initialQuery);
  List<UnrealAssetRef> _found = const [];
  bool _busy = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// Los materiales de Unreal ya usados en algún vínculo.
  List<UnrealAssetRef> _known(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final byPath = <String, UnrealAssetRef>{
      for (final id in UnrealLibrary.instance.materialPaths.keys)
        if (UnrealLibrary.instance.materialLinkOf(id) case final r?) r.path: r,
    };
    return [
      for (final r in byPath.values)
        if (words.every('${r.name} ${r.path}'.toLowerCase().contains)) r,
    ];
  }

  Future<void> _search() async {
    final query = _query.text;
    setState(() {
      _found = _known(query);
      _error = null;
      _busy = widget.link.isOn;
    });
    if (!widget.link.isOn) return;
    try {
      final found = await widget.link.findMaterials(query);
      if (!mounted || _query.text != query) return;
      final seen = {for (final r in _found) r.path};
      setState(
        () => _found = [
          ..._found,
          for (final a in found)
            if (seen.add(a.path)) a.toRef(),
        ],
      );
    } catch (e) {
      if (mounted) setState(() => _error = UnrealLink.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      title: const Text('Material en Unreal'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('unreal-material-query'),
              controller: _query,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'brick, Megascans, wood…',
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _search);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.link.isOn
                  ? 'Materiales del proyecto de Unreal: lo que hayas añadido '
                        'de Fab o Megascans, o lo tuyo. En IRIS se sigue '
                        'viendo la textura de IRIS; en Unreal, este.'
                  : 'Conecta con Unreal para buscar en su proyecto. Mientras, '
                        'los que ya has vinculado antes.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: AppTypography.bodyMedium(
                  palette,
                ).copyWith(color: palette.error),
              ),
            Expanded(
              child: _found.isEmpty && !_busy
                  ? Center(
                      child: Text(
                        'Nada con ese nombre.',
                        style: AppTypography.caption(palette),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final r in _found)
                          ListTile(
                            dense: true,
                            selected: r.path == widget.current?.path,
                            title: Text(r.name),
                            subtitle: Text(
                              '${r.source.label} · '
                              '${r.path.split('.').first}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () =>
                                Navigator.pop(context, _MaterialPick(r)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            key: const ValueKey('unreal-material-unlink'),
            onPressed: () => Navigator.pop(context, const _MaterialPick(null)),
            child: const Text('Sin vincular'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
