/// Configuración Cloudinary vía `--dart-define`.
abstract final class CloudinaryConfig {
  static const cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );

  static const uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );

  static const apiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  static const maxDimension = 3840;

  static const uploadUrl = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_URL',
    defaultValue: '',
  );

  static String get effectiveUploadUrl {
    if (uploadUrl.isNotEmpty) return uploadUrl;
    return 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  }

  static String deliveryUrl(String publicId) {
    final encoded = publicId.split('/').map(Uri.encodeComponent).join('/');
    return 'https://res.cloudinary.com/$cloudName/image/upload/f_auto,q_auto:good/$encoded';
  }

  static const rootFolder = 'iris-dp';
}
