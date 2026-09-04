import 'package:flutter/material.dart';

class AnnualFlowPage extends StatelessWidget {
  const AnnualFlowPage({super.key});

  static const _months = <Map<String, dynamic>>[
    {'m': 1, 'stage': '휴면기', 'goal': '연간계획·시설점검', 'tasks': ['전년도 기록 정리', '올해 작업계획 수립', '농기계·시설 점검']},
    {'m': 2, 'stage': '휴면기', 'goal': '동계전정', 'tasks': ['동계전정', '수형 정리', '가지·수간 상태 점검']},
    {'m': 3, 'stage': '발아 준비', 'goal': '발아 전 준비', 'tasks': ['전정 마무리', '유인·지주 점검', '토양·배수 상태 확인']},
    {'m': 4, 'stage': '발아·개화', 'goal': '개화·저온 관리', 'tasks': ['꽃눈·개화 상태 관찰', '저온·서리 위험 확인', '수분 상태 관찰']},
    {'m': 5, 'stage': '착과', 'goal': '착과·적과 시작', 'tasks': ['착과 상태 확인', '적과 시작', '신초·병해충 예찰']},
    {'m': 6, 'stage': '초기 과실비대', 'goal': '과실비대 관리', 'tasks': ['적과 마무리', '유인 작업', '관수·토양수분 점검', '잡초 관리']},
    {'m': 7, 'stage': '과실비대', 'goal': '고온·수분 관리', 'tasks': ['고온·가뭄 대응', '관수 필요성 점검', '잡초 관리', '과실·가지 예찰']},
    {'m': 8, 'stage': '과실비대·착색 준비', 'goal': '수확 전 품질관리', 'tasks': ['과실 상태 확인', '가지 처짐·지주 점검', '착색 준비']},
    {'m': 9, 'stage': '착색·성숙', 'goal': '수확 준비', 'tasks': ['착색 상태 확인', '성숙도 관찰', '낙과·강풍 위험 점검', '수확 계획']},
    {'m': 10, 'stage': '본격 수확', 'goal': '수확·선별·출하', 'tasks': ['수확 적기 확인', '수확', '선별·출하', '수확량 기록']},
    {'m': 11, 'stage': '수확 후', 'goal': '수확 후 정리', 'tasks': ['수확 마무리', '낙엽·잔재 관리', '수세·수확 결과 기록']},
    {'m': 12, 'stage': '휴면 진입', 'goal': '결산·다음 해 준비', 'tasks': ['비용·수익 결산', '작업기록 분석', '다음 해 개선계획']},
  ];

  String _season(int month) {
    if (month <= 3) return '① 겨울 준비·전정';
    if (month <= 5) return '② 개화·착과';
    if (month <= 8) return '③ 과실비대';
    if (month <= 10) return '④ 착색·수확';
    return '⑤ 수확 후·결산';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final current = _months[currentMonth - 1];
    final yearProgress = currentMonth / 12.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('📅 연간 농작업', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('1년 전체 흐름에서 지금 해야 할 일을 한눈에 봅니다.'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${now.year}년 농사 진행도', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: yearProgress),
              const SizedBox(height: 8),
              Text('${(yearProgress * 100).round()}% · 현재 ${_season(currentMonth)}'),
              const SizedBox(height: 6),
              Text('현재 단계: ${current['stage']}'),
              Text('이번 달 핵심목표: ${current['goal']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        const Text('이번 달 핵심 작업', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Card(
          child: Column(
            children: (current['tasks'] as List<String>)
                .map((task) => ListTile(
                      leading: const Icon(Icons.check_box_outline_blank),
                      title: Text(task),
                      subtitle: const Text('오늘 브리핑의 자동추천과 연결해 우선순위를 판단합니다.'),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        const Text('월별 농작업 타임라인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ..._months.map((item) {
          final month = item['m'] as int;
          final isCurrent = month == currentMonth;
          final isPast = month < currentMonth;
          return Card(
            child: ExpansionTile(
              initiallyExpanded: isCurrent,
              leading: CircleAvatar(child: Text('$month')),
              title: Text('$month월 · ${item['stage']}', style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text('${item['goal']}${isCurrent ? ' · 현재' : isPast ? ' · 지난 단계' : ''}'),
              children: [
                ...((item['tasks'] as List<String>).map((task) => ListTile(
                      dense: true,
                      leading: Icon(isPast ? Icons.check_circle_outline : Icons.arrow_right),
                      title: Text(task),
                    ))),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('시기는 자동 보정 대상입니다'),
            subtitle: Text('월별 일정은 기본 가이드이며 지역·품종·실제 기상·생육단계에 따라 앞뒤로 조정해야 합니다. 병해충 방제는 예찰과 필요성 판단까지만 자동화하고 제품·농도는 PSIS와 라벨을 확인합니다.'),
          ),
        ),
      ],
    );
  }
}
