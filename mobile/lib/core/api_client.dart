import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'local_store.dart';

class ApiClient {
  ApiClient(this.store);

  static const defaultBaseUrl = 'http://10.0.0.2:8003';

  final LocalStore store;

  Future<Dio> _dio() async {
    final configuredBaseUrl = await store.setting('api_url');
    final baseUrl =
        configuredBaseUrl == null || configuredBaseUrl.trim().isEmpty
        ? defaultBaseUrl
        : configuredBaseUrl.trim();
    final token = await store.setting('token');
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 24),
        headers: token == null || token.isEmpty
            ? null
            : {'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<void> login(String email, String password) async {
    final dio = await _dio();
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await store.setSetting('token', response.data!['access_token'] as String);
  }

  Future<void> bootstrap() async {
    final dio = await _dio();
    final response = await dio.get<Map<String, dynamic>>('/mobile/bootstrap');
    await store.saveBootstrap(response.data!);
  }

  Future<Map<String, dynamic>> syncPending() async {
    final dio = await _dio();
    final pending = await store.collections(onlyPending: true);
    final byUuid = {
      for (final collection in pending)
        collection['local_uuid'] as String: collection,
    };
    final response = await dio.post<Map<String, dynamic>>(
      '/mobile/sync',
      data: {
        'device_id': 'android-${const Uuid().v4()}',
        'collections': pending,
      },
    );
    final synced = response.data?['synced'] as List<dynamic>? ?? [];
    for (final item in synced) {
      final row = Map<String, dynamic>.from(item as Map);
      final localUuid = row['local_uuid'] as String;
      final serverUuid = row['server_uuid'] as String;
      await store.markSynced(localUuid, serverUuid);
      // Best-effort binary upload of any photos. Failures never break sync;
      // the local metadata/paths remain intact for a later retry.
      await _uploadPhotosBestEffort(serverUuid, byUuid[localUuid]);
    }
    return response.data ?? {'synced': [], 'errors': []};
  }

  /// Uploads every photo found in [payload] to the dedicated photo endpoint.
  /// Errors are swallowed on purpose so an unavailable endpoint does not break
  /// the structured-data sync flow.
  Future<void> _uploadPhotosBestEffort(
    String collectionId,
    Map<String, dynamic>? payload,
  ) async {
    if (payload == null) return;
    final photos = _extractPhotos(payload);
    if (photos.isEmpty) return;
    for (final photo in photos) {
      try {
        await uploadCollectionPhoto(collectionId: collectionId, photo: photo);
      } on Object {
        // Ignore: keep local copy for a future retry.
      }
    }
  }

  /// Uploads a single photo via multipart/form-data. Returns true on a 2xx.
  Future<bool> uploadCollectionPhoto({
    required String collectionId,
    required Map<String, dynamic> photo,
  }) async {
    final path = photo['local_path'] as String?;
    if (path == null || path.isEmpty) return false;
    final file = File(path);
    if (!await file.exists()) return false;
    final dio = await _dio();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: photo['original_name'] as String?,
      ),
      'photo_type': photo['type'],
      if (photo['field_name'] != null) 'field_name': photo['field_name'],
      if (photo['level_index'] != null) 'level_index': photo['level_index'],
      if (photo['created_at'] != null) 'captured_at': photo['created_at'],
      if (photo['latitude'] != null) 'latitude': photo['latitude'],
      if (photo['longitude'] != null) 'longitude': photo['longitude'],
      if (photo['accuracy'] != null) 'accuracy': photo['accuracy'],
    });
    final response = await dio.post<dynamic>(
      '/mobile/collections/$collectionId/photos',
      data: form,
    );
    final status = response.statusCode ?? 0;
    return status >= 200 && status < 300;
  }

  /// Recursively collects every photo metadata map (objects that carry both a
  /// `local_path` and a `type`) from an arbitrary collection payload.
  List<Map<String, dynamic>> _extractPhotos(Object? node) {
    final out = <Map<String, dynamic>>[];
    void walk(Object? current) {
      if (current is Map) {
        if (current['local_path'] is String && current['type'] is String) {
          out.add(Map<String, dynamic>.from(current));
        }
        current.values.forEach(walk);
      } else if (current is List) {
        current.forEach(walk);
      }
    }

    walk(node);
    return out;
  }
}
