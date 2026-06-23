/// A captured geographic point with GPS metadata and manual-edit tracking.
class GeoPoint {
  const GeoPoint({
    this.latitude,
    this.longitude,
    this.altitude,
    this.accuracy,
    this.coordinateWasEdited = false,
    this.originalLatitude,
    this.originalLongitude,
    this.capturedAt,
  });

  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? accuracy;
  final bool coordinateWasEdited;
  final double? originalLatitude;
  final double? originalLongitude;
  final String? capturedAt;

  bool get hasValue => latitude != null && longitude != null;

  GeoPoint copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    bool? coordinateWasEdited,
    double? originalLatitude,
    double? originalLongitude,
    String? capturedAt,
  }) {
    return GeoPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      coordinateWasEdited: coordinateWasEdited ?? this.coordinateWasEdited,
      originalLatitude: originalLatitude ?? this.originalLatitude,
      originalLongitude: originalLongitude ?? this.originalLongitude,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'accuracy': accuracy,
    'coordinate_was_edited': coordinateWasEdited,
    'original_latitude': originalLatitude,
    'original_longitude': originalLongitude,
    'captured_at': capturedAt,
  };

  static GeoPoint fromJson(Object? raw) {
    if (raw == null) return const GeoPoint();
    final json = Map<String, dynamic>.from(raw as Map);
    return GeoPoint(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      coordinateWasEdited: json['coordinate_was_edited'] as bool? ?? false,
      originalLatitude: (json['original_latitude'] as num?)?.toDouble(),
      originalLongitude: (json['original_longitude'] as num?)?.toDouble(),
      capturedAt: json['captured_at'] as String?,
    );
  }
}
