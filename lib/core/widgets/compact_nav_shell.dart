import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

/// Pestaña de la barra inferior del iPhone.
class CompactNavTab {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final WidgetBuilder builder;

  const CompactNavTab({
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
  });
}

/// Barra inferior para el iPhone (docs/PLAN_IPHONE.md, IP.1.2).
///
/// En compacto muestra [tabs] con una NavigationBar abajo; cada pestaña se
/// construye la primera vez que se visita y luego se conserva (IndexedStack),
/// así el storyboard no se recarga al volver de la planta. En iPad y
/// escritorio no añade nada: muestra solo la primera pestaña, que es la
/// pantalla de siempre.
class CompactNavShell extends StatefulWidget {
  final List<CompactNavTab> tabs;
  final int initialIndex;

  /// Fuerza el modo compacto (pruebas); si es null decide el ancho.
  final bool? compact;

  const CompactNavShell({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.compact,
  }) : assert(tabs.length >= 2 && tabs.length <= 5);

  @override
  State<CompactNavShell> createState() => _CompactNavShellState();
}

class _CompactNavShellState extends State<CompactNavShell> {
  late int _index = widget.initialIndex;
  late final Set<int> _visited = {widget.initialIndex};

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact ?? AppLayout.isCompact(context);
    if (!compact) return widget.tabs.first.builder(context);

    final palette = context.palette;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            _visited.contains(i)
                ? Builder(builder: widget.tabs[i].builder)
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        backgroundColor: palette.surface,
        indicatorColor: palette.accent.withValues(alpha: 0.18),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final tab in widget.tabs)
            NavigationDestination(
              icon: Icon(tab.icon, color: palette.textSecondary),
              selectedIcon: Icon(
                tab.selectedIcon ?? tab.icon,
                color: palette.accent,
              ),
              label: tab.label,
              tooltip: '',
            ),
        ],
      ),
    );
  }
}
