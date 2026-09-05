import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'finance_page.dart';
import 'gps_settings_page.dart';
import 'in_app_update_page.dart';
import 'notification_settings_page.dart';
import 'server_diagnostics_page.dart';
import 'services/orchard_selection.dart';

class ManagementPage extends StatelessWidget {
  const ManagementPage({super.key});

  static final Uri _releaseUri = Uri.parse(
    'https://github.com/ssambaguita-sketch/apple-farm-assistant/releases/latest',
  );

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

  Future<void> _openOfficialRelease(BuildContext context) async {
    final opened = await launchUrl(_releaseUri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공식 다운로드 페이지를 열 수 없습니다. 네트워크를 확인하세요.')),
      );
    }
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
          color: const Color(0xFFEAF5E5),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.system_update_alt_rounded)),
            title: const Text('앱 안에서 업데이트', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('최신 버전 확인 → APK 자동 다운로드 → 기존 앱 위에 업데이트'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, '앱 안에서 업데이트', const InAppUpdatePage()),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.open_in_new_rounded)),
            title: const Text('공식 설치 출처', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('GitHub Releases 공식 배포 페이지를 직접 엽니다.'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => _openOfficialRelease(context),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: const Color(0xFFFFF6E8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.notifications_active_rounded)),
            title: const Text('추천작업 강화 알림', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('P3~P5 자동추천 작업 반복 알림 · 완료 시 자동 해제 · 테스트 알림'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, '추천작업 강화 알림', const NotificationSettingsPage()),
          ),
        ),
        const SizedBox(height: 10),
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
            subtitle: const Text('현재 선택 과수원 기준 서버, KMA, 작업·코치 API 전체 기능 진단'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, '설정 · 기능 진단', const ServerDiagnosticsPage()),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.speed_outlined)),
            title: Text('속도 최적화 적용', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('탭 화면 상태 유지 · 과수원 변경 시 관련 화면만 재생성 · 서버 날씨 5분 캐시'),
          ),
        ),
      ],
    );
  }
}
