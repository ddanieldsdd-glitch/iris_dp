import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';

/// Cliente Supabase con respuestas PostgREST simuladas para tests de humo.
SupabaseClient createSupabaseMockClient({
  List<Map<String, dynamic>> cloudProjects = const [],
  List<Map<String, dynamic>> snapshots = const [],
  bool snapshotsTableMissing = true,
}) {
  return SupabaseClient(
    'http://127.0.0.1:9',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.test',
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (path.contains('cloud_projects')) {
        return http.Response(
          jsonEncode(cloudProjects),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (path.contains('cloud_project_snapshots')) {
        if (snapshotsTableMissing) {
          return http.Response(
            jsonEncode({
              'code': 'PGRST205',
              'details': null,
              'hint': null,
              'message':
                  "Could not find the table 'public.cloud_project_snapshots'",
            }),
            404,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode(snapshots),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
}
