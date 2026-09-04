import 'package:flutter/material.dart';

import 'services/orchard_api.dart';
import 'services/orchard_selection.dart';

class OrchardManagerPage extends StatefulWidget {
  const OrchardManagerPage({super.key});

  @override
  State<OrchardManagerPage> createState() => _OrchardManagerPageState();
}

class _OrchardManagerPageState extends State<OrchardManagerPage> {
  final api = OrchardApi();
  final varieties = const ['후지', '홍로', '감홍', '아리수', '시나노골드', '루비에스', '기타'];
  List<Map<String, dynamic>> items = [];
  bool loading = false;
  String message = '';

  Future<void> load() async {
    setState(() {
      loading = true;
      message = '';
    });
    final r = await api.list();
    if (!mounted) return;
    setState(() {
      items = r;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  List<String> _parseVarieties(dynamic value) => '${value ?? ''}'
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> edit([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final area = TextEditingController(text: '${existing?['area_m2'] ?? 0}');
    final trees = TextEditingController(text: '${existing?['tree_count'] ?? 0}');
    final stage = TextEditingController(text: '${existing?['growth_stage'] ?? ''}');
    final selected = <String>{..._parseVarieties(existing?['variety'])};
    if (selected.isEmpty) selected.add('후지');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '과수원 추가' : '과수원 수정'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: '과수원 이름')),
              const SizedBox(height: 12),
              const Text('재배 품종 · 복수 선택 가능', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: varieties.map((v) => FilterChip(
                  label: Text(v),
                  selected: selected.contains(v),
                  onSelected: (on) => setDialogState(() {
                    if (on) {
                      selected.add(v);
                    } else if (selected.length > 1) {
                      selected.remove(v);
                    }
                  }),
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(controller: area, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '면적 ㎡ (선택)')),
              TextField(controller: trees, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '나무 수 (선택)')),
              TextField(controller: stage, decoration: const InputDecoration(labelText: '현재 생육단계 (선택)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || selected.isEmpty) return;
                final result = existing == null
                    ? await api.create(
                        name: name.text.trim(),
                        varieties: selected.toList(),
                        areaM2: double.tryParse(area.text.trim()) ?? 0,
                        treeCount: int.tryParse(trees.text.trim()) ?? 0,
                        growthStage: stage.text.trim(),
                      )
                    : await api.update(
                        id: existing['id'] as int,
                        name: name.text.trim(),
                        varieties: selected.toList(),
                        areaM2: double.tryParse(area.text.trim()) ?? 0,
                        treeCount: int.tryParse(trees.text.trim()) ?? 0,
                        growthStage: stage.text.trim(),
                      );
                if (!context.mounted) return;
                if (result['error'] != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result['error']}')));
                  return;
                }
                await OrchardSelection.select(name.text.trim(), varietyText: selected.join(', '));
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await load();
      if (mounted) setState(() => message = '과수원 정보가 저장되고 현재 과수원으로 선택되었습니다.');
    }
  }

  Future<void> selectItem(Map<String, dynamic> item) async {
    await OrchardSelection.select('${item['name']}', varietyText: '${item['variety'] ?? ''}');
    if (!mounted) return;
    setState(() => message = '${item['name']}을(를) 현재 과수원으로 선택했습니다.');
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(child: Text('🍎 과수원 · 품종 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
          ]),
          const Text('여러 과수원을 등록하고, 과수원마다 한 개 이상의 사과 품종을 지정할 수 있습니다.'),
          const SizedBox(height: 10),
          ValueListenableBuilder<String>(
            valueListenable: OrchardSelection.notifier,
            builder: (context, selected, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text('현재 과수원: $selected'),
                subtitle: Text('품종: ${OrchardSelection.varieties}'),
              ),
            ),
          ),
          FilledButton.icon(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('새 과수원 추가')),
          if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(message)),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          if (!loading && items.isEmpty) const Card(child: ListTile(title: Text('등록된 과수원이 없습니다. 새 과수원을 추가하세요.'))),
          ...items.map((item) {
            final isSelected = OrchardSelection.name == '${item['name']}';
            return Card(
              child: ListTile(
                leading: Icon(isSelected ? Icons.check_circle : Icons.park_outlined),
                title: Text('${item['name']}', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text('품종: ${item['variety'] ?? '미지정'}\n나무 ${item['tree_count'] ?? 0}주 · 면적 ${item['area_m2'] ?? 0}㎡ · ${item['growth_stage'] ?? ''}'),
                isThreeLine: true,
                onTap: () => selectItem(item),
                trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => edit(item)),
              ),
            );
          }),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('현재 과수원 선택'),
              subtitle: Text('선택한 과수원은 앱에 저장됩니다. 홈 브리핑과 작업 목록은 선택된 과수원을 기준으로 불러오도록 연결됩니다.'),
            ),
          ),
        ],
      );
}
