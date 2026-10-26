import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../onboarding/tutorial_shell.dart';
import 'unreal_link.dart';
import 'unreal_stage_card.dart';
import 'unreal_stage_launcher.dart';

/// Tutorial «IRIS con Unreal». Lo que se puede hacer desde la app se hace
/// aquí mismo: el paso central es el botón «Abrir en Unreal», que crea,
/// prepara, abre y conecta.
class UnrealTutorialScreen extends StatefulWidget {
  final UnrealLink link;

  /// Proyecto de IRIS cuyo proyecto de Unreal se abre; sin él (desde
  /// Ajustes), uno general de IRIS.
  final int? projectId;
  final String projectName;

  const UnrealTutorialScreen({
    super.key,
    required this.link,
    this.projectId,
    this.projectName = 'Stage',
  });

  static Future<void> open(
    BuildContext context, {
    UnrealLink? link,
    int? projectId,
    String? projectName,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UnrealTutorialScreen(
        link: link ?? UnrealLink.instance,
        projectId: projectId,
        projectName: projectName ?? 'Stage',
      ),
    ),
  );

  @override
  State<UnrealTutorialScreen> createState() => _UnrealTutorialScreenState();
}

class _UnrealTutorialScreenState extends State<UnrealTutorialScreen> {
  int _step = 0;
  static const _total = 5;

  bool? _streamOk;
  bool _streamBusy = false;

  @override
  void initState() {
    super.initState();
    widget.link.loadPrefs();
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
      1 => ('Abrir en Unreal', _stage()),
      2 => ('Render RTX', _render()),
      3 => ('Cómo se trabaja', _howTo()),
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

  Widget _bullet(String text) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: palette.accent),
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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.bodyMedium(palette).copyWith(
          color: error
              ? palette.error
              : ok
              ? palette.success
              : palette.textSecondary,
        ),
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
      'Solo necesitas:',
    ],
    bullets: const [
      'Unreal Engine 5.5 instalado en el PC (Epic Games Launcher → Unreal '
          'Engine → Biblioteca → +).',
      'Nada más: IRIS crea y prepara el proyecto de Unreal.',
      'Para usarlo desde el Mac o el iPad: estar en la misma red que el PC.',
    ],
  );

  Widget _stage() => _page(
    icon: Icons.rocket_launch_outlined,
    title: 'Abrir en Unreal',
    paragraphs: [
      UnrealStageLauncher.supported
          ? 'Pulsa el botón. La primera vez IRIS crea el proyecto de Unreal '
                'en Documentos\\Unreal Projects y Unreal prepara la calidad '
                'RTX: puede tardar varios minutos. Las siguientes, poco.'
          : 'En el PC, pulsa «Abrir en Unreal» en IRIS Stage. Aquí conéctate '
                'a él con su dirección en la red.',
      'Este mismo botón está siempre en IRIS Stage (menú del proyecto).',
    ],
    children: [
      UnrealStageCard(
        projectId: widget.projectId,
        projectName: widget.projectName,
      ),
    ],
  );

  Widget _render() => _page(
    icon: Icons.live_tv_outlined,
    title: 'Ver Unreal dentro de IRIS',
    paragraphs: const [
      'Render RTX enseña dentro de IRIS la imagen de Unreal, con Lumen y el '
          'trazado de rayos de la tarjeta.',
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
        label: const Text('Probar Render RTX'),
        onPressed: _streamBusy ? null : _testStream,
      ),
      if (_streamOk == true)
        _note('Funciona: ya puedes ver Unreal dentro de IRIS.', ok: true),
      if (_streamOk == false)
        _note(
          'Todavía no responde. Abre Unreal con el botón del paso anterior '
          'y espera a que termine de abrirse.',
          error: true,
        ),
    ],
  );

  Widget _howTo() => _page(
    icon: Icons.school_outlined,
    title: 'Cómo se trabaja',
    paragraphs: const [
      'Abre la planta de cámara y luz con el 3D. Si Unreal está conectado:',
    ],
    bullets: const [
      'Lo que cambias en la planta (luces, regulación, color, cámaras, '
          'atrezzo, sol) llega a Unreal al momento.',
      'Lo que mueves, giras, regulas o cambias de color en Unreal vuelve a la '
          'planta y se guarda.',
      'Cada set de rodaje es un mundo propio en Unreal. Al abrir la planta '
          'de otro set, Unreal cambia de mundo solo.',
      'Icono de la tele (Render RTX): la imagen de Unreal, también «por la '
          'cámara» de un plano.',
      'En la planta de un plano: Render RTX → Capturar con RTX guarda la '
          'imagen en su storyboard.',
      'Atrezzo con modelos de Fab o Megascans: añádelos en Unreal (Window → '
          'Fab) y, en el 3D de IRIS, selecciona la pieza → Elegir asset de '
          'Unreal.',
    ],
  );

  Widget _trouble() => _page(
    icon: Icons.help_outline,
    title: 'Si algo falla',
    paragraphs: const [],
    bullets: const [
      '«No encuentro Unreal»: instala Unreal Engine 5.5 desde el Epic Games '
          'Launcher y vuelve a pulsar «Abrir en Unreal».',
      'Unreal tarda mucho la primera vez: es normal, prepara la calidad RTX. '
          'Cuando su ventana esté lista, pulsa «Abrir en Unreal» otra vez.',
      'Desde el Mac o el iPad no conecta: misma red que el PC, y en Windows '
          'permite a Unreal en el cortafuegos la primera vez que lo pregunte.',
      '«El nivel abierto tiene cambios sin guardar»: guarda tu nivel en '
          'Unreal; IRIS no cierra lo tuyo.',
      'La imagen se ve muy oscura o quemada: es la exposición automática de '
          'Unreal con luz real; prueba la escena de día o con más luces.',
    ],
  );
}
