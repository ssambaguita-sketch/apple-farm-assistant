import 'dart:convert';

import 'package:http/http.dart' as http;

import 'farm_api.dart';
import 'orchard_selection.dart';

class WeedApi {
  Future<Map<String, dynamic>> assess({
    required String zone,
    required double coveragePct,
    required String distribution,
    required String growthStage,
    required String weedGroup,
    required bool survivorSeen,
    required int daysAfterLastSpray,
    required int photoCount,
    String note = '',
  }) async {
    final payload = {
      'orchard': OrchardSelection.name,
      'zone': zone,
      'coverage_pct': coveragePct,
      'distribution': distribution,
      'growth_stage': growthStage,
      'weed_group': weedGroup,
      'survivor_seen': survivorSeen,
      'days_after_last_spray': daysAfterLastSpray,
      'photo_count': photoCount,
      'note': note,
    };
    try {
      final r = await http
          .post(
            Uri.parse('${FarmApi.baseUrl}/api/weeds/camera-assess'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(r.body));
      return {'error': '서버 응답 ${r.statusCode}'};
    } catch (_) {
      return {'error': '잡초 카메라 분석 API 연결 실패'};
    }
  }

  Future<List<Map<String, dynamic>>> history({String zone = ''}) async {
    try {
      final u = Uri.parse('${FarmApi.baseUrl}/api/weeds/history').replace(queryParameters: {
        'orchard': OrchardSelection.name,
        'zone': zone,
      });
      final r = await http.get(u).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return [];
      final raw = jsonDecode(r.body) as List;
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
