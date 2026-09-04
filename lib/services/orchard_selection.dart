import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrchardSelection {
  static const _nameKey = 'selected_orchard_name';
  static const _varietyKey = 'selected_orchard_varieties';

  static final ValueNotifier<String> notifier = ValueNotifier<String>('A과수원');
  static String varieties = '후지';

  static String get name => notifier.value;

  static Future<void> initialize() async {
    final p = await SharedPreferences.getInstance();
    notifier.value = (p.getString(_nameKey) ?? 'A과수원').trim().isEmpty
        ? 'A과수원'
        : (p.getString(_nameKey) ?? 'A과수원').trim();
    varieties = (p.getString(_varietyKey) ?? '후지').trim();
  }

  static Future<void> select(String name, {String varietyText = ''}) async {
    final normalized = name.trim().isEmpty ? 'A과수원' : name.trim();
    notifier.value = normalized;
    if (varietyText.trim().isNotEmpty) varieties = varietyText.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_nameKey, normalized);
    await p.setString(_varietyKey, varieties);
  }
}
