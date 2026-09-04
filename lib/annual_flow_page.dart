import 'package:flutter/material.dart';

class AnnualFlowPage extends StatelessWidget {
  const AnnualFlowPage({super.key});

  static const _months = <Map<String, dynamic>>[
    {
      'm': 1, 'stage': '휴면기', 'goal': '연간계획·시설점검',
      'tasks': ['전년도 기록 정리', '올해 작업계획 수립', '농기계·시설 점검'],
      'nutrition': ['전년도 결핍·엽분석·토양검정 기록 검토', '올해 토양·엽 분석 계획 수립'],
      'pest': ['월동 해충 흔적·알·피해가지 점검', '전년도 다발생 구역 표시'],
      'disease': ['병든 가지·과실 잔재·월동 감염원 점검'],
      'environment': ['동해·수피 갈라짐·배수 취약구역 점검'],
    },
    {
      'm': 2, 'stage': '휴면기', 'goal': '동계전정',
      'tasks': ['동계전정', '수형 정리', '가지·수간 상태 점검'],
      'nutrition': ['수세 불균형 구역 확인', '전년도 미량원소 결핍 의심 나무 표시'],
      'pest': ['전정 중 월동 해충·피해가지 확인'],
      'disease': ['전정 중 궤양·고사·병든 가지 확인'],
      'environment': ['동해 피해·가지 갈라짐 확인'],
    },
    {
      'm': 3, 'stage': '발아 준비', 'goal': '발아 전 준비',
      'tasks': ['전정 마무리', '유인·지주 점검', '토양·배수 상태 확인'],
      'nutrition': ['토양 pH·배수 상태와 결핍 위험 함께 확인', '발아 전 수세·눈 상태 비교'],
      'pest': ['발아 전 월동해충 예찰 강화'],
      'disease': ['병든 조직·낙엽 잔재 재점검'],
      'environment': ['늦서리·저온 예보 확인', '과습·배수불량 구역 확인'],
    },
    {
      'm': 4, 'stage': '발아·개화', 'goal': '개화·저온 관리',
      'tasks': ['꽃눈·개화 상태 관찰', '저온·서리 위험 확인', '수분 상태 관찰'],
      'nutrition': ['새잎 황화·왜소·기형 등 Fe/Zn/B 계열 의심증상 예찰', '새잎과 정상잎 비교 촬영'],
      'pest': ['개화기 해충 발생 여부 예찰', '수분곤충 활동 중 살충 작업 주의'],
      'disease': ['강우·고습 뒤 꽃·잎 병반 발생 여부 점검'],
      'environment': ['서리·저온·강풍 피해 즉시 확인'],
    },
    {
      'm': 5, 'stage': '착과', 'goal': '착과·적과 시작',
      'tasks': ['착과 상태 확인', '적과 시작', '신초·병해충 예찰'],
      'nutrition': ['신초 황화·잎맥간 황화·잎끝 마름 예찰', '착과 불량과 영양·수분 스트레스 구분'],
      'pest': ['진딧물·응애·나방류 등 실제 개체·식흔 예찰', '피해 잎·과실 비율 기록'],
      'disease': ['낙화 후 잎·과실 병반을 주 1회 이상 확인'],
      'environment': ['가뭄·과습·강풍 후 착과 상태 재확인'],
    },
    {
      'm': 6, 'stage': '초기 과실비대', 'goal': '과실비대 관리',
      'tasks': ['적과 마무리', '유인 작업', '관수·토양수분 점검', '잡초 관리'],
      'nutrition': ['오래된 잎 황화·잎맥간 황화 등 Mg/K 계열 패턴 예찰', '과실비대 편차·수세 차이 기록'],
      'pest': ['응애·흡즙해충·과실가해 해충 예찰', '트랩이 있으면 포획량 추세 기록'],
      'disease': ['장마 전후 잎·과실 반점과 확산속도 점검'],
      'environment': ['토양수분·배수·고온 스트레스 점검'],
    },
    {
      'm': 7, 'stage': '과실비대', 'goal': '고온·수분 관리',
      'tasks': ['고온·가뭄 대응', '관수 필요성 점검', '잡초 관리', '과실·가지 예찰'],
      'nutrition': ['고온기 황화·엽연괴사와 실제 결핍을 구분', 'Ca/Mg/K 불균형 의심 시 증상 분포 기록'],
      'pest': ['응애·나방류 등 개체수와 피해 증가속도 집중 예찰'],
      'disease': ['고온다습·강우 뒤 병반 확대 여부 집중 확인'],
      'environment': ['일소·가뭄·과습·뿌리 스트레스 예찰'],
    },
    {
      'm': 8, 'stage': '과실비대·착색 준비', 'goal': '수확 전 품질관리',
      'tasks': ['과실 상태 확인', '가지 처짐·지주 점검', '착색 준비'],
      'nutrition': ['잎 황화·과실 품질 저하가 결핍인지 노화인지 구분', '필요 시 엽분석 검토'],
      'pest': ['과실 피해 흔적·해충 개체수 점검'],
      'disease': ['과실 반점·부패·잎 병반 재확인'],
      'environment': ['고온·일소·강풍·태풍 대비'],
    },
    {
      'm': 9, 'stage': '착색·성숙', 'goal': '수확 준비',
      'tasks': ['착색 상태 확인', '성숙도 관찰', '낙과·강풍 위험 점검', '수확 계획'],
      'nutrition': ['늦은 황화·엽연마름은 자연노화와 구분', '수확 전 불필요한 교정 살포 지양'],
      'pest': ['수확 전 피해과·해충 밀도 확인', '안전사용기준 확인이 필요한 시기'],
      'disease': ['수확 전 과실 병반·부패 위험 점검'],
      'environment': ['태풍·강풍·낙과 위험 예찰'],
    },
    {
      'm': 10, 'stage': '본격 수확', 'goal': '수확·선별·출하',
      'tasks': ['수확 적기 확인', '수확', '선별·출하', '수확량 기록'],
      'nutrition': ['수확기 결핍 증상은 위치·나무별로 기록해 다음 해 분석자료로 사용'],
      'pest': ['피해과 비율·해충 흔적 기록'],
      'disease': ['부패·병반 과실 비율 기록'],
      'environment': ['비·강풍 전후 수확 우선순위 조정'],
    },
    {
      'm': 11, 'stage': '수확 후', 'goal': '수확 후 정리',
      'tasks': ['수확 마무리', '낙엽·잔재 관리', '수세·수확 결과 기록'],
      'nutrition': ['엽색·수세·수확량 차이를 구역별로 정리', '토양·엽 분석 필요 구역 선정'],
      'pest': ['피해가 많았던 나무·구역 표시'],
      'disease': ['병든 잎·과실·가지와 발생구역 기록'],
      'environment': ['배수·토양구조 문제구역 정리'],
    },
    {
      'm': 12, 'stage': '휴면 진입', 'goal': '결산·다음 해 준비',
      'tasks': ['비용·수익 결산', '작업기록 분석', '다음 해 개선계획'],
      'nutrition': ['결핍 의심 사진·분석결과·시비기록 종합', '다음 해 검사·보정 계획 수립'],
      'pest': ['연간 해충 발생시기·밀도·피해량 정리'],
      'disease': ['연간 병 발생시기·기상조건·피해구역 정리'],
      'environment': ['서리·폭염·가뭄·과습·태풍 피해 이력 정리'],
    },
  ];

  String _season(int month) {
    if (month <= 3) return '① 겨울 준비·전정';
    if (month <= 5) return '② 개화·착과';
    if (month <= 8) return '③ 과실비대';
    if (month <= 10) return '④ 착색·수확';
    return '⑤ 수확 후·결산';
  }

  Widget _section(IconData icon, String title, List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
          ),
          ...items.map((x) => ListTile(dense: true, visualDensity: VisualDensity.compact, leading: const Icon(Icons.arrow_right), title: Text(x))),
        ],
      );

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
        const Text('농작업뿐 아니라 영양결핍·병해충·환경위협 예찰 시기도 함께 봅니다.'),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${now.year}년 농사 진행도', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10), LinearProgressIndicator(value: yearProgress), const SizedBox(height: 8),
          Text('${(yearProgress * 100).round()}% · 현재 ${_season(currentMonth)}'),
          Text('현재 단계: ${current['stage']}'),
          Text('이번 달 핵심목표: ${current['goal']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]))),
        const SizedBox(height: 6),
        const Text('이번 달 예찰 포인트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Card(child: Column(children: [
          _section(Icons.science_outlined, '영양결핍 예찰', current['nutrition'] as List<String>),
          _section(Icons.bug_report_outlined, '해충 위협 예찰', current['pest'] as List<String>),
          _section(Icons.coronavirus_outlined, '병해 위협 예찰', current['disease'] as List<String>),
          _section(Icons.warning_amber_outlined, '환경위협 예찰', current['environment'] as List<String>),
        ])),
        const SizedBox(height: 8),
        const Text('월별 농작업·예찰 타임라인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ..._months.map((item) {
          final month = item['m'] as int;
          final isCurrent = month == currentMonth;
          final isPast = month < currentMonth;
          return Card(child: ExpansionTile(
            initiallyExpanded: isCurrent,
            leading: CircleAvatar(child: Text('$month')),
            title: Text('$month월 · ${item['stage']}', style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text('${item['goal']}${isCurrent ? ' · 현재' : isPast ? ' · 지난 단계' : ''}'),
            children: [
              _section(Icons.agriculture_outlined, '핵심 농작업', item['tasks'] as List<String>),
              _section(Icons.science_outlined, '영양결핍 예찰', item['nutrition'] as List<String>),
              _section(Icons.bug_report_outlined, '해충 위협 예찰', item['pest'] as List<String>),
              _section(Icons.coronavirus_outlined, '병해 위협 예찰', item['disease'] as List<String>),
              _section(Icons.warning_amber_outlined, '환경위협 예찰', item['environment'] as List<String>),
            ],
          ));
        }),
        const SizedBox(height: 8),
        const Card(child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('시기는 기본 가이드입니다'),
          subtitle: Text('지역·품종·기상·실제 생육단계에 따라 예찰 시기는 앞뒤로 조정해야 합니다. 사진 증상은 결핍·병해·해충·환경장해 후보를 구분하는 근거로 사용하고, 결핍 확정은 토양·엽 분석이 더 강한 근거입니다. 농약 제품·농도·혼용·재살포 간격은 자동 처방하지 않습니다.'),
        )),
      ],
    );
  }
}
