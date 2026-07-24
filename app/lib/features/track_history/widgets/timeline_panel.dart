import 'package:flutter/material.dart';
import '../models/timeline.dart';
import 'timeline_summary_card.dart';
import 'timeline_event_tile.dart';

class TimelinePanel extends StatelessWidget {
  final TimelineResponse timeline;

  const TimelinePanel({super.key, required this.timeline});

  @override
  Widget build(BuildContext context) {
    if (timeline.events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No events recorded for this day.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          TimelineSummaryCard(
            summary: timeline.summary,
            pointCount: timeline.metadata.pointCount,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: timeline.events.length,
              itemBuilder: (context, index) {
                final event = timeline.events[index];
                return TimelineEventTile(event: event);
              },
            ),
          ),
        ],
      ),
    );
  }
}
