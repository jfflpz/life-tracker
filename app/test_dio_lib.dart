import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(baseUrl: 'http://192.168.100.57:8000/api/v1'));
  
  // Try with leading slash
  try {
    print('Testing /daily/2026-07-24');
    final r1 = await dio.get('/daily/2026-07-24');
    print(r1.realUri);
  } catch (e) {
    if (e is DioException) print(e.requestOptions.uri);
  }

  // Try without leading slash
  try {
    print('Testing daily/2026-07-24');
    final r2 = await dio.get('daily/2026-07-24');
    print(r2.realUri);
  } catch (e) {
    if (e is DioException) print(e.requestOptions.uri);
  }
}
