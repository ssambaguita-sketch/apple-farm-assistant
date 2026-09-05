import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'farm_api.dart';
import 'orchard_selection.dart';

class IntegratedApi {
  static final Map<String, Map<String, dynamic>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<Map<String, dynamic>>> _briefingInFlight = {};
  static final Map<String, Future<Map<String, dynamic>>> _syncInFlight = {};
  static const Duration _ttl = Duration(seconds: 45);

  String get _orchard => OrchardSelection.name.trim();

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
    if (orchard.isEmpty) return _offline('선택된 과수원이 없습니다.');

    final at = _cacheAt[orchard];
    if (!refresh && at != null && DateTime.now().difference(at) < _ttl && _cache[orchard] != null) {
      return _cache[orchard]!;
    }

    final existing = _briefingInFlight[orchard];
    if (existing != null) return existing;

    final request = _fetchBriefing(orchard, refresh: refresh);
    _briefingInFlight[orchard] = request;
    try {
      return await request;
    } finally {
      if (identical(_briefingInFlight[orchard], request)) {
        _briefingInFlight.remove(orchard);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchBriefing(String orchard, {required bool refresh}) async {
    try {
      final uri = Uri.parse('${FarmApi.baseUrl}/api/integrated/briefing').replace(
        queryParameters: {'orchard': orchard, 'refresh': refresh ? 'true' : 'false'},
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(r.body));
        _cache[orchard] = data;
        _cacheAt[orchard] = DateTime.now();
        return data;
      }
      return _offline('통합 엔진 응답 오류 (${r.statusCode})', orchard: orchard);
    } catch (_) {
      return _offline('통합 엔진 서버 연결에 실패했습니다.', orchard: orchard);
    }
  }

  Future<Map<String, dynamic>> syncTasks() async {
    final orchard = _orchard;
    if (orchard.isEmpty) return {'ok': false, 'message': '선택된 과수원이 없습니다.'};

    final existing = _syncInFlight[orchard];
    if (existing != null) return existing;

    final request = _syncTasks(orchard);
    _syncInFlight[orchard] = request;
    try {
      return await request;
    } finally {
      if (identical(_syncInFlight[orchard], request)) {
        _syncInFlight.remove(orchard);
      }
    }
  }

  Future<Map<String, dynamic>> _syncTasks(String orchard) async {
    try {
      final uri = Uri.parse('${FarmApi.baseUrl}/api/integrated/sync').replace(queryParameters: {'orchard': orchard});
      final r = await http.post(uri).timeout(const Duration(seconds: 20));
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

  Map<String, dynamic> _offline(String message, {String? orchard}) => {
        'orchard': {'name': orchard ?? _orchard},
        'actions': <dynamic>[],
        'engine_links': <String, dynamic>{},
        'offline_mode': true,
        'policy': message,
      };
}
