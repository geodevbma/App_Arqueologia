import 'package:path/path.dart' as p;

/// Metadata for a photo captured during a "Poço teste" collection.
///
/// The app stores the local file path plus capture metadata. Binary upload to
/// the server is performed later (see ApiClient.uploadCollectionPhoto), and
/// [uploadStatus] tracks per-photo upload progress.
class PocoTestePhoto {
  const PocoTestePhoto({
    required this.localPath,
    required this.originalName,
    required this.type,
    this.fieldName,
    this.levelIndex,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.capturedAt,
    this.fileSize,
    this.uploadStatus = 'pending',
  });

  /// Local file system path of the captured image.
  final String localPath;

  /// Original file name (basename of [localPath]).
  final String originalName;

  /// Logical photo type, e.g. `foto_superficie`, `foto_abertura_pt`,
  /// `foto_material_superficie`, `foto_material_nivel`, `foto_solo`,
  /// `foto_peneira`, `foto_finalizacao`.
  final String type;

  /// The XLSForm field name this photo belongs to.
  final String? fieldName;

  /// 1-based level index when the photo belongs to a level, otherwise null.
  final int? levelIndex;

  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? capturedAt;
  final int? fileSize;

  /// `pending`, `uploaded` or `error`.
  final String uploadStatus;

  PocoTestePhoto copyWith({String? uploadStatus, int? levelIndex}) {
    return PocoTestePhoto(
      localPath: localPath,
      originalName: originalName,
      type: type,
      fieldName: fieldName,
      levelIndex: levelIndex ?? this.levelIndex,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      capturedAt: capturedAt,
      fileSize: fileSize,
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'local_path': localPath,
    'original_name': originalName,
    'type': type,
    if (fieldName != null) 'field_name': fieldName,
    if (levelIndex != null) 'level_index': levelIndex,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'created_at': capturedAt,
    'file_size': fileSize,
    'upload_status': uploadStatus,
  };

  static PocoTestePhoto? fromJson(Object? raw) {
    if (raw == null) return null;
    final json = Map<String, dynamic>.from(raw as Map);
    final localPath = json['local_path'] as String?;
    if (localPath == null || localPath.isEmpty) return null;
    return PocoTestePhoto(
      localPath: localPath,
      originalName: json['original_name'] as String? ?? p.basename(localPath),
      type: json['type'] as String? ?? 'foto',
      fieldName: json['field_name'] as String?,
      levelIndex: (json['level_index'] as num?)?.toInt(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      capturedAt: json['created_at'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      uploadStatus: json['upload_status'] as String? ?? 'pending',
    );
  }
}
