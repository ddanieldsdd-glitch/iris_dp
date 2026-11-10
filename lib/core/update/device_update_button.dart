import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'device_update_request.dart';

/// «Actualizar desde el Mac»: en el iPad y el iPhone, llama al Mac para que
/// instale la última versión publicada.
class DeviceUpdateButton extends ConsumerWidget {
  const DeviceUpdateButton({super.key});

  static const _maxWidth = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final update = ref.watch(deviceUpdateProvider);
    final caption = AppTypography.caption(palette);

    if (update.busy) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(update.message ?? '', style: caption)),
          ],
        ),
      );
    }

    final note = update.hostAvailable
        ? update.message
        : 'Abre IRIS en el Mac para usar este botón. Si no, se instalará '
              'sola cuando coincidan encendidos.';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Con letra grande del sistema, se encoge en vez de desbordar.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Actualizar desde el Mac',
              icon: Icons.laptop_mac_outlined,
              onTap: update.hostAvailable
                  ? () => unawaited(update.request())
                  : null,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: caption),
          ],
        ],
      ),
    );
  }
}
