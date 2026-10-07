import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_color.dart';

/// Localización elegida y el set dentro de ella. Sin set propio, [set] es el
/// set base de la localización (la localización entera).
class LocationChoice {
  final LocationSite site;
  final LocationBasePlan set;

  const LocationChoice({required this.site, required this.set});

  /// El set es la localización entera, no una zona de ella.
  bool get isWholeSite =>
      set.locationName.trim().toLowerCase() == site.name.trim().toLowerCase();

  /// Cómo se nombra el lugar en la escena.
  String get placeName => isWholeSite ? site.name : set.locationName;

  String get label =>
      isWholeSite ? site.name : '${site.name} › ${set.locationName}';
}

/// Elige la localización de entre las del proyecto, o crea una, y dentro de
/// ella un set si se quiere. No se escribe el lugar a mano en cada escena.
class LocationPickerPanel extends ConsumerStatefulWidget {
  final int projectId;
  final int? initialSiteId;
  final int? initialSetId;
  final ValueChanged<LocationChoice?> onChanged;

  /// Alto de la lista de localizaciones.
  final double listHeight;

  const LocationPickerPanel({
    super.key,
    required this.projectId,
    required this.onChanged,
    this.initialSiteId,
    this.initialSetId,
    this.listHeight = 176,
  });

  @override
  ConsumerState<LocationPickerPanel> createState() =>
      _LocationPickerPanelState();
}

class _LocationPickerPanelState extends ConsumerState<LocationPickerPanel> {
  final _search = TextEditingController();
  final _newSet = TextEditingController();
  int? _siteId;
  int? _setId;
  bool _addingSet = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _siteId = widget.initialSiteId;
    _setId = widget.initialSetId;
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _newSet.dispose();
    super.dispose();
  }

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> _selectSite(LocationSite site) async {
    final base = await _db.ensureDefaultSetForSite(
      projectId: widget.projectId,
      site: site,
    );
    if (!mounted) return;
    setState(() {
      _siteId = site.id;
      _setId = base.id;
      _addingSet = false;
    });
    widget.onChanged(LocationChoice(site: site, set: base));
  }

  Future<void> _createSite(String name) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final site = await _db.ensureSite(
        projectId: widget.projectId,
        siteName: name.trim().toUpperCase(),
      );
      _search.clear();
      await _selectSite(site);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createSet(LocationSite site) async {
    final name = _newSet.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final ensured = await _db.ensureSiteAndSet(
        projectId: widget.projectId,
        siteName: site.name,
        setName: name.toUpperCase(),
      );
      if (!mounted) return;
      _newSet.clear();
      setState(() {
        _setId = ensured.set.id;
        _addingSet = false;
      });
      widget.onChanged(LocationChoice(site: ensured.site, set: ensured.set));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          final query = _search.text.trim();
          final q = query.toLowerCase();
          final shown = [
            for (final s in sites)
              if (q.isEmpty || s.name.toLowerCase().contains(q)) s,
          ];
          final exact = sites.any((s) => s.name.toLowerCase() == q);
          LocationSite? selected;
          for (final s in sites) {
            if (s.id == _siteId) selected = s;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _search,
                style: AppTypography.bodyLarge(palette),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: sites.isEmpty
                      ? 'Nombre de la primera localización'
                      : 'Buscar o crear localización',
                ),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) return;
                  if (shown.length == 1 && exact) {
                    _selectSite(shown.first);
                  } else if (!exact) {
                    _createSite(v);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                height: widget.listHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final site in shown)
                      _siteTile(site, sets, palette, site.id == _siteId),
                    if (query.isNotEmpty && !exact)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.add, color: palette.accent),
                        title: Text(
                          'Crear «${query.toUpperCase()}»',
                          style: AppTypography.bodyMedium(
                            palette,
                          ).copyWith(color: palette.accent),
                        ),
                        onTap: () => _createSite(query),
                      ),
                    if (shown.isEmpty && query.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Aún no hay localizaciones. Escribe un nombre '
                          'arriba para crear la primera.',
                          style: AppTypography.bodyMedium(palette),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Set dentro de ${selected.name} (opcional)',
                  style: AppTypography.label(palette),
                ),
                const SizedBox(height: 6),
                _setChips(selected, sets, palette),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _siteTile(
    LocationSite site,
    List<LocationBasePlan> sets,
    AppPalette palette,
    bool selected,
  ) {
    final own = [
      for (final s in sets)
        if (s.siteId == site.id) s,
    ];
    final zones = own
        .where(
          (s) => s.locationName.trim().toLowerCase() != site.name.toLowerCase(),
        )
        .length;
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: palette.accent.withValues(alpha: 0.14),
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: sceneDisplayColor(own.isEmpty ? null : own.first.color),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        site.name,
        style: AppTypography.bodyLarge(
          palette,
        ).copyWith(color: palette.textPrimary),
      ),
      subtitle: zones == 0
          ? null
          : Text(
              zones == 1 ? '1 set' : '$zones sets',
              style: AppTypography.caption(palette),
            ),
      trailing: selected
          ? Icon(Icons.check, size: 18, color: palette.accent)
          : null,
      onTap: () => _selectSite(site),
    );
  }

  Widget _setChips(
    LocationSite site,
    List<LocationBasePlan> sets,
    AppPalette palette,
  ) {
    final own = [
      for (final s in sets)
        if (s.siteId == site.id) s,
    ];
    bool isBase(LocationBasePlan s) =>
        s.locationName.trim().toLowerCase() == site.name.trim().toLowerCase();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in own)
          ChoiceChip(
            label: Text(isBase(s) ? 'Toda la localización' : s.locationName),
            selected: s.id == _setId,
            onSelected: (_) {
              setState(() => _setId = s.id);
              widget.onChanged(LocationChoice(site: site, set: s));
            },
          ),
        if (_addingSet)
          SizedBox(
            width: 220,
            child: TextField(
              controller: _newSet,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(color: palette.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Nombre del set',
                suffixIcon: IconButton(
                  tooltip: 'Crear set',
                  icon: const Icon(Icons.check, size: 18),
                  onPressed: () => _createSet(site),
                ),
              ),
              onSubmitted: (_) => _createSet(site),
            ),
          )
        else
          ActionChip(
            avatar: Icon(Icons.add, size: 16, color: palette.accent),
            label: const Text('Nuevo set'),
            onPressed: () => setState(() => _addingSet = true),
          ),
      ],
    );
  }
}

/// Selector de localización en un diálogo, para pantallas que solo necesitan
/// el resultado.
Future<LocationChoice?> showLocationPicker(
  BuildContext context, {
  required int projectId,
  int? initialSiteId,
  int? initialSetId,
}) {
  LocationChoice? choice;
  return showDialog<LocationChoice>(
    context: context,
    builder: (ctx) {
      final palette = ctx.palette;
      return AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Localización', style: AppTypography.titleMedium(palette)),
        content: SizedBox(
          width: 480,
          child: LocationPickerPanel(
            projectId: projectId,
            initialSiteId: initialSiteId,
            initialSetId: initialSetId,
            listHeight: 240,
            onChanged: (c) => choice = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, choice),
            child: const Text('Elegir'),
          ),
        ],
      );
    },
  );
}
