import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_runtime_config.dart';
import 'cloud_session.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!CloudRuntimeConfig.isActive) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

final authStateProvider = StreamProvider<AuthState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream.value(null);
  return client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client?.auth.currentUser;
});

final isCloudModeProvider = Provider<bool>((ref) {
  return CloudRuntimeConfig.isActive;
});

final cloudSessionRoleProvider = FutureProvider<String?>((ref) {
  return CloudSessionStore.userRole();
});

/// Carga preferencias y conecta Supabase solo si el usuario activó la nube.
Future<void> initializeCloud() async {
  await CloudRuntimeConfig.load();
  await CloudRuntimeConfig.initializeIfActive();
}
