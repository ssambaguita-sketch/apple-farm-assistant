import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'task_management_page.dart';
import 'variety_annual_flow_page.dart';
import 'recommendation_diagnosis_page.dart';
import 'behavior_coach_page.dart';
import 'orchard_manager_page.dart';
import 'weed_intelligence_page.dart';
import 'management_page.dart';
import 'services/farm_api.dart';
import 'services/integrated_api.dart';
import 'services/orchard_api.dart';
import 'services/orchard_selection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    FarmApi.initialize(),
    OrchardSelection.initialize(),
  ]);
  runApp(const AnnualApp());
}

class AnnualApp extends StatelessWidget {
  const AnnualApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E7D45)),
          scaffoldBackgroundColor: const Color(0xFFF6F7F3),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0x10000000)),
            ),
          ),
          navigationBarTheme: const NavigationBarThemeData(
            height: 72,
            backgroundColor: Colors.white,
            indicatorColor: Color(0xFFDCEFD8),
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3E7D45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E6B35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        home: const AnnualHome(),
      );
}

class AnnualHome extends StatefulWidget {
  const AnnualHome({super.key});

  @override
  State<AnnualHome> createState() => _AnnualHomeState();
}

class _AnnualHomeState extends State<AnnualHome> {
  int index = 0;
  final orchardApi = OrchardApi();
  final integratedApi = IntegratedApi();
  final dashboardKey = GlobalKey<DashboardPageState>();
  final taskKey = GlobalKey<TaskManagementPageState>();
  List<Map<String, dynamic>> orchards = [];
  Map<String, dynamic> integrated = {};
  bool syncing = false;
  bool orchardReady = false;
  List<Widget> pages = const [];

  @override
  void initState() {
    super.initState();
    OrchardSelection.notifier.addListener(_onSelectionChanged);
    loadOrchards();
  }

  @override
  void dispose() {
    OrchardSelection.notifier.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    integratedApi.invalidate();
    _rebuildPages();
    if (mounted) setState(() => integrated = {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      dashboardKey.currentState?.reload();
      taskKey.currentState?.reload();
    });
  }

  void _rebuildPages() {
    final orchard = OrchardSelection.name;
    pages = [
      DashboardPage(key: dashboardKey),
      VarietyAnnualFlowPage(key: ValueKey('annual:$orchard')),
      RecommendationDiagnosisPage(key: ValueKey('diagnosis:$orchard')),
      TaskManagementPage(key: taskKey),
      WeedIntelligencePage(key: ValueKey('weed:$orchard')),
      BehaviorCoachPage(key: ValueKey('coach:$orchard')),
      ManagementPage(key: ValueKey('management:$orchard')),
    ];
  }

  Future<void> loadOrchards() async {
    final r = await orchardApi.list();
    if (!mounted) return;

    if (r.isNotEmpty && !r.any((x) => '${x['name']}' == OrchardSelection.name)) {
      await OrchardSelection.select(
        '${r.first['name']}',
        varietyText: '${r.first['variety'] ?? ''}',
      );
    }

    _rebuildPages();
    if (!mounted) return;
    setState(() {
      orchards = r;
      orchardReady = true;
    });
    await _refreshIntegrated(syncTasks: true);
  }

  Future<void> _refreshIntegrated({bool syncTasks = false, bool force = false}) async {
    if (syncing || !orchardReady) return;
    if (mounted) setState(() => syncing = true);
    try {
      Map<String, dynamic>? data;
      if (syncTasks) {
        final sync = await integratedApi.syncTasks();
        if (sync['briefing'] is Map) {
          data = Map<String, dynamic>.from(sync['briefing'] as Map);
        }
      }
      data ??= await integratedApi.briefing(refresh: force);
      if (!mounted) return;
      setState(() => integrated = data!);
      await Future.wait([
        taskKey.currentState?.reload() ?? Future<void>.value(),
        dashboardKey.currentState?.reload() ?? Future<void>.value(),
      ]);
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> choose(String? name) async {
    if (name == null || name == OrchardSelection.name) return;
    final item = orchards.cast<Map<String, dynamic>>().firstWhere(
          (x) => '${x['name']}' == name,
          orElse: () => <String, dynamic>{'name': name, 'variety': ''},
        );
    await OrchardSelection.select(name, varietyText: '${item['variety'] ?? ''}');
    await _refreshIntegrated(syncTasks: true, force: true);
  }

  Future<void> openManager() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: const Color(0xFFF6F7F3),
        appBar: AppBar(title: const Text('과수원 · 품종 관리')),
        body: const SafeArea(child: OrchardManagerPage()),
      ),
    ));
    await loadOrchards();
  }

  Widget _compactTopBar(String selected) {
    final item = orchards.cast<Map<String, dynamic>?>().firstWhere(
          (x) => x != null && '${x['name']}' == selected,
          orElse: () => null,
        );
    final variety = '${item?['variety'] ?? OrchardSelection.varieties}'.trim();

    return Container(
      color: const Color(0xFFF6F7F3),
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFDFF0DC),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: const Text('🍎', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: orchardReady && orchards.isNotEmpty
                ? DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: orchards.any((x) => '${x['name']}' == selected) ? selected : null,
                      hint: Text(selected),
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      selectedItemBuilder: (context) => orchards
                          .map((x) => Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${x['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                    Text('${x['variety'] ?? '품종 미지정'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF667067))),
                                  ],
                                ),
                              ))
                          .toList(),
                      items: orchards
                          .map((x) => DropdownMenuItem<String>(
                                value: '${x['name']}',
                                child: Text('${x['name']} · ${x['variety'] ?? '품종 미지정'}'),
                              ))
                          .toList(),
                      onChanged: choose,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      if (variety.isNotEmpty) Text(variety, style: const TextStyle(fontSize: 11, color: Color(0xFF667067))),
                    ],
                  ),
          ),
          IconButton(
            tooltip: '과수원·품종 관리',
            onPressed: openManager,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }

  Widget _integratedBar() {
    final actions = List<dynamic>.from(integrated['actions'] ?? const []);
    final observations = Map<String, dynamic>.from(integrated['observations'] ?? const {});
    final finance = Map<String, dynamic>.from(integrated['finance'] ?? const {});
    final annual = Map<String, dynamic>.from(integrated['annual'] ?? const {});
    final offline = integrated['offline_mode'] == true;

    return Material(
      color: offline ? const Color(0xFFFFF4E8) : const Color(0xFFEAF5E5),
      child: InkWell(
        onTap: syncing ? null : () => _refreshIntegrated(syncTasks: true, force: true),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 10, 7),
          child: Row(
            children: [
              Icon(offline ? Icons.sync_problem_rounded : Icons.hub_rounded, size: 18, color: offline ? const Color(0xFF9A6230) : const Color(0xFF2F6B35)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  !orchardReady
                      ? '과수원 정보를 확인하는 중입니다'
                      : offline
                          ? '통합 엔진 연결 확인 필요'
                          : '통합 엔진 · ${annual['month'] ?? '-'}월 · 우선작업 ${actions.length} · 위험 ${observations['max_risk'] ?? 0}/5 · 순이익 ${finance['profit'] ?? 0}원',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
              if (syncing || !orchardReady)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.sync_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: OrchardSelection.notifier,
        builder: (context, selected, _) => Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _compactTopBar(selected),
                _integratedBar(),
                const Divider(height: 1, color: Color(0x10000000)),
                Expanded(
                  child: !orchardReady || pages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : IndexedStack(index: index, children: pages),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (v) {
              if (v == 3) {
                taskKey.currentState?.reload();
              } else if (v == 0) {
                dashboardKey.currentState?.reload();
              }
              if (v != index) setState(() => index = v);
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: '홈'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: '연간'),
              NavigationDestination(icon: Icon(Icons.biotech_outlined), label: '예찰진단'),
              NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: '작업'),
              NavigationDestination(icon: Icon(Icons.grass_outlined), selectedIcon: Icon(Icons.grass_rounded), label: '잡초'),
              NavigationDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology_alt_rounded), label: '코치'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: '경영·설정'),
            ],
          ),
        ),
      );
}
