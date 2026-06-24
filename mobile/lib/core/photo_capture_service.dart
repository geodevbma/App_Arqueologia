import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/poco_teste_geo.dart';
import '../models/poco_teste_photo.dart';
import 'watermark_service.dart';

/// Opens the camera or the gallery, burns a date/time + UTM watermark into the
/// resulting image and builds a [PocoTestePhoto] with capture metadata.
///
/// Keeps the same image settings as the legacy collection form (quality 74,
/// max width 1600) so behavior stays consistent across the app.
class PhotoCaptureService {
  PhotoCaptureService({ImagePicker? picker, WatermarkService? watermark})
    : _picker = picker ?? ImagePicker(),
      _watermark = watermark ?? const WatermarkService();

  final ImagePicker _picker;
  final WatermarkService _watermark;

  Future<PocoTestePhoto?> capture({
    required String type,
    ImageSource source = ImageSource.camera,
    String? fieldName,
    int? levelIndex,
    GeoPoint geo = const GeoPoint(),
  }) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 74,
      maxWidth: 1600,
    );
    if (image == null) return null;

    final capturedAt = DateTime.now();
    await _watermark.apply(
      image.path,
      latitude: geo.latitude,
      longitude: geo.longitude,
      accuracy: geo.accuracy,
      capturedAt: capturedAt,
    );

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
      capturedAt: capturedAt.toIso8601String(),
      fileSize: size,
    );
  }
}
