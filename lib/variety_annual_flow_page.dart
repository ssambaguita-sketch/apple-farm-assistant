import 'package:flutter/material.dart';

import 'annual_flow_page.dart';
import 'services/orchard_selection.dart';

class VarietyAnnualFlowPage extends StatelessWidget {
  const VarietyAnnualFlowPage({super.key});

  static const _profiles = <String, Map<String, dynamic>>{
    '루비에스': {'group': '조생', 'harvest': '8월 중심', 'focus': {7: '성숙 전 과실 병반·일소·수분 스트레스 확인', 8: '수확 전 과실 병해·낙과·해충 피해 집중 확인', 9: '수확 결과·피해과 비율 기록 및 수세 회복 점검'}},
    '홍로': {'group': '조중생', 'harvest': '8~9월 중심', 'focus': {7: '착색 전 과실 병반·응애·나방류 피해 확인', 8: '착색·성숙과 함께 탄저병 등 과실 병반·낙과 집중 예찰', 9: '수확 전후 피해과·낙과·병반 기록'}},
    '아리수': {'group': '중생', 'harvest': '9월 중심', 'focus': {8: '9월 수확 준비를 고려해 과실 병반·착색·노린재류 피해 확인', 9: '성숙·수확 전 병해·낙과·강풍 위험 집중 확인', 10: '수확 결과와 잎·수세 상태 기록'}},
    '감홍': {'group': '중만생', 'harvest': '9~10월 중심', 'focus': {8: '후반 과실비대·Mg/K 불균형·과실 병반 함께 확인', 9: '성숙·착색과 탄저병·갈색무늬병·낙과 위험 집중 확인', 10: '수확기 과실 건전성·저온·강우 스트레스 점검'}},
    '시나노골드': {'group': '만생', 'harvest': '10월 중심', 'focus': {9: '늦은 성숙기를 고려해 잎·과실 병해와 강풍 위험 지속 확인', 10: '수확 전 과실 건전성·병반·저온 스트레스 집중 확인', 11: '수확 후 수세·병든 잎·월동 감염원 정리'}},
    '후지': {'group': '만생', 'harvest': '10~11월 중심', 'focus': {9: '착색·성숙 초기 병해·낙과·Mg/K 불균형 지속 확인', 10: '수확 전 과실 병해·강우·저온·낙과 위험 집중 확인', 11: '늦은 수확과 수확 후 수세·병든 잎·월동 감염원 정리'}},
  };

  static const _weedPlan = <int, List<String>>{
    1: ['월동잡초·전년도 재발생 구역 기록 정리', '제초제 살포보다 문제구역 지도 작성'],
    2: ['월동잡초 분포 예찰', '봄 1차 제초 후보구역 표시'],
    3: ['새 잡초 발생초기 촬영 시작', '피복도 증가 구역은 봄 1차 제초 준비'],
    4: ['봄 1차 핵심 제초 후보', '카메라 피복도·분포·강우예보를 함께 판정'],
    5: ['1차 처리 후 재발생·생존 잡초 재촬영', '효과 불량 구역은 원인분석 우선'],
    6: ['초여름 재발생 관리', '장마 전후 건조시간과 잡초 크기를 함께 확인'],
    7: ['여름잡초 집중 예찰', '고온·가뭄 스트레스와 재발생 속도 확인'],
    8: ['여름 2차 제초 후보', '피복도 급증 구역 우선 재평가'],
    9: ['수확 전 선택적 관리', '수확 동선과 품종 숙기를 고려해 필요한 구역만 관리'],
    10: ['수확기 최소 개입', '수확 방해 구역 중심 관리'],
    11: ['생존·재발생 잡초 지도 작성', '다음 해 저항성/방제실패 의심 구역 표시'],
    12: ['연간 제초 이력 결산', '살포 횟수·피복도 변화·생존 잡초 기록 분석'],
  };

  List<String> _varieties() {
    final raw = OrchardSelection.varieties.trim();
    final out = raw.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    return out.isEmpty ? const ['후지'] : out;
  }

  Widget _hero(BuildContext context) {
    final month = DateTime.now().month;
    final varieties = _varieties();
    final first = varieties.first;
    final p = _profiles[first];
    final group = p?['group'] ?? '기본';
    final harvest = p?['harvest'] ?? '생육단계 기준';
    final focusMap = p == null ? <int, String>{} : Map<int, String>.from(p['focus'] as Map);
    final focus = focusMap[month] ?? '실제 생육단계와 기상·관찰기록을 우선해 관리합니다.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.spa_outlined, color: Color(0xFF2F6B35)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${OrchardSelection.name} · 품종별 연간 플로우',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${varieties.join(' · ')} · $group · $harvest',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF637064)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniInfo(Icons.calendar_today_outlined, '$month월 집중', focus)),
              const SizedBox(width: 8),
              Expanded(child: _miniInfo(Icons.flag_outlined, '관리 기준', '실제 생육단계 우선')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String title, String value) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0x0E000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF35733C)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.3, color: Color(0xFF4D574F)),
          ),
        ],
      ),
    );
  }

  Widget _weedStrip() {
    final month = DateTime.now().month;
    final items = _weedPlan[month] ?? const <String>[];
    final primary = items.isNotEmpty ? items.first : '이번 달 잡초 관리 계획 확인';
    final secondary = items.length > 1 ? items[1] : '잡초 탭에서 카메라·구역이력·기상으로 재평가';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x10000000)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFE1F0DC),
            child: Icon(Icons.grass_rounded, color: Color(0xFF2F6B35), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('이번 달 잡초·제초', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(primary, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(secondary, style: const TextStyle(fontSize: 12, color: Color(0xFF667067))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _hero(context),
          _weedStrip(),
          const Expanded(child: AnnualFlowPage()),
        ],
      );
}
