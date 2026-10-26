import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/settings/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../onboarding/tutorial_shell.dart';
import 'unreal_link.dart';
import 'unreal_project_installer.dart';

/// Tutorial «IRIS con Unreal»: de un proyecto de Unreal cualquiera a ver y
/// mover el set en vivo desde IRIS. Los pasos que se pueden hacer desde la
/// app (preparar el proyecto, abrir Unreal, probar la conexión y Pixel
/// Streaming) se hacen aquí mismo.
class UnrealTutorialScreen extends StatefulWidget {
  final UnrealLink link;
  const UnrealTutorialScreen({super.key, required this.link});

  /// Proyecto de Unreal preparado la última vez.
  static const projectKey = PrefKey<String>('unrealLink.project', '');

  static Future<void> open(BuildContext context, {UnrealLink? link}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              UnrealTutorialScreen(link: link ?? UnrealLink.instance),
        ),
      );

  @override
  State<UnrealTutorialScreen> createState() => _UnrealTutorialScreenState();
}

class _UnrealTutorialScreenState extends State<UnrealTutorialScreen> {
  int _step = 0;
  static const _total = 7;

  // Paso 2: preparar el proyecto.
  UnrealInstallReport? _report;
  String? _installError;
  bool _installing = false;

  // Paso 4: conexión.
  late final _host = TextEditingController(text: widget.link.host);
  List<String> _myAddresses = const [];

  // Paso 5: Pixel Streaming.
  bool? _streamOk;
  bool _streamBusy = false;

  bool get _desktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    widget.link.loadPrefs();
    _host.text = widget.link.host;
    _loadAddresses();
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final list = await NetworkInterface.list(type: InternetAddressType.IPv4);
      if (!mounted) return;
      setState(() {
        _myAddresses = [
          for (final i in list)
            for (final a in i.addresses)
              if (!a.isLoopback) a.address,
        ];
      });
    } catch (_) {}
  }

  String get _savedProject =>
      AppPrefs.instance.get(UnrealTutorialScreen.projectKey);

  Future<void> _pickAndInstall() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Elige el proyecto de Unreal (.uproject)',
      type: FileType.custom,
      allowedExtensions: const ['uproject'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() {
      _installing = true;
      _installError = null;
    });
    try {
      final report = await UnrealProjectInstaller.install(path);
      await AppPrefs.instance.setIn(
        UnrealTutorialScreen.projectKey,
        const SettingsScope.global(),
        path,
      );
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) {
        setState(
          () => _installError = e is FormatException ? e.message : '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  /// El lanzador del proyecto preparado, si está en este equipo.
  String? get _launcher {
    final path = _report?.launcherPath;
    if (path != null) return path;
    final project = _savedProject;
    if (project.isEmpty) return null;
    final file = File(project);
    final name = file.uri.pathSegments.last.replaceAll('.uproject', '');
    final bat =
        '${file.parent.path}${Platform.pathSeparator}Abrir $name con IRIS Stage.bat';
    return File(bat).existsSync() ? bat : null;
  }

  Future<void> _openUnreal(String launcher) async {
    await Process.start('cmd.exe', [
      '/c',
      launcher,
    ], mode: ProcessStartMode.detached);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Abriendo Unreal. La primera vez puede tardar varios minutos.',
        ),
      ),
    );
  }

  Future<void> _testStream() async {
    setState(() {
      _streamBusy = true;
      _streamOk = null;
    });
    var ok = false;
    try {
      final r = await http
          .get(widget.link.streamUrl)
          .timeout(const Duration(seconds: 4));
      ok = r.statusCode == 200;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _streamOk = ok;
        _streamBusy = false;
      });
    }
  }

  void _next() {
    if (_step == _total - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (_step) {
      0 => ('IRIS y Unreal', _intro()),
      1 => ('Preparar el proyecto', _prepare()),
      2 => ('Abrir Unreal', _open()),
      3 => ('Conectar', _connect()),
      4 => ('Render RTX', _render()),
      5 => ('Cómo se trabaja', _howTo()),
      _ => ('Si algo falla', _trouble()),
    };
    return Stack(
      children: [
        TutorialShell(
          stepIndex: _step,
          totalSteps: _total,
          title: title,
          body: body,
          onBack: _step == 0 ? null : () => setState(() => _step--),
          onNext: _next,
          nextLabel: _step == _total - 1 ? 'Terminar' : 'Siguiente',
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top,
          right: 0,
          child: IconButton(
            tooltip: 'Cerrar el tutorial',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  // ── Piezas comunes ───────────────────────────────────────────────────────

  Widget _page({
    required IconData icon,
    required String title,
    required List<String> paragraphs,
    List<String> bullets = const [],
    List<Widget> children = const [],
  }) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 48, color: palette.accent),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: AppTypography.titleLarge(palette)),
        const SizedBox(height: AppSpacing.md),
        for (final p in paragraphs) ...[
          Text(
            p,
            style: AppTypography.bodyMedium(
              palette,
            ).copyWith(color: palette.textSecondary, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final b in bullets) _bullet(b),
        if (children.isNotEmpty) const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    );
  }

  Widget _bullet(String text, {IconData? icon, Color? color}) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.check_circle_outline,
            size: 18,
            color: color ?? palette.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppTypography.bodyMedium(palette)),
          ),
        ],
      ),
    );
  }

  Widget _note(String text, {bool error = false, bool ok = false}) {
    final palette = context.palette;
    final color = error
        ? palette.error
        : ok
        ? palette.success
        : palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.bodyMedium(palette).copyWith(color: color),
      ),
    );
  }

  // ── Pasos ───────────────────────────────────────────────────────────────

  Widget _intro() => _page(
    icon: Icons.view_in_ar_outlined,
    title: 'IRIS y Unreal, juntos',
    paragraphs: const [
      'Con IRIS Stage, la planta de cámara y luz de IRIS y Unreal trabajan '
          'en vivo: lo que cambias en uno aparece en el otro, y la imagen de '
          'Unreal, con la calidad de la tarjeta RTX, se ve dentro de IRIS.',
      'Lo que necesitas:',
    ],
    bullets: const [
      'Un PC con Unreal Engine 5.5 (del Epic Games Launcher) y tarjeta NVIDIA.',
      'Un proyecto de Unreal: uno vacío vale (Games → Blank).',
      'IRIS en el mismo PC o en otro equipo de la misma red (Mac o iPad).',
      'Unos 10 minutos la primera vez.',
    ],
  );

  Widget _prepare() {
    final palette = context.palette;
    final report = _report;
    return _page(
      icon: Icons.build_circle_outlined,
      title: 'Preparar el proyecto de Unreal',
      paragraphs: [
        'IRIS deja el proyecto listo en un paso:',
      ],
      bullets: const [
        'Activa los plugins Python, Remote Control, Editor Scripting y Pixel '
            'Streaming 2.',
        'Copia IRIS Stage Link en Content/Python.',
        'Activa Lumen con trazado de rayos por hardware.',
        'Crea junto al proyecto el lanzador «Abrir … con IRIS Stage».',
      ],
      children: [
        Text(
          'No borra nada: guarda una copia (.antes-de-iris) de cada archivo '
          'que cambia. Cierra Unreal antes de seguir.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_desktop)
          FilledButton.icon(
            icon: _installing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_outlined),
            label: Text(
              report == null
                  ? 'Elegir el proyecto (.uproject)…'
                  : 'Preparar otro proyecto…',
            ),
            onPressed: _installing ? null : _pickAndInstall,
          )
        else
          _note(
            'Hazlo desde IRIS en el PC que tiene Unreal (Ajustes → IRIS con '
            'Unreal). Desde aquí solo te conectarás a él.',
          ),
        if (_installError != null) _note(_installError!, error: true),
        if (report != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Proyecto «${report.projectName}»',
            style: AppTypography.titleMedium(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final l in report.lines)
            _bullet(
              l.text,
              icon: l.warning
                  ? Icons.warning_amber
                  : l.changed
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
              color: l.warning ? palette.warning : palette.success,
            ),
        ] else if (_savedProject.isNotEmpty)
          _note('Último proyecto preparado: $_savedProject'),
      ],
    );
  }

  Widget _open() {
    final launcher = _launcher;
    return _page(
      icon: Icons.play_circle_outline,
      title: 'Abrir Unreal con IRIS Stage',
      paragraphs: const [
        'Abre el proyecto siempre con su lanzador «Abrir … con IRIS Stage» '
            '(junto al .uproject): así Pixel Streaming empieza a emitir la '
            'imagen para IRIS.',
        'La primera vez Unreal compila sombreadores para el trazado de '
            'rayos: puede tardar varios minutos.',
      ],
      bullets: const [
        'En Unreal, abre Window → Output Log.',
        'Debe salir «[IRIS Stage] Link v1 listo». Si sale, sigue.',
        'Si abriste el proyecto de otra forma: botón Pixel Streaming de la '
            'barra → Stream Level Editor.',
      ],
      children: [
        if (launcher != null && Platform.isWindows)
          FilledButton.icon(
            icon: const Icon(Icons.rocket_launch_outlined),
            label: const Text('Abrir Unreal ahora'),
            onPressed: () => _openUnreal(launcher),
          ),
      ],
    );
  }

  Widget _connect() {
    final link = widget.link;
    return ListenableBuilder(
      listenable: link,
      builder: (context, _) => _page(
        icon: Icons.cast_connected_outlined,
        title: 'Conectar IRIS con Unreal',
        paragraphs: [
          'Escribe el equipo donde está Unreal: 127.0.0.1 si es este mismo. '
              'Desde el Mac o el iPad, la dirección del PC en la red.',
          if (_myAddresses.isNotEmpty)
            'Este equipo es: ${_myAddresses.join(', ')}.',
        ],
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _host,
                  enabled: !link.isOn,
                  decoration: const InputDecoration(
                    labelText: 'Equipo con Unreal',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (link.isOn)
                OutlinedButton(
                  onPressed: link.disconnect,
                  child: const Text('Desconectar'),
                )
              else
                FilledButton(
                  onPressed: link.state == UnrealLinkState.connecting
                      ? null
                      : () => link.connect(host: _host.text),
                  child: const Text('Probar conexión'),
                ),
            ],
          ),
          if (link.isOn)
            _note(
              'Conectado con Unreal ${link.engine?.split('-').first ?? ''}. '
              'Ya puedes seguir.',
              ok: true,
            ),
          if (link.state == UnrealLinkState.error && link.error != null)
            _note(link.error!, error: true),
          const SizedBox(height: AppSpacing.md),
          _bullet(
            'Desde ahora, el botón de Unreal de la barra del 3D de la planta '
            'conecta con este mismo equipo.',
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }

  Widget _render() => _page(
    icon: Icons.live_tv_outlined,
    title: 'Ver Unreal dentro de IRIS',
    paragraphs: const [
      'Render RTX enseña dentro de IRIS la imagen de Unreal, con Lumen y el '
          'trazado de rayos de la tarjeta, por Pixel Streaming (puerto 80).',
    ],
    children: [
      FilledButton.icon(
        icon: _streamBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.network_check),
        label: const Text('Probar Pixel Streaming'),
        onPressed: _streamBusy ? null : _testStream,
      ),
      if (_streamOk == true)
        _note('Pixel Streaming responde. Render RTX funcionará.', ok: true),
      if (_streamOk == false)
        _note(
          'No responde en ${widget.link.streamUrl.host}:'
          '${widget.link.viewerPort}. Abre Unreal con el lanzador, o en '
          'Unreal pulsa Pixel Streaming → Stream Level Editor.',
          error: true,
        ),
    ],
  );

  Widget _howTo() => _page(
    icon: Icons.school_outlined,
    title: 'Cómo se trabaja',
    paragraphs: const [
      'Todo empieza en la planta de cámara y luz, con el 3D abierto y el '
          'botón de Unreal conectado:',
    ],
    bullets: const [
      'Lo que cambias en la planta (luces, regulación, color, cámaras, '
          'atrezzo, sol) llega a Unreal al momento.',
      'Lo que mueves, giras, regulas o cambias de color en Unreal vuelve a la '
          'planta y se guarda.',
      'Cada set de rodaje es un mundo propio en Unreal '
          '(/Game/IRIS/<localización>/<set>). Al abrir la planta de otro set, '
          'Unreal cambia de mundo solo.',
      'Icono de la tele (Render RTX): la imagen de Unreal, también «por la '
          'cámara» de un plano.',
      'En la planta de un plano, Render RTX → Capturar con RTX guarda la '
          'imagen en su storyboard.',
      'Atrezzo con modelos de Fab o Megascans: añádelos en Unreal y, en el '
          '3D de IRIS a pantalla entera, selecciona la pieza → Elegir asset '
          'de Unreal. En IRIS queda la pieza con sus medidas.',
    ],
  );

  Widget _trouble() => _page(
    icon: Icons.help_outline,
    title: 'Si algo falla',
    paragraphs: const [],
    bullets: const [
      '«Unreal no contesta»: Unreal está cerrado, o falta el plugin Remote '
          'Control (repite «Preparar el proyecto»).',
      '«No tiene IRIS Stage Link»: falta Content/Python en el proyecto, o '
          'Unreal estaba abierto al prepararlo. Ciérralo y vuelve a abrirlo.',
      'Desde el Mac o el iPad no conecta: mismo wifi que el PC, y en Windows '
          'permite a Unreal en el cortafuegos la primera vez que lo pregunte.',
      'Render RTX en negro o «no responde»: Unreal no se abrió con el '
          'lanzador. Pixel Streaming → Stream Level Editor.',
      '«El nivel abierto tiene cambios sin guardar»: guarda tu nivel en '
          'Unreal; IRIS no cierra lo tuyo.',
      'La imagen se ve muy oscura o quemada: es la exposición automática de '
          'Unreal con luz real; prueba la escena de día o con más luces.',
    ],
  );
}
