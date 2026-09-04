import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'services/farm_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FarmApi.initialize();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
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
  int index = 0;
  final pages = const [DashboardPage(), TaskPage(), WeedPage(), CoachPage(), MorePage()];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: pages[index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
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
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final api = FarmApi();
  final orchard = TextEditingController(text: 'A과수원');
  Map<String, dynamic> data = {};
  bool loading = false;

  Future<void> load() async {
    setState(() => loading = true);
    data = await api.dashboard(orchard.text.trim().isEmpty ? 'A과수원' : orchard.text.trim());
    if (mounted) setState(() => loading = false);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Widget _evidenceRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: $value')),
        ]),
      );

  Widget _recommendationCard(dynamic raw) {
    final x = Map<String, dynamic>.from(raw as Map);
    final evidence = x['decision_evidence'] is Map
        ? Map<String, dynamic>.from(x['decision_evidence'] as Map)
        : <String, dynamic>{};
    final confidence = '${x['confidence'] ?? data['recommendation_confidence'] ?? '-'}';
    final when = '${x['recommended_time'] ?? x['scheduled_at'] ?? '오늘'}';
    final reason = '${x['reason'] ?? '판단근거가 제공되지 않았습니다.'}';
    final source = '${evidence['weather_source'] ?? data['weather_source'] ?? 'unknown'}';
    final stage = '${evidence['growth_stage'] ?? '미등록'}';
    final risk = '${evidence['recent_max_risk'] ?? '-'}';
    final obsCount = '${evidence['recent_observation_count'] ?? '-'}';
    final temp = '${evidence['forecast_max_temp_c'] ?? '-'}';
    final pop = '${evidence['forecast_max_rain_probability_pct'] ?? '-'}';
    final wind = '${evidence['forecast_max_wind_ms'] ?? '-'}';
    final score = '${evidence['best_work_score'] ?? '-'}';

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.auto_awesome),
        title: Text('${x['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('추천시간 $when · 신뢰도 $confidence'),
        trailing: Text('P${x['priority'] ?? 2}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('왜 이 작업을 추천했나요?', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: Text(reason)),
          const Divider(height: 22),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('판단에 사용한 실제 데이터', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          _evidenceRow(Icons.cloud_outlined, '기상 데이터', source == 'kma' ? '기상청 KMA' : source),
          _evidenceRow(Icons.thermostat, '예보 최고기온', '$temp℃'),
          _evidenceRow(Icons.water_drop_outlined, '최대 강수확률', '$pop%'),
          _evidenceRow(Icons.air, '최대 풍속', '$wind m/s'),
          _evidenceRow(Icons.schedule, '최적 작업시간 점수', '$score점'),
          _evidenceRow(Icons.eco_outlined, '생육단계', stage),
          _evidenceRow(Icons.visibility_outlined, '최근 관찰', '$obsCount건 · 최고 위험도 $risk/5'),
          const Divider(height: 22),
          _evidenceRow(Icons.verified_outlined, '추천 신뢰도', confidence),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '이 추천은 작업 의사결정 지원용입니다. 농약 제품·농도·혼용·재살포 간격은 자동 처방하지 않습니다.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = (data['tasks'] as List?) ?? [];
    final best = (data['best_work_times'] as List?) ?? [];
    final source = '${data['weather_source'] ?? 'unknown'}';
    final confidence = '${data['recommendation_confidence'] ?? '-'}';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('🍎 사과 재배 관리 비서', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const Text('기상 · 작업 · 병해충 · 잡초 · 경영 · 개인화 코치'),
      Card(
        child: ListTile(
          leading: Icon(source == 'kma' ? Icons.cloud_done : Icons.warning_amber),
          title: Text(source == 'kma' ? '기상청 실제 예보 사용 중' : '데모 날씨 사용 중'),
          subtitle: Text('${data['weather_warning'] ?? '현재 예보 기반 추천입니다.'}'),
        ),
      ),
      TextField(controller: orchard, decoration: const InputDecoration(labelText: '과수원')),
      FilledButton.icon(onPressed: loading ? null : load, icon: const Icon(Icons.refresh), label: Text(loading ? '불러오는 중...' : '오늘 브리핑')),
      Row(children: [
        Expanded(child: Card(child: ListTile(title: const Text('위험점수'), trailing: Text('${data['risk_score'] ?? 0}')))),
        Expanded(child: Card(child: ListTile(title: const Text('순이익'), trailing: Text('${data['profit'] ?? 0}원')))),
      ]),
      Row(children: [
        const Expanded(child: Text('오늘 우선작업', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        if (data['today_recommendations'] is List)
          Chip(label: Text('추천 신뢰도 $confidence')),
      ]),
      if (tasks.isEmpty) const Card(child: ListTile(title: Text('등록된 예정 작업이 없습니다.'))),
      ...tasks.map((x) {
        final m = x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
        if (m['auto_recommended'] == true) return _recommendationCard(m);
        return Card(child: ListTile(
          leading: const Icon(Icons.task_outlined),
          title: Text('${m['title'] ?? ''}'),
          subtitle: Text('${m['scheduled_at'] ?? ''}'),
          trailing: Text('P${m['priority'] ?? 2}'),
        ));
      }),
      if (data['recommendation_policy'] != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('${data['recommendation_policy']}', style: Theme.of(context).textTheme.bodySmall),
        ),
      const SizedBox(height: 8),
      const Text('추천 작업시간', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ...best.take(3).map((x) => Card(child: ListTile(
            title: Text('${x['time']}'),
            subtitle: Text('기온 ${x['temp']}℃ · 바람 ${x['wind']}m/s · 강수 ${x['rain_probability']}%'),
            trailing: Text('${x['grade']} ${x['score']}'),
          ))),
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
    setState(() => loading = true);
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
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: '작업명')),
            TextField(controller: scheduled, decoration: const InputDecoration(labelText: '예정시간/날짜')),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: '분류'),
              items: const ['일반', '전정', '적과', '관수', '방제', '예찰', '수확'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setDialogState(() => category = v ?? '일반'),
            ),
            DropdownButtonFormField<int>(
              value: priority,
              decoration: const InputDecoration(labelText: '우선순위'),
              items: const [1, 2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('P$e'))).toList(),
              onChanged: (v) => setDialogState(() => priority = v ?? 2),
            ),
          ])),
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
      message = '✅ 작업 저장 완료';
      await load();
    } else if (mounted) {
      setState(() => message = '⚠️ 저장하지 않았거나 저장 실패');
    }
  }

  Future<void> complete(int id) async {
    final ok = await api.completeTask(id);
    if (!mounted) return;
    setState(() => message = ok ? '✅ 완료 처리됨' : '⚠️ 완료 처리 실패');
    if (ok) await load();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(child: Text('작업관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
        ]),
        TextField(controller: orchard, decoration: const InputDecoration(labelText: '과수원'), onSubmitted: (_) => load()),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('작업 추가')),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(message)),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
        if (!loading && items.isEmpty) const Card(child: ListTile(title: Text('등록된 작업이 없습니다.'))),
        ...items.map((x) {
          final status = '${x['status'] ?? '예정'}';
          return Card(child: ListTile(
            leading: Icon(status == '완료' ? Icons.check_circle : Icons.pending_actions),
            title: Text('${x['title']}'),
            subtitle: Text('${x['category'] ?? '일반'} · ${x['scheduled_at'] ?? ''} · P${x['priority'] ?? 2}'),
            trailing: status == '완료' ? const Text('완료') : IconButton(onPressed: () => complete((x['id'] as num).toInt()), icon: const Icon(Icons.check)),
          ));
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
  Map<String, dynamic> data = {};
  Future<void> run() async {
    data = await api.survivorAdvice({
      'orchard': 'A과수원',
      'weed_type': '미상 잡초',
      'days_after': 7,
      'survival': '높음',
      'growth_stage': '왕성생육',
      'weather_issue': '없음',
      'coverage_issue': '없음',
      'repeated_mode': true,
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final causes = (data['possible_causes'] as List?) ?? [];
    final actions = (data['actions'] as List?) ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('🌱 잡초·제초 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
  Map<String, dynamic> data = {};
  Future<void> load() async {
    data = await api.coach();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    final best = (data['best_hours'] as List?) ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('작업효율 AI 코치', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const Text('작업완료·시간대·체감난이도만 사용하며 생체정보를 추론하지 않습니다.'),
      ...best.map((x) => Card(child: ListTile(title: Text('${x['hour']}시'), subtitle: Text('${x['samples']}건 학습'), trailing: Text('${x['score']}점')))),
    ]);
  }
}

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  final api = FarmApi();
  late final TextEditingController server;
  final orchard = TextEditingController(text: 'A과수원');
  String serverStatus = '서버 주소 저장됨';
  String gpsStatus = '과수원 GPS를 아직 저장하지 않았습니다.';
  bool checking = false;
  bool locating = false;
  bool diagnosing = false;
  Map<String, dynamic> diag = {};

  @override
  void initState() {
    super.initState();
    server = TextEditingController(text: FarmApi.baseUrl);
  }

  Future<void> saveAndTest() async {
    setState(() { checking = true; serverStatus = '연결 확인 중...'; });
    await FarmApi.setBaseUrl(server.text);
    final ok = await api.health();
    if (!mounted) return;
    setState(() { checking = false; serverStatus = ok ? '✅ 서버 연결 성공' : '⚠️ 서버 연결 실패'; });
  }

  Future<void> saveCurrentGps() async {
    setState(() { locating = true; gpsStatus = '현재 위치 확인 중...'; });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('휴대폰 위치 서비스를 켜주세요.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 필요합니다.');
      }
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      final name = orchard.text.trim().isEmpty ? 'A과수원' : orchard.text.trim();
      final ok = await api.saveOrchardLocation(orchard: name, lat: p.latitude, lon: p.longitude);
      if (!mounted) return;
      setState(() {
        locating = false;
        gpsStatus = ok
            ? '✅ $name GPS 저장 완료\n위도 ${p.latitude.toStringAsFixed(5)} · 경도 ${p.longitude.toStringAsFixed(5)}'
            : '⚠️ 위치는 확인했지만 서버 저장에 실패했습니다.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { locating = false; gpsStatus = '⚠️ ${e.toString().replaceFirst('Exception: ', '')}'; });
    }
  }

  Future<void> runDiagnostics() async {
    setState(() => diagnosing = true);
    diag = await api.diagnostics(orchard.text.trim().isEmpty ? 'A과수원' : orchard.text.trim());
    if (mounted) setState(() => diagnosing = false);
  }

  Widget diagCard(String title, bool ok, String subtitle) => Card(
        child: ListTile(
          leading: Icon(ok ? Icons.check_circle : Icons.warning_amber),
          title: Text('${ok ? '✅' : '⚠️'} $title'),
          subtitle: Text(subtitle),
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('설정 · 서버 연결', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        TextField(controller: server, keyboardType: TextInputType.url, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '클라우드 서버 URL')),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: checking ? null : saveAndTest, icon: const Icon(Icons.cloud_done_outlined), label: Text(checking ? '확인 중...' : '저장하고 연결 테스트')),
        Card(child: ListTile(leading: const Icon(Icons.info_outline), title: Text(serverStatus), subtitle: Text(FarmApi.baseUrl))),
        const Divider(),
        const Text('과수원 위치', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text('실제 기상청 예보를 사용하려면 과수원에서 아래 버튼을 눌러 위치를 저장하세요.'),
        TextField(controller: orchard, decoration: const InputDecoration(labelText: '과수원 이름')),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: locating ? null : saveCurrentGps, icon: const Icon(Icons.my_location), label: Text(locating ? 'GPS 확인 중...' : '현재 GPS를 과수원 위치로 저장')),
        Card(child: ListTile(leading: const Icon(Icons.location_on_outlined), title: const Text('GPS 상태'), subtitle: Text(gpsStatus))),
        const Divider(),
        const Text('전체 기능 진단', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text('데이터를 쓰지 않고 서버·DB·날씨·작업·코치 API를 읽기 전용으로 검사합니다.'),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: diagnosing ? null : runDiagnostics, icon: const Icon(Icons.health_and_safety_outlined), label: Text(diagnosing ? '진단 중...' : '전체 기능 진단 실행')),
        if (diag.isNotEmpty) ...[
          diagCard('서버', diag['server'] == true, '버전 ${diag['server_version'] ?? '-'}'),
          diagCard('데이터베이스', diag['database'] == true && diag['database_type'] == 'postgresql', '${diag['database_type'] ?? '-'}'),
          diagCard('KMA 키 설정', diag['kma_configured'] == true, diag['kma_configured'] == true ? '설정됨' : '미설정'),
          diagCard('날씨 API', diag['weather'] == true && diag['weather_source'] == 'kma', '소스: ${diag['weather_source'] ?? '-'}\n${diag['weather_warning'] ?? ''}'),
          diagCard('작업 API', diag['tasks'] == true, '${diag['task_count'] ?? 0}건 조회'),
          diagCard('AI 코치', diag['coach'] == true, diag['coach'] == true ? '정상 응답' : '응답 실패'),
        ],
        const Divider(),
        const Card(child: ListTile(title: Text('농약 안전'), subtitle: Text('등록작물·적용대상·사용시기·횟수·작용기작은 공식 PSIS와 제품 라벨을 확인하세요.'))),
      ]);
}
