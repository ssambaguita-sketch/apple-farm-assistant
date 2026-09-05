import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/diagnosis_api.dart';
import 'services/orchard_selection.dart';

class DiagnosisPage extends StatefulWidget {
  const DiagnosisPage({super.key});

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  final api = DiagnosisApi();
  final picker = ImagePicker();
  final note = TextEditingController();
  final List<XFile> photos = [];

  String organ = '잎';
  String leafAge = '모름';
  String pattern = '모름';
  String veinState = '모름';
  String lesionShape = '없음';
  String symmetry = '모름';
  String spread = '한잎';
  String insectsSeen = '모름';
  String feedingDamage = '모름';
  String soilCondition = '보통';
  bool loading = false;
  Map<String, dynamic> result = {};

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> capture() async {
    final shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 82, maxWidth: 1800);
    if (shot == null) return;
    setState(() => photos.add(shot));
  }

  Future<void> assess() async {
    setState(() => loading = true);
    final r = await api.assess({
      'orchard': OrchardSelection.name,
      'has_photo': photos.isNotEmpty,
      'organ': organ,
      'leaf_age': leafAge,
      'pattern': pattern,
      'vein_state': veinState,
      'lesion_shape': lesionShape,
      'symmetry': symmetry,
      'spread': spread,
      'insects_seen': insectsSeen,
      'feeding_damage': feedingDamage,
      'soil_condition': soilCondition,
      'note': note.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      result = r;
      loading = false;
    });
  }

  Widget dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget bulletList(String title, dynamic raw, {IconData icon = Icons.check_circle_outline}) {
    final items = raw is List ? raw : const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...items.map((x) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, size: 17),
                  const SizedBox(width: 6),
                  Expanded(child: Text('$x')),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget resultSection() {
    if (result.isEmpty) return const SizedBox.shrink();
    if (result['error'] != null) {
      return Card(child: ListTile(leading: const Icon(Icons.warning_amber), title: const Text('진단 실패'), subtitle: Text('${result['error']}')));
    }
    final scores = (result['category_scores'] as List?) ?? [];
    final ctx = result['context'] is Map ? Map<String, dynamic>.from(result['context'] as Map) : <String, dynamic>{};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const Text('판정 결과', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Card(
        child: ListTile(
          leading: const Icon(Icons.analytics_outlined),
          title: Text('${result['top_candidate'] ?? '-'} 의심'),
          subtitle: Text('후보 점수 ${result['top_score'] ?? '-'} / 100\n위협도 ${result['threat_score'] ?? '-'} / 100 · ${result['threat_level'] ?? '-'}'),
          trailing: Chip(label: Text('확신도 ${result['confidence'] ?? '-'}')),
        ),
      ),
      if (result['nutrient_hint'] != null)
        Card(child: ListTile(leading: const Icon(Icons.science_outlined), title: const Text('영양 후보'), subtitle: Text('${result['nutrient_hint']}'))),
      const Text('경쟁 후보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ...scores.map((x) {
        final m = Map<String, dynamic>.from(x as Map);
        final score = (m['score'] as num?)?.toDouble() ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.bold))), Text('${score.toInt()}/100')]),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: score / 100),
            ]),
          ),
        );
      }),
      bulletList('판단 근거', result['evidence']),
      bulletList('아직 부족한 증거', result['missing_evidence'], icon: Icons.help_outline),
      bulletList('다음 확인', result['next_checks'], icon: Icons.search),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('판정에 사용한 환경자료', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('과수원: ${OrchardSelection.name}'),
            Text('기상: ${ctx['weather_source'] ?? '-'}'),
            Text('최고기온: ${ctx['forecast_max_temp_c'] ?? '-'}℃'),
            Text('최고습도: ${ctx['forecast_max_humidity_pct'] ?? '-'}%'),
            Text('최대 강수확률: ${ctx['forecast_max_rain_probability_pct'] ?? '-'}%'),
            Text('생육단계: ${ctx['growth_stage'] ?? '-'}'),
            Text('사진 증거: ${ctx['photo_recorded'] == true ? '있음' : '없음'}'),
            const SizedBox(height: 6),
            const Text('현재 버전은 사진을 자동 영상판독하지 않고 현장 증거로 기록합니다.', style: TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('📷 결핍·병해충 진단', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Text('사진 증거 + 시각 특징 + KMA 기상 + 생육정보를 합쳐 후보와 위협도를 계산합니다.'),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.park_outlined),
            title: const Text('진단 대상 과수원'),
            subtitle: Text('${OrchardSelection.name} · ${OrchardSelection.varieties}'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('촬영 가이드', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('전체 나무 → 가지 → 잎 앞면 → 잎 뒷면 → 증상 확대 → 정상 잎 비교 순으로 여러 장을 찍으면 좋습니다.'),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: capture, icon: const Icon(Icons.camera_alt_outlined), label: const Text('사진 추가 촬영')),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('사진 ${photos.length}장 수집됨'),
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(photos[i].path), width: 86, height: 86, fit: BoxFit.cover)),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => photos.removeAt(i)),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      )
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 8),
        const Text('사진에서 보이는 특징', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        dropdown('관찰 부위', organ, const ['잎', '과실', '가지', '수간', '꽃'], (v) => setState(() => organ = v ?? '잎')),
        const SizedBox(height: 8),
        dropdown('증상이 먼저 보이는 잎', leafAge, const ['모름', '새잎', '오래된잎', '전체'], (v) => setState(() => leafAge = v ?? '모름')),
        const SizedBox(height: 8),
        dropdown('주요 패턴', pattern, const ['모름', '잎맥사이황화', '가장자리마름', '반점', '구멍식흔', '말림기형', '전체황화'], (v) => setState(() => pattern = v ?? '모름')),
        const SizedBox(height: 8),
        dropdown('잎맥 상태', veinState, const ['모름', '녹색유지', '함께황화'], (v) => setState(() => veinState = v ?? '모름')),
        const SizedBox(height: 8),
        dropdown('병반 형태', lesionShape, const ['없음', '원형', '불규칙', '수침상', '동심원'], (v) => setState(() => lesionShape = v ?? '없음')),
        const SizedBox(height: 8),
        dropdown('증상 분포', symmetry, const ['모름', '대칭', '불규칙'], (v) => setState(() => symmetry = v ?? '모름')),
        const SizedBox(height: 8),
        dropdown('발생 범위', spread, const ['한잎', '한가지', '한나무', '여러나무'], (v) => setState(() => spread = v ?? '한잎')),
        const SizedBox(height: 8),
        dropdown('해충·알·유충이 보이나요?', insectsSeen, const ['모름', '예', '아니오'], (v) => setState(() => insectsSeen = v ?? '모름')),
        const SizedBox(height: 8),
        dropdown('식흔·흡즙 흔적이 있나요?', feedingDamage, const ['모름', '예', '아니오'], (v) => setState(() => feedingDamage = v ?? '모름')),
        const SizedBox(height: 8),
        dropdown('토양 상태', soilCondition, const ['보통', '건조', '과습', '배수불량', '모름'], (v) => setState(() => soilCondition = v ?? '보통')),
        const SizedBox(height: 8),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: '추가 메모', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: loading ? null : assess, icon: const Icon(Icons.biotech_outlined), label: Text(loading ? '판정 중...' : '근거를 종합해 판정')),
        resultSection(),
        const SizedBox(height: 20),
        const Text('※ 결과는 현장 의사결정 지원용입니다. 영양결핍은 토양·엽 분석으로 확인하고, 방제 필요 시 사과 등록사항과 제품 라벨을 확인하세요.', style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
