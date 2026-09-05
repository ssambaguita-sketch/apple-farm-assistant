import 'package:flutter/material.dart';

import 'services/farm_api.dart';
import 'services/orchard_selection.dart';
import 'services/task_notification_service.dart';

class TaskManagementPage extends StatefulWidget {
  const TaskManagementPage({super.key});

  @override
  State<TaskManagementPage> createState() => TaskManagementPageState();
}

class TaskManagementPageState extends State<TaskManagementPage> {
  final api = FarmApi();
  final notifications = TaskNotificationService.instance;
  List<dynamic> items = const [];
  bool loading = false;
  bool _reloadAgain = false;
  String message = '';
  DateTime? _lastLoadedAt;
  String _lastLoadedOrchard = '';

  String get orchard => OrchardSelection.name.trim();

  @override
  void initState() {
    super.initState();
    OrchardSelection.notifier.addListener(_orchardChanged);
    reload(force: true);
  }

  @override
  void dispose() {
    OrchardSelection.notifier.removeListener(_orchardChanged);
    super.dispose();
  }

  void _orchardChanged() {
    _lastLoadedAt = null;
    reload(force: true);
  }

  Future<void> reload({bool force = false}) async {
    if (!mounted) return;
    final targetOrchard = orchard;
    if (targetOrchard.isEmpty) return;

    final fresh = _lastLoadedAt != null &&
        _lastLoadedOrchard == targetOrchard &&
        DateTime.now().difference(_lastLoadedAt!) < const Duration(seconds: 15);
    if (!force && fresh) return;

    if (loading) {
      _reloadAgain = _reloadAgain || force || _lastLoadedOrchard != targetOrchard;
      return;
    }

    do {
      _reloadAgain = false;
      final requestOrchard = orchard;
      if (!mounted || requestOrchard.isEmpty) return;
      setState(() => loading = true);

      final result = await api.tasks(requestOrchard);
      if (!mounted) return;

      if (requestOrchard == orchard) {
        setState(() {
          items = result;
          loading = false;
          _lastLoadedAt = DateTime.now();
          _lastLoadedOrchard = requestOrchard;
        });
        await notifications.syncTasks(result, orchard: requestOrchard);
      } else {
        setState(() => loading = false);
        _reloadAgain = true;
      }
    } while (_reloadAgain && mounted);
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
                  initialValue: category,
                  decoration: const InputDecoration(labelText: '분류'),
                  items: const ['일반', '전정', '적과', '관수', '방제', '예찰', '수확', '잡초', '엽면시비']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? '일반'),
                ),
                DropdownButtonFormField<int>(
                  initialValue: priority,
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
      _lastLoadedAt = null;
      await reload(force: true);
    } else if (ok == false && mounted) {
      setState(() => message = '작업 추가를 취소했습니다.');
    }
  }

  Future<void> complete(int id) async {
    final ok = await api.completeTask(id);
    if (!mounted) return;
    setState(() => message = ok ? '✅ 완료 처리됨 · 후속 알림도 해제했습니다.' : '⚠️ 완료 처리 실패');
    if (ok) {
      await notifications.cancelTask(id);
      _lastLoadedAt = null;
      await reload(force: true);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () => reload(force: true),
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
                  onPressed: loading ? null : () => reload(force: true),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '상단에서 선택한 $orchard 과수원의 작업만 표시합니다.',
              style: const TextStyle(color: Color(0xFF667067)),
            ),
            const SizedBox(height: 10),
            const Card(
              color: Color(0xFFFFF6E8),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notifications_active_rounded, color: Color(0xFF9A6230)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '자동추천 P3~P5 작업은 중요 알림으로 등록됩니다. 예정 시각 알림 후 미완료 상태면 30분, 2시간 뒤 다시 알려줍니다.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
              final priority = m['priority'] ?? 2;
              final parsedPriority = priority is num ? priority.toInt() : int.tryParse('$priority') ?? 2;
              final strongAlert = auto && parsedPriority >= 3;
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
                    title: Row(
                      children: [
                        Expanded(child: Text('${m['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
                        if (strongAlert && status != '완료')
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.notifications_active_rounded, size: 18, color: Color(0xFFB56A22)),
                          ),
                      ],
                    ),
                    subtitle: Text('${m['category'] ?? '일반'} · ${m['scheduled_at'] ?? ''} · P$parsedPriority'),
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
