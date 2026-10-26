import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/light/light_scene.dart';
import '../camera_plan/rig/plan_scene3d.dart';
import 'unreal_link.dart';

/// Qué asset de Unreal (Fab, Megascans o propio) hace de esta pieza en
/// Unreal (paso 5 de F6.19). Los assets de Fab y Megascans solo se pueden
/// usar dentro de Unreal: no se copian a IRIS, que se queda con un sustituto
/// de las mismas medidas.
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

  static String? assetOf(PlanElement el) =>
      el.props[PlanScene3d.unrealAssetKey] as String?;

  /// Pone [asset] a la pieza y le da sus medidas: la huella (lo más ancho)
  /// y el alto.
  static void assign(PlanElement el, UnrealAsset asset) {
    el.props[PlanScene3d.unrealAssetKey] = asset.path;
    final s = asset.sizeCm;
    if (s.length == 3 && s.every((v) => v > 0)) {
      el.props[LightScene.sizeKey] =
          (math.max(s[0], s[1])).roundToDouble() / 100;
      el.props[LightScene.heightKey] = s[2].roundToDouble() / 100;
    }
  }

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
              asset == null
                  ? 'Un bloque con sus medidas.'
                  : asset.split('/').last.split('.').first,
              style: AppTypography.bodyMedium(palette),
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
                        builder: (_) => _AssetDialog(link: link),
                      );
                      if (picked == null) return;
                      if (picked.asset == null) {
                        element.props.remove(PlanScene3d.unrealAssetKey);
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
  const _AssetDialog({required this.link});

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
      if (mounted) setState(() => _found = found);
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
                            subtitle: Text('${a.sizeLabel} · ${a.folder}'),
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
          child: const Text('Sin asset (bloque)'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
