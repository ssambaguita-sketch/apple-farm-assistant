import 'package:flutter/material.dart';

import 'services/orchard_selection.dart';
import 'services/phenology_api.dart';

class VarietyAnnualFlowPage extends StatefulWidget {
  const VarietyAnnualFlowPage({super.key});

  @override
  State<VarietyAnnualFlowPage> createState() => _VarietyAnnualFlowPageState();
}

class _VarietyAnnualFlowPageState extends State<VarietyAnnualFlowPage> {
  final PhenologyApi _api = PhenologyApi();
  Map<String, dynamic> _data = {};
  bool _loading = true;

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
    final result = await _api.calendar();
    if (!mounted) return;
    setState(() {
      _data = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final orchard = Map<String, dynamic>.from(_data['orchard'] ?? const {});
    final weather = Map<String, dynamic>.from(_data['weather'] ?? const {});
    final gdd = Map<String, dynamic>.from(_data['gdd'] ?? const {});
    final months = List<Map<String, dynamic>>.from(_data['months'] ?? const []);
    final reasons = List<String>.from(_data['adjustment_reasons'] ?? const []);
    final currentMonth = (_data['current_month'] as num?)?.toInt() ?? DateTime.now().month;
    final shift = (_data['current_adjustment_days'] as num?)?.toInt() ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _hero(orchard, weather, gdd, shift),
          const SizedBox(height: 12),
          if (_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                  SizedBox(width: 12),
                  Expanded(child: Text('과수원 데이터와 연간 농작업을 불러오는 중입니다...')),
                ]),
              ),
            )
          else if (_data['error'] != null)
            Card(
              color: const Color(0xFFFFF1F1),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('${_data['error']}', style: const TextStyle(color: Color(0xFF9A3F3F))),
              ),
            )
          else ...[
            _adjustmentCard(reasons, shift, weather, gdd),
            const SizedBox(height: 12),
            const Text('양력 12개월 통합 농작업 일정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text(
              '농작업·잡초 제거·엽면시비 타이밍과 함께, 시기별로 우선 검토할 영양성분과 피해야 할 성분을 표시합니다.',
              style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF667067)),
            ),
            const SizedBox(height: 12),
            ...months.map((month) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _monthCard(context, month, currentMonth),
                )),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_data['policy'] ?? ''}',
                      style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF5F695F)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '엽면시비 성분 표시는 사과 생육단계별 일반적인 검토 우선순위입니다. 실제 살포 여부는 엽분석·토양검정·수세·착과량·품종 숙기와 제품 라벨을 우선합니다. 제품명·농도·혼용비는 자동 처방하지 않습니다.',
                      style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF6B5A3B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hero(Map<String, dynamic> orchard, Map<String, dynamic> weather, Map<String, dynamic> gdd, int shift) {
    final varieties = List<String>.from(orchard['varieties'] ?? const ['후지']);
    final harvest = List<String>.from(orchard['harvest_hint'] ?? const []);
    final trees = orchard['tree_count'] ?? 0;
    final area = orchard['area_m2'] ?? 0;
    final stage = orchard['growth_stage'] ?? '미등록';
    final hasGps = orchard['lat'] != null && orchard['lon'] != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF5E5), Color(0xFFF8FAF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x10000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.calendar_month_rounded, color: Color(0xFF2F6B35)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${OrchardSelection.name} · 통합 연간 농작업', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  '${varieties.join(' · ')}${harvest.isEmpty ? '' : ' · ${harvest.join(' / ')}'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF637064)),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('생육단계 $stage'),
              _chip('$trees주 · ${_num(area)}㎡'),
              _chip(hasGps ? 'GPS 등록' : 'GPS 미등록'),
              _chip(weather['weather_source'] == 'kma' ? 'KMA 기상' : '기상 참고모드'),
              _chip('GDD ${gdd['gdd5'] ?? 0} · ${gdd['observed_days'] ?? 0}일'),
              _chip(shift == 0 ? '일정 보정 없음' : shift < 0 ? '${shift.abs()}일 앞당김' : '$shift일 늦춤'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adjustmentCard(List<String> reasons, int shift, Map<String, dynamic> weather, Map<String, dynamic> gdd) {
    final source = '${weather['weather_source'] ?? 'unknown'}';
    final meanTemp = weather['forecast_mean_temp_c'];
    final pop = weather['forecast_max_rain_probability_pct'];
    final wind = weather['forecast_max_wind_ms'];
    final coverage = '${gdd['coverage'] ?? '없음'}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune_rounded, color: Color(0xFF2F6B35)),
            const SizedBox(width: 8),
            const Expanded(child: Text('생육·기상 자동 일정 보정', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            Text(
              shift == 0 ? '0일' : shift < 0 ? '${shift.abs()}일 빠르게' : '$shift일 늦게',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2F6B35)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            '기상원 $source · 평균기온 ${meanTemp ?? '-'}℃ · 강수확률 ${pop ?? '-'}% · 풍속 ${wind ?? '-'}m/s · GDD 자료 $coverage',
            style: const TextStyle(fontSize: 12, color: Color(0xFF637064)),
          ),
          const SizedBox(height: 10),
          ...reasons.map((r) => _bullet(r, const Color(0xFF4A7C50))),
        ]),
      ),
    );
  }

  Widget _monthCard(BuildContext context, Map<String, dynamic> month, int currentMonth) {
    final m = (month['month'] as num).toInt();
    final terms = List<String>.from(month['solar_terms'] ?? const []);
    final tasks = List<String>.from(month['tasks'] ?? const []);
    final weed = List<String>.from(month['weed_timing'] ?? const []);
    final foliar = List<String>.from(month['foliar_timing'] ?? const []);
    final nutrients = _foliarNutrients(m);
    final weedStatus = '${month['weed_status'] ?? '월별 기준'}';
    final foliarStatus = '${month['foliar_status'] ?? '월별 기준'}';
    final active = month['active_adjustment'] == true;
    final adjustment = (month['adjustment_days'] as num?)?.toInt() ?? 0;
    final isCurrent = m == currentMonth;

    return Card(
      color: isCurrent ? const Color(0xFFF2F8EF) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF3E7D45) : const Color(0xFFE2F0DE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('$m월', style: TextStyle(fontWeight: FontWeight.w900, color: isCurrent ? Colors.white : const Color(0xFF2E6B35))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${month['stage']} · ${month['goal']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(terms.join(' · '), style: const TextStyle(fontSize: 12, color: Color(0xFF6A746B))),
              ]),
            ),
            if (active)
              _statusChip(
                adjustment == 0 ? '기준일 유지' : adjustment < 0 ? '${adjustment.abs()}일 당김' : '$adjustment일 늦춤',
                const Color(0xFFDCEFD8),
                const Color(0xFF2E6B35),
              ),
          ]),
          const SizedBox(height: 14),
          _sectionTitle(Icons.check_circle_rounded, '주요 농작업', const Color(0xFF4A8D50)),
          const SizedBox(height: 7),
          ...tasks.map((task) => _bullet(task, const Color(0xFF4A8D50))),
          const Divider(height: 22),
          Row(children: [
            Expanded(child: _sectionTitle(Icons.grass_rounded, '잡초 제거 타이밍', const Color(0xFF728F3E))),
            _statusChip(weedStatus, const Color(0xFFF0F5E5), const Color(0xFF617A35)),
          ]),
          const SizedBox(height: 7),
          ...weed.map((item) => _bullet(item, const Color(0xFF7A9B43))),
          const Divider(height: 22),
          Row(children: [
            Expanded(child: _sectionTitle(Icons.water_drop_outlined, '엽면시비 타이밍', const Color(0xFF4E7FB6))),
            _statusChip(foliarStatus, const Color(0xFFEAF2FA), const Color(0xFF426C98)),
          ]),
          const SizedBox(height: 7),
          ...foliar.map((item) => _bullet(item, const Color(0xFF4E7FB6))),
          const SizedBox(height: 8),
          const Text('시기별 성분 우선순위', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF355D86))),
          const SizedBox(height: 8),
          ...nutrients.map(_nutrientRow),
        ]),
      ),
    );
  }

  List<Map<String, String>> _foliarNutrients(int month) {
    switch (month) {
      case 1:
      case 2:
        return const [
          {'name': '정기 엽면시비 없음', 'level': '보류', 'role': '휴면기에는 살포보다 토양·엽분석 계획과 결핍 이력 정리가 우선'},
          {'name': 'B·Zn·Mg·Mn·Fe', 'level': '분석대상', 'role': '전년도 결핍 이력이 있는 성분을 다음 생육기 점검 대상으로 기록'},
        ];
      case 3:
        return const [
          {'name': '붕소(B)', 'level': '조건부', 'role': '꽃눈·수분·착과 관련 결핍 이력이 있을 때 우선 점검'},
          {'name': '아연(Zn)', 'level': '조건부', 'role': '로제트·소엽 등 아연 결핍 이력이 있는 과원에서 점검'},
          {'name': '질소(N)', 'level': '일률살포 아님', 'role': '발아 직전 엽면적이 작아 정기 엽면 공급 대상으로 두지 않음'},
        ];
      case 4:
        return const [
          {'name': '붕소(B)', 'level': '우선검토', 'role': '개화 전후 수분·착과 관련. 결핍 근거가 있을 때만 사용'},
          {'name': '아연(Zn)', 'level': '조건부', 'role': '초기 잎 전개와 신초 결핍 증상이 있을 때 보완 검토'},
          {'name': '철(Fe)·망간(Mn)', 'level': '증상교정', 'role': '황화 증상 시 원인 확인 후 단기 교정용으로 검토; 토양 pH·근권 원인도 함께 해결'},
          {'name': '칼슘(Ca)', 'level': '착과 후 시작', 'role': '만개 중 일률 살포보다 낙화·착과 후 과실 관리 단계에서 시작 검토'},
        ];
      case 5:
        return const [
          {'name': '칼슘(Ca)', 'level': '우선', 'role': '착과 후 어린 과실의 칼슘 관리 시작 시기'},
          {'name': '붕소(B)', 'level': '조건부', 'role': '착과 불량·결핍 이력이 명확한 경우만 추가 검토'},
          {'name': '마그네슘(Mg)', 'level': '조건부', 'role': '엽색 저하·분석상 부족 시 광합성 유지 보완'},
          {'name': '아연(Zn)·망간(Mn)', 'level': '조건부', 'role': '신초·잎 분석이나 결핍 증상 근거가 있을 때 보완'},
        ];
      case 6:
        return const [
          {'name': '칼슘(Ca)', 'level': '우선', 'role': '초기 과실비대기의 핵심 보완 성분으로 우선 검토'},
          {'name': '마그네슘(Mg)', 'level': '조건부', 'role': 'K와 길항 가능성을 함께 보며 결핍 시 보완'},
          {'name': '망간(Mn)·아연(Zn)', 'level': '조건부', 'role': '엽분석 또는 결핍 증상이 있을 때만 보완'},
          {'name': '철(Fe)', 'level': '증상교정', 'role': '철 결핍성 황화가 확인될 때 단기 교정; 근권 pH 개선 병행'},
        ];
      case 7:
        return const [
          {'name': '칼슘(Ca)', 'level': '우선', 'role': '과실비대기 과실 칼슘 관리 지속 검토'},
          {'name': '마그네슘(Mg)', 'level': '조건부', 'role': '중·하엽 황화나 분석상 부족 시 보완'},
          {'name': '칼륨(K)', 'level': '조건부', 'role': '과실비대에 필요하지만 과다 시 Mg·Ca 길항 우려가 있어 분석 근거가 있을 때만 보완'},
          {'name': 'Mn·Zn', 'level': '조건부', 'role': '결핍이 확인된 구역만 선택적으로 보완'},
        ];
      case 8:
        return const [
          {'name': '칼슘(Ca)', 'level': '우선', 'role': '수확이 아직 남은 품종에서 과실 칼슘 관리 지속 검토'},
          {'name': '칼륨(K)', 'level': '조건부', 'role': '착색·당도 목적의 일률 살포는 피하고 분석·수세·품종 숙기를 보고 판단'},
          {'name': '마그네슘(Mg)', 'level': '조건부', 'role': 'K 사용량이 많거나 잎 황화가 있을 때 길항관계 점검'},
          {'name': '질소(N)', 'level': '피함', 'role': '착색기 과다 질소는 착색·성숙 지연 우려가 있어 불필요한 엽면시비 피함'},
        ];
      case 9:
        return const [
          {'name': '칼슘(Ca)', 'level': '만생종 조건부', 'role': '수확이 충분히 남은 만생 품종에서만 필요성 검토'},
          {'name': 'Mg·K', 'level': '분석기반', 'role': '결핍이 확인되어도 수확 예정일이 가까우면 일률 살포하지 않음'},
          {'name': '질소(N)', 'level': '피함', 'role': '수확 직전 착색·성숙 단계에서는 불필요한 질소성 엽면시비 피함'},
        ];
      case 10:
        return const [
          {'name': '수확 중 정기 성분 없음', 'level': '보류', 'role': '수확 품종은 엽면시비보다 수확·품질·잔류 안전을 우선'},
          {'name': '질소(N)', 'level': '수확후 조건부', 'role': '수확이 끝나고 잎이 충분히 건전한 경우 저장양분 보완 필요성을 분석 후 검토'},
          {'name': '붕소(B)·아연(Zn)', 'level': '수확후 조건부', 'role': '결핍 이력이 있고 잎 기능이 유지되는 경우 다음 해 꽃눈·신초 대비 보완 검토'},
        ];
      case 11:
        return const [
          {'name': 'B·Zn', 'level': '조건부', 'role': '낙엽 전 잎이 아직 건전하고 결핍 이력이 있을 때만 보완 검토'},
          {'name': '질소(N)', 'level': '조건부', 'role': '저장양분 보완 목적은 수세·엽분석 근거가 있는 경우에만 검토'},
          {'name': 'Ca·K·Mg', 'level': '정기살포 아님', 'role': '수확 후에는 무조건적 반복 엽면시비보다 다음 해 토양·시비 계획에 반영'},
        ];
      case 12:
      default:
        return const [
          {'name': '정기 엽면시비 없음', 'level': '종료', 'role': '휴면 진입 후에는 연간 기록·분석과 다음 해 성분 계획 수립'},
        ];
    }
  }

  Widget _nutrientRow(Map<String, String> item) {
    final level = item['level'] ?? '';
    final avoid = level == '피함' || level == '보류' || level == '종료';
    final color = avoid ? const Color(0xFF9B4B46) : const Color(0xFF426C98);
    final background = avoid ? const Color(0xFFFFF1EF) : const Color(0xFFF2F7FC);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusChip(level, background, color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 3),
                Text(item['role'] ?? '', style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF58625A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      );

  Widget _bullet(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 7, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35))),
        ]),
      );

  Widget _statusChip(String text, Color background, Color foreground) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: foreground)),
      );

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF425044))),
      );

  String _num(dynamic value) {
    if (value is num) return value.toStringAsFixed(0);
    return '$value';
  }
}
