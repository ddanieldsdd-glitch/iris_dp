/// Release remota publicada en Supabase (metadatos; binario en GitHub).
class AppRelease {
  final String platform;
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String? releaseNotes;

  const AppRelease({
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    this.releaseNotes,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      platform: json['platform'] as String,
      version: json['version'] as String,
      buildNumber: (json['build_number'] as num).toInt(),
      downloadUrl: json['download_url'] as String,
      releaseNotes: json['release_notes'] as String?,
    );
  }
}
