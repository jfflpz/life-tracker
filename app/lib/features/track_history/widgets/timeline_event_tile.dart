import 'package:flutter/material.dart';
import '../models/timeline.dart';

class TimelineEventTile extends StatelessWidget {
  final TimelineEvent event;

  const TimelineEventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(context),
          const SizedBox(width: 16.0),
          Expanded(child: _buildDetails(context)),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final bool isStop = event.isStop;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isStop
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isStop ? Icons.location_on : Icons.directions_run,
        color: isStop
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSecondaryContainer,
        size: 24,
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.isStop ? (event.locationName ?? 'Unknown Location') : 'Moving',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4.0),
        Row(
          children: [
            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4.0),
            Text(
              '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4.0),
            Text(
              _formatDuration(event.durationSec),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (event.isMoving && event.distanceM != null) ...[
              const SizedBox(width: 12.0),
              Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4.0),
              Text(
                '${(event.distanceM! / 1000).toStringAsFixed(2)} km',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds s';
    final m = seconds ~/ 60;
    if (m < 60) return '$m m';
    final h = m ~/ 60;
    final remainingM = m % 60;
    return '${h}h ${remainingM}m';
  }
}
