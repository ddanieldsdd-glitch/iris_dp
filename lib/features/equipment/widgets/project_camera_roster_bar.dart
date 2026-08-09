import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/equipment/project_equipment_roles.dart';

/// Muestra cámaras asignadas al proyecto con roles A-CAM / B-CAM.
class ProjectCameraRosterBar extends StatelessWidget {
  final AppDatabase db;
  final int projectId;
  final int? activeCameraId;
  final AppPalette palette;

  const ProjectCameraRosterBar({
    super.key,
    required this.db,
    required this.projectId,
    required this.activeCameraId,
    required this.palette,
  });

  Future<List<Camera>> _loadCameras(List<ProjectEquipmentData> rows) async {
    final cameras = <Camera>[];
    for (final row in rows) {
      if (row.equipmentType != 'camera') continue;
      final cam = await db.getCameraById(row.equipmentId);
      if (cam != null) cameras.add(cam);
    }
    return cameras;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VisualBible?>(
      stream: db.watchVisualBibleForProject(projectId),
      builder: (context, bibleSnap) {
        final primaryId = bibleSnap.data?.primaryCameraId;
        return StreamBuilder<List<ProjectEquipmentData>>(
          stream: db.watchProjectEquipment(projectId),
          builder: (context, eqSnap) {
            final rows = eqSnap.data ?? [];
            return FutureBuilder<List<Camera>>(
              future: _loadCameras(rows),
              builder: (context, camSnap) {
                final assigned = camSnap.data ?? [];
                if (assigned.length < 2) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CÁMARAS DEL PROYECTO',
                        style: AppTypography.label(palette).copyWith(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: palette.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cam in assigned)
                            _RoleChip(
                              palette: palette,
                              role: ProjectEquipmentRoles.cameraRoleLabel(
                                cameraId: cam.id,
                                primaryCameraId: primaryId,
                                assignedInOrder: assigned,
                              ),
                              title: '${cam.brand} ${cam.model}'.trim(),
                              hint: ProjectEquipmentRoles.cameraRoleHint(
                                ProjectEquipmentRoles.cameraRoleLabel(
                                  cameraId: cam.id,
                                  primaryCameraId: primaryId,
                                  assignedInOrder: assigned,
                                ),
                              ),
                              active: activeCameraId != null
                                  ? cam.id == activeCameraId
                                  : ProjectEquipmentRoles.drivesActiveSpecs(
                                      cameraId: cam.id,
                                      primaryCameraId: primaryId,
                                      assignedInOrder: assigned,
                                    ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RoleChip extends StatelessWidget {
  final AppPalette palette;
  final String role;
  final String title;
  final String hint;
  final bool active;

  const _RoleChip({
    required this.palette,
    required this.role,
    required this.title,
    required this.hint,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final accent = active;
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent
            ? palette.accent.withValues(alpha: 0.12)
            : palette.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent
              ? palette.accent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role,
            style: AppTypography.mono(palette).copyWith(
              fontSize: 10,
              color: accent ? palette.accent : palette.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTypography.bodyMedium(palette).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            hint,
            style: AppTypography.caption(palette).copyWith(
              fontSize: 10,
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
