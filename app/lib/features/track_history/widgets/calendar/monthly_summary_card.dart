import 'package:flutter/material.dart';
import '../../models/monthly_summary.dart';

class MonthlySummaryCard extends StatelessWidget {
  final SummaryStats? stats;
  final bool isLoading;

  const MonthlySummaryCard({
    super.key,
    required this.stats,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        margin: EdgeInsets.all(16.0),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              height: 24.0,
              width: 24.0,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
          ),
        ),
      );
    }

    if (stats == null) {
      return const Card(
        margin: EdgeInsets.all(16.0),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('No data for this month.'),
          ),
        ),
      );
    }

    final distanceKm = (stats!.totalDistanceM / 1000).toStringAsFixed(1);
    final movingHours = (stats!.movingTimeSec / 3600).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatCol('Active Days', '${stats!.activeDaysCount}', Icons.calendar_today),
            _buildStatCol('Distance', '${distanceKm}km', Icons.directions_walk),
            _buildStatCol('Moving', '${movingHours}h', Icons.timer),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: Colors.blueGrey),
        const SizedBox(height: 8.0),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
