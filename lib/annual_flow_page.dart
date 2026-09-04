import 'package:flutter/material.dart';

class AnnualFlowPage extends StatelessWidget {
  const AnnualFlowPage({super.key});

  static const _months = <Map<String, dynamic>>[
    {
      'm': 1, 'stage': '휴면기', 'goal': '연간계획·시설점검',
      'tasks': ['전년도 기록 정리', '올해 작업계획 수립', '농기계·시설 점검'],
      'predicted': ['월동 해충 흔적', '병든 가지·월동 감염원', '동해·수피 갈라짐', '전년도 결핍 반복구역'],
      'nutrition': ['전년도 결핍·엽분석·토양검정 기록 검토', '올해 토양·엽 분석 계획 수립'],
      'pest': ['월동 해충 흔적·알·피해가지 점검', '전년도 다발생 구역 표시'],
      'disease': ['병든 가지·과실 잔재·월동 감염원 점검'],
      'environment': ['동해·수피 갈라짐·배수 취약구역 점검'],
    },
    {
      'm': 2, 'stage': '휴면기', 'goal': '동계전정',
      'tasks': ['동계전정', '수형 정리', '가지·수간 상태 점검'],
      'predicted': ['사과응애 월동알', '사과면충·깍지벌레류', '궤양성 병반', '동해·가지 갈라짐'],
      'nutrition': ['수세 불균형 구역 확인', '전년도 미량원소 결핍 의심 나무 표시'],
      'pest': ['전정 중 월동 해충·피해가지 확인'],
      'disease': ['전정 중 궤양·고사·병든 가지 확인'],
      'environment': ['동해 피해·가지 갈라짐 확인'],
    },
    {
      'm': 3, 'stage': '발아 준비', 'goal': '발아 전 준비',
      'tasks': ['전정 마무리', '유인·지주 점검', '토양·배수 상태 확인'],
      'predicted': ['검은별무늬병', '점무늬낙엽병', '사과응애 월동알', '사과면충·깍지벌레류', '늦서리·배수불량'],
      'nutrition': ['토양 pH·배수 상태와 결핍 위험 함께 확인', '발아 전 수세·눈 상태 비교'],
      'pest': ['발아 전 월동해충 예찰 강화'],
      'disease': ['병든 조직·낙엽 잔재 재점검'],
      'environment': ['늦서리·저온 예보 확인', '과습·배수불량 구역 확인'],
    },
    {
      'm': 4, 'stage': '발아·개화', 'goal': '개화·저온 관리',
      'tasks': ['꽃눈·개화 상태 관찰', '저온·서리 위험 확인', '수분 상태 관찰'],
      'predicted': ['검은별무늬병', '점무늬낙엽병', '사과혹진딧물', '잎말이나방류', '철 결핍', '붕소 등 미량원소 불균형', '저온·서리 피해'],
      'nutrition': ['새잎 황화·왜소·기형 등 Fe/Zn/B 계열 의심증상 예찰', '새잎과 정상잎 비교 촬영'],
      'pest': ['개화기 해충 발생 여부 예찰', '수분곤충 활동 중 살충 작업 주의'],
      'disease': ['강우·고습 뒤 꽃·잎 병반 발생 여부 점검'],
      'environment': ['서리·저온·강풍 피해 즉시 확인'],
    },
    {
      'm': 5, 'stage': '착과', 'goal': '착과·적과 시작',
      'tasks': ['착과 상태 확인', '적과 시작', '신초·병해충 예찰'],
      'predicted': ['갈색무늬병', '붉은별무늬병', '점무늬낙엽병', '복숭아순나방', '사과응애', '철 결핍', '붕소 등 미량원소 불균형', '강풍·과습·착과 스트레스'],
      'nutrition': ['신초 황화·잎맥간 황화·잎끝 마름 예찰', '착과 불량과 영양·수분 스트레스 구분'],
      'pest': ['진딧물·응애·나방류 등 실제 개체·식흔 예찰', '피해 잎·과실 비율 기록'],
      'disease': ['낙화 후 잎·과실 병반을 주 1회 이상 확인'],
      'environment': ['가뭄·과습·강풍 후 착과 상태 재확인'],
    },
    {
      'm': 6, 'stage': '초기 과실비대', 'goal': '과실비대 관리',
      'tasks': ['적과 마무리', '유인 작업', '관수·토양수분 점검', '잡초 관리'],
      'predicted': ['갈색무늬병', '겹무늬썩음병', '탄저병', '복숭아순나방', '사과응애', '마그네슘 결핍', '칼륨 불균형', '과습·수분 스트레스'],
      'nutrition': ['오래된 잎 황화·잎맥간 황화 등 Mg/K 계열 패턴 예찰', '과실비대 편차·수세 차이 기록'],
      'pest': ['응애·흡즙해충·과실가해 해충 예찰', '트랩이 있으면 포획량 추세 기록'],
      'disease': ['장마 전후 잎·과실 반점과 확산속도 점검'],
      'environment': ['토양수분·배수·고온 스트레스 점검'],
    },
    {
      'm': 7, 'stage': '과실비대', 'goal': '고온·수분 관리',
      'tasks': ['고온·가뭄 대응', '관수 필요성 점검', '잡초 관리', '과실·가지 예찰'],
      'predicted': ['탄저병', '갈색무늬병', '겹무늬썩음병', '사과응애', '복숭아순나방', '노린재류', '마그네슘 결핍', '칼륨 불균형', '고온·일소·가뭄 스트레스'],
      'nutrition': ['고온기 황화·엽연괴사와 실제 결핍을 구분', 'Ca/Mg/K 불균형 의심 시 증상 분포 기록'],
      'pest': ['응애·나방류 등 개체수와 피해 증가속도 집중 예찰'],
      'disease': ['고온다습·강우 뒤 병반 확대 여부 집중 확인'],
      'environment': ['일소·가뭄·과습·뿌리 스트레스 예찰'],
    },
    {
      'm': 8, 'stage': '과실비대·착색 준비', 'goal': '수확 전 품질관리',
      'tasks': ['과실 상태 확인', '가지 처짐·지주 점검', '착색 준비'],
      'predicted': ['탄저병', '갈색무늬병', '겹무늬썩음병', '복숭아순나방', '노린재류', '사과응애', '마그네슘 결핍', '칼륨 불균형', '일소·강풍·낙과 스트레스'],
      'nutrition': ['잎 황화·과실 품질 저하가 결핍인지 노화인지 구분', '필요 시 엽분석 검토'],
      'pest': ['과실 피해 흔적·해충 개체수 점검'],
      'disease': ['과실 반점·부패·잎 병반 재확인'],
      'environment': ['고온·일소·강풍·태풍 대비'],
    },
    {
      'm': 9, 'stage': '착색·성숙', 'goal': '수확 준비',
      'tasks': ['착색 상태 확인', '성숙도 관찰', '낙과·강풍 위험 점검', '수확 계획'],
      'predicted': ['탄저병', '갈색무늬병', '겹무늬썩음병', '복숭아순나방', '노린재류', '마그네슘 결핍', '칼륨 불균형', '태풍·강풍·낙과 스트레스'],
      'nutrition': ['늦은 황화·엽연마름은 자연노화와 구분', '수확 전 불필요한 교정 살포 지양'],
      'pest': ['수확 전 피해과·해충 밀도 확인', '안전사용기준 확인이 필요한 시기'],
      'disease': ['수확 전 과실 병반·부패 위험 점검'],
      'environment': ['태풍·강풍·낙과 위험 예찰'],
    },
    {
      'm': 10, 'stage': '본격 수확', 'goal': '수확·선별·출하',
      'tasks': ['수확 적기 확인', '수확', '선별·출하', '수확량 기록'],
      'predicted': ['갈색무늬병', '과실 부패성 병해', '잔존 해충 피해과', '강우·저온 수확 스트레스'],
      'nutrition': ['수확기 결핍 증상은 위치·나무별로 기록해 다음 해 분석자료로 사용'],
      'pest': ['피해과 비율·해충 흔적 기록'],
      'disease': ['부패·병반 과실 비율 기록'],
      'environment': ['비·강풍 전후 수확 우선순위 조정'],
    },
    {
      'm': 11, 'stage': '수확 후', 'goal': '수확 후 정리',
      'tasks': ['수확 마무리', '낙엽·잔재 관리', '수세·수확 결과 기록'],
      'predicted': ['월동 해충 발생구역', '병든 잎·과실·가지 감염원', '결핍 의심 반복구역', '배수·토양구조 취약구역'],
      'nutrition': ['엽색·수세·수확량 차이를 구역별로 정리', '토양·엽 분석 필요 구역 선정'],
      'pest': ['피해가 많았던 나무·구역 표시'],
      'disease': ['병든 잎·과실·가지와 발생구역 기록'],
      'environment': ['배수·토양구조 문제구역 정리'],
    },
    {
      'm': 12, 'stage': '휴면 진입', 'goal': '결산·다음 해 준비',
      'tasks': ['비용·수익 결산', '작업기록 분석', '다음 해 개선계획'],
      'predicted': ['동해', '월동 해충', '월동 감염원', '반복 결핍 위험구역'],
      'nutrition': ['결핍 의심 사진·분석결과·시비기록 종합', '다음 해 검사·보정 계획 수립'],
      'pest': ['연간 해충 발생시기·밀도·피해량 정리'],
      'disease': ['연간 병 발생시기·기상조건·피해구역 정리'],
      'environment': ['서리·폭염·가뭄·과습·태풍 피해 이력 정리'],
    },
  ];

  static const _micronutrients = <int, List<String>>{
    1: ['미량원소 직접 투입보다 전년도 엽분석·토양검정 결과 확인', 'B·Zn·Fe·Mn 결핍 이력 구역 표시'],
    2: ['B·Zn 결핍 이력 확인', '고pH 토양은 Fe·Mn 흡수장해 가능성 점검'],
    3: ['B·Zn 상태 점검 — 꽃눈·발아 균일성과 과거 결핍기록 기준', 'Fe·Mn은 토양 pH와 새잎 황화 이력 있을 때 우선 확인'],
    4: ['B(붕소) — 개화·착과 관련 결핍 징후 있을 때 검토', 'Zn(아연) — 왜소엽·짧은 마디 등 결핍 이력 있을 때 확인', 'Fe·Mn — 새잎 잎맥 사이 황화가 보일 때 확인'],
    5: ['B·Zn — 신초·착과 이상이 지속될 때 재확인', 'Fe·Mn — 새잎 황화가 지속될 때 pH·뿌리환경과 함께 점검'],
    6: ['Fe·Mn — 새잎 황화 지속 시 확인', 'B·Zn은 무조건 추가하지 말고 증상·분석결과가 있을 때만 검토'],
    7: ['미량원소보다 Mg·K·Ca 상태 확인 비중 증가', 'Fe·Mn 결핍은 고pH·과습 등 흡수장해와 구분'],
    8: ['미량원소 추가 살포보다 엽분석·증상 확인 우선', '수확 전 불필요한 B·Zn·Fe·Mn 추가 투입 지양'],
    9: ['수확기에는 결핍 증상 기록 중심', 'B·Zn·Fe·Mn 보정은 분석자료를 모아 다음 시기 계획에 반영'],
    10: ['수확 중 결핍 의심 나무·구역 표시', '미량원소 보정은 수확 후 토양·엽 분석과 함께 계획'],
    11: ['B·Zn·Fe·Mn 결핍 이력과 분석결과 정리', '다음 해 필요 원소를 과원 구역별로 선정'],
    12: ['다음 해 미량원소 계획 수립', '분석결과 없는 예방적 과다 투입은 피함'],
  };

  static const _fertilizerReview = <int, List<String>>{
    1: ['기비 계획 수립 — N·P·K는 토양검정과 목표 수량 기준으로 결정', '유기물·토양개량 필요 여부를 배수·토양구조와 함께 검토'],
    2: ['기비 시용 여부·시기는 지역 토양과 동결 상태를 고려해 결정', '석회·고토 등 토양개량재는 pH·Mg 분석값 확인 후 검토'],
    3: ['발아 전 N·P·K 부족 여부 확인', '질소는 수세가 강한 나무에 일률적으로 추가하지 않음'],
    4: ['개화기 과도한 질소 추비는 피하고 수세·엽색을 먼저 확인', 'Ca·Mg 부족 이력은 이후 과실비대기 관리계획에 반영'],
    5: ['착과량이 많고 수세가 약할 때만 추비 필요성 검토', 'N·K 균형을 보되 과도한 질소는 웃자람 위험과 함께 판단'],
    6: ['과실비대기 K(칼륨) 수요와 Mg(마그네슘) 길항관계 함께 점검', 'Ca(칼슘)는 과실 품질 관리 관점에서 토양·엽 상태와 함께 검토'],
    7: ['K·Mg·Ca 균형 점검 — 한 성분 과다 투입으로 다른 성분 흡수 저해가 없는지 확인', '고온·가뭄 시 비료보다 관수·뿌리환경 정상화가 우선'],
    8: ['착색기 추가 질소는 신중히 판단', 'K·Mg·Ca는 엽분석·과실 상태를 근거로 부족할 때만 보정 검토'],
    9: ['수확 직전 불필요한 추비를 피하고 품질·수세 기록 중심', '수확 후 보정이 필요한 구역을 표시'],
    10: ['수확 중 수세·수량·과실품질을 기록해 다음 비료계획의 근거로 사용', '즉시 추비보다 수확 후 분석계획 수립 우선'],
    11: ['수확 후 토양검정 결과에 따라 기비·유기물·토양개량 계획 수립', 'N·P·K·Ca·Mg 부족/과다를 구역별로 정리'],
    12: ['연간 시비량·수량·수세를 함께 결산', '다음 해 기비·추비 계획을 토양검정·엽분석 기반으로 확정'],
  };

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
            child: Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ),
          ...items.map((x) => ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.arrow_right),
                title: Text(x),
              )),
        ],
      );

  Widget _predictedThreats(List<String> items, {bool current = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.crisis_alert_outlined, size: 19),
            const SizedBox(width: 6),
            Text(current ? '이번 달 예측 위협 후보' : '시기별 예측 위협 후보', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: items.map((x) => Chip(label: Text(x), avatar: const Icon(Icons.search, size: 16))).toList(),
          ),
          const SizedBox(height: 6),
          const Text('시기 기반 예찰 후보이며 확진이 아닙니다. 현재 기상·관찰기록과 카메라 현장진단으로 우선순위를 다시 판정합니다.', style: TextStyle(fontSize: 12)),
        ]),
      );

  Widget _nutrientPlan(int month, {bool current = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section(Icons.science_outlined, current ? '이번 달 필요 미량원소 검토' : '시기별 미량원소 검토', _micronutrients[month] ?? const []),
          _section(Icons.grass_outlined, current ? '이번 달 추가 비료 검토' : '시기별 추가 비료 검토', _fertilizerReview[month] ?? const []),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Text('※ “필요”는 고정 살포 의미가 아닙니다. 토양검정·엽분석·수세·착과량·결핍 증상을 확인한 뒤 실제 투입 여부와 양을 결정합니다.', style: TextStyle(fontSize: 12)),
          ),
        ]),
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
        const Text('농작업·예찰·예측위협과 함께 시기별 미량원소·추가 비료 검토 항목을 봅니다.'),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${now.year}년 농사 진행도', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: yearProgress),
          const SizedBox(height: 8),
          Text('${(yearProgress * 100).round()}% · 현재 ${_season(currentMonth)}'),
          Text('현재 단계: ${current['stage']}'),
          Text('이번 달 핵심목표: ${current['goal']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]))),
        const SizedBox(height: 6),
        Card(child: _predictedThreats(current['predicted'] as List<String>, current: true)),
        const SizedBox(height: 6),
        Card(child: _nutrientPlan(currentMonth, current: true)),
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
              _predictedThreats(item['predicted'] as List<String>, current: isCurrent),
              _nutrientPlan(month, current: isCurrent),
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
          title: Text('영양·비료 계획은 분석값으로 보정합니다'),
          subtitle: Text('월별 영양항목은 “확인할 시기”를 보여주는 기본 가이드입니다. 실제 투입 여부와 양은 토양검정·엽분석·수세·착과량·과거 시비기록을 함께 보고 결정해야 합니다. 과다 시비와 미량원소 과잉도 생육·품질 문제를 만들 수 있으므로 고정 처방으로 사용하지 않습니다.'),
        )),
      ],
    );
  }
}
