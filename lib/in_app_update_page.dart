import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppUpdatePage extends StatefulWidget {
  const InAppUpdatePage({super.key});

  @override
  State<InAppUpdatePage> createState() => _InAppUpdatePageState();
}

class _InAppUpdatePageState extends State<InAppUpdatePage> {
  static final Uri _latestReleaseApi = Uri.parse(
    'https://api.github.com/repos/ssambaguita-sketch/apple-farm-assistant/releases/latest',
  );
  static final Uri _latestReleasePage = Uri.parse(
    'https://github.com/ssambaguita-sketch/apple-farm-assistant/releases/latest',
  );

  String currentVersion = '-';
  String latestVersion = '-';
  String status = '최신 버전을 확인하세요.';
  String? apkUrl;
  bool checking = false;
  bool updating = false;
  double? progress;
  StreamSubscription<OtaEvent>? _otaSub;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  @override
  void dispose() {
    _otaSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => currentVersion = '${info.version}+${info.buildNumber}');
  }

  List<int> _versionParts(String text) {
    final clean = text.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    return clean.split('.').map((x) => int.tryParse(x) ?? 0).toList();
  }

  bool _isNewer(String remote, String local) {
    final a = _versionParts(remote);
    final b = _versionParts(local);
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av > bv;
    }
    final remoteBuild = int.tryParse(remote.split('+').length > 1 ? remote.split('+').last : '') ?? 0;
    final localBuild = int.tryParse(local.split('+').length > 1 ? local.split('+').last : '') ?? 0;
    return remoteBuild > localBuild;
  }

  Future<void> checkUpdate() async {
    if (checking || updating) return;
    setState(() {
      checking = true;
      status = '공식 배포 버전을 확인하는 중입니다...';
    });
    try {
      final r = await http.get(
        _latestReleaseApi,
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) {
        throw Exception('GitHub 응답 ${r.statusCode}');
      }
      final data = Map<String, dynamic>.from(jsonDecode(r.body));
      final tag = '${data['tag_name'] ?? ''}'.replaceFirst(RegExp(r'^[vV]'), '');
      final assets = List<dynamic>.from(data['assets'] ?? const []);
      String? url;
      for (final raw in assets) {
        if (raw is! Map) continue;
        final asset = Map<String, dynamic>.from(raw);
        final name = '${asset['name'] ?? ''}'.toLowerCase();
        if (name.endsWith('.apk')) {
          url = '${asset['browser_download_url'] ?? ''}';
          if (url.isNotEmpty) break;
        }
      }
      final newer = tag.isNotEmpty && _isNewer(tag, currentVersion);
      if (!mounted) return;
      setState(() {
        latestVersion = tag.isEmpty ? '-' : tag;
        apkUrl = url;
        status = newer
            ? (url == null ? '새 버전이 있지만 APK 파일을 찾지 못했습니다.' : '새 버전이 있습니다. 앱 안에서 바로 업데이트할 수 있습니다.')
            : '현재 최신 버전을 사용 중입니다.';
      });
    } catch (e) {
      if (mounted) setState(() => status = '업데이트 확인 실패: $e');
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> startUpdate() async {
    final url = apkUrl;
    if (url == null || url.isEmpty || updating) return;
    await _otaSub?.cancel();
    setState(() {
      updating = true;
      progress = 0;
      status = 'APK 다운로드를 시작합니다...';
    });

    _otaSub = OtaUpdate()
        .execute(
          url,
          destinationFilename: 'apple-farm-assistant-update.apk',
        )
        .listen(
      (event) {
        if (!mounted) return;
        final value = double.tryParse(event.value ?? '');
        setState(() {
          if (value != null && value >= 0 && value <= 100) progress = value / 100.0;
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              status = '업데이트 다운로드 중${event.value == null ? '' : ' · ${event.value}%'}';
              break;
            case OtaStatus.INSTALLING:
              status = '다운로드 완료 · Android 설치 확인창을 엽니다.';
              progress = 1;
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              status = '이미 업데이트가 진행 중입니다.';
              updating = false;
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              status = '앱 설치 권한이 필요합니다. Android의 “이 출처 허용”을 켜 주세요.';
              updating = false;
              break;
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            case OtaStatus.INTERNAL_ERROR:
              status = '업데이트 실패: ${event.value ?? event.status.name}';
              updating = false;
              break;
          }
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          updating = false;
          status = '업데이트 실패: $e';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => updating = false);
      },
    );
  }

  Future<void> openReleasePage() async {
    await launchUrl(_latestReleasePage, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final newer = latestVersion != '-' && _isNewer(latestVersion, currentVersion);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Card(
          color: Color(0xFFF1F8EF),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.system_update_alt_rounded, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '앞으로 APK 파일을 직접 찾아 설치하지 않아도 됩니다. 앱에서 새 버전을 확인하고 다운로드한 뒤 Android 설치 확인창에서 한 번만 승인하면 기존 앱 위에 업데이트됩니다.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('현재 버전  $currentVersion', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('공식 최신 버전  $latestVersion'),
                const SizedBox(height: 12),
                Text(status),
                if (progress != null) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: checking || updating ? null : checkUpdate,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(checking ? '확인 중...' : '최신 업데이트 확인'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: newer && apkUrl != null && !updating ? startUpdate : null,
          icon: const Icon(Icons.download_for_offline_rounded),
          label: Text(updating ? '업데이트 진행 중...' : '앱 안에서 업데이트'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: openReleasePage,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('공식 배포 페이지 열기'),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              '중요: 기존 앱 위에 업데이트하려면 이전 버전과 새 버전의 Android 서명이 같아야 합니다. 또한 Android 정책상 APK 업데이트 시 최종 설치 확인 자체를 일반 앱이 자동으로 우회할 수는 없습니다.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}
