import 'package:flutter/material.dart';
import '../../models/monthly_summary.dart';

class ActivityMarker extends StatelessWidget {
  final ActiveDay activeDay;

  const ActivityMarker({super.key, required this.activeDay});

  @override
  Widget build(BuildContext context) {
    // Heatmap style coloring based on distance
    Color markerColor = Colors.green.shade300;
    
    if (activeDay.distanceM > 15000) {
      markerColor = Colors.green.shade900;
    } else if (activeDay.distanceM > 8000) {
      markerColor = Colors.green.shade700;
    } else if (activeDay.distanceM > 3000) {
      markerColor = Colors.green.shade500;
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: markerColor,
      ),
      width: 8.0,
      height: 8.0,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
    );
  }
}
