import 'package:flutter/material.dart';
import 'services/behavior_coach_api.dart';

class BehaviorCoachPage extends StatefulWidget {
  const BehaviorCoachPage({super.key});

  @override
  State<BehaviorCoachPage> createState() => _BehaviorCoachPageState();
}

class _BehaviorCoachPageState extends State<BehaviorCoachPage> {
  final api = BehaviorCoachApi();
  final planned = TextEditingController(text: '3');
  final completed = TextEditingController(text: '2');
  final delay = TextEditingController(text: '0');
  final switches = TextEditingController(text: '0');
  final estimated = TextEditingController(text: '60');
  final actual = TextEditingController(text: '60');

  int attention = 0;
  int lowMood = 0;
  int lowInterest = 0;
  int functionDifficulty = 0;
  bool saving = false;
  bool loading = false;
  Map<String, dynamic> result = {};
  String message = '';

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Future<void> save() async {
    setState(() {
      saving = true;
      message = '';
    });
    final ok = await api.saveCheckin({
      'planned_tasks': _int(planned),
      'completed_tasks': _int(completed),
      'start_delay_min': _int(delay),
      'task_switches': _int(switches),
      'estimated_duration_min': _int(estimated),
      'actual_duration_min': _int(actual),
      'attention_difficulty': attention,
      'low_mood': lowMood,
      'low_interest': lowInterest,
      'function_difficulty': functionDifficulty,
    });
    if (!mounted) return;
    setState(() {
      saving = false;
      message = ok ? '오늘 기록을 저장했습니다.' : '저장에 실패했습니다.';
    });
    if (ok) await load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final r = await api.analysis();
    if (!mounted) return;
    setState(() {
      result = r;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Widget numberField(String label, TextEditingController c) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  Widget scale(String label, int value, ValueChanged<int> onChanged) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('없음')),
                ButtonSegment(value: 1, label: Text('가끔')),
                ButtonSegment(value: 2, label: Text('자주')),
                ButtonSegment(value: 3, label: Text('매우 자주')),
              ],
              selected: {value},
              onSelectionChanged: (x) => onChanged(x.first),
            ),
          ]),
        ),
      );

  Widget signalCard(String title, dynamic raw) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final evidence = (m['evidence'] as List?) ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
            const Chip(label: Text('비진단')),
          ]),
          Text('상태: ${m['level'] ?? '-'} · 점수 ${m['score'] ?? 0}/100'),
          if (m['basis'] != null) Text('${m['basis']}', style: const TextStyle(fontSize: 12)),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('근거', style: TextStyle(fontWeight: FontWeight.bold)),
            ...evidence.map((x) => Text('• $x')),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patterns = (result['patterns'] as List?) ?? [];
    final actions = (result['interventions'] as List?) ?? [];
    final metrics = result['metrics'] is Map
        ? Map<String, dynamic>.from(result['metrics'] as Map)
        : <String, dynamic>{};
    final experiment = result['experiment'] is Map
        ? Map<String, dynamic>.from(result['experiment'] as Map)
        : <String, dynamic>{};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('🧠 행동 기반 작업효율 코치', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('작업행동과 사용자의 직접 자기보고를 분석해 행동 패턴과 교정 실험을 제안합니다. 정신질환을 진단하지 않습니다.'),
        const SizedBox(height: 12),
        const Text('오늘 작업행동 기록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: numberField('계획 작업 수', planned)),
          const SizedBox(width: 8),
          Expanded(child: numberField('완료 작업 수', completed)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: numberField('시작 지연(분)', delay)),
          const SizedBox(width: 8),
          Expanded(child: numberField('작업 전환 횟수', switches)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: numberField('예상시간(분)', estimated)),
          const SizedBox(width: 8),
          Expanded(child: numberField('실제시간(분)', actual)),
        ]),
        const SizedBox(height: 8),
        scale('주의를 유지하거나 한 작업을 끝까지 이어가기 어려웠나요?', attention, (v) => setState(() => attention = v)),
        scale('기분이 가라앉거나 의욕이 떨어졌다고 느꼈나요?', lowMood, (v) => setState(() => lowMood = v)),
        scale('평소 하던 일에 흥미나 즐거움이 줄었다고 느꼈나요?', lowInterest, (v) => setState(() => lowInterest = v)),
        scale('이런 상태가 일상 작업 수행을 어렵게 했나요?', functionDifficulty, (v) => setState(() => functionDifficulty = v)),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? '저장 중...' : '오늘 행동기록 저장'),
        ),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(message)),
        const Divider(height: 28),
        Row(children: [
          const Expanded(child: Text('최근 14일 분석', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
        ]),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
        if (!loading && result['error'] != null) Card(child: ListTile(title: Text('${result['error']}'))),
        if (!loading && result['error'] == null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('기록 ${result['sample_count'] ?? 0}건'),
                Text('완료율 ${metrics['completion_ratio_pct'] ?? '-'}% · 평균 시작지연 ${metrics['avg_start_delay_min'] ?? '-'}분'),
                Text('평균 작업전환 ${metrics['avg_task_switches'] ?? '-'}회 · 시간예측 오차 ${metrics['avg_duration_error_pct'] ?? '-'}%'),
              ]),
            ),
          ),
          signalCard('ADHD 관련 주의·실행기능 선별 신호', result['attention_signal']),
          signalCard('우울 관련 기분·활동 저하 선별 신호', result['mood_signal']),
          if (patterns.isNotEmpty) ...[
            const Text('감지된 행동 패턴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...patterns.map((x) {
              final m = Map<String, dynamic>.from(x as Map);
              return Card(child: ListTile(leading: const Icon(Icons.pattern), title: Text('${m['name']}'), subtitle: Text('${m['evidence']}')));
            }),
          ],
          if (actions.isNotEmpty) ...[
            const Text('행동 교정 제안', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...actions.map((x) => Card(child: ListTile(leading: const Icon(Icons.tips_and_updates_outlined), title: Text('$x')))),
          ],
          if (experiment.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.science_outlined),
                title: Text('${experiment['duration_days'] ?? 5}일 행동실험'),
                subtitle: Text('${experiment['instruction'] ?? ''}\n측정: ${experiment['measure'] ?? ''}'),
              ),
            ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.health_and_safety_outlined),
              title: Text('선별 신호는 진단이 아닙니다'),
              subtitle: Text('주의·실행기능 또는 기분·흥미·일상기능의 어려움이 지속되거나 생활에 영향을 주면 의료·정신건강 전문가 평가를 고려하세요. 앱은 작업행동만으로 우울증을 추정하지 않습니다.'),
            ),
          ),
        ],
      ],
    );
  }
}
