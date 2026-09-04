import 'package:flutter/material.dart';
import 'services/behavior_coach_api.dart';

class BehaviorCoachPage extends StatefulWidget {
  const BehaviorCoachPage({super.key});

  @override
  State<BehaviorCoachPage> createState() => _BehaviorCoachPageState();
}

class _BehaviorCoachPageState extends State<BehaviorCoachPage> {
  final api = BehaviorCoachApi();

  int? plannedChoice;
  int? completedChoice;
  int? delayChoice;
  int? switchesChoice;
  int? estimatedChoice;
  int? actualChoice;
  int? attention;
  int? lowMood;
  int? lowInterest;
  int? functionDifficulty;

  bool saving = false;
  bool loading = false;
  Map<String, dynamic> result = {};
  String message = '';

  bool get allAnswered =>
      plannedChoice != null &&
      completedChoice != null &&
      delayChoice != null &&
      switchesChoice != null &&
      estimatedChoice != null &&
      actualChoice != null &&
      attention != null &&
      lowMood != null &&
      lowInterest != null &&
      functionDifficulty != null;

  int get plannedTasks => const [1, 2, 3, 5][plannedChoice ?? 0];

  int get completedTasks {
    final ratio = const [0.0, 0.5, 0.8, 1.0][completedChoice ?? 0];
    return (plannedTasks * ratio).round();
  }

  int get startDelayMin => const [0, 10, 30, 60][delayChoice ?? 0];
  int get taskSwitches => const [0, 1, 3, 5][switchesChoice ?? 0];
  int get estimatedMinutes => const [30, 60, 120, 240][estimatedChoice ?? 0];
  int get actualMinutes => const [30, 60, 120, 240][actualChoice ?? 0];

  Future<void> save() async {
    if (!allAnswered) {
      setState(() => message = '모든 문항에서 하나씩 선택해야 저장할 수 있습니다.');
      return;
    }
    setState(() {
      saving = true;
      message = '';
    });
    final ok = await api.saveCheckin({
      'planned_tasks': plannedTasks,
      'completed_tasks': completedTasks,
      'start_delay_min': startDelayMin,
      'task_switches': taskSwitches,
      'estimated_duration_min': estimatedMinutes,
      'actual_duration_min': actualMinutes,
      'attention_difficulty': attention!,
      'low_mood': lowMood!,
      'low_interest': lowInterest!,
      'function_difficulty': functionDifficulty!,
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

  Widget choiceQuestion({
    required String question,
    required List<String> choices,
    required int? value,
    required ValueChanged<int> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...List.generate(4, (i) {
            final selected = value == i;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: SizedBox(
                width: double.infinity,
                child: selected
                    ? FilledButton.icon(
                        onPressed: () => onChanged(i),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Align(alignment: Alignment.centerLeft, child: Text(choices[i])),
                      )
                    : OutlinedButton(
                        onPressed: () => onChanged(i),
                        child: Align(alignment: Alignment.centerLeft, child: Text(choices[i])),
                      ),
              ),
            );
          }),
        ]),
      ),
    );
  }

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
        const Text('오늘 상태를 4지선다로 빠르게 기록합니다. 모든 문항을 선택해야 저장됩니다. 정신질환을 진단하지 않습니다.'),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('오늘 체크인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Chip(label: Text('${[
            plannedChoice, completedChoice, delayChoice, switchesChoice, estimatedChoice,
            actualChoice, attention, lowMood, lowInterest, functionDifficulty
          ].where((x) => x != null).length}/10')),
        ]),
        const SizedBox(height: 6),
        choiceQuestion(
          question: '1. 오늘 계획한 작업은 몇 개인가요?',
          choices: const ['1개', '2개', '3개', '4개 이상'],
          value: plannedChoice,
          onChanged: (v) => setState(() => plannedChoice = v),
        ),
        choiceQuestion(
          question: '2. 계획한 작업을 어느 정도 완료했나요?',
          choices: const ['거의 못함', '절반 정도', '대부분 완료', '모두 완료'],
          value: completedChoice,
          onChanged: (v) => setState(() => completedChoice = v),
        ),
        choiceQuestion(
          question: '3. 첫 작업을 시작하기까지 얼마나 미뤘나요?',
          choices: const ['바로 시작', '10분 안팎', '30분 안팎', '1시간 이상'],
          value: delayChoice,
          onChanged: (v) => setState(() => delayChoice = v),
        ),
        choiceQuestion(
          question: '4. 작업 도중 다른 일로 몇 번 정도 바뀌었나요?',
          choices: const ['거의 없음', '1회 정도', '2~3회', '4회 이상'],
          value: switchesChoice,
          onChanged: (v) => setState(() => switchesChoice = v),
        ),
        choiceQuestion(
          question: '5. 시작 전 예상한 전체 작업시간은?',
          choices: const ['30분 이하', '약 1시간', '약 2시간', '3시간 이상'],
          value: estimatedChoice,
          onChanged: (v) => setState(() => estimatedChoice = v),
        ),
        choiceQuestion(
          question: '6. 실제로 걸린 전체 작업시간은?',
          choices: const ['30분 이하', '약 1시간', '약 2시간', '3시간 이상'],
          value: actualChoice,
          onChanged: (v) => setState(() => actualChoice = v),
        ),
        choiceQuestion(
          question: '7. 오늘 한 작업에 주의를 계속 유지하기 어려웠나요?',
          choices: const ['전혀 아님', '조금', '자주', '매우 자주'],
          value: attention,
          onChanged: (v) => setState(() => attention = v),
        ),
        choiceQuestion(
          question: '8. 오늘 기분이 가라앉거나 의욕이 떨어졌나요?',
          choices: const ['전혀 아님', '조금', '자주', '매우 자주'],
          value: lowMood,
          onChanged: (v) => setState(() => lowMood = v),
        ),
        choiceQuestion(
          question: '9. 평소 하던 일의 흥미나 즐거움이 줄었나요?',
          choices: const ['전혀 아님', '조금', '자주', '매우 자주'],
          value: lowInterest,
          onChanged: (v) => setState(() => lowInterest = v),
        ),
        choiceQuestion(
          question: '10. 이런 상태 때문에 오늘 일상 작업이 어려웠나요?',
          choices: const ['전혀 아님', '조금', '많이', '매우 많이'],
          value: functionDifficulty,
          onChanged: (v) => setState(() => functionDifficulty = v),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: (!allAnswered || saving) ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? '저장 중...' : allAnswered ? '10문항 저장하고 분석' : '모든 문항을 선택하세요'),
        ),
        if (!allAnswered)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('미응답 문항이 있으면 저장할 수 없습니다.', style: TextStyle(fontSize: 12)),
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
