import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'farm_api.dart';

class GpsApi {
  Future<Map<String, dynamic>> status(String orchard) async {
    try {
      final uri = Uri.parse('${FarmApi.baseUrl}/api/gps/status')
          .replace(queryParameters: {'orchard': orchard});
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
      return {'ok': false, 'error': _message(r, 'GPS 상태 조회 실패')};
    } on TimeoutException {
      return {'ok': false, 'error': 'GPS 상태 조회 시간이 초과되었습니다.'};
    } catch (e) {
      return {'ok': false, 'error': 'GPS 상태 조회 연결 실패 (${e.runtimeType})'};
    }
  }

  Future<Map<String, dynamic>> save({
    required String orchard,
    required double lat,
    required double lon,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('${FarmApi.baseUrl}/api/gps/save'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'orchard': orchard, 'lat': lat, 'lon': lon}),
          )
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
      return {'ok': false, 'error': _message(r, 'GPS 저장 실패')};
    } on TimeoutException {
      return {'ok': false, 'error': 'GPS 저장 요청 시간이 초과되었습니다.'};
    } catch (e) {
      return {'ok': false, 'error': 'GPS 저장 서버 연결 실패 (${e.runtimeType})'};
    }
  }

  String _message(http.Response response, String fallback) {
    try {
      final j = jsonDecode(response.body);
      if (j is Map && j['detail'] != null) {
        return '${j['detail']} (HTTP ${response.statusCode})';
      }
    } catch (_) {}
    return '$fallback (HTTP ${response.statusCode})';
  }
}
