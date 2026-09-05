import 'package:flutter/material.dart';
import 'main.dart' as legacy;
import 'variety_annual_flow_page.dart';
import 'recommendation_diagnosis_page.dart';
import 'behavior_coach_page.dart';
import 'orchard_manager_page.dart';
import 'weed_intelligence_page.dart';
import 'management_page.dart';
import 'services/farm_api.dart';
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
  List<Map<String, dynamic>> orchards = [];
  late List<Widget> pages;

  @override
  void initState() {
    super.initState();
    _rebuildPages();
    loadOrchards();
  }

  void _rebuildPages() {
    pages = const [
      legacy.DashboardPage(),
      VarietyAnnualFlowPage(),
      RecommendationDiagnosisPage(),
      legacy.TaskPage(),
      WeedIntelligencePage(),
      BehaviorCoachPage(),
      ManagementPage(),
    ];
  }

  Future<void> loadOrchards() async {
    final r = await orchardApi.list();
    if (!mounted) return;
    if (r.isNotEmpty && !r.any((x) => '${x['name']}' == OrchardSelection.name)) {
      await OrchardSelection.select('${r.first['name']}', varietyText: '${r.first['variety'] ?? ''}');
      _rebuildPages();
    }
    if (!mounted) return;
    setState(() => orchards = r);
  }

  Future<void> choose(String? name) async {
    if (name == null || name == OrchardSelection.name) return;
    final item = orchards.cast<Map<String, dynamic>>().firstWhere(
          (x) => '${x['name']}' == name,
          orElse: () => <String, dynamic>{'name': name, 'variety': ''},
        );
    await OrchardSelection.select(name, varietyText: '${item['variety'] ?? ''}');
    _rebuildPages();
    if (mounted) setState(() {});
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
    _rebuildPages();
    if (mounted) setState(() {});
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
            child: DropdownButtonHideUnderline(
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
                              Text(
                                '${x['name']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${x['variety'] ?? '품종 미지정'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF667067)),
                              ),
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
            ),
          ),
          if (orchards.isEmpty && variety.isNotEmpty)
            Flexible(child: Text(variety, overflow: TextOverflow.ellipsis)),
          IconButton(
            tooltip: '과수원·품종 관리',
            onPressed: openManager,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
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
                const Divider(height: 1, color: Color(0x10000000)),
                Expanded(
                  child: IndexedStack(
                    index: index,
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (v) {
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
