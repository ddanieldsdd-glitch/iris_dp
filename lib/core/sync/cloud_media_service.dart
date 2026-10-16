import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloudinary_config.dart';
import '../cloud/supabase_config.dart';
import '../utils/media_storage.dart';
import 'media_optimizer.dart';

class CloudUploadResult {
  final String publicId;
  final String deliveryUrl;
  final int bytesOriginal;
  final int bytesStored;
  final String contentHash;

  const CloudUploadResult({
    required this.publicId,
    required this.deliveryUrl,
    required this.bytesOriginal,
    required this.bytesStored,
    required this.contentHash,
  });
}

/// Sube y descarga imágenes vía Cloudinary; registra en Supabase `media_assets`.
class CloudMediaService {
  final SupabaseClient _client;
  final http.Client _http;

  CloudMediaService(this._client, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static String hashBytes(Uint8List bytes) =>
      sha256.convert(bytes).toString();

  static String hashFile(String path) {
    final bytes = File(path).readAsBytesSync();
    return hashBytes(bytes);
  }

  Future<CloudUploadResult?> uploadFile({
    required String localPath,
    required String publicId,
    required String projectCloudId,
    required String entityType,
    required String entityKey,
    required int sortOrder,
    String? source,
    int? bytesOriginalOverride,
  }) async {
    if (!CloudinaryConfig.isConfigured) return null;
    if (!File(localPath).existsSync()) return null;

    final rawBytes = await File(localPath).readAsBytes();
    final optimized = MediaOptimizer.optimizeBytes(
      rawBytes,
      extension: _extFromPath(localPath),
    );

    final contentHash = hashBytes(optimized.bytes);

    final existing = await _client
        .from('media_assets')
        .select('id, content_hash, public_id, delivery_url')
        .eq('project_id', projectCloudId)
        .eq('entity_type', entityType)
        .eq('entity_key', entityKey)
        .maybeSingle();

    if (existing != null &&
        existing['content_hash'] == contentHash &&
        existing['public_id'] != null) {
      return CloudUploadResult(
        publicId: existing['public_id'] as String,
        deliveryUrl: existing['delivery_url'] as String? ??
            CloudinaryConfig.deliveryUrl(existing['public_id'] as String),
        bytesOriginal: bytesOriginalOverride ?? optimized.originalBytes,
        bytesStored: optimized.optimizedBytes,
        contentHash: contentHash,
      );
    }

    // La misma imagen ya está en la nube con otra clave (p. ej. la de posición
    // de antes de los uid): se registra con esta sin volver a subirla.
    final same = existing == null
        ? await _client
              .from('media_assets')
              .select('public_id, delivery_url, bytes_stored')
              .eq('project_id', projectCloudId)
              .eq('content_hash', contentHash)
              .not('public_id', 'is', null)
              .limit(1)
              .maybeSingle()
        : null;

    final String returnedPublicId;
    final int storedBytes;
    if (same != null) {
      returnedPublicId = same['public_id'] as String;
      storedBytes =
          (same['bytes_stored'] as num?)?.toInt() ?? optimized.optimizedBytes;
    } else {
      final uploadResponse = await _uploadToCloudinary(
        bytes: optimized.bytes,
        publicId: publicId,
        extension: optimized.extension,
      );
      if (uploadResponse == null) return null;
      storedBytes =
          (uploadResponse['bytes'] as num?)?.toInt() ??
          optimized.optimizedBytes;
      returnedPublicId = uploadResponse['public_id'] as String? ?? publicId;
    }
    final deliveryUrl =
        same?['delivery_url'] as String? ??
        CloudinaryConfig.deliveryUrl(returnedPublicId);

    final row = {
      'project_id': projectCloudId,
      'storage_path': returnedPublicId,
      'provider': 'cloudinary',
      'public_id': returnedPublicId,
      'delivery_url': deliveryUrl,
      'entity_type': entityType,
      'entity_key': entityKey,
      'content_hash': contentHash,
      'sort_order': sortOrder,
      'bytes_original': bytesOriginalOverride ?? optimized.originalBytes,
      'bytes_stored': storedBytes,
      'local_path_hint': localPath,
      'category': entityType,
      'local_hash': contentHash,
      'metadata': {
        if (source != null) 'source': source,
      },
    };

    if (existing != null && existing['id'] != null) {
      await _client
          .from('media_assets')
          .update(row)
          .eq('id', existing['id'] as String);
    } else {
      await _client.from('media_assets').insert(row);
    }

    return CloudUploadResult(
      publicId: returnedPublicId,
      deliveryUrl: deliveryUrl,
      bytesOriginal: bytesOriginalOverride ?? optimized.originalBytes,
      bytesStored: storedBytes,
      contentHash: contentHash,
    );
  }

  /// Sube un archivo que no es imagen (guion, PDF, escaneo, modelo 3D) tal
  /// cual a Supabase Storage, en `projects/<proyecto>/<tipo>/<clave>/<nombre>`
  /// (la ruta que permite la seguridad del bucket), y lo registra en
  /// `media_assets`. Si ya está con la misma huella, no lo vuelve a subir.
  /// Devuelve nulo si el archivo pasa de [maxBytes].
  Future<CloudUploadResult?> uploadRawFile({
    required String localPath,
    required String projectCloudId,
    required String entityType,
    required String entityKey,
    required int sortOrder,
    required int maxBytes,
    String? source,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) return null;
    final size = file.lengthSync();
    if (size > maxBytes) return null;
    final bytes = await file.readAsBytes();
    final contentHash = hashBytes(bytes);

    final existing = await _client
        .from('media_assets')
        .select('id, content_hash, storage_path')
        .eq('project_id', projectCloudId)
        .eq('entity_type', entityType)
        .eq('entity_key', entityKey)
        .maybeSingle();
    if (existing != null &&
        existing['content_hash'] == contentHash &&
        existing['storage_path'] != null) {
      return CloudUploadResult(
        publicId: existing['storage_path'] as String,
        deliveryUrl: '',
        bytesOriginal: size,
        bytesStored: size,
        contentHash: contentHash,
      );
    }

    final safeKey = entityKey.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final name = p.basename(localPath);
    final storagePath = 'projects/$projectCloudId/$entityType/$safeKey/$name';
    await _client.storage
        .from(SupabaseConfig.storageBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final row = {
      'project_id': projectCloudId,
      'storage_path': storagePath,
      'provider': 'supabase',
      'entity_type': entityType,
      'entity_key': entityKey,
      'content_hash': contentHash,
      'sort_order': sortOrder,
      'bytes_original': size,
      'bytes_stored': size,
      'local_path_hint': localPath,
      'category': entityType,
      'local_hash': contentHash,
      'metadata': {'file_name': name, if (source != null) 'source': source},
    };
    if (existing != null && existing['id'] != null) {
      await _client
          .from('media_assets')
          .update(row)
          .eq('id', existing['id'] as String);
    } else {
      await _client.from('media_assets').insert(row);
    }
    return CloudUploadResult(
      publicId: storagePath,
      deliveryUrl: '',
      bytesOriginal: size,
      bytesStored: size,
      contentHash: contentHash,
    );
  }

  /// Descarga un archivo de Supabase Storage al proyecto.
  Future<String?> downloadStorageFile({
    required int localProjectId,
    required String storagePath,
    required String subfolder,
    required String fileName,
  }) async {
    final bytes = await _client.storage
        .from(SupabaseConfig.storageBucket)
        .download(storagePath);
    if (bytes.isEmpty) return null;
    return MediaStorage.writeProjectFileBytes(
      projectId: localProjectId,
      subfolder: subfolder,
      bytes: bytes,
      fileName: fileName,
    );
  }

  Future<Map<String, dynamic>?> _uploadToCloudinary({
    required Uint8List bytes,
    required String publicId,
    required String extension,
  }) async {
    final uri = Uri.parse(CloudinaryConfig.effectiveUploadUrl);
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['public_id'] = publicId
      ..fields['quality'] = 'auto:good'
      ..fields['fetch_format'] = 'auto'
      ..fields['flags'] = 'strip_profile'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload$extension',
      ));

    final streamed = await _http.send(request);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Cloudinary upload failed (${streamed.statusCode}): $body');
    }
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  Future<String?> downloadToLocal({
    required int localProjectId,
    required String deliveryUrl,
    required String subfolder,
    required String fileName,
  }) async {
    final response = await _http.get(Uri.parse(deliveryUrl));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }
    return MediaStorage.writeProjectFileBytes(
      projectId: localProjectId,
      subfolder: subfolder,
      bytes: response.bodyBytes,
      fileName: fileName,
    );
  }

  Future<List<Map<String, dynamic>>> fetchProjectAssets(
    String projectCloudId,
  ) async {
    final rows = await _client
        .from('media_assets')
        .select()
        .eq('project_id', projectCloudId)
        .inFilter('provider', const ['cloudinary', 'supabase'])
        .order('entity_type')
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static String _extFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    return path.substring(dot).toLowerCase();
  }
}
