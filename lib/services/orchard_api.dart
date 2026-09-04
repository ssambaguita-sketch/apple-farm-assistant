import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'farm_api.dart';

class OrchardApi {
  Future<List<Map<String, dynamic>>> list() async {
    try {
      final r = await http
          .get(Uri.parse('${FarmApi.baseUrl}/api/orchards'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final raw = jsonDecode(r.body) as List;
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required List<String> varieties,
    double areaM2 = 0,
    int treeCount = 0,
    String growthStage = '',
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('${FarmApi.baseUrl}/api/orchards/multi'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'varieties': varieties,
              'area_m2': areaM2,
              'tree_count': treeCount,
              'growth_stage': growthStage,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
      return {'error': _message(r, '과수원 등록 실패')};
    } on TimeoutException {
      return {'error': '서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도하세요.'};
    } catch (e) {
      return {'error': '서버 연결 실패 (${e.runtimeType})'};
    }
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required String name,
    required List<String> varieties,
    double areaM2 = 0,
    int treeCount = 0,
    String growthStage = '',
  }) async {
    try {
      final r = await http
          .put(
            Uri.parse('${FarmApi.baseUrl}/api/orchards/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'varieties': varieties,
              'area_m2': areaM2,
              'tree_count': treeCount,
              'growth_stage': growthStage,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
      return {'error': _message(r, '과수원 수정 실패')};
    } on TimeoutException {
      return {'error': '과수원 수정 요청 시간이 초과되었습니다. 서버가 깨어난 뒤 다시 시도하세요.'};
    } catch (e) {
      return {'error': '과수원 수정 서버 연결 실패 (${e.runtimeType})'};
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
