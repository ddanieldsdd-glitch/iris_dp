import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloudinary_config.dart';
import '../utils/media_storage.dart';
import 'media_entity_types.dart';
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

    final uploadResponse = await _uploadToCloudinary(
      bytes: optimized.bytes,
      publicId: publicId,
      extension: optimized.extension,
    );
    if (uploadResponse == null) return null;

    final storedBytes =
        (uploadResponse['bytes'] as num?)?.toInt() ?? optimized.optimizedBytes;
    final returnedPublicId =
        uploadResponse['public_id'] as String? ?? publicId;
    final deliveryUrl = CloudinaryConfig.deliveryUrl(returnedPublicId);

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
        .eq('provider', 'cloudinary')
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
