import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ImageStorageService {
  static const _bucket = 'recipe-images';
  static const _uuid = Uuid();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Returns true if [path] is already a remote URL (already uploaded).
  static bool isRemoteUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  /// Uploads [localPath] to Supabase Storage under [userId]/[recipeId]/.
  /// Returns the public URL on success, or null on failure.
  static Future<String?> uploadImage({
    required String localPath,
    required String userId,
    required String recipeId,
  }) async {
    if (kIsWeb) return null;
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final ext = localPath.split('.').last.toLowerCase();
      final storagePath = '$userId/$recipeId/${_uuid.v4()}.$ext';
      final bytes = await file.readAsBytes();

      await _client.storage.from(_bucket).uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(contentType: _mimeType(ext), upsert: true),
      );

      return _client.storage.from(_bucket).getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('[ImageStorageService] upload error: $e');
      return null;
    }
  }

  static String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
