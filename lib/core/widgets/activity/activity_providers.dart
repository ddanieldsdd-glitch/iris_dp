import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/cloud_providers.dart';
import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../../sync/project_activity_service.dart';

/// El id en la nube de un proyecto local: el suyo o, en una copia de
/// consulta, el del proyecto original.
Future<String?> projectCloudIdOf(AppDatabase db, int projectId) async {
  final p = await db.getProject(projectId);
  return p?.cloudId ?? p?.mirrorCloudId;
}

/// El último cambio de cada cosa de un proyecto (por `colección/uid`). Vacío
/// sin nube, sin la 021 o sin conexión.
final lastChangesProvider = FutureProvider.autoDispose
    .family<Map<String, ActivityEntry>, int>((ref, projectId) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null || client.auth.currentUser == null) return const {};
      final cloudId = await projectCloudIdOf(
        ref.read(databaseProvider),
        projectId,
      );
      if (cloudId == null) return const {};
      try {
        return await ProjectActivityService(client).lastChanges(cloudId);
      } catch (_) {
        // Es un dato de ayuda: sin él no se enseña la línea.
        return const {};
      }
    });

/// «hace 5 min», «hace 3 h», «ayer 17:42», «12-11 09:30».
String whenLabel(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(at);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  final hm =
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  if (day == today) return 'hoy $hm';
  if (day == today.subtract(const Duration(days: 1))) return 'ayer $hm';
  return '${at.day.toString().padLeft(2, '0')}-${at.month.toString().padLeft(2, '0')} $hm';
}
