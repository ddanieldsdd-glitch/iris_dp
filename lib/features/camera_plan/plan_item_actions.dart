import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_scope.dart';
import 'light_setup_actions.dart';
import 'plan_trash_ui.dart';
import '../../core/utils/platform_keys.dart';

/// Qué hay copiado en la pantalla de plantas: un esquema de luz o un set.
enum PlanClipKind { setup, set }

class PlanClip {
  final PlanClipKind kind;
  final int id;
  final String name;

  const PlanClip.setup(this.id, this.name) : kind = PlanClipKind.setup;
  const PlanClip.set(this.id, this.name) : kind = PlanClipKind.set;

  /// «el esquema «Setup A»» / «el set «Cocina»».
  String get label =>
      '${kind == PlanClipKind.setup ? 'el esquema' : 'el set'} «$name»';
}

/// Portapapeles de esquemas y sets. Vive mientras la app esté abierta, y
/// sirve para pegar en otra escena, set o localización.
abstract final class PlanBoardClipboard {
  static final current = ValueNotifier<PlanClip?>(null);

  static void copy(BuildContext context, PlanClip clip) {
    current.value = clip;
    _tell(context, 'Copiado ${clip.label}. Pégalo con ${modKey}V donde quieras.');
  }
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Dónde se pega lo copiado.
class PlanPasteTarget {
  /// Set al que va un esquema.
  final int? setId;

  /// Localización: recibe un set, o un esquema como luz general.
  final int? siteId;

  const PlanPasteTarget({this.setId, this.siteId});

  /// Plantas libres: solo esquemas.
  const PlanPasteTarget.free() : setId = null, siteId = null;

  bool accepts(PlanClip? clip) => switch (clip?.kind) {
    null => false,
    PlanClipKind.setup => true,
    PlanClipKind.set => setId == null && siteId != null,
  };
}

/// Pega lo copiado en [target]. Devuelve el nombre de lo creado, o `null`
/// si no había nada que pegar ahí.
Future<String?> pastePlanClip(
  BuildContext context,
  AppDatabase db,
  PlanPasteTarget target,
) async {
  final clip = PlanBoardClipboard.current.value;
  if (!target.accepts(clip)) return null;
  final repo = FloorPlanRepository(db);
  String? created;
  switch (clip!.kind) {
    case PlanClipKind.setup:
      final source = await db.getLightSetupById(clip.id);
      if (source != null) {
        created = (await repo.copyLightSetup(
          source,
          setId: target.setId,
          siteId: target.siteId,
        )).name;
      }
    case PlanClipKind.set:
      final source = await db.getLocationById(clip.id);
      if (source != null) {
        created = (await repo.copySet(
          source,
          siteId: target.siteId,
          keepSite: false,
        )).locationName;
      }
  }
  if (!context.mounted) return created;
  _tell(
    context,
    created == null
        ? 'Lo copiado ya no existe: ${clip.label} se ha borrado.'
        : 'Pegado «$created».',
  );
  return created;
}

/// Atajos sobre un esquema o un set con el ratón encima: ⌘C copia, ⌘D
/// duplica, ⌘V pega en él y Supr lo borra (pidiendo confirmación).
class PlanItemKeys extends StatefulWidget {
  final VoidCallback? onCopy;
  final VoidCallback? onDuplicate;
  final VoidCallback? onPaste;
  final VoidCallback? onDelete;
  final Widget child;

  const PlanItemKeys({
    super.key,
    this.onCopy,
    this.onDuplicate,
    this.onPaste,
    this.onDelete,
    required this.child,
  });

  @override
  State<PlanItemKeys> createState() => _PlanItemKeysState();
}

class _PlanItemKeysState extends State<PlanItemKeys> {
  final _focus = FocusNode(debugLabel: 'esquema o set');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void run(VoidCallback? action) => action?.call();
    return CallbackShortcuts(
      bindings: {
        for (final meta in [true, false]) ...{
          SingleActivator(
            LogicalKeyboardKey.keyC,
            meta: meta,
            control: !meta,
          ): () =>
              run(widget.onCopy),
          SingleActivator(
            LogicalKeyboardKey.keyD,
            meta: meta,
            control: !meta,
          ): () =>
              run(widget.onDuplicate),
          SingleActivator(
            LogicalKeyboardKey.keyV,
            meta: meta,
            control: !meta,
          ): () =>
              run(widget.onPaste),
        },
        const SingleActivator(LogicalKeyboardKey.delete): () =>
            run(widget.onDelete),
        const SingleActivator(LogicalKeyboardKey.backspace): () =>
            run(widget.onDelete),
      },
      child: Focus(
        focusNode: _focus,
        child: MouseRegion(
          // Con el ratón encima coge el foco (salvo que se esté escribiendo):
          // los atajos van a lo que está debajo del ratón.
          onEnter: (_) {
            final focused = FocusManager.instance.primaryFocus?.context?.widget;
            if (focused is! EditableText) _focus.requestFocus();
          },
          onExit: (_) {
            if (_focus.hasPrimaryFocus) _focus.unfocus();
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Esquema de luz: copiar, duplicar y borrar, para menús y atajos.
class LightSetupActions {
  final BuildContext context;
  final AppDatabase db;
  final LightSetup setup;
  final int shotCount;

  const LightSetupActions(this.context, this.db, this.setup, this.shotCount);

  void copy() =>
      PlanBoardClipboard.copy(context, PlanClip.setup(setup.id, setup.name));

  Future<void> duplicate() async {
    final copy = await FloorPlanRepository(db).duplicateLightSetup(setup);
    if (context.mounted) _tell(context, 'Duplicado como «${copy.name}».');
  }

  /// Pega en el set (o la localización) de este esquema.
  Future<void> pasteBeside() => pastePlanClip(
    context,
    db,
    PlanPasteTarget(
      setId: setup.locationBasePlanId,
      siteId: setup.locationSiteId,
    ),
  );

  Future<void> delete() async {
    final ok = await confirmPlanDelete(
      context,
      title: '¿Borrar el esquema «${setup.name}»?',
      body: shotCount == 0
          ? 'Se borra el esquema de luz con su planta.'
          : 'Se borra el esquema de luz con su planta. '
                '$shotCount plano${shotCount == 1 ? '' : 's'} '
                'se quedará${shotCount == 1 ? '' : 'n'} sin luz, con sus '
                'cámaras. Podrás recuperarlo desde la Papelera de plantas.',
    );
    if (!ok || !context.mounted) return;
    await deleteWithUndo(
      context,
      db,
      done: 'Esquema «${setup.name}» borrado.',
      delete: (trash) => trash.deleteLightSetup(setup.id),
    );
  }

  /// Quita luces, grip y ambiente para empezar el esquema de cero.
  Future<void> clear() => confirmClearPlan(
    context,
    db,
    scope: FloorPlanScope.lightSetup,
    id: setup.id,
    name: setup.name,
  );
}

/// Pide confirmación para borrar.
Future<bool> confirmPlanDelete(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final palette = context.palette;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(title, style: AppTypography.titleMedium(palette)),
      content: Text(body, style: AppTypography.bodyMedium(palette)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Borrar', style: TextStyle(color: palette.error)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Set: renombrar, copiar, duplicar, pegar un esquema en él y borrarlo.
class SetActions {
  final BuildContext context;
  final AppDatabase db;
  final LocationBasePlan set;

  /// Escenas y esquemas del set, para avisar al borrar.
  final int sceneCount;
  final int setupCount;

  const SetActions(
    this.context,
    this.db,
    this.set, {
    this.sceneCount = 0,
    this.setupCount = 0,
  });

  void copy() =>
      PlanBoardClipboard.copy(context, PlanClip.set(set.id, set.locationName));

  Future<void> duplicate() async {
    final copy = await FloorPlanRepository(db).copySet(set);
    if (context.mounted) {
      _tell(
        context,
        'Duplicado como «${copy.locationName}», con su planta y sus '
        'esquemas.',
      );
    }
  }

  /// Un esquema copiado entra en este set; un set copiado, en su
  /// localización.
  Future<void> paste() {
    final clip = PlanBoardClipboard.current.value;
    return pastePlanClip(
      context,
      db,
      clip?.kind == PlanClipKind.set
          ? PlanPasteTarget(siteId: set.siteId)
          : PlanPasteTarget(setId: set.id),
    );
  }

  Future<void> rename() async {
    final name = await askPlanName(
      context,
      title: 'Nombre del set',
      initial: set.locationName,
    );
    if (name != null) await db.updateLocation(set.copyWith(locationName: name));
  }

  /// Borra el set con sus esquemas; sus planos pierden la planta. Se puede
  /// deshacer y queda en la Papelera de plantas.
  Future<void> delete() => confirmDeleteSet(context, db, set);

  /// Vacía la planta del set para empezarla de cero.
  Future<void> clear() => confirmClearPlan(
    context,
    db,
    scope: FloorPlanScope.set,
    id: set.id,
    name: set.locationName,
  );
}

/// Menú «⋯» de un set.
class SetMenuButton extends ConsumerWidget {
  final LocationBasePlan set;
  final int sceneCount;
  final int setupCount;

  const SetMenuButton({
    super.key,
    required this.set,
    this.sceneCount = 0,
    this.setupCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return ValueListenableBuilder<PlanClip?>(
      valueListenable: PlanBoardClipboard.current,
      builder: (context, clip, _) => PopupMenuButton<String>(
        tooltip: 'Opciones del set',
        icon: Icon(Icons.more_horiz, color: palette.textSecondary),
        onSelected: (action) {
          final actions = SetActions(
            context,
            ref.read(databaseProvider),
            set,
            sceneCount: sceneCount,
            setupCount: setupCount,
          );
          switch (action) {
            case 'rename':
              actions.rename();
            case 'copy':
              actions.copy();
            case 'duplicate':
              actions.duplicate();
            case 'paste':
              actions.paste();
            case 'clear':
              actions.clear();
            case 'delete':
              actions.delete();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
          PopupMenuItem(
            value: 'copy',
            child: PlanMenuRow('Copiar set', '${modKey}C'),
          ),
          PopupMenuItem(
            value: 'duplicate',
            child: PlanMenuRow('Duplicar set', '${modKey}D'),
          ),
          if (clip != null)
            PopupMenuItem(
              value: 'paste',
              child: PlanMenuRow(
                clip.kind == PlanClipKind.setup
                    ? 'Pegar «${clip.name}» en este set'
                    : 'Pegar el set «${clip.name}»',
                '${modKey}V',
              ),
            ),
          const PopupMenuItem(value: 'clear', child: Text('Vaciar planta…')),
          PopupMenuItem(
            value: 'delete',
            child: Text('Borrar set…', style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
  }
}

/// Botón «Pegar …» que solo aparece cuando lo copiado cabe en [target].
class PlanPasteButton extends ConsumerWidget {
  final PlanPasteTarget target;

  const PlanPasteButton({super.key, required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<PlanClip?>(
      valueListenable: PlanBoardClipboard.current,
      builder: (context, clip, _) {
        if (!target.accepts(clip)) return const SizedBox.shrink();
        return TextButton.icon(
          icon: const Icon(Icons.content_paste, size: 15),
          label: Text('Pegar «${clip!.name}»'),
          onPressed: () =>
              pastePlanClip(context, ref.read(databaseProvider), target),
        );
      },
    );
  }
}

/// Texto de un menú con su atajo a la derecha.
class PlanMenuRow extends StatelessWidget {
  final String text;
  final String shortcut;

  const PlanMenuRow(this.text, this.shortcut, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(child: Text(text)),
        const SizedBox(width: 16),
        Text(
          shortcut,
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}
