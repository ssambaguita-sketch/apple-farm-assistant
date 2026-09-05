import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'farm_api.dart';
import 'orchard_selection.dart';

class IntegratedApi {
  static final Map<String, Map<String, dynamic>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static const Duration _ttl = Duration(seconds: 30);

  String get _orchard => OrchardSelection.name.trim().isEmpty ? 'A과수원' : OrchardSelection.name.trim();

  void invalidate([String? orchard]) {
    if (orchard == null) {
      _cache.clear();
      _cacheAt.clear();
      return;
    }
    _cache.remove(orchard);
    _cacheAt.remove(orchard);
  }

  Future<Map<String, dynamic>> briefing({bool refresh = false}) async {
    final orchard = _orchard;
    final at = _cacheAt[orchard];
    if (!refresh && at != null && DateTime.now().difference(at) < _ttl && _cache[orchard] != null) {
      return _cache[orchard]!;
    }

    try {
      final uri = Uri.parse('${FarmApi.baseUrl}/api/integrated/briefing').replace(
        queryParameters: {'orchard': orchard, 'refresh': refresh ? 'true' : 'false'},
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(r.body));
        _cache[orchard] = data;
        _cacheAt[orchard] = DateTime.now();
        return data;
      }
    } catch (_) {}

    return {
      'orchard': {'name': orchard},
      'actions': <dynamic>[],
      'engine_links': <String, dynamic>{},
      'offline_mode': true,
      'policy': '통합 엔진 서버 연결에 실패했습니다.',
    };
  }

  Future<Map<String, dynamic>> syncTasks() async {
    final orchard = _orchard;
    try {
      final uri = Uri.parse('${FarmApi.baseUrl}/api/integrated/sync').replace(queryParameters: {'orchard': orchard});
      final r = await http.post(uri).timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(r.body));
        if (data['briefing'] is Map) {
          final briefing = Map<String, dynamic>.from(data['briefing'] as Map);
          _cache[orchard] = briefing;
          _cacheAt[orchard] = DateTime.now();
        } else {
          invalidate(orchard);
        }
        return data;
      }
      return {'ok': false, 'message': '통합 작업 동기화 실패 (${r.statusCode})'};
    } catch (e) {
      return {'ok': false, 'message': '통합 작업 동기화 실패: $e'};
    }
  }
}
