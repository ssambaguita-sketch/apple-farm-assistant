import 'package:flutter/material.dart';

import 'services/orchard_selection.dart';
import 'services/task_notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final service = TaskNotificationService.instance;
  bool enabled = true;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await service.isEnabled();
    if (!mounted) return;
    setState(() {
      enabled = value;
      loading = false;
    });
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => enabled = value);
    await service.setEnabled(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? '추천작업 강화 알림을 켰습니다.' : '추천작업 강화 알림을 껐습니다. 예약 알림도 취소했습니다.')),
    );
  }

  Future<void> _test() async {
    await service.showTest(orchard: OrchardSelection.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('테스트 알림을 보냈습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            value: enabled,
            onChanged: _setEnabled,
            secondary: const CircleAvatar(child: Icon(Icons.notifications_active_rounded)),
            title: const Text('추천작업 강화 알림', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('자동추천 P3~P5 작업을 예정 시각, 30분 후, 2시간 후까지 반복 알림합니다. 작업 완료 시 후속 알림은 즉시 취소됩니다.'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.vibration_rounded)),
            title: const Text('알림 강도', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Android 최대 중요도 · 진동 · 소리 · 잠금화면 표시 · 앱 배지'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? _test : null,
            icon: const Icon(Icons.notifications_none_rounded),
            label: const Text('지금 테스트 알림 보내기'),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          color: Color(0xFFFFF6E8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '휴대폰의 알림 권한이 꺼져 있거나 절전 정책이 매우 강하면 알림이 늦어질 수 있습니다. 앱 설치 후 알림 권한은 허용해 주세요.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
