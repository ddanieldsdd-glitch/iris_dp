// Hoja de «añadir elemento» del editor de planta.
part of 'camera_plan_editor.dart';

class _AddElementSheet extends StatefulWidget {
  final AppPalette palette;
  final VoidCallback onAddCamera;
  final ValueChanged<Color> onAddActor;
  final ValueChanged<LightType> onAddLight;
  final ValueChanged<PropType> onAddProp;
  final ValueChanged<ArchitectureType> onAddArchitecture;
  final VoidCallback onAddHall;

  /// Dónde van paredes y props: al entorno o al set. `null` si no hay
  /// elección (solo existe una de las dos capas).
  final bool? wallsToEnvironment;
  final ValueChanged<bool>? onWallsToEnvironment;

  const _AddElementSheet({
    this.wallsToEnvironment,
    this.onWallsToEnvironment,
    required this.palette,
    required this.onAddCamera,
    required this.onAddActor,
    required this.onAddLight,
    required this.onAddProp,
    required this.onAddArchitecture,
    required this.onAddHall,
  });

  @override
  State<_AddElementSheet> createState() => _AddElementSheetState();
}

class _AddElementSheetState extends State<_AddElementSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool? _toEnvironment = widget.wallsToEnvironment;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Añadir elemento',
                    style: AppTypography.titleMedium(palette),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (_toEnvironment != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Paredes y props se añaden a',
                        style: AppTypography.caption(palette),
                      ),
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Set')),
                        ButtonSegment(value: true, label: Text('Entorno')),
                      ],
                      selected: {_toEnvironment!},
                      onSelectionChanged: (v) {
                        setState(() => _toEnvironment = v.first);
                        widget.onWallsToEnvironment?.call(v.first);
                      },
                    ),
                  ],
                ),
              ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: palette.accent,
              unselectedLabelColor: palette.textSecondary,
              indicatorColor: palette.accent,
              tabs: const [
                Tab(text: 'Cámara'),
                Tab(text: 'Actores'),
                Tab(text: 'Luces'),
                Tab(text: 'Props'),
                Tab(text: 'Arquitectura'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CameraTab(palette: palette, onAdd: widget.onAddCamera),
                  _ActorTab(palette: palette, onAdd: widget.onAddActor),
                  _LightTab(palette: palette, onAdd: widget.onAddLight),
                  _PropTab(palette: palette, onAdd: widget.onAddProp),
                  _ArchitectureTab(
                    palette: palette,
                    onAdd: widget.onAddArchitecture,
                    onHall: widget.onAddHall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  final AppPalette palette;
  final Widget child;
  final String label;
  final VoidCallback onTap;

  const _GridTile({
    required this.palette,
    required this.child,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            child,
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.caption(palette),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraTab extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onAdd;

  const _CameraTab({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 140,
        height: 120,
        child: _GridTile(
          palette: palette,
          label: 'Cámara',
          onTap: onAdd,
          child: Icon(Icons.videocam, color: palette.accent, size: 36),
        ),
      ),
    );
  }
}

class _ActorTab extends StatelessWidget {
  final AppPalette palette;
  final ValueChanged<Color> onAdd;

  const _ActorTab({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: kActorColors.length,
      itemBuilder: (context, i) {
        final color = kActorColors[i];
        return _GridTile(
          palette: palette,
          label: 'Actor ${i + 1}',
          onTap: () => onAdd(color),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: palette.border),
            ),
          ),
        );
      },
    );
  }
}

class _LightTab extends StatelessWidget {
  final AppPalette palette;
  final ValueChanged<LightType> onAdd;

  const _LightTab({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520
            ? 8
            : constraints.maxWidth >= 360
            ? 6
            : 4;

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.72,
          ),
          itemCount: kShotDesignerLightGrid.length,
          itemBuilder: (context, i) {
            final type = kShotDesignerLightGrid[i];
            return LightGridTile(type: type, onTap: () => onAdd(type));
          },
        );
      },
    );
  }
}

class _PropTab extends StatelessWidget {
  final AppPalette palette;
  final ValueChanged<PropType> onAdd;

  const _PropTab({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      // El fotómetro, último de la lista, se añade desde «Medición».
      itemCount: PropType.values.length - 1,
      itemBuilder: (context, i) {
        final type = PropType.values[i];
        return _GridTile(
          palette: palette,
          label: type.label,
          onTap: () => onAdd(type),
          child: Icon(type.icon, color: palette.textSecondary, size: 28),
        );
      },
    );
  }
}

class _ArchitectureTab extends StatelessWidget {
  final AppPalette palette;
  final ValueChanged<ArchitectureType> onAdd;
  final VoidCallback onHall;

  const _ArchitectureTab({
    required this.palette,
    required this.onAdd,
    required this.onHall,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      // La nave, la primera; luego las piezas sueltas.
      itemCount: ArchitectureType.values.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _GridTile(
            palette: palette,
            label: 'Nave',
            onTap: onHall,
            child: Icon(
              Icons.warehouse_outlined,
              color: palette.textPrimary,
              size: 28,
            ),
          );
        }
        final type = ArchitectureType.values[i - 1];
        return _GridTile(
          palette: palette,
          label: type.label,
          onTap: () => onAdd(type),
          child: Icon(type.icon, color: palette.textPrimary, size: 28),
        );
      },
    );
  }
}
