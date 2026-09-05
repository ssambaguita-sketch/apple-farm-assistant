import 'package:flutter/material.dart';

import 'services/finance_api.dart';
import 'services/orchard_selection.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final api = FinanceApi();
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> entries = [];
  Map<String, dynamic> check = {};
  bool loading = true;
  String message = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        api.summary(),
        api.list(limit: 80),
        api.check(),
      ]);
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(results[0] as Map);
        entries = List<Map<String, dynamic>>.from(results[1] as List);
        check = Map<String, dynamic>.from(results[2] as Map);
        loading = false;
        message = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        message = '⚠️ ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> addEntry(String type) async {
    final amount = TextEditingController();
    final quantity = TextEditingController(text: '0');
    final note = TextEditingController();
    String category = type == 'revenue' ? '사과 판매' : '농자재';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(type == 'revenue' ? '매출 기록' : '비용 기록'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: '분류'),
                  items: (type == 'revenue'
                          ? const ['사과 판매', '직거래', 'APC 출하', '기타 매출']
                          : const ['농자재', '비료', '농약', '인건비', '기계·유류', '포장·운송', '기타 비용'])
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '금액(원)'),
                ),
                const SizedBox(height: 10),
                if (type == 'revenue')
                  TextField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '출하·수확량(kg)'),
                  ),
                if (type == 'revenue') const SizedBox(height: 10),
                TextField(controller: note, decoration: const InputDecoration(labelText: '메모')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(amount.text.replaceAll(',', '').trim());
                if (value == null || value < 0) return;
                try {
                  await api.add(
                    type: type,
                    category: category,
                    amount: value,
                    quantityKg: type == 'revenue' ? (double.tryParse(quantity.text.trim()) ?? 0) : 0,
                    note: note.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (_) {
                  if (context.mounted) Navigator.pop(context, false);
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await load();
      if (mounted) setState(() => message = '✅ 경영 내역 저장 완료');
    } else if (mounted) {
      setState(() => message = '⚠️ 저장하지 않았거나 저장 실패');
    }
  }

  String money(dynamic v) {
    final n = (v is num ? v : num.tryParse('$v') ?? 0).round();
    final s = n.abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}${b.toString()}원';
  }

  Widget statCard(String title, String value, IconData icon) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final profit = money(summary['profit'] ?? 0);
    final rate = '${summary['profit_rate_pct'] ?? 0}%';
    final harvest = '${summary['harvest_kg'] ?? 0} kg';

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(child: Text('경영 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
          ]),
          Text('${OrchardSelection.name} · 매출/비용/수확량/순이익'),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(message)),
          Row(children: [
            statCard('매출', money(summary['revenue'] ?? 0), Icons.trending_up),
            const SizedBox(width: 10),
            statCard('비용', money(summary['expense'] ?? 0), Icons.trending_down),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            statCard('순이익', profit, Icons.account_balance_wallet_outlined),
            const SizedBox(width: 10),
            statCard('수익률', rate, Icons.percent),
          ]),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.scale_outlined),
              title: const Text('누적 출하·수확량'),
              trailing: Text(harvest, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('경영 기록 ${summary['entry_count'] ?? 0}건'),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => addEntry('revenue'), icon: const Icon(Icons.add), label: const Text('매출 추가'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () => addEntry('expense'), icon: const Icon(Icons.remove), label: const Text('비용 추가'))),
          ]),
          const SizedBox(height: 14),
          Card(
            color: check['ok'] == true ? const Color(0xFFF1F8EF) : null,
            child: ListTile(
              leading: Icon(check['ok'] == true ? Icons.verified_outlined : Icons.warning_amber),
              title: Text(check['ok'] == true ? '경영 기능 서버 점검 정상' : '경영 기능 서버 점검 필요'),
              subtitle: Text('DB 읽기 ${check['readable'] == true ? '정상' : '실패'} · 과수원 기록 ${check['orchard_entries'] ?? 0}건'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('최근 경영 내역', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (!loading && entries.isEmpty)
            const Card(child: ListTile(title: Text('아직 경영 기록이 없습니다.'))),
          ...entries.map((x) {
            final revenue = '${x['type']}' == 'revenue';
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(revenue ? Icons.arrow_upward : Icons.arrow_downward),
                ),
                title: Text('${x['category'] ?? (revenue ? '매출' : '비용')}'),
                subtitle: Text('${x['created_at'] ?? ''}\n${x['note'] ?? ''}'),
                isThreeLine: true,
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${revenue ? '+' : '-'}${money(x['amount'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if ((x['quantity_kg'] as num?) != null && (x['quantity_kg'] as num) > 0)
                    Text('${x['quantity_kg']}kg', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}
