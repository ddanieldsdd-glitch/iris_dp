import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class BibleCommandAction {
  final String id;
  final String label;
  final String? shortcut;
  final IconData icon;
  final VoidCallback onInvoke;

  const BibleCommandAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onInvoke,
    this.shortcut,
  });
}

/// Command palette ⌘K (Fase 9).
class BibleCommandPalette extends StatefulWidget {
  final List<BibleCommandAction> actions;

  const BibleCommandPalette({super.key, required this.actions});

  static Future<void> show(
    BuildContext context, {
    required List<BibleCommandAction> actions,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => BibleCommandPalette(actions: actions),
    );
  }

  @override
  State<BibleCommandPalette> createState() => _BibleCommandPaletteState();
}

class _BibleCommandPaletteState extends State<BibleCommandPalette> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filtered = widget.actions.where((a) {
      if (_query.isEmpty) return true;
      return a.label.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 40, right: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar acción…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final a = filtered[i];
                  return ListTile(
                    leading: Icon(a.icon),
                    title: Text(
                      a.label,
                      style: AppTypography.bodyMedium(palette),
                    ),
                    trailing: a.shortcut != null
                        ? Text(a.shortcut!, style: AppTypography.mono(palette))
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      a.onInvoke();
                    },
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

/// Intent para abrir palette con atajo.
class OpenBibleCommandPaletteIntent extends Intent {
  const OpenBibleCommandPaletteIntent();
}

SingleActivator get bibleCommandPaletteActivator =>
    const SingleActivator(LogicalKeyboardKey.keyK, meta: true);
