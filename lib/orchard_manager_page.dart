import 'package:flutter/material.dart';

import 'services/orchard_api.dart';
import 'services/orchard_selection.dart';
import 'services/orchard_zone_api.dart';

class OrchardManagerPage extends StatefulWidget {
  const OrchardManagerPage({super.key});

  @override
  State<OrchardManagerPage> createState() => _OrchardManagerPageState();
}

class _OrchardManagerPageState extends State<OrchardManagerPage> {
  final api = OrchardApi();
  final zoneApi = OrchardZoneApi();
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
              TextField(controller: area, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '과수원 전체 면적 ㎡')),
              TextField(controller: trees, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '과수원 전체 나무 수')),
              TextField(controller: stage, decoration: const InputDecoration(labelText: '대표 생육단계')),
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
                        id: (existing['id'] as num).toInt(),
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

  Future<void> removeOrchard(Map<String, dynamic> item) async {
    final orchardName = '${item['name']}';
    if (items.length <= 1) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('마지막 과수원은 삭제할 수 없습니다'),
          content: const Text('앱이 사용할 과수원이 최소 1개는 필요합니다. 다른 과수원을 먼저 추가한 뒤 삭제하세요.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
        ),
      );
      return;
    }

    final confirm = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 34),
          title: Text('$orchardName 삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '과수원을 삭제하면 이 과수원에 연결된 구역, 작업, 예찰 기록, 경영 기록, 잡초 이력 등도 함께 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
              ),
              const SizedBox(height: 14),
              Text('확인을 위해 아래에 "$orchardName"을 입력하세요.', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: confirm,
                autofocus: true,
                decoration: const InputDecoration(labelText: '과수원 이름 확인'),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: confirm.text.trim() == orchardName ? () => Navigator.pop(context, true) : null,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('영구 삭제'),
            ),
          ],
        ),
      ),
    );

    if (approved != true) return;
    if (mounted) setState(() => loading = true);

    final result = await api.remove(
      id: (item['id'] as num).toInt(),
      confirmName: orchardName,
    );
    if (!mounted) return;

    if (result['error'] != null) {
      setState(() {
        loading = false;
        message = '${result['error']}';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result['error']}')));
      return;
    }

    final wasSelected = OrchardSelection.name == orchardName;
    final next = result['next_orchard'] is Map
        ? Map<String, dynamic>.from(result['next_orchard'] as Map)
        : <String, dynamic>{};
    if (wasSelected && next.isNotEmpty) {
      await OrchardSelection.select(
        '${next['name']}',
        varietyText: '${next['variety'] ?? ''}',
      );
    }

    await load();
    if (!mounted) return;
    setState(() {
      loading = false;
      message = '$orchardName 과수원을 삭제했습니다.${wasSelected && next.isNotEmpty ? ' 현재 과수원은 ${next['name']}으로 변경되었습니다.' : ''}';
    });
  }

  Future<void> selectItem(Map<String, dynamic> item) async {
    await OrchardSelection.select('${item['name']}', varietyText: '${item['variety'] ?? ''}');
    if (!mounted) return;
    setState(() => message = '${item['name']}을(를) 현재 과수원으로 선택했습니다.');
  }

  Future<void> manageZones(Map<String, dynamic> orchard) async {
    final orchardName = '${orchard['name']}';
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _OrchardZonePage(
        orchardName: orchardName,
        allowedVarieties: _parseVarieties(orchard['variety']).isEmpty
            ? varieties
            : _parseVarieties(orchard['variety']),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(child: Text('🍎 과수원 · 품종 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
          ]),
          const Text('여러 과수원을 등록하고, 각 과수원 안에서 품종별 구역·나무 수·생육단계를 따로 관리합니다.'),
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
              child: Column(children: [
                ListTile(
                  leading: Icon(isSelected ? Icons.check_circle : Icons.park_outlined),
                  title: Text('${item['name']}', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text('품종: ${item['variety'] ?? '미지정'}\n전체 ${item['tree_count'] ?? 0}주 · ${item['area_m2'] ?? 0}㎡ · ${item['growth_stage'] ?? ''}'),
                  isThreeLine: true,
                  onTap: () => selectItem(item),
                  trailing: SizedBox(
                    width: 92,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: '수정',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => edit(item),
                        ),
                        IconButton(
                          tooltip: '삭제',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: loading ? null : () => removeOrchard(item),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => manageZones(item),
                      icon: const Icon(Icons.grid_view_outlined),
                      label: const Text('품종별 구역 · 나무 수 관리'),
                    ),
                  ),
                ),
              ]),
            );
          }),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('구역 정보는 자동추천과 예찰진단에 사용'),
              subtitle: Text('예: A구역 홍로 80주, B구역 후지 150주처럼 등록하면 자동추천이 우선 확인할 구역과 품종·나무 수를 함께 표시할 수 있습니다.'),
            ),
          ),
        ],
      );
}

class _OrchardZonePage extends StatefulWidget {
  const _OrchardZonePage({required this.orchardName, required this.allowedVarieties});
  final String orchardName;
  final List<String> allowedVarieties;

  @override
  State<_OrchardZonePage> createState() => _OrchardZonePageState();
}

class _OrchardZonePageState extends State<_OrchardZonePage> {
  final api = OrchardZoneApi();
  List<Map<String, dynamic>> zones = [];
  bool loading = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final r = await api.list(widget.orchardName);
    if (!mounted) return;
    setState(() {
      zones = r;
      loading = false;
    });
  }

  Future<void> editZone([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: '${existing?['zone_name'] ?? ''}');
    final trees = TextEditingController(text: '${existing?['tree_count'] ?? 0}');
    final area = TextEditingController(text: '${existing?['area_m2'] ?? 0}');
    final stage = TextEditingController(text: '${existing?['growth_stage'] ?? ''}');
    final note = TextEditingController(text: '${existing?['note'] ?? ''}');
    String variety = '${existing?['variety'] ?? (widget.allowedVarieties.isNotEmpty ? widget.allowedVarieties.first : '후지')}';
    if (!widget.allowedVarieties.contains(variety) && widget.allowedVarieties.isNotEmpty) variety = widget.allowedVarieties.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '품종 구역 추가' : '품종 구역 수정'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: '구역 이름 예: A구역, 남쪽 1블록')),
              DropdownButtonFormField<String>(
                value: variety,
                decoration: const InputDecoration(labelText: '품종'),
                items: widget.allowedVarieties.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setDialogState(() => variety = v ?? variety),
              ),
              TextField(controller: trees, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '나무 수')),
              TextField(controller: area, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '구역 면적 ㎡')),
              TextField(controller: stage, decoration: const InputDecoration(labelText: '현재 생육단계')),
              TextField(controller: note, decoration: const InputDecoration(labelText: '메모')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || variety.trim().isEmpty) return;
                final result = existing == null
                    ? await api.create(
                        orchard: widget.orchardName,
                        zoneName: name.text.trim(),
                        variety: variety,
                        treeCount: int.tryParse(trees.text.trim()) ?? 0,
                        areaM2: double.tryParse(area.text.trim()) ?? 0,
                        growthStage: stage.text.trim(),
                        note: note.text.trim(),
                      )
                    : await api.update(
                        id: (existing['id'] as num).toInt(),
                        zoneName: name.text.trim(),
                        variety: variety,
                        treeCount: int.tryParse(trees.text.trim()) ?? 0,
                        areaM2: double.tryParse(area.text.trim()) ?? 0,
                        growthStage: stage.text.trim(),
                        note: note.text.trim(),
                      );
                if (!context.mounted) return;
                if (result['error'] != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result['error']}')));
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) await load();
  }

  Future<void> removeZone(Map<String, dynamic> zone) async {
    final ok = await api.delete((zone['id'] as num).toInt());
    if (!mounted) return;
    setState(() => message = ok ? '구역을 삭제했습니다.' : '구역 삭제에 실패했습니다.');
    if (ok) await load();
  }

  @override
  Widget build(BuildContext context) {
    final totalTrees = zones.fold<int>(0, (sum, z) => sum + ((z['tree_count'] as num?)?.toInt() ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text('${widget.orchardName} · 품종 구역')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text('등록 구역 ${zones.length}개 · 총 $totalTrees주'),
            subtitle: const Text('자동추천은 이 정보를 이용해 우선 예찰 구역을 지정합니다.'),
          )),
          FilledButton.icon(onPressed: () => editZone(), icon: const Icon(Icons.add), label: const Text('구역 추가')),
          if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(message)),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          if (!loading && zones.isEmpty) const Card(child: ListTile(title: Text('아직 품종 구역이 없습니다.'))),
          ...zones.map((z) => Card(
            child: ListTile(
              leading: const Icon(Icons.grid_view_outlined),
              title: Text('${z['zone_name']} · ${z['variety']}'),
              subtitle: Text('${z['tree_count'] ?? 0}주 · ${z['area_m2'] ?? 0}㎡\n생육단계 ${z['growth_stage'] ?? '-'}${'${z['note'] ?? ''}'.trim().isNotEmpty ? '\n${z['note']}' : ''}'),
              isThreeLine: true,
              onTap: () => editZone(z),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => removeZone(z)),
            ),
          )),
        ],
      ),
    );
  }
}
