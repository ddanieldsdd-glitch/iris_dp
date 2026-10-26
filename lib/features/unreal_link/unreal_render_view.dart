import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'unreal_link.dart';

/// «Render RTX» (F6.19.4): lo que ve el visor del editor de Unreal, con
/// Lumen y el trazado de rayos de la tarjeta, por Pixel Streaming.
///
/// Unreal tiene que estar abierto con Pixel Streaming emitiendo el visor
/// (`tools/unreal/iris_stage/Abrir con IRIS Stage.bat`). Desde aquí se elige
/// por qué cámara de la planta se mira.
class UnrealRenderScreen extends StatefulWidget {
  /// Cámaras de la planta: id y nombre.
  final List<(String, String)> cameras;
  final UnrealLink link;

  const UnrealRenderScreen({
    super.key,
    required this.cameras,
    required this.link,
  });

  static Future<void> open(
    BuildContext context, {
    required List<(String, String)> cameras,
    UnrealLink? link,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UnrealRenderScreen(
        cameras: cameras,
        link: link ?? UnrealLink.instance,
      ),
    ),
  );

  @override
  State<UnrealRenderScreen> createState() => _UnrealRenderScreenState();
}

class _UnrealRenderScreenState extends State<UnrealRenderScreen> {
  InAppWebViewController? _web;
  String? _camera;
  String? _error;
  bool _loading = true;

  Future<void> _viewThrough(String id) async {
    setState(() {
      _camera = id;
      _error = null;
    });
    try {
      await widget.link.viewThrough(id);
    } catch (e) {
      if (mounted) setState(() => _error = UnrealLink.describe(e));
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _web?.loadUrl(
      urlRequest: URLRequest(url: WebUri.uri(widget.link.streamUrl)),
    );
  }

  Future<void> _editPort() async {
    final controller = TextEditingController(
      text: '${widget.link.viewerPort}',
    );
    final port = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Puerto de Pixel Streaming'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            helperText: 'El «HTTP port» del menú Pixel Streaming de Unreal',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (port == null || port <= 0) return;
    await widget.link.setViewerPort(port);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final link = widget.link;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Render RTX · Unreal'),
        actions: [
          if (widget.cameras.isNotEmpty && link.isOn)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: DropdownButton<String>(
                value: _camera,
                hint: const Text('Ver por la cámara…'),
                underline: const SizedBox.shrink(),
                items: [
                  for (final (id, name) in widget.cameras)
                    DropdownMenuItem(value: id, child: Text(name)),
                ],
                onChanged: (id) => id == null ? null : _viewThrough(id),
              ),
            ),
          IconButton(
            tooltip: 'Puerto de Pixel Streaming',
            icon: const Icon(Icons.settings_ethernet),
            onPressed: _editPort,
          ),
          IconButton(
            tooltip: 'Volver a cargar',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri.uri(link.streamUrl)),
            initialSettings: InAppWebViewSettings(
              isInspectable: kDebugMode,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              transparentBackground: false,
            ),
            onWebViewCreated: (c) => _web = c,
            onLoadStop: (_, _) {
              if (mounted) setState(() => _loading = false);
            },
            onReceivedError: (_, request, error) {
              if (request.isForMainFrame != true || !mounted) return;
              setState(() {
                _loading = false;
                _error =
                    'No se ve Pixel Streaming en ${link.streamUrl.host}:'
                    '${link.viewerPort}. Abre el proyecto con «Abrir con IRIS '
                    'Stage.bat» o, en Unreal, Pixel Streaming → Stream Level '
                    'Editor. (${error.description})';
              });
            },
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Material(
                color: palette.surface,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    _error!,
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.error),
                  ),
                ),
              ),
            ),
          if (!link.isOn)
            Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: Text(
                'Sin conectar con IRIS Stage Link: se ve Unreal, pero los '
                'cambios de la planta no llegan.',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.warning),
              ),
            ),
        ],
      ),
    );
  }
}
