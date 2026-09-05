import 'package:flutter/material.dart';

import 'services/farm_api.dart';
import 'services/orchard_selection.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  final api = FarmApi();
  Map<String, dynamic> data = const {};
  bool loading = false;
  bool _reloadAgain = false;
  DateTime? _lastLoadedAt;
  String _lastLoadedOrchard = '';

  String get orchard => OrchardSelection.name.trim();

  @override
  void initState() {
    super.initState();
    OrchardSelection.notifier.addListener(_orchardChanged);
    reload(force: true);
  }

  @override
  void dispose() {
    OrchardSelection.notifier.removeListener(_orchardChanged);
    super.dispose();
  }

  void _orchardChanged() {
    _lastLoadedAt = null;
    reload(force: true);
  }

  Future<void> reload({bool force = false}) async {
    if (!mounted) return;
    final targetOrchard = orchard;
    if (targetOrchard.isEmpty) return;

    final fresh = _lastLoadedAt != null &&
        _lastLoadedOrchard == targetOrchard &&
        DateTime.now().difference(_lastLoadedAt!) < const Duration(seconds: 15);
    if (!force && fresh) return;

    if (loading) {
      _reloadAgain = _reloadAgain || force || _lastLoadedOrchard != targetOrchard;
      return;
    }

    do {
      _reloadAgain = false;
      final requestOrchard = orchard;
      if (!mounted || requestOrchard.isEmpty) return;
      setState(() => loading = true);
      final result = await api.dashboard(requestOrchard);
      if (!mounted) return;
      if (requestOrchard == orchard) {
        setState(() {
          data = result;
          loading = false;
          _lastLoadedAt = DateTime.now();
          _lastLoadedOrchard = requestOrchard;
        });
      } else {
        setState(() => loading = false);
        _reloadAgain = true;
      }
    } while (_reloadAgain && mounted);
  }

  Widget _evidenceRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('$label: $value')),
          ],
        ),
      );

  Widget _recommendationCard(dynamic raw) {
    final x = Map<String, dynamic>.from(raw as Map);
    final evidence = x['decision_evidence'] is Map
        ? Map<String, dynamic>.from(x['decision_evidence'] as Map)
        : <String, dynamic>{};
    final confidence = '${x['confidence'] ?? data['recommendation_confidence'] ?? '-'}';
    final when = '${x['recommended_time'] ?? x['scheduled_at'] ?? '오늘'}';
    final reason = '${x['reason'] ?? '판단근거가 제공되지 않았습니다.'}';
    final source = '${evidence['weather_source'] ?? data['weather_source'] ?? 'unknown'}';
    final stage = '${evidence['growth_stage'] ?? '미등록'}';
    final risk = '${evidence['recent_max_risk'] ?? '-'}';
    final obsCount = '${evidence['recent_observation_count'] ?? '-'}';
    final temp = '${evidence['forecast_max_temp_c'] ?? '-'}';
    final pop = '${evidence['forecast_max_rain_probability_pct'] ?? '-'}';
    final wind = '${evidence['forecast_max_wind_ms'] ?? '-'}';
    final score = '${evidence['best_work_score'] ?? '-'}';

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.auto_awesome),
        title: Text('${x['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('추천시간 $when · 신뢰도 $confidence'),
        trailing: Text('P${x['priority'] ?? 2}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('왜 이 작업을 추천했나요?', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: Text(reason)),
          const Divider(height: 22),
          _evidenceRow(Icons.cloud_outlined, '기상 데이터', source == 'kma' ? '기상청 KMA' : source),
          _evidenceRow(Icons.thermostat, '예보 최고기온', '$temp℃'),
          _evidenceRow(Icons.water_drop_outlined, '최대 강수확률', '$pop%'),
          _evidenceRow(Icons.air, '최대 풍속', '$wind m/s'),
          _evidenceRow(Icons.schedule, '최적 작업시간 점수', '$score점'),
          _evidenceRow(Icons.eco_outlined, '생육단계', stage),
          _evidenceRow(Icons.visibility_outlined, '최근 관찰', '$obsCount건 · 최고 위험도 $risk/5'),
          _evidenceRow(Icons.verified_outlined, '추천 신뢰도', confidence),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = (data['tasks'] as List?) ?? const [];
    final best = (data['best_work_times'] as List?) ?? const [];
    final source = '${data['weather_source'] ?? 'unknown'}';
    final confidence = '${data['recommendation_confidence'] ?? '-'}';

    return RefreshIndicator(
      onRefresh: () => reload(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text(
            '🍎 사과 재배 관리 비서',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text('기상 · 작업 · 병해충 · 잡초 · 경영 · 개인화 코치'),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: Icon(source == 'kma' ? Icons.cloud_done : Icons.warning_amber),
              title: Text(source == 'kma' ? '기상청 실제 예보 사용 중' : '기상 연결 상태 확인 필요'),
              subtitle: Text('${data['weather_warning'] ?? '$orchard 현재 예보 기반 추천입니다.'}'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : () => reload(force: true),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(loading ? '불러오는 중...' : '오늘 브리핑'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    title: const Text('위험점수'),
                    trailing: Text('${data['risk_score'] ?? 0}'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: ListTile(
                    title: const Text('순이익'),
                    trailing: Text('${data['profit'] ?? 0}원'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('오늘 우선작업', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              if (data['today_recommendations'] is List)
                Chip(label: Text('신뢰도 $confidence')),
            ],
          ),
          if (!loading && tasks.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.inbox_outlined),
                title: Text('등록된 예정 작업이 없습니다.'),
                subtitle: Text('통합 엔진 동기화 후 자동추천 작업이 있으면 이곳에 표시됩니다.'),
              ),
            ),
          ...tasks.map((x) {
            final m = x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
            if (m['auto_recommended'] == true) return _recommendationCard(m);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.task_outlined),
                title: Text('${m['title'] ?? ''}'),
                subtitle: Text('${m['scheduled_at'] ?? ''}'),
                trailing: Text('P${m['priority'] ?? 2}'),
              ),
            );
          }),
          const SizedBox(height: 14),
          const Text('추천 작업시간', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ...best.take(3).map(
                (x) => Card(
                  child: ListTile(
                    title: Text('${x['time']}'),
                    subtitle: Text('기온 ${x['temp']}℃ · 바람 ${x['wind']}m/s · 강수 ${x['rain_probability']}%'),
                    trailing: Text('${x['grade']} ${x['score']}'),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
