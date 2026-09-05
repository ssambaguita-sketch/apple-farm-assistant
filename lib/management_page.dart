import 'package:flutter/material.dart';

import 'finance_page.dart';
import 'gps_settings_page.dart';
import 'main.dart' as legacy;
import 'services/orchard_selection.dart';

class ManagementPage extends StatelessWidget {
  const ManagementPage({super.key});

  void _open(BuildContext context, String title, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(child: page),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('경영 · 설정', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${OrchardSelection.name} 기준 통합 관리'),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
            title: const Text('경영 관리', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('매출 · 비용 · 수확량 · 순이익 · 수익률을 실제 DB에 기록/조회'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, '경영 관리', const FinancePage()),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.my_location_rounded)),
            title: const Text('과수원 GPS', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('현재 선택 과수원에 GPS 저장 · DB 재조회 검증 · KMA 격자 확인'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, '과수원 GPS', const GpsSettingsPage()),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.settings_outlined)),
            title: const Text('서버 · 기능 진단', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('서버 연결, KMA 상태, 작업·코치 API 전체 기능 진단'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, '설정 · 기능 진단', const legacy.MorePage()),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.speed_outlined)),
            title: Text('속도 최적화 적용', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('탭 화면 상태 유지 · 중복 화면 재생성 감소 · 서버 날씨 5분 캐시'),
          ),
        ),
      ],
    );
  }
}
