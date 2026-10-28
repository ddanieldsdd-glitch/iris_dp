import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../camera_plan/camera_plan_constants.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/light/light_scene.dart';
import '../camera_plan/rig/plan_scene3d.dart';
import 'unreal_link.dart';

/// Qué asset de Unreal (Fab, Megascans o propio) hace de este elemento en
/// Unreal: cualquier tipo, no solo el atrezzo (F6.20 B2). Los assets de Fab
/// y Megascans solo se pueden usar dentro de Unreal: no se copian a IRIS,
/// que guarda su ruta y, en el atrezzo, sus medidas.
class UnrealAssetTile extends StatelessWidget {
  final PlanElement element;
  final UnrealLink link;
  final Future<void> Function() onChanged;

  const UnrealAssetTile({
    super.key,
    required this.element,
    required this.link,
    required this.onChanged,
  });

  static UnrealAssetRef? assetOf(PlanElement el) => UnrealAssetRef.of(el);

  /// Pone [asset] al elemento. Al atrezzo le da además sus medidas: la
  /// huella (lo más ancho) y el alto.
  static void assign(PlanElement el, UnrealAsset asset) {
    UnrealAssetRef.set(el, asset.toRef());
    final s = asset.sizeCm;
    if (el.type == ElementType.prop &&
        PlanScene3d.furniture.contains(el.propType) &&
        s != null &&
        s.every((v) => v > 0)) {
      el.props[LightScene.sizeKey] =
          (math.max(s[0], s[1])).roundToDouble() / 100;
      el.props[LightScene.heightKey] = s[2].roundToDouble() / 100;
    }
  }

  /// Qué clases de asset tienen sentido para el elemento: personajes para
  /// los actores; mallas y Blueprints para lo demás.
  static Set<UnrealAssetKind> kindsFor(PlanElement el) =>
      el.type == ElementType.actor
      ? {
          UnrealAssetKind.skeletal,
          UnrealAssetKind.metahuman,
          UnrealAssetKind.blueprint,
        }
      : {UnrealAssetKind.mesh, UnrealAssetKind.blueprint};

  /// Lo que no tiene asset: el atrezzo va como bloque; lo demás no sale en
  /// Unreal (salvo focos y cámaras, que son luz y cámara de Unreal).
  static String withoutAsset(PlanElement el) => switch (el.type) {
    ElementType.prop => 'Un bloque con sus medidas.',
    ElementType.light => 'La luz de Unreal, sin el cuerpo del aparato.',
    ElementType.camera => 'La cámara de cine, sin cuerpo ni rig.',
    _ => 'No sale en Unreal hasta que tenga un asset.',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final asset = assetOf(element);
    return ListenableBuilder(
      listenable: link,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('En Unreal', style: AppTypography.label(palette)),
            Text(
              asset == null ? withoutAsset(element) : asset.name,
              style: AppTypography.bodyMedium(palette),
            ),
            if (asset != null)
              Text(
                '${asset.source.label} · ${asset.path}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textTertiary),
              ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              icon: const Icon(Icons.chair_outlined, size: 16),
              label: Text(
                asset == null ? 'Elegir asset de Unreal…' : 'Cambiar asset…',
              ),
              onPressed: link.isOn
                  ? () async {
                      final picked = await showDialog<_Pick>(
                        context: context,
                        builder: (_) => _AssetDialog(
                          link: link,
                          kinds: kindsFor(element),
                        ),
                      );
                      if (picked == null) return;
                      if (picked.asset == null) {
                        UnrealAssetRef.set(element, null);
                      } else {
                        assign(element, picked.asset!);
                      }
                      await onChanged();
                    }
                  : null,
            ),
            if (!link.isOn)
              Text(
                'Conecta con Unreal para elegir un asset de su proyecto.',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pick {
  final UnrealAsset? asset;
  const _Pick(this.asset);
}

class _AssetDialog extends StatefulWidget {
  final UnrealLink link;
  final Set<UnrealAssetKind> kinds;
  const _AssetDialog({required this.link, required this.kinds});

  @override
  State<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends State<_AssetDialog> {
  final _query = TextEditingController();
  List<UnrealAsset> _found = const [];
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

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await widget.link.findAssets(_query.text);
      if (mounted) {
        setState(
          () => _found = [
            for (final a in found)
              if (widget.kinds.contains(a.kind)) a,
          ],
        );
      }
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
      title: const Text('Asset de Unreal'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'sofá, chair, Megascans…',
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _search);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Mallas del proyecto de Unreal: lo que hayas añadido de Fab o '
              'Megascans, o lo tuyo. Se usan solo en Unreal; en IRIS queda '
              'la pieza con sus medidas.',
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
                        for (final a in _found)
                          ListTile(
                            dense: true,
                            title: Text(a.name),
                            subtitle: Text(
                              '${a.source.label} · ${a.sizeLabel} · ${a.folder}',
                            ),
                            onTap: () => Navigator.pop(context, _Pick(a)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const _Pick(null)),
          child: const Text('Sin asset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
