import 'dart:convert';

import 'package:http/http.dart' as http;

import 'farm_api.dart';
import 'orchard_selection.dart';

class PhenologyApi {
  Future<Map<String, dynamic>> calendar() async {
    final orchard = OrchardSelection.name;
    try {
      final uri = Uri.parse('${FarmApi.baseUrl}/api/annual/phenology').replace(
        queryParameters: {'orchard': orchard},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      return {'error': '연간 농작업 조회 실패 (HTTP ${response.statusCode})'};
    } catch (e) {
      return {'error': '연간 농작업 서버 연결 실패 (${e.runtimeType})'};
    }
  }
}
