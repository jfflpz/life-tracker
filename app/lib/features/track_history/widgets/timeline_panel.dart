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

    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 16.0,
      ),
      itemCount: timeline.events.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return TimelineSummaryCard(
            summary: timeline.summary,
            pointCount: timeline.metadata.pointCount,
          );
        }
        final event = timeline.events[index - 1];
        return TimelineEventTile(event: event);
      },
    );
  }
}
