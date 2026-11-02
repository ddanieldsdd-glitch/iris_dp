import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'scan_builder.dart';

/// «Crear escaneo desde fotos o vídeo» (F6.20 E1–E2), solo en el PC: elige
/// la carpeta o el vídeo, lanza [ScanBuildJob] y devuelve el resultado para
/// ponerlo en la planta.
class ScanBuilderSheet extends StatefulWidget {
  const ScanBuilderSheet({super.key});

  static bool get supported => Platform.isWindows;

  static Future<ScanBuildResult?> show(BuildContext context) =>
      showDialog<ScanBuildResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          insetPadding: EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(width: 560, child: ScanBuilderSheet()),
        ),
      );

  @override
  State<ScanBuilderSheet> createState() => _ScanBuilderSheetState();
}

class _ScanBuilderSheetState extends State<ScanBuilderSheet> {
  final _realityScan = RealityScanInstall.find();
  final _ffmpeg = findFfmpeg();
  final _name = TextEditingController();
  String? _source;
  ScanBuildJob? _job;
  ScanBuildProgress? _progress;
  StreamSubscription<ScanBuildProgress>? _sub;
  final _clock = Stopwatch();
  Timer? _tick;

  bool get _running =>
      _job != null &&
      _progress?.stage != ScanBuildStage.done &&
      _progress?.stage != ScanBuildStage.error;

  @override
  void dispose() {
    _sub?.cancel();
    _job?.cancel();
    _tick?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _setSource(String? path) {
    if (path == null) return;
    setState(() {
      _source = path;
      if (_name.text.isEmpty) {
        _name.text = p.basenameWithoutExtension(path);
      }
    });
  }

  Future<void> _pickFolder() async => _setSource(
    await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Carpeta con las fotos de la localización',
    ),
  );

  Future<void> _pickVideo() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Vídeo de la localización',
      type: FileType.custom,
      allowedExtensions: scanVideoFormats,
    );
    _setSource(picked?.files.single.path);
  }

  void _start() {
    final rs = _realityScan, source = _source;
    if (rs == null || source == null) return;
    final job = ScanBuildJob(
      source: source,
      name: _name.text,
      realityScan: rs,
      ffmpeg: _ffmpeg,
    );
    _clock
      ..reset()
      ..start();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
    setState(() {
      _job = job;
      _progress = null;
    });
    _sub = job.run().listen(
      (e) => setState(() => _progress = e),
      onDone: () {
        _clock.stop();
        _tick?.cancel();
        if (mounted) setState(() {});
      },
    );
  }

  void _cancel() {
    _job?.cancel();
    _sub?.cancel();
    _clock.stop();
    _tick?.cancel();
    setState(() {
      _job = null;
      _progress = null;
    });
  }

  String get _elapsed {
    final d = _clock.elapsed;
    final m = d.inMinutes, s = d.inSeconds % 60;
    return d.inHours > 0
        ? '${d.inHours} h ${m % 60} min'
        : '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.caption(
      palette,
    ).copyWith(color: palette.textTertiary);
    final progress = _progress;
    final result = progress?.result;
    final rs = _realityScan;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crear escaneo desde fotos o vídeo',
            style: AppTypography.titleMedium(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            rs == null
                ? 'No encuentro RealityScan en este PC. Instálalo desde el '
                      'Epic Games Launcher (es gratis) y vuelve a abrir esto.'
                : 'Con ${rs.name}, sin abrir su ventana. Salen dos mallas: '
                      'una ligera para la planta y el 3D, y otra con todo el '
                      'detalle para Unreal.',
            style: AppTypography.bodyMedium(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_job == null) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Carpeta de fotos'),
                  onPressed: _pickFolder,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.videocam_outlined, size: 16),
                  label: const Text('Vídeo'),
                  onPressed: _pickVideo,
                ),
              ],
            ),
            if (_source case final source?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(source, style: AppTypography.mono(palette)),
              if (FileSystemEntity.isFileSync(source) && _ffmpeg == null)
                Text(
                  'Para un vídeo hace falta ffmpeg: «winget install ffmpeg» '
                  'en una terminal y vuelve a abrir IRIS.',
                  style: caption.copyWith(color: palette.warning),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Para el mejor resultado: exposición, balance y foco en manual; '
              'luz plana (nublado o todo encendido, sin sol directo); solape '
              'del 70–80 % en anillos a dos o tres alturas; y dos dianas o '
              'una medida conocida por sala para la escala. Si es vídeo: 4K, '
              'obturación de 1/250 o más rápida y movimiento lento.',
              style: caption,
            ),
          ] else ...[
            Text(
              progress?.message ?? 'Empezando…',
              style: AppTypography.bodyMedium(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_running) LinearProgressIndicator(value: progress?.fraction),
            const SizedBox(height: AppSpacing.xs),
            Text(_elapsed, style: AppTypography.mono(palette)),
            if (result != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${result.images} imágenes'
                '${result.discarded > 0 ? ', ${result.discarded} movidas descartadas' : ''}. '
                'La malla para Unreal está en ${result.folder}.',
                style: caption,
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _running
                    ? _cancel
                    : () => Navigator.of(context).pop(),
                child: Text(_running ? 'Cancelar' : 'Cerrar'),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (result != null)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(result),
                  child: const Text('Poner en la planta'),
                )
              else if (_job == null)
                FilledButton(
                  onPressed: rs != null && _source != null ? _start : null,
                  child: const Text('Crear escaneo'),
                )
              else if (progress?.stage == ScanBuildStage.error)
                FilledButton(
                  onPressed: () => setState(() {
                    _job = null;
                    _progress = null;
                  }),
                  child: const Text('Volver'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
