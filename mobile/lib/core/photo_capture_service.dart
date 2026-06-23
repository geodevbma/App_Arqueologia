import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/poco_teste_geo.dart';
import '../models/poco_teste_photo.dart';

/// Opens the camera and builds a [PocoTestePhoto] with capture metadata.
///
/// Keeps the same camera settings as the legacy collection form (quality 74,
/// max width 1600) so behavior stays consistent across the app.
class PhotoCaptureService {
  PhotoCaptureService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<PocoTestePhoto?> capture({
    required String type,
    String? fieldName,
    int? levelIndex,
    GeoPoint geo = const GeoPoint(),
  }) async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 74,
      maxWidth: 1600,
    );
    if (image == null) return null;
    int? size;
    try {
      size = await File(image.path).length();
    } on Object {
      size = null;
    }
    return PocoTestePhoto(
      localPath: image.path,
      originalName: p.basename(image.path),
      type: type,
      fieldName: fieldName,
      levelIndex: levelIndex,
      latitude: geo.latitude,
      longitude: geo.longitude,
      accuracy: geo.accuracy,
      capturedAt: DateTime.now().toIso8601String(),
      fileSize: size,
    );
  }
}
