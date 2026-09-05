import 'package:flutter/material.dart';

import 'services/farm_api.dart';
import 'services/orchard_selection.dart';

class ServerDiagnosticsPage extends StatefulWidget {
  const ServerDiagnosticsPage({super.key});

  @override
  State<ServerDiagnosticsPage> createState() => _ServerDiagnosticsPageState();
}

class _ServerDiagnosticsPageState extends State<ServerDiagnosticsPage> {
  final api = FarmApi();
  late final TextEditingController server;
  bool checking = false;
  bool diagnosing = false;
  String serverStatus = '서버 주소 저장됨';
  Map<String, dynamic> diag = {};

  @override
  void initState() {
    super.initState();
    server = TextEditingController(text: FarmApi.baseUrl);
  }

  @override
  void dispose() {
    server.dispose();
    super.dispose();
  }

  Future<void> saveAndTest() async {
    setState(() {
      checking = true;
      serverStatus = '연결 확인 중...';
    });
    await FarmApi.setBaseUrl(server.text);
    final ok = await api.health();
    if (!mounted) return;
    setState(() {
      checking = false;
      serverStatus = ok ? '✅ 서버 연결 성공' : '⚠️ 서버 연결 실패';
    });
  }

  Future<void> runDiagnostics() async {
    setState(() => diagnosing = true);
    final result = await api.diagnostics(OrchardSelection.name);
    if (!mounted) return;
    setState(() {
      diag = result;
      diagnosing = false;
    });
  }

  Widget diagCard(String title, bool ok, String subtitle) => Card(
        child: ListTile(
          leading: Icon(ok ? Icons.check_circle : Icons.warning_amber),
          title: Text('${ok ? '✅' : '⚠️'} $title'),
          subtitle: Text(subtitle),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('서버 · 기능 진단', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Card(
          child: ListTile(
            leading: const Icon(Icons.park_outlined),
            title: const Text('진단 대상 과수원'),
            subtitle: Text('${OrchardSelection.name} · ${OrchardSelection.varieties}'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: server,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '클라우드 서버 URL',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: checking ? null : saveAndTest,
          icon: const Icon(Icons.cloud_done_outlined),
          label: Text(checking ? '확인 중...' : '저장하고 연결 테스트'),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(serverStatus),
            subtitle: Text(FarmApi.baseUrl),
          ),
        ),
        const Divider(height: 28),
        const Text('전체 기능 진단', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text('상단에서 선택한 현재 과수원을 기준으로 서버·DB·날씨·작업·코치 API를 읽기 전용으로 검사합니다.'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: diagnosing ? null : runDiagnostics,
          icon: const Icon(Icons.health_and_safety_outlined),
          label: Text(diagnosing ? '진단 중...' : '전체 기능 진단 실행'),
        ),
        if (diag.isNotEmpty) ...[
          diagCard('서버', diag['server'] == true, '버전 ${diag['server_version'] ?? '-'}'),
          diagCard('데이터베이스', diag['database'] == true && diag['database_type'] == 'postgresql', '${diag['database_type'] ?? '-'}'),
          diagCard('KMA 키 설정', diag['kma_configured'] == true, diag['kma_configured'] == true ? '설정됨' : '미설정'),
          diagCard('날씨 API', diag['weather'] == true && diag['weather_source'] == 'kma', '소스: ${diag['weather_source'] ?? '-'}\n${diag['weather_warning'] ?? ''}'),
          diagCard('작업 API', diag['tasks'] == true, '${diag['task_count'] ?? 0}건 조회'),
          diagCard('코치 API', diag['coach'] == true, diag['coach'] == true ? '정상 응답' : '응답 실패'),
        ],
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('과수원 이름은 이 화면에서 따로 입력하지 않습니다.'),
            subtitle: Text('앱 최상단에서 선택한 과수원이 모든 진단·경영·GPS·작업 기능에 공통 적용됩니다.'),
          ),
        ),
      ],
    );
  }
}
