import 'dart:async';
import 'dart:convert';

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
    final uri = Uri.parse('${FarmApi.baseUrl}/api/integrated/briefing').replace(
      queryParameters: {'orchard': orchard, 'refresh': refresh ? 'true' : 'false'},
    );
    final r = await FarmApi.getWithWakeup(uri);
    if (r?.statusCode == 200) {
      final data = Map<String, dynamic>.from(jsonDecode(r!.body));
      _cache[orchard] = data;
      _cacheAt[orchard] = DateTime.now();
      return data;
    }
    if (r != null) return _offline('통합 엔진 응답 오류 (${r.statusCode})', orchard: orchard);
    return _offline('운영 서버가 응답하지 않습니다. 서버가 깨어나는 중이면 잠시 후 다시 시도하세요.', orchard: orchard);
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
    final uri = Uri.parse('${FarmApi.baseUrl}/api/integrated/sync').replace(queryParameters: {'orchard': orchard});
    final r = await FarmApi.postWithWakeup(uri);
    if (r?.statusCode == 200) {
      final data = Map<String, dynamic>.from(jsonDecode(r!.body));
      if (data['briefing'] is Map) {
        final briefing = Map<String, dynamic>.from(data['briefing'] as Map);
        _cache[orchard] = briefing;
        _cacheAt[orchard] = DateTime.now();
      } else {
        invalidate(orchard);
      }
      return data;
    }
    if (r != null) return {'ok': false, 'message': '통합 작업 동기화 실패 (${r.statusCode})'};
    return {'ok': false, 'message': '운영 서버가 응답하지 않습니다. 잠시 후 다시 시도하세요.'};
  }

  Map<String, dynamic> _offline(String message, {String? orchard}) => {
        'orchard': {'name': orchard ?? _orchard},
        'actions': <dynamic>[],
        'engine_links': <String, dynamic>{},
        'offline_mode': true,
        'policy': message,
      };
}
