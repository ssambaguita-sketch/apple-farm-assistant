import 'package:flutter/material.dart';

import 'services/farm_api.dart';
import 'services/orchard_selection.dart';

class TaskManagementPage extends StatefulWidget {
  const TaskManagementPage({super.key});

  @override
  State<TaskManagementPage> createState() => TaskManagementPageState();
}

class TaskManagementPageState extends State<TaskManagementPage> {
  final api = FarmApi();
  List<dynamic> items = const [];
  bool loading = false;
  String message = '';

  String get orchard => OrchardSelection.name.trim();

  @override
  void initState() {
    super.initState();
    OrchardSelection.notifier.addListener(_orchardChanged);
    reload();
  }

  @override
  void dispose() {
    OrchardSelection.notifier.removeListener(_orchardChanged);
    super.dispose();
  }

  void _orchardChanged() {
    reload();
  }

  Future<void> reload() async {
    if (!mounted || loading) return;
    setState(() => loading = true);
    final result = await api.tasks(orchard);
    if (!mounted) return;
    setState(() {
      items = result;
      loading = false;
    });
  }

  Future<void> add() async {
    final title = TextEditingController();
    final scheduled = TextEditingController(text: '오늘');
    String category = '일반';
    int priority = 2;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$orchard 작업 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: '작업명')),
                TextField(controller: scheduled, decoration: const InputDecoration(labelText: '예정시간/날짜')),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: '분류'),
                  items: const ['일반', '전정', '적과', '관수', '방제', '예찰', '수확', '잡초', '엽면시비']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? '일반'),
                ),
                DropdownButtonFormField<int>(
                  value: priority,
                  decoration: const InputDecoration(labelText: '우선순위'),
                  items: const [1, 2, 3, 4, 5]
                      .map((e) => DropdownMenuItem(value: e, child: Text('P$e')))
                      .toList(),
                  onChanged: (v) => setDialogState(() => priority = v ?? 2),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                final success = await api.addTask(
                  orchard: orchard,
                  title: title.text.trim(),
                  category: category,
                  priority: priority,
                  scheduledAt: scheduled.text.trim(),
                );
                if (context.mounted) Navigator.pop(context, success);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    scheduled.dispose();
    if (ok == true) {
      if (mounted) setState(() => message = '✅ $orchard 작업 저장 완료');
      await reload();
    } else if (ok == false && mounted) {
      setState(() => message = '작업 추가를 취소했습니다.');
    }
  }

  Future<void> complete(int id) async {
    final ok = await api.completeTask(id);
    if (!mounted) return;
    setState(() => message = ok ? '✅ 완료 처리됨' : '⚠️ 완료 처리 실패');
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('작업관리', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  tooltip: '새로고침',
                  onPressed: loading ? null : reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '상단에서 선택한 $orchard 과수원의 작업만 표시합니다.',
              style: const TextStyle(color: Color(0xFF667067)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: add,
                icon: const Icon(Icons.add_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Text('작업 추가'),
                ),
              ),
            ),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(message),
              ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!loading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inbox_outlined),
                            SizedBox(width: 10),
                            Text('등록된 작업이 없습니다.', style: TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('통합 엔진 동기화 후 자동추천 작업이 생성되면 이곳에 표시됩니다.'),
                      ],
                    ),
                  ),
                ),
              ),
            ...items.map((x) {
              final m = x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
              final status = '${m['status'] ?? '예정'}';
              final auto = m['auto_recommended'] == true;
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: auto ? const Color(0xFFDCEFD8) : const Color(0xFFF0F2EE),
                      child: Icon(
                        status == '완료' ? Icons.check_rounded : auto ? Icons.auto_awesome : Icons.pending_actions,
                        color: const Color(0xFF2E6B35),
                      ),
                    ),
                    title: Text('${m['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${m['category'] ?? '일반'} · ${m['scheduled_at'] ?? ''} · P${m['priority'] ?? 2}'),
                    trailing: status == '완료'
                        ? const Text('완료', style: TextStyle(fontWeight: FontWeight.w700))
                        : IconButton(
                            tooltip: '완료 처리',
                            onPressed: m['id'] is num ? () => complete((m['id'] as num).toInt()) : null,
                            icon: const Icon(Icons.check_circle_outline_rounded),
                          ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
}
