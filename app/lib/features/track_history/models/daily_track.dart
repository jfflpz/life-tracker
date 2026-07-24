import 'package:latlong2/latlong.dart';

class DailyTrack {
  final String id;
  final String date;
  final double distanceMeters;
  final int pointCount;
  final List<LatLng> routePoints;

  DailyTrack({
    required this.id,
    required this.date,
    required this.distanceMeters,
    required this.pointCount,
    required this.routePoints,
  });

  factory DailyTrack.fromJson(Map<String, dynamic> json) {
    // We expect the GeoJSON FeatureCollection format we built in FastAPI
    final feature = json['features'][0];
    final props = feature['properties'];
    final geometry = feature['geometry'];

    // GeoJSON LineString coordinates are [lon, lat]
    // LatLng expects (lat, lon), so we have to flip them!
    final coordsList = geometry['coordinates'] as List;
    final List<LatLng> points = coordsList.map((coord) {
      return LatLng(coord[1].toDouble(), coord[0].toDouble());
    }).toList();

    return DailyTrack(
      id: props['id'],
      date: props['date'],
      distanceMeters: (props['distance_m'] ?? 0).toDouble(),
      pointCount: props['points'] ?? 0,
      routePoints: points,
    );
  }
}
