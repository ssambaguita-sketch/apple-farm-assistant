import 'package:flutter/material.dart';
import 'main.dart' as legacy;
import 'variety_annual_flow_page.dart';
import 'recommendation_diagnosis_page.dart';
import 'behavior_coach_page.dart';
import 'orchard_manager_page.dart';
import 'services/farm_api.dart';
import 'services/orchard_api.dart';
import 'services/orchard_selection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FarmApi.initialize();
  await OrchardSelection.initialize();
  runApp(const AnnualApp());
}

class AnnualApp extends StatelessWidget {
  const AnnualApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
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

  List<Widget> get pages => const [
        legacy.DashboardPage(),
        VarietyAnnualFlowPage(),
        RecommendationDiagnosisPage(),
        legacy.TaskPage(),
        legacy.WeedPage(),
        BehaviorCoachPage(),
        legacy.MorePage(),
      ];

  @override
  void initState() {
    super.initState();
    loadOrchards();
  }

  Future<void> loadOrchards() async {
    final r = await orchardApi.list();
    if (!mounted) return;
    setState(() => orchards = r);
    if (r.isNotEmpty && !r.any((x) => '${x['name']}' == OrchardSelection.name)) {
      await OrchardSelection.select('${r.first['name']}', varietyText: '${r.first['variety'] ?? ''}');
    }
  }

  Future<void> choose(String? name) async {
    if (name == null) return;
    final item = orchards.cast<Map<String, dynamic>>().firstWhere(
          (x) => '${x['name']}' == name,
          orElse: () => <String, dynamic>{'name': name, 'variety': ''},
        );
    await OrchardSelection.select(name, varietyText: '${item['variety'] ?? ''}');
    if (mounted) setState(() {});
  }

  Future<void> openManager() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('과수원 · 품종 관리')),
          body: const SafeArea(child: OrchardManagerPage()),
        )));
    await loadOrchards();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: OrchardSelection.notifier,
        builder: (context, selected, _) => Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: orchards.any((x) => '${x['name']}' == selected) ? selected : null,
                hint: Text(selected),
                isExpanded: false,
                items: orchards
                    .map((x) => DropdownMenuItem<String>(
                          value: '${x['name']}',
                          child: Text('${x['name']} · ${x['variety'] ?? '품종 미지정'}'),
                        ))
                    .toList(),
                onChanged: choose,
              ),
            ),
            actions: [
              IconButton(
                tooltip: '과수원·품종 관리',
                onPressed: openManager,
                icon: const Icon(Icons.park_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: KeyedSubtree(
              key: ValueKey('$index-$selected'),
              child: pages[index],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (v) => setState(() => index = v),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '연간'),
              NavigationDestination(icon: Icon(Icons.biotech_outlined), label: '예찰진단'),
              NavigationDestination(icon: Icon(Icons.task_alt), label: '작업'),
              NavigationDestination(icon: Icon(Icons.grass), label: '잡초'),
              NavigationDestination(icon: Icon(Icons.psychology_outlined), label: '코치'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
            ],
          ),
        ),
      );
}
