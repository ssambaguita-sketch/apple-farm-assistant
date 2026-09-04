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
      return {'error': _message(r.body, '과수원 등록 실패')};
    } catch (_) {
      return {'error': '서버 연결 실패'};
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
      return {'error': _message(r.body, '과수원 수정 실패')};
    } catch (_) {
      return {'error': '서버 연결 실패'};
    }
  }

  String _message(String body, String fallback) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['detail'] != null) return '${j['detail']}';
    } catch (_) {}
    return fallback;
  }
}
