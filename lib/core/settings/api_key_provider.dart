import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_key_storage.dart';

final claudeApiKeyProvider =
    AsyncNotifierProvider<ClaudeApiKeyNotifier, String?>(ClaudeApiKeyNotifier.new);

class ClaudeApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ApiKeyStorage.readClaudeApiKey();

  Future<void> save(String key) async {
    await ApiKeyStorage.saveClaudeApiKey(key);
    state = AsyncData(key.trim().isEmpty ? null : key.trim());
  }

  Future<void> clear() async {
    await ApiKeyStorage.clearClaudeApiKey();
    state = const AsyncData(null);
  }
}
