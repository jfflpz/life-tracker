import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/local_db/database_helper.dart';

void main() {
  test('fetch track', () async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    print('Date: $date');
    
    // Test SQLite interaction on device? SQLite doesn't work in standard flutter test unless sqflite_common_ffi is used.
    // Instead, let's just test ApiClient
    final apiClient = ApiClient();
    final apiTrack = await apiClient.getDailyTrack(date);
    if (apiTrack != null) {
      print('API points: ${apiTrack.routePoints.length}');
    } else {
      print('API track is null');
    }
  });
}
