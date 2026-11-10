/// Release remota publicada en Supabase (metadatos; binario en GitHub).
class AppRelease {
  final String platform;
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String? releaseNotes;

  /// Huella SHA-256 del archivo publicado. Las publicaciones anteriores a la
  /// columna no la traen y se instalan como hasta ahora.
  final String? sha256;

  const AppRelease({
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    this.releaseNotes,
    this.sha256,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      platform: json['platform'] as String,
      version: json['version'] as String,
      buildNumber: (json['build_number'] as num).toInt(),
      downloadUrl: json['download_url'] as String,
      releaseNotes: json['release_notes'] as String?,
      sha256: json['sha256'] as String?,
    );
  }
}
