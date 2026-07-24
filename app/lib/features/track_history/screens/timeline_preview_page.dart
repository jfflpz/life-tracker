import 'package:flutter/material.dart';
import '../models/timeline.dart';
import '../widgets/timeline_panel.dart';

class TimelinePreviewPage extends StatelessWidget {
  const TimelinePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Generate some mock data for preview
    final mockTimeline = TimelineResponse(
      metadata: TimelineMetadata(
        version: 1,
        date: '2026-07-22',
        generatedAt: DateTime.now(),
        pointCount: 1542,
      ),
      summary: TimelineSummary(
        totalDistanceM: 14500.5,
        movingTimeSec: 4500, // 1h 15m
        stationaryTimeSec: 28800, // 8h
      ),
      events: [
        TimelineEvent(
          id: '1',
          type: 'stop',
          startTime: DateTime.now().subtract(const Duration(hours: 10)),
          endTime: DateTime.now().subtract(const Duration(hours: 2)),
          durationSec: 28800,
          locationName: 'Home',
        ),
        TimelineEvent(
          id: '2',
          type: 'moving',
          startTime: DateTime.now().subtract(const Duration(hours: 2)),
          endTime: DateTime.now().subtract(const Duration(minutes: 45)),
          durationSec: 4500,
          distanceM: 14500.5,
        ),
        TimelineEvent(
          id: '3',
          type: 'stop',
          startTime: DateTime.now().subtract(const Duration(minutes: 45)),
          endTime: DateTime.now(),
          durationSec: 2700,
          locationName: 'Extremely Long Location Name That Might Wrap Or Overflow If Not Handled Properly By The Widget',
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline Widget Preview'),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: TimelinePanel(timeline: mockTimeline),
      ),
    );
  }
}
