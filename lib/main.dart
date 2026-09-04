import 'package:flutter/material.dart';
import 'services/farm_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FarmApi.initialize();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  final pages = const [
    DashboardPage(),
    TaskPage(),
    WeedPage(),
    CoachPage(),
    MorePage()
  ];
  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(child: pages[i]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
            NavigationDestination(icon: Icon(Icons.task_alt), label: '작업'),
            NavigationDestination(icon: Icon(Icons.grass), label: '잡초'),
            NavigationDestination(
                icon: Icon(Icons.psychology_outlined), label: '코치'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined), label: '설정'),
          ],
        ),
      );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final api = FarmApi();
  final orchard = TextEditingController(text: 'A과수원');
  Map<String, dynamic> d = {};
  bool loading = false;

  Future<void> load() async {
    setState(() => loading = true);
    d = await api.dashboard(orchard.text.trim().isEmpty ? 'A과수원' : orchard.text.trim());
    if (mounted) setState(() => loading = false);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext c) {
    final best = (d['best_work_times'] as List?) ?? [];
    final tasks = (d['tasks'] as List?) ?? [];
    final offline = d['offline_mode'] == true;
    final weatherSource = '${d['weather_source'] ?? 'unknown'}';
    final warning = d['weather_warning'];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('🍎 사과 재배 관리 비서',
          style: Theme.of(c)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
      const Text('기상 · 작업 · 병해충 · 잡초 · 경영 · 개인화 코치'),
      if (offline)
        const Card(
            child: ListTile(
                leading: Icon(Icons.cloud_off),
                title: Text('오프라인 모드'),
                subtitle: Text('서버 연결 실패로 기본값을 표시합니다.'))),
      Card(
        child: ListTile(
          leading: Icon(weatherSource == 'kma' ? Icons.cloud_done : Icons.warning_amber),
          title: Text(weatherSource == 'kma' ? '기상청 실시간 예보 사용 중' : '데모 날씨 사용 중'),
          subtitle: Text(warning == null ? '추천 작업시간은 현재 예보를 기반으로 계산합니다.' : '$warning'),
        ),
      ),
      TextField(
          controller: orchard,
          decoration: const InputDecoration(labelText: '과수원')),
      FilledButton.icon(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
          label: Text(loading ? '불러오는 중...' : '오늘 브리핑')),
      Row(children: [
        Expanded(
            child: Card(
                child: ListTile(
                    title: const Text('위험점수'),
                    trailing: Text('${d['risk_score'] ?? 0}')))),
        Expanded(
            child: Card(
                child: ListTile(
                    title: const Text('순이익'),
                    trailing: Text('${d['profit'] ?? 0}원')))),
      ]),
      const Text('오늘 우선작업',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      if (tasks.isEmpty)
        const Card(child: ListTile(title: Text('등록된 예정 작업이 없습니다.'))),
      ...tasks.map((x) => Card(
          child: ListTile(
              title: Text('${x['title']}'),
              subtitle: Text('${x['scheduled_at'] ?? ''}'),
              trailing: Text('P${x['priority']}')))),
      const Text('추천 작업시간',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ...best.take(3).map((x) => Card(
          child: ListTile(
              title: Text('${x['time']}'),
              subtitle: Text(
                  '기온 ${x['temp']}℃ · 바람 ${x['wind']}m/s · 강수 ${x['rain_probability']}%'),
              trailing: Text('${x['grade']} ${x['score']}')))),
    ]);
  }
}

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});
  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final api = FarmApi();
  final orchard = TextEditingController(text: 'A과수원');
  List<dynamic> items = [];
  bool loading = false;
  String message = '';

  Future<void> load() async {
    setState(() {
      loading = true;
      message = '';
    });
    items = await api.tasks(orchard.text.trim().isEmpty ? 'A과수원' : orchard.text.trim());
    if (mounted) setState(() => loading = false);
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
          title: const Text('작업 추가'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: '작업명')),
              TextField(controller: scheduled, decoration: const InputDecoration(labelText: '예정시간/날짜')),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: '분류'),
                items: const ['일반', '전정', '적과', '관수', '방제', '예찰', '수확']
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
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                final success = await api.addTask(
                  orchard: orchard.text.trim().isEmpty ? 'A과수원' : orchard.text.trim(),
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
    if (ok == true) {
      message = '✅ 작업이 서버에 저장되었습니다.';
      await load();
    } else if (ok == false && mounted) {
      setState(() => message = '⚠️ 저장하지 않았거나 서버 저장에 실패했습니다.');
    }
  }

  Future<void> complete(int id) async {
    final ok = await api.completeTask(id);
    if (!mounted) return;
    setState(() => message = ok ? '✅ 작업 완료 처리되었습니다.' : '⚠️ 완료 처리에 실패했습니다.');
    if (ok) await load();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(
              child: Text('작업관리',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
        ]),
        TextField(
          controller: orchard,
          decoration: const InputDecoration(labelText: '과수원'),
          onSubmitted: (_) => load(),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('작업 추가')),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(message)),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
        if (!loading && items.isEmpty)
          const Card(child: ListTile(title: Text('등록된 작업이 없습니다.'), subtitle: Text('위의 작업 추가 버튼으로 첫 작업을 등록하세요.'))),
        ...items.map((x) {
          final status = '${x['status'] ?? '예정'}';
          return Card(
            child: ListTile(
              leading: Icon(status == '완료' ? Icons.check_circle : Icons.pending_actions),
              title: Text('${x['title']}'),
              subtitle: Text('${x['category'] ?? '일반'} · ${x['scheduled_at'] ?? ''} · P${x['priority'] ?? 2}'),
              trailing: status == '완료'
                  ? const Text('완료')
                  : IconButton(
                      tooltip: '완료 처리',
                      onPressed: () => complete((x['id'] as num).toInt()),
                      icon: const Icon(Icons.check),
                    ),
            ),
          );
        }),
      ]);
}

class WeedPage extends StatefulWidget {
  const WeedPage({super.key});
  @override
  State<WeedPage> createState() => _WeedPageState();
}

class _WeedPageState extends State<WeedPage> {
  final api = FarmApi();
  Map<String, dynamic> d = {};
  Future<void> run() async {
    d = await api.survivorAdvice({
      'orchard': 'A과수원',
      'weed_type': '미상 잡초',
      'days_after': 7,
      'survival': '높음',
      'growth_stage': '왕성생육',
      'weather_issue': '없음',
      'coverage_issue': '없음',
      'repeated_mode': true
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) {
    final causes = (d['possible_causes'] as List?) ?? [];
    final actions = (d['actions'] as List?) ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('🌱 잡초·제초 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const Card(child: ListTile(title: Text('잡초 예찰'), subtitle: Text('유형·생육단계·밀도·구역 기록'))),
      FilledButton(onPressed: run, child: const Text('제초 후 안 죽는 잡초 원인분석')),
      ...causes.map((x) => Text('• 원인: $x')),
      ...actions.map((x) => Text('• 조언: $x')),
      const SizedBox(height: 8),
      const Text('제품·농도는 자동 처방하지 않습니다. PSIS 등록사항과 제품 라벨을 확인하세요.', style: TextStyle(color: Colors.redAccent)),
    ]);
  }
}

class CoachPage extends StatefulWidget {
  const CoachPage({super.key});
  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final api = FarmApi();
  Map<String, dynamic> d = {};
  Future<void> load() async {
    d = await api.coach();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext c) {
    final b = (d['best_hours'] as List?) ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('작업효율 AI 코치', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const Text('작업완료·시간대·체감난이도만 사용하며 생체정보를 추론하지 않습니다.'),
      ...b.map((x) => Card(child: ListTile(title: Text('${x['hour']}시'), subtitle: Text('${x['samples']}건 학습'), trailing: Text('${x['score']}점')))),
    ]);
  }
}

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  late final TextEditingController server;
  String status = FarmApi.isOfflineOnly ? '오프라인 모드' : '서버 주소 저장됨';
  bool checking = false;

  @override
  void initState() {
    super.initState();
    server = TextEditingController(text: FarmApi.baseUrl);
  }

  Future<void> saveAndTest() async {
    setState(() {
      checking = true;
      status = '연결 확인 중...';
    });
    await FarmApi.setBaseUrl(server.text);
    final ok = await FarmApi().health();
    if (!mounted) return;
    setState(() {
      checking = false;
      status = ok ? '✅ 서버 연결 성공' : '⚠️ 연결 실패 - 오프라인 폴백 사용';
    });
  }

  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('설정 · 서버 연결', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: server,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '클라우드 서버 URL',
            hintText: 'https://xxxxx.onrender.com',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: checking ? null : saveAndTest,
            icon: const Icon(Icons.cloud_done_outlined),
            label: const Text('저장하고 연결 테스트')),
        Card(
            child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(status),
                subtitle: Text(FarmApi.baseUrl))),
        const Divider(),
        const Card(child: ListTile(title: Text('과수원 관리'), subtitle: Text('품종·면적·나무수·GPS·생육단계'))),
        const Card(child: ListTile(title: Text('경영 관리'), subtitle: Text('비용·매출·수확량·순이익'))),
        const Card(child: ListTile(title: Text('외부 연동'), subtitle: Text('기상청 API · Telegram은 서버 환경변수로 설정'))),
        const Card(child: ListTile(title: Text('농약 안전'), subtitle: Text('등록작물·적용대상·사용시기·횟수·작용기작은 공식 PSIS와 제품 라벨 확인'))),
      ]);
}
