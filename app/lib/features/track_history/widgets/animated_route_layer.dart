import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AnimatedRouteLayer extends StatelessWidget {
  final List<LatLng> routePoints;
  final Animation<double> animation;

  const AnimatedRouteLayer({
    super.key,
    required this.routePoints,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    if (routePoints.isEmpty) {
      return const SizedBox.shrink();
    }

    if (routePoints.length < 3) {
      // Too short to animate effectively, just draw it statically
      return PolylineLayer(
        polylines: [
          Polyline(
            points: routePoints,
            color: Colors.blue,
            strokeWidth: 4.0,
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final currentPointCount = (routePoints.length * animation.value).ceil();
        
        // Ensure at least 0 points, at most full length
        final clampedCount = currentPointCount.clamp(0, routePoints.length);
        
        // Draw the visible portion
        final visiblePoints = routePoints.take(clampedCount).toList();

        // Polyline requires at least 2 points to render without errors
        if (visiblePoints.length < 2) {
          return const SizedBox.shrink();
        }

        return PolylineLayer(
          polylines: [
            Polyline(
              points: visiblePoints,
              color: Colors.blue,
              strokeWidth: 4.0,
            ),
          ],
        );
      },
    );
  }
}
