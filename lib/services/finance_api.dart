import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'farm_api.dart';
import 'orchard_selection.dart';

class FinanceApi {
  static const _timeout = Duration(seconds: 12);

  String get _orchard => OrchardSelection.name.trim().isEmpty ? 'A과수원' : OrchardSelection.name.trim();

  Future<Map<String, dynamic>> summary() async {
    final u = Uri.parse('${FarmApi.baseUrl}/api/finance/summary').replace(queryParameters: {'orchard': _orchard});
    final r = await http.get(u).timeout(_timeout);
    if (r.statusCode != 200) throw Exception('경영 요약 조회 실패 (${r.statusCode})');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<List<Map<String, dynamic>>> list({int limit = 100}) async {
    final u = Uri.parse('${FarmApi.baseUrl}/api/finance').replace(queryParameters: {
      'orchard': _orchard,
      'limit': '$limit',
    });
    final r = await http.get(u).timeout(_timeout);
    if (r.statusCode != 200) throw Exception('경영 내역 조회 실패 (${r.statusCode})');
    final raw = jsonDecode(r.body) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> add({
    required String type,
    required String category,
    required double amount,
    double quantityKg = 0,
    String note = '',
  }) async {
    final r = await http
        .post(
          Uri.parse('${FarmApi.baseUrl}/api/finance/entry'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'orchard': _orchard,
            'type': type,
            'category': category,
            'amount': amount,
            'quantity_kg': quantityKg,
            'note': note,
          }),
        )
        .timeout(_timeout);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('경영 내역 저장 실패 (${r.statusCode})');
    }
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<Map<String, dynamic>> check() async {
    final u = Uri.parse('${FarmApi.baseUrl}/api/finance/check').replace(queryParameters: {'orchard': _orchard});
    final r = await http.get(u).timeout(_timeout);
    if (r.statusCode != 200) throw Exception('경영 기능 점검 실패 (${r.statusCode})');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }
}
