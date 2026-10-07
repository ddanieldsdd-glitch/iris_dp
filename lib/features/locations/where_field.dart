import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_color.dart';
import 'location_picker.dart';

/// «¿Dónde ocurre?»: un solo campo para decir el lugar de una escena.
///
/// Vacío enseña las localizaciones del proyecto con sus sets. Al escribir
/// filtra ambos a la vez. Un nombre que no existe se crea como localización
/// nueva (Intro) o como set dentro de una que ya hay.
class WhereField extends ConsumerStatefulWidget {
  final int projectId;
  final LocationChoice? initial;
  final ValueChanged<LocationChoice?> onChanged;

  /// Intro con un lugar ya elegido: el padre puede dar la escena por lista.
  final VoidCallback? onSubmitted;
  final bool autofocus;
  final double listHeight;

  const WhereField({
    super.key,
    required this.projectId,
    required this.onChanged,
    this.initial,
    this.onSubmitted,
    this.autofocus = false,
    this.listHeight = 220,
  });

  @override
  ConsumerState<WhereField> createState() => WhereFieldState();
}

/// Una fila de la lista: un lugar que ya existe o una forma de crearlo.
class _Option {
  final LocationSite? site;
  final LocationBasePlan? set;

  /// Crear localización nueva con lo escrito.
  final bool createSite;

  /// Abrir la elección de localización madre para crear un set.
  final bool createSet;

  /// Crear el set dentro de [site].
  final bool createSetIn;

  const _Option({
    this.site,
    this.set,
    this.createSite = false,
    this.createSet = false,
    this.createSetIn = false,
  });
}

class WhereFieldState extends ConsumerState<WhereField> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  LocationChoice? _choice;

  /// Fila marcada con las flechas; nula mientras valga la de partida.
  int? _marked;
  int _highlight = 0;
  bool _pickingParent = false;
  bool _busy = false;
  List<_Option> _options = const [];

  @override
  void initState() {
    super.initState();
    _choice = widget.initial;
    _text.text = widget.initial?.label ?? '';
    _text.addListener(_onTyped);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Lo escrito, salvo que sea el rótulo del lugar ya elegido.
  String get _query {
    final t = _text.text.trim();
    return _choice != null && t == _choice!.label ? '' : t;
  }

  void _onTyped() {
    final choice = _choice;
    if (choice != null && _text.text.trim() != choice.label) {
      // Se ha editado el texto: lo elegido deja de valer.
      _choice = null;
      widget.onChanged(null);
    }
    setState(() {
      _marked = null;
      _pickingParent = false;
    });
  }

  /// Vacía el campo para decir otro lugar y le devuelve el foco.
  void clear() {
    _choice = null;
    _text.clear();
    _focus.requestFocus();
  }

  void _setChoice(LocationChoice choice) {
    _choice = choice;
    _text.value = TextEditingValue(
      text: choice.label,
      selection: TextSelection.collapsed(offset: choice.label.length),
    );
    setState(() => _pickingParent = false);
    widget.onChanged(choice);
  }

  Future<void> _pick(_Option o) async {
    if (_busy) return;
    final name = _query.toUpperCase();
    if (o.createSet) {
      setState(() {
        _pickingParent = true;
        _marked = null;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      if (o.createSite) {
        final site = await _db.ensureSite(
          projectId: widget.projectId,
          siteName: name,
        );
        final base = await _db.ensureDefaultSetForSite(
          projectId: widget.projectId,
          site: site,
        );
        _setChoice(LocationChoice(site: site, set: base));
      } else if (o.createSetIn) {
        final ensured = await _db.ensureSiteAndSet(
          projectId: widget.projectId,
          siteName: o.site!.name,
          setName: name,
        );
        _setChoice(LocationChoice(site: ensured.site, set: ensured.set));
      } else {
        final site = o.site!;
        final set =
            o.set ??
            await _db.ensureDefaultSetForSite(
              projectId: widget.projectId,
              site: site,
            );
        _setChoice(LocationChoice(site: site, set: set));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_options.isNotEmpty) {
        setState(() => _marked = (_highlight + 1) % _options.length);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_options.isNotEmpty) {
        setState(
          () =>
              _highlight = (_highlight - 1 + _options.length) % _options.length,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _pickingParent) {
      setState(() => _pickingParent = false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_choice != null && _query.isEmpty) {
        widget.onSubmitted?.call();
      } else if (_options.isNotEmpty) {
        _pick(_options[_highlight.clamp(0, _options.length - 1)]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static bool _isBase(LocationSite site, LocationBasePlan set) =>
      set.locationName.trim().toLowerCase() == site.name.trim().toLowerCase();

  List<_Option> _buildOptions(
    List<LocationSite> sites,
    List<LocationBasePlan> sets,
  ) {
    final query = _query;
    final q = query.toLowerCase();

    if (_pickingParent) {
      return [for (final s in sites) _Option(site: s, createSetIn: true)];
    }

    final options = <_Option>[];
    var exact = false;
    for (final site in sites) {
      final zones = [
        for (final s in sets)
          if (s.siteId == site.id && !_isBase(site, s)) s,
      ];
      final siteMatches = q.isEmpty || site.name.toLowerCase().contains(q);
      final matching = [
        for (final z in zones)
          if (siteMatches || z.locationName.toLowerCase().contains(q)) z,
      ];
      if (!siteMatches && matching.isEmpty) continue;
      if (site.name.toLowerCase() == q) exact = true;
      options.add(_Option(site: site));
      for (final z in matching) {
        if (z.locationName.toLowerCase() == q) exact = true;
        options.add(_Option(site: site, set: z));
      }
    }
    if (query.isNotEmpty && !exact) {
      options.add(const _Option(createSite: true));
      if (sites.isNotEmpty) options.add(const _Option(createSet: true));
    }
    return options;
  }

  /// Qué elige Intro: la coincidencia exacta; si no, la primera que
  /// coincida en parte (para no duplicar un lugar por escribirlo a medias);
  /// y solo si nada coincide, crear la localización.
  int _defaultHighlight(List<_Option> options) {
    final q = _query.toLowerCase();
    if (q.isEmpty || _pickingParent) return 0;
    for (var i = 0; i < options.length; i++) {
      final o = options[i];
      final name = (o.set?.locationName ?? o.site?.name ?? '').toLowerCase();
      if (name == q) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<LocationSite>>(
      stream: db.watchSitesForProject(widget.projectId),
      builder: (context, siteSnap) => StreamBuilder<List<LocationBasePlan>>(
        stream: db.watchLocationsForProject(widget.projectId),
        builder: (context, setSnap) {
          final sites = siteSnap.data ?? const <LocationSite>[];
          final sets = setSnap.data ?? const <LocationBasePlan>[];
          _options = _buildOptions(sites, sets);
          final marked = _marked;
          final highlight = marked == null || marked >= _options.length
              ? _defaultHighlight(_options)
              : marked;
          _highlight = highlight;
          final name = _query.toUpperCase();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onKeyEvent: _onKey,
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  style: AppTypography.bodyLarge(palette),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '¿Dónde ocurre?',
                    prefixIcon: Icon(
                      _choice != null
                          ? Icons.check_circle
                          : Icons.place_outlined,
                      size: 18,
                      color: _choice != null
                          ? palette.accent
                          : palette.textTertiary,
                    ),
                    suffixIcon: _text.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar',
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              clear();
                              widget.onChanged(null);
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                height: widget.listHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (_pickingParent)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Text(
                            '¿Dentro de qué localización está «$name»?',
                            style: AppTypography.label(palette),
                          ),
                        ),
                      if (_options.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            'Aún no hay localizaciones. Escribe el nombre del '
                            'lugar y pulsa Intro para crear la primera.',
                            style: AppTypography.bodyMedium(palette),
                          ),
                        ),
                      for (var i = 0; i < _options.length; i++)
                        _tile(_options[i], i == highlight, sets, name, palette),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(
    _Option o,
    bool highlighted,
    List<LocationBasePlan> sets,
    String name,
    AppPalette palette,
  ) {
    final accentText = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.accent);
    final Widget leading;
    final Widget title;
    Widget? trailing;
    var indent = 12.0;

    if (o.createSite) {
      leading = Icon(Icons.add, size: 18, color: palette.accent);
      title = Text('Crear «$name» como localización nueva', style: accentText);
    } else if (o.createSet) {
      leading = Icon(
        Icons.subdirectory_arrow_right,
        size: 18,
        color: palette.accent,
      );
      title = Text('Crear «$name» como set dentro de…', style: accentText);
    } else {
      final site = o.site!;
      final own = sets.where((s) => s.siteId == site.id).toList();
      final colorHex = o.set?.color ?? (own.isEmpty ? null : own.first.color);
      final selected =
          !o.createSetIn &&
          _choice != null &&
          _choice!.site.id == site.id &&
          (o.set == null ? _choice!.isWholeSite : _choice!.set.id == o.set!.id);
      if (o.set != null) indent = 36;
      leading = Container(
        width: o.set == null ? 14 : 10,
        height: o.set == null ? 14 : 10,
        decoration: BoxDecoration(
          color: sceneDisplayColor(colorHex),
          shape: BoxShape.circle,
        ),
      );
      title = Text(
        o.set?.locationName ?? site.name,
        style: AppTypography.bodyLarge(palette).copyWith(
          color: palette.textPrimary,
          fontSize: o.set == null ? null : 14,
        ),
      );
      trailing = selected
          ? Icon(Icons.check, size: 18, color: palette.accent)
          : Text(
              o.createSetIn
                  ? 'aquí'
                  : o.set == null
                  ? 'localización'
                  : 'set',
              style: AppTypography.caption(palette),
            );
    }

    return InkWell(
      onTap: () => _pick(o),
      child: Container(
        color: highlighted ? palette.accent.withValues(alpha: 0.14) : null,
        padding: EdgeInsets.fromLTRB(indent, 9, 12, 9),
        child: Row(
          children: [
            SizedBox(width: 20, child: Center(child: leading)),
            const SizedBox(width: 10),
            Expanded(child: title),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
