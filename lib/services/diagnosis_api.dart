import 'dart:convert';
import 'package:http/http.dart' as http;
import 'farm_api.dart';
import 'orchard_selection.dart';

class DiagnosisApi {
  Future<Map<String, dynamic>> assess(Map<String, dynamic> payload) async {
    final body = Map<String, dynamic>.from(payload);
    body['orchard'] = OrchardSelection.name;
    try {
      final r = await http
          .post(
            Uri.parse('${FarmApi.baseUrl}/api/diagnosis/assess'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
      return {'error': '서버 응답 ${r.statusCode}'};
    } catch (e) {
      return {'error': '진단 API 연결 실패'};
    }
  }
}
