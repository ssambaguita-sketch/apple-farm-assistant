import 'package:flutter/material.dart';

import 'services/orchard_api.dart';
import 'services/orchard_selection.dart';

class VarietyAnnualFlowPage extends StatefulWidget {
  const VarietyAnnualFlowPage({super.key});

  @override
  State<VarietyAnnualFlowPage> createState() => _VarietyAnnualFlowPageState();
}

class _VarietyAnnualFlowPageState extends State<VarietyAnnualFlowPage> {
  final OrchardApi _api = OrchardApi();
  Map<String, dynamic>? _orchard;
  bool _loading = true;

  static const _profiles = <String, Map<String, dynamic>>{
    '루비에스': {'group': '조생', 'harvest': '8월'},
    '홍로': {'group': '조중생', 'harvest': '8~9월'},
    '아리수': {'group': '중생', 'harvest': '9월'},
    '감홍': {'group': '중만생', 'harvest': '9~10월'},
    '시나노골드': {'group': '만생', 'harvest': '10월'},
    '후지': {'group': '만생', 'harvest': '10~11월'},
  };

  static const _terms = <Map<String, dynamic>>[
    {'name': '소한', 'm': 1, 'd': 5, 'stage': '휴면', 'tasks': ['전년도 경영·수확·병해충 기록 결산', '동해·수피 갈라짐·월동해충 흔적 점검', '전정 계획과 작업구역 우선순위 설정']},
    {'name': '대한', 'm': 1, 'd': 20, 'stage': '휴면', 'tasks': ['전정 도구·시설·지주 점검', '병든 가지·월동 감염원 표시', '토양검정·엽분석 결과로 시비 계획 검토']},
    {'name': '입춘', 'm': 2, 'd': 4, 'stage': '휴면 후반', 'tasks': ['동계전정 시작·진행', '수형·가지 밀도 조정', '월동 해충·병반을 전정 중 함께 기록']},
    {'name': '우수', 'm': 2, 'd': 19, 'stage': '휴면 후반', 'tasks': ['동계전정 지속', '배수로·토양 과습 취약구역 점검', '전년도 결핍 반복 나무 표시']},
    {'name': '경칩', 'm': 3, 'd': 5, 'stage': '발아 준비', 'tasks': ['전정 마무리', '유인·지주·관수시설 점검', '발아 전 월동해충·병든 조직 집중 예찰']},
    {'name': '춘분', 'm': 3, 'd': 20, 'stage': '발아 준비', 'tasks': ['눈 발달 상태 비교', '늦서리·저온 예보 확인', '봄 잡초 발생초기 구역 촬영 시작']},
    {'name': '청명', 'm': 4, 'd': 5, 'stage': '발아·개화 전', 'tasks': ['꽃눈·새잎 상태 확인', '강우 뒤 초기 병반 예찰', 'Fe·Zn·B 계열 결핍 의심 신초 비교 관찰']},
    {'name': '곡우', 'm': 4, 'd': 20, 'stage': '개화', 'tasks': ['개화·수분 상태 관찰', '서리·강풍 피해 확인', '수분곤충 활동을 고려해 방제 의사결정 주의']},
    {'name': '입하', 'm': 5, 'd': 5, 'stage': '착과', 'tasks': ['착과량 확인', '적과 시작', '진딧물·응애·나방류와 잎 병반 예찰']},
    {'name': '소만', 'm': 5, 'd': 21, 'stage': '착과', 'tasks': ['적과 강도 조정', '신초 생육·수세 편차 기록', '잡초 1차 처리 후 재발생 구역 확인']},
    {'name': '망종', 'm': 6, 'd': 6, 'stage': '초기 과실비대', 'tasks': ['적과 마무리', '유인·가지 배치 점검', '장마 전 배수·토양수분·잡초 상태 확인']},
    {'name': '하지', 'm': 6, 'd': 21, 'stage': '과실비대', 'tasks': ['과실비대 편차 기록', 'Mg·K 불균형 의심 잎 예찰', '응애·과실가해 해충·병반 증가속도 확인']},
    {'name': '소서', 'm': 7, 'd': 7, 'stage': '과실비대', 'tasks': ['고온·가뭄·일소 위험 점검', '관수 필요성 판단', '여름잡초 피복도와 재발생 속도 확인']},
    {'name': '대서', 'm': 7, 'd': 23, 'stage': '과실비대', 'tasks': ['과실·잎 일소와 수분 스트레스 점검', '탄저병·갈색무늬병 등 여름 병해 집중 예찰', '가지 처짐·지주 보강']},
    {'name': '입추', 'm': 8, 'd': 7, 'stage': '착색 준비', 'tasks': ['착색 준비와 과실 건전성 점검', '태풍·강풍 대비 지주·유인끈 확인', '여름 2차 잡초 관리 필요구역 재평가']},
    {'name': '처서', 'm': 8, 'd': 23, 'stage': '착색·성숙', 'tasks': ['조생·중생 품종 성숙도 확인', '탄저병·노린재류·낙과 집중 예찰', '수확 동선과 인력 계획 수립']},
    {'name': '백로', 'm': 9, 'd': 8, 'stage': '착색·성숙', 'tasks': ['홍로·아리수 등 수확 적기 판단', '태풍·강풍·낙과 위험 점검', '수확 전 피해과·병반 비율 기록']},
    {'name': '추분', 'm': 9, 'd': 23, 'stage': '성숙·수확', 'tasks': ['중생·중만생 품종 수확·선별', '만생 품종 착색·성숙도 지속 관찰', '수확량·판매·비용 기록 시작']},
    {'name': '한로', 'm': 10, 'd': 8, 'stage': '본격 수확', 'tasks': ['감홍·시나노골드 등 수확 적기 확인', '후지 성숙·착색·병반 점검', '강우·저온 전후 수확 우선순위 조정']},
    {'name': '상강', 'm': 10, 'd': 23, 'stage': '수확', 'tasks': ['만생 품종 본격 수확·선별·출하', '피해과·낙과·수확량 기록', '수확 구역별 품질 차이 기록']},
    {'name': '입동', 'm': 11, 'd': 7, 'stage': '수확 후', 'tasks': ['후지 수확 마무리', '병든 잎·과실·잔재 정리', '수세·수확량·품질을 구역별로 정리']},
    {'name': '소설', 'm': 11, 'd': 22, 'stage': '휴면 진입', 'tasks': ['월동 해충·감염원 다발생 구역 표시', '토양·엽 분석 필요구역 선정', '배수·토양구조 문제구역 정리']},
    {'name': '대설', 'm': 12, 'd': 7, 'stage': '휴면', 'tasks': ['동해·적설 대비 시설 점검', '연간 작업·제초·병해충 기록 분석', '다음 해 개선 작업 후보 작성']},
    {'name': '동지', 'm': 12, 'd': 22, 'stage': '휴면', 'tasks': ['연간 매출·비용·순이익 결산', '품종별 수확성과 비교', '다음 해 전정·시비·예찰·잡초관리 계획 확정']},
  ];

  @override
  void initState() {
    super.initState();
    OrchardSelection.notifier.addListener(_selectionChanged);
    _load();
  }

  @override
  void dispose() {
    OrchardSelection.notifier.removeListener(_selectionChanged);
    super.dispose();
  }

  void _selectionChanged() => _load();

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final items = await _api.list();
    final selected = OrchardSelection.name;
    Map<String, dynamic>? found;
    for (final item in items) {
      if ('${item['name']}' == selected) {
        found = item;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _orchard = found;
      _loading = false;
    });
  }

  List<String> _varieties() {
    final raw = '${_orchard?['variety'] ?? OrchardSelection.varieties}'.trim();
    final values = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return values.isEmpty ? const ['후지'] : values;
  }

  int _termIndex(DateTime now) {
    final dates = _terms.map((t) => DateTime(now.year, t['m'] as int, t['d'] as int)).toList();
    var index = 0;
    for (var i = 0; i < dates.length; i++) {
      if (!now.isBefore(dates[i])) index = i;
    }
    return index;
  }

  String _harvestHint(List<String> varieties) {
    final hints = <String>[];
    for (final v in varieties) {
      final h = _profiles[v]?['harvest'];
      if (h != null) hints.add('$v $h');
    }
    return hints.isEmpty ? '등록 생육단계 기준' : hints.join(' · ');
  }

  List<String> _personalizedTasks(Map<String, dynamic> term) {
    final tasks = List<String>.from(term['tasks'] as List);
    final varieties = _varieties();
    final stage = '${_orchard?['growth_stage'] ?? ''}'.trim();
    final trees = (_orchard?['tree_count'] as num?)?.toInt() ?? 0;
    final area = (_orchard?['area_m2'] as num?)?.toDouble() ?? 0;
    final name = OrchardSelection.name;

    if (stage.isNotEmpty) {
      tasks.insert(0, '$name의 실제 등록 생육단계 「$stage」를 절기 예상단계보다 우선해 작업 시기를 조정');
    }
    if (trees > 0 || area > 0) {
      final scale = [if (trees > 0) '$trees주', if (area > 0) '${area.toStringAsFixed(0)}㎡'].join(' · ');
      tasks.add('작업 규모 $scale 기준으로 구역을 나눠 완료율 기록');
    }
    if (varieties.length > 1) {
      tasks.add('품종별 숙기가 다르므로 ${varieties.join('·')}를 같은 날짜에 일괄 처리하지 말고 품종별 상태를 따로 확인');
    }
    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentIndex = _termIndex(now);
    final current = _terms[currentIndex];
    final next = _terms[(currentIndex + 1) % _terms.length];
    final varieties = _varieties();
    final stage = '${_orchard?['growth_stage'] ?? '미등록'}';
    final trees = _orchard?['tree_count'] ?? 0;
    final area = _orchard?['area_m2'] ?? 0;
    final hasLocation = _orchard?['lat'] != null && _orchard?['lon'] != null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEAF5E5), Color(0xFFF8FAF6)]),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x10000000)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.eco_outlined, color: Color(0xFF2F6B35))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${OrchardSelection.name} · 24절기 연간 농작업', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('${varieties.join(' · ')} · ${_harvestHint(varieties)}', style: const TextStyle(fontSize: 12, color: Color(0xFF637064))),
                ])),
                if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _chip('현재 절기', '${current['name']}'),
                _chip('다음 절기', '${next['name']}'),
                _chip('생육단계', stage),
                _chip('규모', '${area}㎡ · ${trees}주'),
                _chip('위치', hasLocation ? 'GPS 적용' : 'GPS 미등록'),
              ]),
              const SizedBox(height: 12),
              const Text('※ 24절기는 태양 황경 기준입니다. 절기 날짜는 해마다 약 ±1일 차이가 날 수 있으며, 실제 발아·개화·착과·성숙 상태와 현장 기상을 우선합니다.', style: TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF667067))),
            ]),
          ),
          const SizedBox(height: 14),
          _currentCard(current),
          const SizedBox(height: 18),
          const Text('24절기 연간 작업표', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('선택한 과수원 데이터가 각 절기 작업에 반영됩니다.', style: TextStyle(color: Color(0xFF667067))),
          const SizedBox(height: 10),
          ...List.generate(_terms.length, (i) => _termCard(_terms[i], i == currentIndex, now.year)),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x10000000))),
        child: Text('$label · $value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );

  Widget _currentCard(Map<String, dynamic> term) {
    final tasks = _personalizedTasks(term);
    return Card(
      color: const Color(0xFFF1F8EE),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.today_rounded, color: Color(0xFF2F6B35)),
            const SizedBox(width: 8),
            Expanded(child: Text('지금은 ${term['name']} · 예상 ${term['stage']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 12),
          ...tasks.take(5).map((t) => _taskRow(t)),
        ]),
      ),
    );
  }

  Widget _termCard(Map<String, dynamic> term, bool active, int year) {
    final tasks = _personalizedTasks(term);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: active ? const Color(0xFFF3F9F0) : Colors.white,
        child: ExpansionTile(
          initiallyExpanded: active,
          leading: CircleAvatar(
            backgroundColor: active ? const Color(0xFF3E7D45) : const Color(0xFFE6F0E3),
            foregroundColor: active ? Colors.white : const Color(0xFF2F6B35),
            child: Text('${term['m']}/${term['d']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          title: Text('${term['name']} · ${term['stage']}', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('$year년 기준 약 ${term['m']}월 ${term['d']}일 · 실제 날짜 ±1일 가능'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: tasks.map(_taskRow).toList(),
        ),
      ),
    );
  }

  Widget _taskRow(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF3E7D45))),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ]),
      );
}
