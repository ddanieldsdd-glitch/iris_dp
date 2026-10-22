import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'plan_scene3d.dart';

/// La planta en 3D: three.js en un WebView, empaquetado en la app para que
/// funcione sin red (`assets/viewer3d/`). Recibe la escena resuelta
/// ([PlanScene3d]) cada vez que la planta cambia y avisa de lo que se toca
/// en el 3D para seleccionarlo también en la planta.
class Plan3dView extends StatefulWidget {
  final List<PlanElement> elements;
  final double metersPerUnit;
  final String? name;
  final PlanElement? selected;
  final ValueChanged<PlanElement?>? onSelect;

  /// Botón de cerrar en la barra (el panel junto a la planta).
  final VoidCallback? onClose;

  const Plan3dView({
    super.key,
    required this.elements,
    required this.metersPerUnit,
    this.name,
    this.selected,
    this.onSelect,
    this.onClose,
  });

  static const asset = 'assets/viewer3d/index.html';

  @override
  State<Plan3dView> createState() => _Plan3dViewState();
}

class _Plan3dViewState extends State<Plan3dView> {
  InAppWebViewController? _web;
  bool _ready = false;
  String? _sent;
  Timer? _debounce;
  String _view = 'iso';
  bool _cones = true;
  bool _roof = true;
  bool _ortho = false;
  String? _status;

  @override
  void didUpdateWidget(Plan3dView old) {
    super.didUpdateWidget(old);
    _schedule();
    if (old.selected != widget.selected) _pushSelection();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// La planta cambia a menudo mientras se arrastra: se manda al 3D como
  /// mucho cada 150 ms y solo si ha cambiado.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _push);
  }

  Future<void> _push() async {
    final web = _web;
    if (!_ready || web == null || !mounted) return;
    final json = jsonEncode(
      PlanScene3d.build(
        widget.elements,
        metersPerUnit: widget.metersPerUnit,
        name: widget.name,
      ),
    );
    if (json == _sent) return;
    _sent = json;
    await web.evaluateJavascript(source: 'iris.load($json);');
    await _pushSelection();
  }

  Future<void> _pushSelection() async {
    final web = _web;
    if (!_ready || web == null) return;
    final index = widget.selected == null
        ? -1
        : widget.elements.indexOf(widget.selected!);
    final id = index < 0
        ? null
        : PlanScene3d.idOf(widget.elements[index], index);
    await web.evaluateJavascript(source: 'iris.select(${jsonEncode(id)});');
  }

  Future<void> _call(String js) async => _web?.evaluateJavascript(source: js);

  dynamic _onMessage(List<dynamic> args) {
    final message = args.isEmpty ? null : args.first;
    if (message is! Map) return null;
    switch (message['type']) {
      case 'ready':
        _ready = true;
        _sent = null;
        final bg = context.palette.background;
        final hex = (bg.toARGB32() & 0xFFFFFF)
            .toRadixString(16)
            .padLeft(6, '0');
        _call(
          'iris.set(${jsonEncode({'bg': '#$hex', 'cones': _cones, 'roof': _roof, 'ortho': _ortho})});',
        );
        _push();
      case 'select':
        final id = message['id'];
        PlanElement? hit;
        for (final (i, el) in widget.elements.indexed) {
          if (PlanScene3d.idOf(el, i) == id) hit = el;
        }
        widget.onSelect?.call(hit);
      case 'view':
        if (mounted) setState(() => _view = message['view'] as String);
      case 'loaded':
        final lit = message['lit'], total = message['fixtures'];
        if (mounted && total is num && lit is num) {
          setState(
            () => _status = total > lit
                ? '$lit de $total focos con luz real'
                : null,
          );
        }
    }
    return null;
  }

  /// Guarda lo que se ve en un glTF binario, para Unreal o cualquier
  /// programa 3D.
  Future<void> _exportGlb() async {
    final web = _web;
    if (web == null || !_ready) return;
    final result = await web.callAsyncJavaScript(
      functionBody: 'return await iris.exportGlb();',
    );
    final b64 = result?.value;
    if (b64 is! String || b64.isEmpty) return;
    final bytes = base64Decode(b64);
    final name =
        '${(widget.name ?? 'planta').replaceAll(RegExp(r'[^\w\- ]'), '')}.glb';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportar el 3D',
      fileName: name,
      bytes: bytes,
    );
    // En el Mac el diálogo solo da la ruta: el archivo se escribe aquí.
    if (path != null && !Platform.isIOS && !Platform.isAndroid) {
      await File(path).writeAsBytes(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bar = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 'top', label: Text('Arriba')),
              ButtonSegment(value: 'front', label: Text('Frente')),
              ButtonSegment(value: 'right', label: Text('Lado')),
              ButtonSegment(value: 'iso', label: Text('Iso')),
            ],
            selected: {
              const ['top', 'front', 'right', 'iso'].contains(_view)
                  ? _view
                  : 'iso',
            },
            onSelectionChanged: (v) {
              setState(() => _view = v.first);
              _call('iris.view(${jsonEncode(v.first)});');
            },
          ),
          const Spacer(),
          _Toggle(
            icon: Icons.flashlight_on_outlined,
            tooltip: 'Conos de luz',
            on: _cones,
            onChanged: (v) {
              setState(() => _cones = v);
              _call('iris.set({cones: $v});');
            },
          ),
          _Toggle(
            icon: Icons.roofing_outlined,
            tooltip: 'Cubierta',
            on: _roof,
            onChanged: (v) {
              setState(() => _roof = v);
              _call('iris.set({roof: $v});');
            },
          ),
          _Toggle(
            icon: Icons.grid_view_outlined,
            tooltip: 'Vista ortográfica (sin perspectiva)',
            on: _ortho,
            onChanged: (v) {
              setState(() => _ortho = v);
              _call('iris.set({ortho: $v});');
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Exportar',
            icon: Icon(Icons.ios_share, size: 18, color: palette.textSecondary),
            onSelected: (_) => _exportGlb(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'glb',
                child: Text('glTF (.glb) para Unreal y programas 3D'),
              ),
            ],
          ),
          if (widget.onClose != null)
            IconButton(
              tooltip: 'Cerrar el 3D',
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
    return Material(
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Divider(height: 1, color: palette.divider),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialFile: Plan3dView.asset,
                  initialSettings: InAppWebViewSettings(
                    isInspectable: kDebugMode,
                    transparentBackground: false,
                    disableContextMenu: true,
                    supportZoom: false,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                  ),
                  onWebViewCreated: (controller) {
                    _web = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'iris',
                      callback: _onMessage,
                    );
                  },
                ),
                if (_status != null)
                  Positioned(
                    left: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Text(
                      _status!,
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool on;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.icon,
    required this.tooltip,
    required this.on,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      tooltip: tooltip,
      isSelected: on,
      icon: Icon(
        icon,
        size: 18,
        color: on ? palette.accent : palette.textTertiary,
      ),
      onPressed: () => onChanged(!on),
    );
  }
}

/// El 3D a pantalla entera: la pestaña propia del iPad.
class Plan3dScreen extends StatelessWidget {
  final List<PlanElement> elements;
  final double metersPerUnit;
  final String? name;
  final PlanElement? selected;
  final ValueChanged<PlanElement?>? onSelect;

  const Plan3dScreen({
    super.key,
    required this.elements,
    required this.metersPerUnit,
    this.name,
    this.selected,
    this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PlanElement> elements,
    required double metersPerUnit,
    String? name,
    PlanElement? selected,
    ValueChanged<PlanElement?>? onSelect,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Plan3dScreen(
        elements: elements,
        metersPerUnit: metersPerUnit,
        name: name,
        selected: selected,
        onSelect: onSelect,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(name == null ? '3D' : '3D · $name')),
    body: Plan3dView(
      elements: elements,
      metersPerUnit: metersPerUnit,
      name: name,
      selected: selected,
      onSelect: onSelect,
    ),
  );
}
