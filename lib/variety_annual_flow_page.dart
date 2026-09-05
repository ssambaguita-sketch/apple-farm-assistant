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
                  Expanded(child: Text('과수원 데이터와 기상 보정값을 불러오는 중입니다...')),
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
            const Text('양력 12개월 농작업 일정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text(
              '각 월 안에 해당 24절기를 표시하고, 현재 월과 다음 달은 실제 생육단계·기상·수집된 적산온도로 작업창을 보정합니다.',
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
                child: Text(
                  '${_data['policy'] ?? ''}',
                  style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF5F695F)),
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
                Text('${OrchardSelection.name} · 양력 12개월 농작업', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
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
            '기상원 $source · 예보 평균기온 ${meanTemp ?? '-'}℃ · 최대 강수확률 ${pop ?? '-'}% · 적산온도 자료 $coverage',
            style: const TextStyle(fontSize: 12, color: Color(0xFF637064)),
          ),
          const SizedBox(height: 10),
          ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 7, color: Color(0xFF4A7C50)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _monthCard(BuildContext context, Map<String, dynamic> month, int currentMonth) {
    final m = (month['month'] as num).toInt();
    final terms = List<String>.from(month['solar_terms'] ?? const []);
    final tasks = List<String>.from(month['tasks'] ?? const []);
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFDCEFD8), borderRadius: BorderRadius.circular(999)),
                child: Text(
                  adjustment == 0 ? '기준일 유지' : adjustment < 0 ? '${adjustment.abs()}일 당김' : '$adjustment일 늦춤',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2E6B35)),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          ...tasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF4A8D50)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task, style: const TextStyle(fontSize: 13, height: 1.35))),
                ]),
              )),
        ]),
      ),
    );
  }

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
