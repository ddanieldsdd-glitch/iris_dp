import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shoot_documents/shoot_documents_screen.dart';

/// @deprecated Usar [ShootDocumentsScreen].
class DailyOrderScreen extends ConsumerWidget {
  final int projectId;
  final String projectName;

  const DailyOrderScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShootDocumentsScreen(
      projectId: projectId,
      projectName: projectName,
    );
  }
}
