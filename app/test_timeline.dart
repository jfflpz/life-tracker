import 'dart:io';
import 'package:dio/dio.dart';
import 'lib/core/network/api_client.dart';

void main() async {
  final client = ApiClient();
  print('Fetching timeline for 2026-07-22...');
  final timeline = await client.getDailyTimeline('2026-07-22');
  if (timeline != null) {
    print('Parsed successfully!');
    print('Version: ${timeline.metadata.version}');
    print('Events: ${timeline.events.length}');
    print('Total Distance: ${timeline.summary.totalDistanceM}');
    print('First event ID: ${timeline.events.first.id}');
    exit(0);
  } else {
    print('Failed to parse or fetch!');
    exit(1);
  }
}
