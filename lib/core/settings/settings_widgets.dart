import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_prefs.dart';

/// Bloque de filas con su rótulo, como en los Ajustes del sistema.
class SettingsGroupBox extends StatelessWidget {
  final String? title;
  final String? footer;
  final List<Widget> children;

  const SettingsGroupBox({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: palette.divider));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text(
              title!.toUpperCase(),
              style: AppTypography.caption(
                palette,
              ).copyWith(letterSpacing: 0.6, color: palette.textSecondary),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 0),
            child: Text(footer!, style: AppTypography.caption(palette)),
          ),
      ],
    );
  }
}

/// Fila base: título, subtítulo opcional y control a la derecha.
class SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyMedium(palette)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: AppTypography.caption(palette),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Marca de «cambiado en este proyecto» con el botón para volver al valor
/// general. No pinta nada si el ajuste no tiene excepción en [scope].
class _OverrideMark extends ConsumerWidget {
  final PrefKey pref;
  final SettingsScope scope;

  const _OverrideMark({required this.pref, required this.scope});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPrefsProvider);
    final pid = scope.projectId;
    if (pid == null || !prefs.hasOverride(pref, pid)) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Tooltip(
        message: 'Cambiado solo en este proyecto. Toca para volver al general.',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => prefs.clearOverride(pref, pid),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Proyecto',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.warning, fontSize: 11),
                ),
                const SizedBox(width: 4),
                Icon(Icons.undo, size: 12, color: palette.warning),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Interruptor ligado a un ajuste.
class PrefSwitchRow extends ConsumerWidget {
  final PrefKey<bool> pref;
  final SettingsScope scope;
  final String title;
  final String? subtitle;

  const PrefSwitchRow({
    super.key,
    required this.pref,
    required this.scope,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPrefsProvider);
    final value = prefs.valueIn(pref, scope);
    return SettingsRow(
      title: title,
      subtitle: subtitle,
      onTap: () => prefs.setIn(pref, scope, !value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OverrideMark(pref: pref, scope: scope),
          Switch.adaptive(
            value: value,
            onChanged: (v) => prefs.setIn(pref, scope, v),
          ),
        ],
      ),
    );
  }
}

/// Una opción de [PrefChoiceRow].
class PrefChoice<T> {
  final T value;
  final String label;

  const PrefChoice(this.value, this.label);
}

/// Elección entre opciones ligada a un ajuste: segmentos si son pocas y
/// cortas, menú desplegable si no.
class PrefChoiceRow<T extends Object> extends ConsumerWidget {
  final PrefKey<T> pref;
  final SettingsScope scope;
  final String title;
  final String? subtitle;
  final List<PrefChoice<T>> choices;

  const PrefChoiceRow({
    super.key,
    required this.pref,
    required this.scope,
    required this.title,
    required this.choices,
    this.subtitle,
  });

  bool get _useSegments =>
      choices.length <= 3 &&
      choices.fold<int>(0, (n, c) => n + c.label.length) <= 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prefs = ref.watch(appPrefsProvider);
    final value = prefs.valueIn(pref, scope);
    final selected = choices.any((c) => c.value == value)
        ? value
        : pref.defaultValue;

    final Widget control;
    if (_useSegments) {
      control = SegmentedButton<T>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          for (final c in choices)
            ButtonSegment<T>(value: c.value, label: Text(c.label)),
        ],
        selected: {selected},
        onSelectionChanged: (s) => prefs.setIn(pref, scope, s.first),
      );
    } else {
      control = DropdownButton<T>(
        value: selected,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(10),
        dropdownColor: palette.surfaceOverlay,
        style: AppTypography.bodyMedium(
          palette,
        ).copyWith(color: palette.textSecondary),
        items: [
          for (final c in choices)
            DropdownMenuItem<T>(value: c.value, child: Text(c.label)),
        ],
        onChanged: (v) {
          if (v != null) prefs.setIn(pref, scope, v);
        },
      );
    }

    return SettingsRow(
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OverrideMark(pref: pref, scope: scope),
          control,
        ],
      ),
    );
  }
}
