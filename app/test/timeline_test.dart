import 'package:flutter_test/flutter_test.dart';
import '../lib/core/network/api_client.dart';
void main() {
  test('fetch timeline', () async {
    final client = ApiClient();
    final timeline = await client.getDailyTimeline('2026-07-22');
    expect(timeline, isNotNull);
    expect(timeline!.metadata.version, 1);
    expect(timeline.events.isNotEmpty, true);
    print('Parsed correctly, events length: ${timeline.events.length}');
  });
}
