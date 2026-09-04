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
  @override State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  final pages = const [DashboardPage(), TaskPage(), WeedPage(), CoachPage(), MorePage()];
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
        NavigationDestination(icon: Icon(Icons.psychology_outlined), label: '코치'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
      ],
    ),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final api = FarmApi();
  final orchard = TextEditingController(text: 'A과수원');
  Map<String, dynamic> d = {};
  Future<void> load() async {
    d = await api.dashboard(orchard.text);
    if (mounted) setState(() {});
  }
  @override void initState() { super.initState(); load(); }
  @override
  Widget build(BuildContext c) {
    final best = (d['best_work_times'] as List?) ?? [];
    final tasks = (d['tasks'] as List?) ?? [];
    final offline = d['offline_mode'] == true;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('🍎 사과 재배 관리 비서', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const Text('기상 · 작업 · 병해충 · 잡초 · 경영 · 개인화 코치'),
      if (offline) const Card(child: ListTile(leading: Icon(Icons.cloud_off), title: Text('오프라인 모드'), subtitle: Text('설정에서 클라우드 서버 주소를 입력하면 실시간 서버 기능을 사용합니다.'))),
      TextField(controller: orchard, decoration: const InputDecoration(labelText: '과수원')),
      FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('오늘 브리핑')),
      Row(children: [
        Expanded(child: Card(child: ListTile(title: const Text('위험점수'), trailing: Text('${d['risk_score'] ?? 0}')))),
        Expanded(child: Card(child: ListTile(title: const Text('순이익'), trailing: Text('${d['profit'] ?? 0}원')))),
      ]),
      const Text('오늘 우선작업', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ...tasks.map((x) => Card(child: ListTile(title: Text('${x['title']}'), subtitle: Text('${x['scheduled_at']}'), trailing: Text('P${x['priority']}')))),
      const Text('추천 작업시간', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ...best.take(3).map((x) => Card(child: ListTile(title: Text('${x['time']}'), subtitle: Text('기온 ${x['temp']}℃ · 바람 ${x['wind']}m/s · 강수 ${x['rain_probability']}%'), trailing: Text('${x['grade']} ${x['score']}')))),
    ]);
  }
}

class TaskPage extends StatelessWidget {
  const TaskPage({super.key});
  @override Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: const [
    Text('작업관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    Card(child: ListTile(leading: Icon(Icons.agriculture), title: Text('적과·전정·관수·방제'), subtitle: Text('우선순위와 예정시간 관리'))),
    Card(child: ListTile(leading: Icon(Icons.notifications_active_outlined), title: Text('자동 알림'), subtitle: Text('서버 연결 후 작업 알림 기능 확장 가능'))),
    Card(child: ListTile(leading: Icon(Icons.cloud_outlined), title: Text('기상 연동'), subtitle: Text('강수·풍속·고온 조건으로 작업 적합시간 계산'))),
  ]);
}

class WeedPage extends StatefulWidget {
  const WeedPage({super.key});
  @override State<WeedPage> createState() => _WeedPageState();
}

class _WeedPageState extends State<WeedPage> {
  final api = FarmApi();
  Map<String, dynamic> d = {};
  Future<void> run() async {
    d = await api.survivorAdvice({'orchard':'A과수원','weed_type':'미상 잡초','days_after':7,'survival':'높음','growth_stage':'왕성생육','weather_issue':'없음','coverage_issue':'없음','repeated_mode':true});
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
  @override State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final api = FarmApi();
  Map<String, dynamic> d = {};
  Future<void> load() async { d = await api.coach(); if (mounted) setState(() {}); }
  @override void initState() { super.initState(); load(); }
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
  @override State<MorePage> createState() => _MorePageState();
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
    setState(() { checking = true; status = '연결 확인 중...'; });
    await FarmApi.setBaseUrl(server.text);
    final ok = await FarmApi().health();
    if (!mounted) return;
    setState(() { checking = false; status = ok ? '✅ 서버 연결 성공' : '⚠️ 연결 실패 - 오프라인 폴백 사용'; });
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
    FilledButton.icon(onPressed: checking ? null : saveAndTest, icon: const Icon(Icons.cloud_done_outlined), label: const Text('저장하고 연결 테스트')),
    Card(child: ListTile(leading: const Icon(Icons.info_outline), title: Text(status), subtitle: Text(FarmApi.baseUrl.isEmpty ? '서버 주소가 없으면 앱은 오프라인 기본값으로 동작합니다.' : FarmApi.baseUrl))),
    const Divider(),
    const Card(child: ListTile(title: Text('과수원 관리'), subtitle: Text('품종·면적·나무수·GPS·생육단계'))),
    const Card(child: ListTile(title: Text('경영 관리'), subtitle: Text('비용·매출·수확량·순이익'))),
    const Card(child: ListTile(title: Text('외부 연동'), subtitle: Text('기상청 API · Telegram은 서버 환경변수로 설정'))),
    const Card(child: ListTile(title: Text('농약 안전'), subtitle: Text('등록작물·적용대상·사용시기·횟수·작용기작은 공식 PSIS와 제품 라벨 확인'))),
  ]);
}
