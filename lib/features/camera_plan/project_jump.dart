import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'plan_data.dart';
import 'plan_target.dart';

/// Un sitio del proyecto al que saltar.
class ProjectJumpHit {
  final String title;
  final String subtitle;
  final IconData icon;
  final PlanTarget target;

  const ProjectJumpHit({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.target,
  });
}

const _maxHits = 60;

String _fold(String text) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final at = from.indexOf(char);
    out.write(at < 0 ? char : to[at]);
  }
  return out.toString();
}

/// Planos, escenas, sets y localizaciones que encajan con [query], primero
/// los que empiezan por lo escrito.
List<ProjectJumpHit> projectJumpHits(PlanProjectData data, String query) {
  final all = <ProjectJumpHit>[
    for (final scene in data.scenes)
      for (final shot in data.shotsOfScene(scene.id))
        ProjectJumpHit(
          title: data.shotLabel(shot),
          subtitle: scene.name,
          icon: Icons.videocam_outlined,
          target: PlanTarget.shot(shot.id, data.shotLabel(shot)),
        ),
    for (final scene in data.scenes)
      if (data.shotsOfScene(scene.id).isNotEmpty)
        ProjectJumpHit(
          title: 'Escena ${scene.number}${scene.numberSuffix ?? ''}',
          subtitle: scene.name,
          icon: Icons.movie_outlined,
          target: () {
            final first = data.shotsOfScene(scene.id).first;
            return PlanTarget.shot(first.id, data.shotLabel(first));
          }(),
        ),
    for (final setup in data.planSetups)
      ProjectJumpHit(
        title: setup.name,
        subtitle: 'Set',
        icon: Icons.light_mode_outlined,
        target: PlanTarget.lightSetup(setup.id, setup.name),
      ),
    for (final zone in data.sets)
      ProjectJumpHit(
        title: zone.locationName,
        subtitle: 'Zona',
        icon: Icons.crop_square,
        target: PlanTarget.set(zone.id, zone.locationName),
      ),
    for (final site in data.sites)
      ProjectJumpHit(
        title: site.name,
        subtitle: 'Localización',
        icon: Icons.place_outlined,
        target: PlanTarget.site(site.id, site.name),
      ),
  ];
  final needle = _fold(query.trim());
  if (needle.isEmpty) return all.take(_maxHits).toList();
  final first = <ProjectJumpHit>[];
  final rest = <ProjectJumpHit>[];
  for (final hit in all) {
    final title = _fold(hit.title);
    if (title.startsWith(needle)) {
      first.add(hit);
    } else if (title.contains(needle) || _fold(hit.subtitle).contains(needle)) {
      rest.add(hit);
    }
  }
  return [...first, ...rest].take(_maxHits).toList();
}

/// Busca y salta a cualquier plano, escena, set o localización del proyecto.
Future<void> showProjectJump(
  BuildContext context, {
  required int projectId,
  required void Function(PlanTarget target) onPick,
}) async {
  final target = await showDialog<PlanTarget>(
    context: context,
    builder: (_) => _ProjectJumpDialog(projectId: projectId),
  );
  if (target != null) onPick(target);
}

/// Abre la búsqueda con ⌘K (Ctrl+K en Windows) mientras esta pantalla es la
/// que está delante, tenga donde tenga el foco.
class ProjectJumpShortcut extends StatefulWidget {
  final int projectId;
  final void Function(PlanTarget target) onPick;
  final Widget child;

  const ProjectJumpShortcut({
    super.key,
    required this.projectId,
    required this.onPick,
    required this.child,
  });

  @override
  State<ProjectJumpShortcut> createState() => _ProjectJumpShortcutState();
}

class _ProjectJumpShortcutState extends State<ProjectJumpShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final keys = HardwareKeyboard.instance;
    if (!keys.isMetaPressed && !keys.isControlPressed) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    unawaited(
      showProjectJump(
        context,
        projectId: widget.projectId,
        onPick: widget.onPick,
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ProjectJumpDialog extends StatefulWidget {
  final int projectId;

  const _ProjectJumpDialog({required this.projectId});

  @override
  State<_ProjectJumpDialog> createState() => _ProjectJumpDialogState();
}

class _ProjectJumpDialogState extends State<_ProjectJumpDialog> {
  String _query = '';
  List<ProjectJumpHit> _hits = const [];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dialog(
      backgroundColor: palette.surfaceElevated,
      alignment: const Alignment(0, -0.5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                key: const ValueKey('project-jump-field'),
                autofocus: true,
                style: AppTypography.bodyMedium(palette),
                decoration: const InputDecoration(
                  hintText: 'Plano, escena, set o localización',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: (_) {
                  if (_hits.isNotEmpty) {
                    Navigator.pop(context, _hits.first.target);
                  }
                },
              ),
            ),
            Flexible(
              child: PlanDataBuilder(
                projectId: widget.projectId,
                builder: (context, data) {
                  final hits = _hits = projectJumpHits(data, _query);
                  if (hits.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Nada con ese nombre.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption(palette),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: hits.length,
                    itemBuilder: (context, i) => ListTile(
                      dense: true,
                      leading: Icon(
                        hits[i].icon,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                      title: Text(
                        hits[i].title,
                        style: AppTypography.bodyMedium(palette),
                      ),
                      subtitle: hits[i].subtitle.isEmpty
                          ? null
                          : Text(
                              hits[i].subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption(palette),
                            ),
                      onTap: () => Navigator.pop(context, hits[i].target),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
