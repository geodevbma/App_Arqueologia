import 'dart:math';

/// Converts WGS84 latitude/longitude (decimal degrees) to a formatted UTM
/// coordinate string, e.g. `"23K 612345mE 7812345mN"`.
///
/// Uses Snyder's transverse Mercator forward series (same model as standard
/// WGS84 UTM). Accuracy is well within a meter for typical field use.
String latLonToUtm(double lat, double lon) {
  const a = 6378137.0; // WGS84 semi-major axis
  const f = 1 / 298.257223563; // WGS84 flattening
  const k0 = 0.9996;
  final e2 = f * (2 - f);
  final ep2 = e2 / (1 - e2);

  final zone = ((lon + 180) / 6).floor() + 1;
  final lonOrigin = (zone - 1) * 6 - 180 + 3;

  final latRad = lat * pi / 180;
  final lonRad = lon * pi / 180;
  final lonOriginRad = lonOrigin * pi / 180;

  final n = a / sqrt(1 - e2 * sin(latRad) * sin(latRad));
  final t = tan(latRad) * tan(latRad);
  final c = ep2 * cos(latRad) * cos(latRad);
  final aa = cos(latRad) * (lonRad - lonOriginRad);
  final m = a *
      ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256) * latRad -
          (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * e2 * e2 * e2 / 1024) *
              sin(2 * latRad) +
          (15 * e2 * e2 / 256 + 45 * e2 * e2 * e2 / 1024) * sin(4 * latRad) -
          (35 * e2 * e2 * e2 / 3072) * sin(6 * latRad));

  final easting = k0 *
          n *
          (aa +
              (1 - t + c) * pow(aa, 3) / 6 +
              (5 - 18 * t + t * t + 72 * c - 58 * ep2) * pow(aa, 5) / 120) +
      500000.0;
  var northing = k0 *
      (m +
          n *
              tan(latRad) *
              (aa * aa / 2 +
                  (5 - t + 9 * c + 4 * c * c) * pow(aa, 4) / 24 +
                  (61 - 58 * t + t * t + 600 * c - 330 * ep2) *
                      pow(aa, 6) /
                      720));
  if (lat < 0) northing += 10000000.0;

  final band = _latBand(lat);
  return '$zone$band ${easting.toStringAsFixed(0)}mE ${northing.toStringAsFixed(0)}mN';
}

/// UTM/MGRS latitude band letter for [lat] (degrees). Returns 'Z' if outside
/// the standard -80..84 range.
String _latBand(double lat) {
  if (lat < -80 || lat > 84) return 'Z';
  const bands = 'CDEFGHJKLMNPQRSTUVWX';
  var index = ((lat + 80) / 8).floor();
  if (index >= bands.length) index = bands.length - 1;
  return bands[index];
}
