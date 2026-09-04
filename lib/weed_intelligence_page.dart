import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/farm_api.dart';
import 'services/orchard_selection.dart';
import 'services/weed_api.dart';
import 'services/weed_vision.dart';

class WeedIntelligencePage extends StatefulWidget {
  const WeedIntelligencePage({super.key});

  @override
  State<WeedIntelligencePage> createState() => _WeedIntelligencePageState();
}

class _WeedIntelligencePageState extends State<WeedIntelligencePage> {
  final picker = ImagePicker();
  final api = WeedApi();
  final farmApi = FarmApi();
  final zone = TextEditingController(text: '전체 구역');
  final note = TextEditingController();

  final List<XFile> photos = [];
  List<Map<String, dynamic>> history = [];
  Map<String, dynamic> result = {};

  double coveragePct = 0;
  String coverageLabel = '미측정';
  String distribution = '군락형';
  String growthStage = '생육초기';
  String weedGroup = '미상';
  int daysAfterLastSpray = 999;
  bool survivorSeen = false;
  bool analyzingPhoto = false;
  bool assessing = false;

  Future<void> takePhoto() async {
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 82);
    if (x == null) return;
    photos.add(x);
    await estimatePhotos();
  }

  Future<void> estimatePhotos() async {
    if (photos.isEmpty) return;
    setState(() => analyzingPhoto = true);
    final estimates = <WeedVisionEstimate>[];
    for (final p in photos) {
      estimates.add(await WeedVision.estimateGreenCover(p.path));
    }
    final valid = estimates.where((e) => e.sampledPixels > 0).toList();
    final avg = valid.isEmpty ? 0.0 : valid.map((e) => e.coveragePct).reduce((a, b) => a + b) / valid.length;
    setState(() {
      coveragePct = double.parse(avg.toStringAsFixed(1));
      coverageLabel = coveragePct < 15 ? '낮음' : coveragePct < 40 ? '중간' : '높음';
      analyzingPhoto = false;
    });
  }

  Future<void> assess() async {
    setState(() => assessing = true);
    result = await api.assess(
      zone: zone.text.trim(),
      coveragePct: coveragePct,
      distribution: distribution,
      growthStage: growthStage,
      weedGroup: weedGroup,
      survivorSeen: survivorSeen,
      daysAfterLastSpray: daysAfterLastSpray,
      photoCount: photos.length,
      note: note.text.trim(),
    );
    history = await api.history(zone: zone.text.trim());
    if (mounted) setState(() => assessing = false);
  }

  Future<void> addTask() async {
    if (result['recommendation'] == null) return;
    final title = '[${zone.text.trim()}] ${result['recommendation']} · 잡초 현장 확인';
    final priority = (result['priority_score'] as num? ?? 0).toInt() >= 75 ? 4 : 3;
    final ok = await farmApi.addTask(
      orchard: OrchardSelection.name,
      title: title,
      category: '잡초',
      priority: priority,
      scheduledAt: '${result['recommended_window'] ?? '오늘'}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '오늘의 할 일에 추가했습니다.' : '작업 추가에 실패했습니다.')));
  }

  Widget _choice(String label, String value, List<String> items, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final reasons = (result['reasons'] as List?) ?? [];
    final cautions = (result['cautions'] as List?) ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('🌱 잡초 스마트 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text('${OrchardSelection.name} · 카메라 피복도 보조 추정 + 살포시기 + 이력 분석'),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text('자동 피복도 추정: $coveragePct% · $coverageLabel'),
            subtitle: Text(photos.isEmpty ? '바닥이 보이도록 잡초 분포 사진을 촬영하세요.' : '${photos.length}장 평균 · 초록 식생 비율 기반 초기 보조 추정'),
          ),
        ),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: analyzingPhoto ? null : takePhoto, icon: const Icon(Icons.camera_alt), label: const Text('사진 추가'))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: photos.isEmpty ? null : () => setState(() { photos.clear(); coveragePct = 0; coverageLabel = '미측정'; }), child: const Text('초기화')),
        ]),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 105,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(photos[i].path), width: 105, height: 105, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(controller: zone, decoration: const InputDecoration(labelText: '구역')),
        _choice('분포 형태', distribution, const ['산발형', '군락형', '전면확산'], (v) => setState(() => distribution = v ?? distribution)),
        _choice('잡초 생육 단계', growthStage, const ['발생초기', '생육초기', '왕성생육', '개화·결실'], (v) => setState(() => growthStage = v ?? growthStage)),
        _choice('우점 잡초군', weedGroup, const ['화본과', '광엽', '사초과', '혼합', '미상'], (v) => setState(() => weedGroup = v ?? weedGroup)),
        DropdownButtonFormField<int>(
          value: daysAfterLastSpray,
          decoration: const InputDecoration(labelText: '직전 제초 후 경과'),
          items: const [
            DropdownMenuItem(value: 999, child: Text('미살포/기억 안 남')),
            DropdownMenuItem(value: 3, child: Text('7일 미만')),
            DropdownMenuItem(value: 10, child: Text('7~14일')),
            DropdownMenuItem(value: 20, child: Text('15일 이상')),
          ],
          onChanged: (v) => setState(() => daysAfterLastSpray = v ?? daysAfterLastSpray),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: survivorSeen,
          onChanged: (v) => setState(() => survivorSeen = v),
          title: const Text('직전 처리 후 살아남은 잡초가 보임'),
        ),
        TextField(controller: note, decoration: const InputDecoration(labelText: '메모 (선택)')),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: assessing || photos.isEmpty ? null : assess,
          icon: const Icon(Icons.auto_awesome),
          label: Text(assessing ? '분석 중...' : '살포시기 추천 실행'),
        ),
        if (photos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('사진이 있어야 자동 피복도 추정과 추천을 실행합니다.', style: TextStyle(fontSize: 12)),
          ),
        if (result.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (result['error'] != null)
                  Text('⚠️ ${result['error']}')
                else ...[
                  Text('${result['recommendation']} · 우선순위 ${result['priority_score']}/100', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${result['recommended_window']}'),
                  const SizedBox(height: 6),
                  Text('연간 플로우: ${result['annual_phase']}'),
                  Text('${result['annual_note']}'),
                  Text('재발생 지수: ${result['recurrence_score']}/100 · 누적기록 ${result['history_count']}건'),
                  const Divider(),
                  const Text('판단 근거', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...reasons.map((x) => Text('• $x')),
                  if (cautions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('주의', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...cautions.map((x) => Text('• $x')),
                  ],
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(onPressed: addTask, icon: const Icon(Icons.playlist_add_check), label: const Text('오늘의 할 일에 추가')),
                  const SizedBox(height: 6),
                  Text('${result['policy']}', style: const TextStyle(fontSize: 12)),
                ]
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text('구역별 최근 잡초 이력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (history.isEmpty) const Card(child: ListTile(title: Text('아직 누적된 잡초 분석 이력이 없습니다.'))),
        ...history.take(8).map((x) => Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text('${x['zone'] ?? '-'} · 피복 ${x['coverage_pct'] ?? 0}% · ${x['recommendation'] ?? ''}'),
                subtitle: Text('${x['growth_stage'] ?? ''} · ${x['distribution'] ?? ''} · 점수 ${x['priority_score'] ?? 0}\n${x['created_at'] ?? ''}'),
                isThreeLine: true,
              ),
            )),
        const SizedBox(height: 8),
        const Text('※ 자동 피복도는 바닥 사진의 초록 식생 비율을 추정하는 초기 비전 보조 기능입니다. 사과 잎·그늘·멀칭 등이 함께 찍히면 오차가 커질 수 있습니다.', style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
