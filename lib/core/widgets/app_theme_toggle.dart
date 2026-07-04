import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_radius.dart';
import '../theme/theme_mode_provider.dart';

class AppThemeToggle extends ConsumerWidget {
  const AppThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceOverlay.withValues(alpha: 0.5),
        borderRadius: AppRadius.pill,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeOption(
            label: 'Oscuro',
            icon: Icons.dark_mode_outlined,
            selected: mode == ThemeMode.dark,
            onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.dark,
          ),
          _ThemeOption(
            label: 'Claro',
            icon: Icons.light_mode_outlined,
            selected: mode == ThemeMode.light,
            onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.light,
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.accent : Colors.transparent,
          borderRadius: AppRadius.pill,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.accentGlow.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : palette.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.titleMedium(palette).copyWith(
                color: selected ? Colors.white : palette.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
