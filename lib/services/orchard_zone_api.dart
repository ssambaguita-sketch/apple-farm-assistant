import 'dart:convert';
import 'package:http/http.dart' as http;
import 'farm_api.dart';

class OrchardZoneApi {
  Future<List<Map<String, dynamic>>> list(String orchard) async {
    try {
      final u = Uri.parse('${FarmApi.baseUrl}/api/orchard-zones')
          .replace(queryParameters: {'orchard': orchard});
      final r = await http.get(u).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data is List) {
          return data.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> create({
    required String orchard,
    required String zoneName,
    required String variety,
    int treeCount = 0,
    double areaM2 = 0,
    String growthStage = '',
    String note = '',
  }) async {
    return _write(
      'POST',
      Uri.parse('${FarmApi.baseUrl}/api/orchard-zones'),
      {
        'orchard': orchard,
        'zone_name': zoneName,
        'variety': variety,
        'tree_count': treeCount,
        'area_m2': areaM2,
        'growth_stage': growthStage,
        'note': note,
      },
    );
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required String zoneName,
    required String variety,
    int treeCount = 0,
    double areaM2 = 0,
    String growthStage = '',
    String note = '',
  }) async {
    return _write(
      'PUT',
      Uri.parse('${FarmApi.baseUrl}/api/orchard-zones/$id'),
      {
        'zone_name': zoneName,
        'variety': variety,
        'tree_count': treeCount,
        'area_m2': areaM2,
        'growth_stage': growthStage,
        'note': note,
      },
    );
  }

  Future<bool> delete(int id) async {
    try {
      final r = await http.delete(Uri.parse('${FarmApi.baseUrl}/api/orchard-zones/$id'))
          .timeout(const Duration(seconds: 20));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _write(String method, Uri uri, Map<String, dynamic> body) async {
    try {
      late http.Response r;
      final headers = {'Content-Type': 'application/json'};
      if (method == 'POST') {
        r = await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
      } else {
        r = await http.put(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
      }
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
      try {
        final j = Map<String, dynamic>.from(jsonDecode(r.body));
        return {'error': j['detail'] ?? '서버 응답 ${r.statusCode}'};
      } catch (_) {
        return {'error': '서버 응답 ${r.statusCode}'};
      }
    } catch (_) {
      return {'error': '과수원 구역 API 연결 실패'};
    }
  }
}
