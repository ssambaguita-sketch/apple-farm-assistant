import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TaskNotificationService {
  TaskNotificationService._();

  static final TaskNotificationService instance = TaskNotificationService._();
  static const _enabledKey = 'strong_task_notifications_enabled';
  static const _channelId = 'recommended_tasks_strong';
  static const _channelName = '추천작업 중요 알림';
  static const _channelDescription = '놓치면 안 되는 추천작업을 반복해서 알려줍니다.';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (!enabled) await _plugin.cancelAll();
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          ongoing: false,
          autoCancel: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
      );

  int _baseId(int taskId) => 100000 + (taskId.abs() % 100000) * 10;

  Future<void> cancelTask(int taskId) async {
    await initialize();
    final base = _baseId(taskId);
    for (var i = 0; i < 4; i++) {
      await _plugin.cancel(base + i);
    }
  }

  Future<void> syncTasks(List<dynamic> tasks, {required String orchard}) async {
    await initialize();
    if (!await isEnabled()) return;

    for (final raw in tasks) {
      if (raw is! Map) continue;
      final task = Map<String, dynamic>.from(raw);
      final idValue = task['id'];
      if (idValue is! num) continue;
      final id = idValue.toInt();
      final status = '${task['status'] ?? ''}';
      if (status == '완료') {
        await cancelTask(id);
        continue;
      }

      final auto = task['auto_recommended'] == true;
      final priority = (task['priority'] is num) ? (task['priority'] as num).toInt() : int.tryParse('${task['priority']}') ?? 2;
      if (!auto || priority < 3) continue;

      await _scheduleTask(task, orchard: orchard, priority: priority);
    }
  }

  Future<void> _scheduleTask(Map<String, dynamic> task, {required String orchard, required int priority}) async {
    final id = (task['id'] as num).toInt();
    await cancelTask(id);

    final title = '${task['title'] ?? '추천작업'}'.trim();
    final scheduledText = '${task['scheduled_at'] ?? ''}'.trim();
    final now = tz.TZDateTime.now(tz.local);
    final due = _parseDue(scheduledText, now) ?? now.add(const Duration(minutes: 2));
    final first = due.isBefore(now.add(const Duration(minutes: 1))) ? now.add(const Duration(minutes: 2)) : due;
    final offsets = <Duration>[
      Duration.zero,
      const Duration(minutes: 30),
      const Duration(hours: 2),
    ];

    final base = _baseId(id);
    for (var i = 0; i < offsets.length; i++) {
      final when = first.add(offsets[i]);
      final prefix = i == 0 ? '추천작업 알림' : '미완료 추천작업 재알림';
      await _plugin.zonedSchedule(
        base + i,
        '🍎 $prefix · P$priority',
        '$orchard · $title${scheduledText.isEmpty ? '' : ' · $scheduledText'}',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task:$id',
      );
    }
  }

  tz.TZDateTime? _parseDue(String text, tz.TZDateTime now) {
    if (text.isEmpty || text == '오늘') return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      final local = parsed.isUtc ? parsed.toLocal() : parsed;
      return tz.TZDateTime(tz.local, local.year, local.month, local.day, local.hour, local.minute);
    }

    final hm = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    if (hm != null) {
      final hour = int.tryParse(hm.group(1) ?? '');
      final minute = int.tryParse(hm.group(2) ?? '');
      if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        var result = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        if (result.isBefore(now)) result = result.add(const Duration(days: 1));
        return result;
      }
    }
    return null;
  }

  Future<void> showTest({required String orchard}) async {
    await initialize();
    await _plugin.show(
      99991,
      '🍎 추천작업 중요 알림 테스트',
      '$orchard · 알림이 정상적으로 작동합니다.',
      _details,
      payload: 'test',
    );
  }
}
