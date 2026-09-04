import 'package:flutter/material.dart';

import 'diagnosis_page.dart';
import 'services/farm_api.dart';
import 'services/recommendation_diagnosis_api.dart';

class RecommendationDiagnosisPage extends StatefulWidget {
  const RecommendationDiagnosisPage({super.key});

  @override
  State<RecommendationDiagnosisPage> createState() => _RecommendationDiagnosisPageState();
}

class _RecommendationDiagnosisPageState extends State<RecommendationDiagnosisPage> {
  final farmApi = FarmApi();
  final diagnosisApi = RecommendationDiagnosisApi();
  final orchard = TextEditingController(text: 'A과수원');
  List<Map<String, dynamic>> recommendations = [];
  final Map<String, Map<String, dynamic>> preResults = {};
  final Set<String> loadingThreats = {};
  bool loading = false;

  Future<void> load() async {
    setState(() => loading = true);
    final name = orchard.text.trim().isEmpty ? 'A과수원' : orchard.text.trim();
    final data = await farmApi.dashboard(name);
    final raw = (data['today_recommendations'] as List?) ?? (data['tasks'] as List?) ?? [];
    recommendations = raw
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .where((x) => '${x['specific_threat'] ?? ''}'.trim().isNotEmpty)
        .toList();
    if (mounted) setState(() => loading = false);
  }

  Future<void> runPreDiagnosis(Map<String, dynamic> rec) async {
    final threat = '${rec['specific_threat'] ?? ''}'.trim();
    if (threat.isEmpty) return;
    final name = orchard.text.trim().isEmpty ? 'A과수원' : orchard.text.trim();
    setState(() => loadingThreats.add(threat));
    final result = await diagnosisApi.assess(
      orchard: name,
      specificThreat: threat,
      threatType: '${rec['threat_type'] ?? ''}',
    );
    if (!mounted) return;
    setState(() {
      preResults[threat] = result;
      loadingThreats.remove(threat);
    });
  }

  void openFieldDiagnosis(String threat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('$threat 현장진단')),
          body: const SafeArea(child: DiagnosisPage()),
        ),
      ),
    );
  }

  Widget _resultCard(String threat, Map<String, dynamic> result) {
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
          onPressed: () => openFieldDiagnosis(threat),
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text('$threat 카메라 현장진단'),
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
        const Text('오늘 자동추천에서 예측된 구체 위협을 진단엔진으로 사전판정하고, 필요한 경우 바로 카메라 현장진단으로 이어집니다.'),
        const SizedBox(height: 12),
        TextField(
          controller: orchard,
          decoration: const InputDecoration(labelText: '과수원', border: OutlineInputBorder()),
          onSubmitted: (_) => load(),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
          label: Text(loading ? '불러오는 중...' : '오늘 예측위협 불러오기'),
        ),
        const SizedBox(height: 12),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (!loading && recommendations.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('현재 구체 예측위협이 없습니다.'),
              subtitle: Text('오늘 브리핑의 자동추천이 구체 위협 후보를 생성하면 이곳에 표시됩니다.'),
            ),
          ),
        ...recommendations.map((rec) {
          final threat = '${rec['specific_threat']}';
          final candidates = (rec['specific_threat_candidates'] as List?) ?? [];
          final result = preResults[threat];
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: FilledButton.tonalIcon(
                  onPressed: loadingThreats.contains(threat) ? null : () => runPreDiagnosis(rec),
                  icon: const Icon(Icons.biotech_outlined),
                  label: Text(loadingThreats.contains(threat) ? '진단엔진 실행 중...' : '$threat 사전진단 실행'),
                ),
              ),
              if (result != null) _resultCard(threat, result),
            ]),
          );
        }),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.verified_user_outlined),
            title: Text('예측과 진단은 구분합니다'),
            subtitle: Text('자동추천은 예찰 우선순위를 정하고, 진단엔진은 현재 근거를 다시 평가합니다. 병해·결핍의 확정은 현장 증상과 필요한 검사 결과를 함께 확인해야 합니다.'),
          ),
        ),
      ],
    );
  }
}
