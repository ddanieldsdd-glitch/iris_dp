import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/shoot_document_repository.dart';

final shootDocumentRepositoryProvider = Provider<ShootDocumentRepository>((ref) {
  return ShootDocumentRepository(ref.watch(databaseProvider));
});
