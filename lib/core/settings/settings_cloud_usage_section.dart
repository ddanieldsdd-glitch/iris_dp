import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_usage_service.dart';
import '../cloud/cloudinary_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Espacio usado en cada nube (Supabase y Cloudinary) frente al plan gratuito.
class SettingsCloudUsageSection extends ConsumerWidget {
  const SettingsCloudUsageSection({super.key});

  static const _bucketNames = {
    'project-media': 'imágenes de proyecto',
    'avatars': 'fotos de perfil',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final usage = ref.watch(cloudUsageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Espacio en la nube',
                style: AppTypography.titleMedium(palette),
              ),
            ),
            IconButton(
              tooltip: 'Volver a medir',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: usage.isLoading
                  ? null
                  : () => ref.invalidate(cloudUsageProvider),
            ),
          ],
        ),
        usage.when(
          loading: () =>
              Text('Midiendo…', style: AppTypography.caption(palette)),
          error: (e, _) => Text(
            e is CloudUsageUnavailable
                ? 'Falta ejecutar la migración 012 en Supabase para ver el espacio usado.'
                : 'No se pudo medir el espacio (¿hay conexión?).',
            style: AppTypography.caption(palette),
          ),
          data: (u) {
            if (u == null) {
              return Text(
                'Inicia sesión para ver el espacio usado.',
                style: AppTypography.caption(palette),
              );
            }
            final buckets = u.storageBuckets.entries
                .where((e) => e.value > 0)
                .map(
                  (e) =>
                      '${_bucketNames[e.key] ?? e.key} ${formatBytes(e.value)}',
                )
                .join(' · ');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UsageBar(
                  label: 'Supabase · base de datos',
                  used: u.databaseBytes,
                  limit: CloudQuota.supabaseDatabaseBytes,
                ),
                UsageBar(
                  label: 'Supabase · archivos',
                  used: u.storageBytes,
                  limit: CloudQuota.supabaseStorageBytes,
                  detail: buckets.isEmpty ? null : buckets,
                ),
                UsageBar(
                  label: 'Cloudinary · imágenes',
                  used: u.cloudinaryBytes,
                  limit: CloudQuota.cloudinaryBytes,
                  detail: CloudinaryConfig.isConfigured
                      ? '${u.cloudinaryAssets} imágenes · estimado con lo que '
                            'ha subido IRIS (25 créditos ≈ 25 GB)'
                      : 'Desactivado en esta versión',
                ),
                Text(
                  'Límites del plan gratuito de cada servicio.',
                  style: AppTypography.caption(palette),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Barra de uso «usado de límite».
class UsageBar extends StatelessWidget {
  const UsageBar({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    this.detail,
  });

  final String label;
  final int used;
  final int limit;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fraction = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final color = fraction >= 0.9
        ? palette.error
        : fraction >= 0.7
        ? palette.warning
        : palette.success;
    final percent = (used / limit * 100);
    final percentText = percent > 0 && percent < 1
        ? '<1 %'
        : '${percent.round()} %';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTypography.label(palette))),
              Text(
                '${formatBytes(used)} de ${formatBytes(limit)} · $percentText',
                style: AppTypography.caption(palette),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: color,
              backgroundColor: palette.border,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(detail!, style: AppTypography.caption(palette)),
          ],
        ],
      ),
    );
  }
}
