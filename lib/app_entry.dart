import 'package:flutter/material.dart';
import 'main.dart' as legacy;
import 'annual_flow_page.dart';
import 'services/farm_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FarmApi.initialize();
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

  final pages = const [
    legacy.DashboardPage(),
    AnnualFlowPage(),
    legacy.TaskPage(),
    legacy.WeedPage(),
    legacy.CoachPage(),
    legacy.MorePage(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: pages[index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '연간'),
            NavigationDestination(icon: Icon(Icons.task_alt), label: '작업'),
            NavigationDestination(icon: Icon(Icons.grass), label: '잡초'),
            NavigationDestination(icon: Icon(Icons.psychology_outlined), label: '코치'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
          ],
        ),
      );
}
