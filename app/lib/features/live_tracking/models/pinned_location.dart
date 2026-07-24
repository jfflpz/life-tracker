import 'package:latlong2/latlong.dart';

class PinnedLocation {
  final String id;
  final String label;
  final LatLng location;
  final double radiusM;

  PinnedLocation({
    required this.id,
    required this.label,
    required this.location,
    required this.radiusM,
  });

  factory PinnedLocation.fromJson(Map<String, dynamic> json) {
    return PinnedLocation(
      id: json['id'],
      label: json['label'],
      location: LatLng(json['location'][1], json['location'][0]), // Backend returns [lon, lat]
      radiusM: json['radius_m']?.toDouble() ?? 100.0,
    );
  }
}
