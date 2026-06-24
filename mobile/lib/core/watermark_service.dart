import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'utm.dart';

/// Burns a date/time + coordinate watermark into a photo file, in place.
///
/// The work (decode/draw/encode) runs in a background isolate via [compute] to
/// keep the UI responsive. Failures are swallowed so a watermark problem never
/// blocks the collection workflow — the original photo is kept as-is.
class WatermarkService {
  const WatermarkService();

  Future<void> apply(
    String path, {
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? capturedAt,
  }) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final lines = buildLines(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        capturedAt: capturedAt ?? DateTime.now(),
      );
      final stamped = await compute(
        _burnWatermark,
        _WatermarkRequest(bytes, lines),
      );
      if (stamped != null) {
        await file.writeAsBytes(stamped, flush: true);
      }
    } on Object {
      // Best-effort: keep the original photo if anything goes wrong.
    }
  }

  /// The text lines drawn onto the image (also reused for tests).
  static List<String> buildLines({
    double? latitude,
    double? longitude,
    double? accuracy,
    required DateTime capturedAt,
  }) {
    final lines = <String>[
      DateFormat('dd/MM/yyyy HH:mm:ss').format(capturedAt),
    ];
    if (latitude != null && longitude != null) {
      lines.add(latLonToUtm(latitude, longitude));
      final acc = accuracy != null ? ' (+-${accuracy.toStringAsFixed(0)}m)' : '';
      lines.add(
        'Lat ${latitude.toStringAsFixed(6)}  Lon ${longitude.toStringAsFixed(6)}$acc',
      );
    } else {
      lines.add('Sem coordenada GPS');
    }
    return lines;
  }
}

class _WatermarkRequest {
  const _WatermarkRequest(this.bytes, this.lines);
  final Uint8List bytes;
  final List<String> lines;
}

/// Top-level so it can run inside [compute].
Uint8List? _burnWatermark(_WatermarkRequest request) {
  final image = img.decodeImage(request.bytes);
  if (image == null) return null;

  final font = img.arial24;
  const padding = 12;
  const lineHeight = 30;
  final stripHeight = request.lines.length * lineHeight + padding * 2;
  final top = (image.height - stripHeight).clamp(0, image.height);

  // Dark band for legibility.
  img.fillRect(
    image,
    x1: 0,
    y1: top,
    x2: image.width - 1,
    y2: image.height - 1,
    color: img.ColorRgb8(0, 0, 0),
  );

  var y = top + padding;
  for (final line in request.lines) {
    img.drawString(
      image,
      line,
      font: font,
      x: padding,
      y: y,
      color: img.ColorRgb8(255, 255, 255),
    );
    y += lineHeight;
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 82));
}
