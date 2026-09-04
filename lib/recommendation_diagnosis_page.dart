import 'package:flutter/material.dart';

import 'diagnosis_page.dart';
import 'services/farm_api.dart';
import 'services/recommendation_diagnosis_api.dart';
import 'services/orchard_selection.dart';

class RecommendationDiagnosisPage extends StatefulWidget {
  const RecommendationDiagnosisPage({super.key});

  @override
  State<RecommendationDiagnosisPage> createState() => _RecommendationDiagnosisPageState();
}

class _RecommendationDiagnosisPageState extends State<RecommendationDiagnosisPage> {
  final farmApi = FarmApi();
  final diagnosisApi = RecommendationDiagnosisApi();
  List<Map<String, dynamic>> recommendations = [];
  final Map<String, Map<String, dynamic>> preResults = {};
  final Set<String> loadingKeys = {};
  bool loading = false;

  String _key(String threat, Map<String, dynamic>? zone) => '$threat|${zone?['zone_name'] ?? '전체'}';

  Future<void> load() async {
    setState(() => loading = true);
    final data = await farmApi.dashboard(OrchardSelection.name);
    final raw = (data['today_recommendations'] as List?) ?? (data['tasks'] as List?) ?? [];
    recommendations = raw
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .where((x) => '${x['specific_threat'] ?? ''}'.trim().isNotEmpty)
        .toList();
    if (mounted) setState(() => loading = false);
  }

  Map<String, dynamic>? _primaryZone(Map<String, dynamic> rec) {
    if (rec['primary_zone_target'] is Map) {
      return Map<String, dynamic>.from(rec['primary_zone_target'] as Map);
    }
    final zones = (rec['zone_targets'] as List?) ?? [];
    if (zones.isNotEmpty && zones.first is Map) return Map<String, dynamic>.from(zones.first as Map);
    return null;
  }

  Future<void> runPreDiagnosis(Map<String, dynamic> rec, [Map<String, dynamic>? zone]) async {
    final threat = '${rec['specific_threat'] ?? ''}'.trim();
    if (threat.isEmpty) return;
    final key = _key(threat, zone);
    setState(() => loadingKeys.add(key));
    final result = await diagnosisApi.assess(
      orchard: OrchardSelection.name,
      specificThreat: threat,
      threatType: '${rec['threat_type'] ?? ''}',
      zoneName: zone?['zone_name']?.toString(),
      variety: zone?['variety']?.toString(),
    );
    if (!mounted) return;
    setState(() {
      preResults[key] = result;
      loadingKeys.remove(key);
    });
  }

  void openFieldDiagnosis(String threat, Map<String, dynamic>? zone) {
    final zoneLabel = zone == null ? '' : ' · ${zone['zone_name']} ${zone['variety']}';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('$threat$zoneLabel 현장진단')),
          body: const SafeArea(child: DiagnosisPage()),
        ),
      ),
    );
  }

  Widget _resultCard(String threat, Map<String, dynamic>? zone, Map<String, dynamic> result) {
    if (result['error'] != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Text('⚠️ ${result['error']}'),
      );
    }
    final evidence = (result['evidence'] as List?) ?? [];
    final missing = (result['missing_evidence'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),
        Text('진단엔진 사전판정 · ${result['score'] ?? '-'} / 100 · ${result['level'] ?? '-'}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('확신도 ${result['confidence'] ?? '-'}'),
        if (zone != null) Text('대상 구역 ${zone['zone_name']} · ${zone['variety']} · ${zone['tree_count'] ?? 0}주'),
        if (evidence.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('현재 근거', style: TextStyle(fontWeight: FontWeight.bold)),
          ...evidence.map((x) => Text('• $x')),
        ],
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('추가 확인 필요', style: TextStyle(fontWeight: FontWeight.bold)),
          ...missing.map((x) => Text('• $x')),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => openFieldDiagnosis(threat, zone),
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(zone == null ? '$threat 카메라 현장진단' : '${zone['zone_name']} 카메라 현장진단'),
        ),
      ]),
    );
  }

  Widget _zoneChips(Map<String, dynamic> rec) {
    final zones = ((rec['zone_targets'] as List?) ?? [])
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .toList();
    if (zones.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('우선 예찰 구역', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: zones.take(6).map((z) => ActionChip(
                avatar: Icon((z['zone_priority'] ?? 2) == 1 ? Icons.priority_high : Icons.grid_view_outlined, size: 16),
                label: Text('${z['zone_name']} · ${z['variety']} · ${z['tree_count'] ?? 0}주'),
                onPressed: () => runPreDiagnosis(rec, z),
              )).toList(),
        ),
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('🔎 자동추천 예찰 진단', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text('${OrchardSelection.name} · ${OrchardSelection.varieties}'),
        const Text('예측된 위협을 품종별 구역 단위로 사전판정하고, 우선 구역에서 바로 현장진단으로 이어집니다.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
          label: Text(loading ? '불러오는 중...' : '오늘 예측위협 불러오기'),
        ),
        const SizedBox(height: 12),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (!loading && recommendations.isEmpty)
          const Card(child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('현재 구체 예측위협이 없습니다.'),
            subtitle: Text('오늘 브리핑의 자동추천이 구체 위협 후보를 생성하면 이곳에 표시됩니다.'),
          )),
        ...recommendations.map((rec) {
          final threat = '${rec['specific_threat']}';
          final candidates = (rec['specific_threat_candidates'] as List?) ?? [];
          final primary = _primaryZone(rec);
          final key = _key(threat, primary);
          final result = preResults[key];
          return Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text(threat, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${rec['prediction_basis'] ?? '자동추천 예측 후보'}\n${rec['reason'] ?? ''}'),
                isThreeLine: true,
              ),
              if (candidates.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: candidates.take(4).map((x) {
                      final m = x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
                      return Chip(label: Text('${m['name'] ?? '-'} ${m['score'] ?? '-'}'));
                    }).toList(),
                  ),
                ),
              _zoneChips(rec),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: FilledButton.tonalIcon(
                  onPressed: loadingKeys.contains(key) ? null : () => runPreDiagnosis(rec, primary),
                  icon: const Icon(Icons.biotech_outlined),
                  label: Text(loadingKeys.contains(key)
                      ? '진단엔진 실행 중...'
                      : primary == null
                          ? '$threat 사전진단 실행'
                          : '${primary['zone_name']} 우선 사전진단'),
                ),
              ),
              if (result != null) _resultCard(threat, primary, result),
            ]),
          );
        }),
        const SizedBox(height: 12),
        const Card(child: ListTile(
          leading: Icon(Icons.verified_user_outlined),
          title: Text('구역 우선순위도 확진이 아닙니다'),
          subtitle: Text('품종·나무 수·생육단계로 먼저 볼 구역을 정하는 기능입니다. 실제 병해·해충·결핍 판정은 현장 증거와 필요한 검사 결과로 다시 확인합니다.'),
        )),
      ],
    );
  }
}
