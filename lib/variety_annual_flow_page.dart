import 'package:flutter/material.dart';

import 'annual_flow_page.dart';
import 'services/orchard_selection.dart';

class VarietyAnnualFlowPage extends StatelessWidget {
  const VarietyAnnualFlowPage({super.key});

  static const _profiles = <String, Map<String, dynamic>>{
    '루비에스': {
      'group': '조생',
      'harvest': '8월 중심',
      'focus': {
        7: '성숙 전 과실 병반·일소·수분 스트레스 확인',
        8: '수확 전 과실 병해·낙과·해충 피해 집중 확인',
        9: '수확 결과·피해과 비율 기록 및 수세 회복 점검',
      }
    },
    '홍로': {
      'group': '조중생',
      'harvest': '8~9월 중심',
      'focus': {
        7: '착색 전 과실 병반·응애·나방류 피해 확인',
        8: '착색·성숙과 함께 탄저병 등 과실 병반·낙과 집중 예찰',
        9: '수확 전후 피해과·낙과·병반 기록',
      }
    },
    '아리수': {
      'group': '중생',
      'harvest': '9월 중심',
      'focus': {
        8: '9월 수확 준비를 고려해 과실 병반·착색·노린재류 피해 확인',
        9: '성숙·수확 전 병해·낙과·강풍 위험 집중 확인',
        10: '수확 결과와 잎·수세 상태 기록',
      }
    },
    '감홍': {
      'group': '중만생',
      'harvest': '9~10월 중심',
      'focus': {
        8: '후반 과실비대·Mg/K 불균형·과실 병반 함께 확인',
        9: '성숙·착색과 탄저병·갈색무늬병·낙과 위험 집중 확인',
        10: '수확기 과실 건전성·저온·강우 스트레스 점검',
      }
    },
    '시나노골드': {
      'group': '만생',
      'harvest': '10월 중심',
      'focus': {
        9: '늦은 성숙기를 고려해 잎·과실 병해와 강풍 위험 지속 확인',
        10: '수확 전 과실 건전성·병반·저온 스트레스 집중 확인',
        11: '수확 후 수세·병든 잎·월동 감염원 정리',
      }
    },
    '후지': {
      'group': '만생',
      'harvest': '10~11월 중심',
      'focus': {
        9: '착색·성숙 초기 병해·낙과·Mg/K 불균형 지속 확인',
        10: '수확 전 과실 병해·강우·저온·낙과 위험 집중 확인',
        11: '늦은 수확과 수확 후 수세·병든 잎·월동 감염원 정리',
      }
    },
  };

  List<String> _varieties() {
    final raw = OrchardSelection.varieties.trim();
    final out = raw.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    return out.isEmpty ? const ['후지'] : out;
  }

  Widget _profileCard(BuildContext context) {
    final month = DateTime.now().month;
    final varieties = _varieties();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text('${OrchardSelection.name} · 품종별 연간 플로우 보정', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 6),
          Text('등록 품종: ${varieties.join(' · ')}'),
          const SizedBox(height: 10),
          ...varieties.map((v) {
            final p = _profiles[v];
            if (p == null) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.eco_outlined),
                title: Text(v),
                subtitle: const Text('등록된 표준 숙기 프로필이 없어 기본 연간 플로우를 사용합니다.'),
              );
            }
            final focus = Map<int, String>.from(p['focus'] as Map);
            final current = focus[month] ?? '현재 월은 기본 연간 플로우를 사용하고 실제 생육단계·기상·관찰기록으로 보정합니다.';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apple_outlined),
              title: Text('$v · ${p['group']} · ${p['harvest']}'),
              subtitle: Text('$month월 집중: $current'),
            );
          }),
          const SizedBox(height: 4),
          const Text('※ 품종 숙기는 지역·대목·수세·기상에 따라 달라질 수 있습니다. 이 값은 예찰 시기 보정용이며 실제 생육단계가 우선합니다.', style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _profileCard(context),
          const Expanded(child: AnnualFlowPage()),
        ],
      );
}
