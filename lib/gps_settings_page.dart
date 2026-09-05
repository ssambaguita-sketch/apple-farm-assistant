import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'services/gps_api.dart';
import 'services/orchard_selection.dart';

class GpsSettingsPage extends StatefulWidget {
  const GpsSettingsPage({super.key});

  @override
  State<GpsSettingsPage> createState() => _GpsSettingsPageState();
}

class _GpsSettingsPageState extends State<GpsSettingsPage> {
  final GpsApi api = GpsApi();
  bool loading = false;
  bool saving = false;
  Map<String, dynamic>? status;
  String message = '';

  @override
  void initState() {
    super.initState();
    OrchardSelection.notifier.addListener(_selectionChanged);
    _loadStatus();
  }

  @override
  void dispose() {
    OrchardSelection.notifier.removeListener(_selectionChanged);
    super.dispose();
  }

  void _selectionChanged() => _loadStatus();

  Future<void> _loadStatus() async {
    if (mounted) setState(() => loading = true);
    final r = await api.status(OrchardSelection.name);
    if (!mounted) return;
    setState(() {
      status = r;
      loading = false;
      if (r['ok'] != true && r['error'] != null) message = '${r['error']}';
    });
  }

  Future<void> _saveCurrentLocation() async {
    setState(() {
      saving = true;
      message = '현재 위치를 확인하는 중입니다...';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('휴대폰 위치 서비스를 켜주세요.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구 거부되어 있습니다. 앱 설정에서 위치 권한을 허용하세요.');
      }
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 필요합니다.');
      }

      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final orchard = OrchardSelection.name;
      final r = await api.save(orchard: orchard, lat: p.latitude, lon: p.longitude);
      if (!mounted) return;
      if (r['ok'] == true && r['verified'] == true) {
        setState(() {
          status = r;
          message = 'GPS가 서버 DB에 저장되고 재조회 검증까지 완료되었습니다.';
        });
      } else {
        setState(() => message = '${r['error'] ?? 'GPS 저장 검증에 실패했습니다.'}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = status?['saved'] == true || status?['verified'] == true;
    final lat = status?['lat'];
    final lon = status?['lon'];
    final nx = status?['nx'];
    final ny = status?['ny'];

    return RefreshIndicator(
      onRefresh: _loadStatus,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('과수원 GPS', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('현재 선택 과수원: ${OrchardSelection.name}'),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: saved ? const Color(0xFFDFF0DC) : const Color(0xFFFFE8C7),
                child: Icon(saved ? Icons.location_on : Icons.location_off_outlined),
              ),
              title: Text(saved ? 'GPS 저장됨' : 'GPS 미저장', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: loading
                  ? const Text('서버 DB 확인 중...')
                  : saved
                      ? Text('위도 ${_fmt(lat)} · 경도 ${_fmt(lon)}\nKMA 격자 nx $nx · ny $ny')
                      : const Text('현재 과수원의 저장된 GPS 좌표가 없습니다.'),
              isThreeLine: saved,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : _saveCurrentLocation,
              icon: const Icon(Icons.my_location_rounded),
              label: Text(saving ? 'GPS 저장·검증 중...' : '현재 위치를 이 과수원 GPS로 저장'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: loading ? null : _loadStatus,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('서버 DB에서 다시 확인'),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(saved ? Icons.verified_outlined : Icons.info_outline),
                title: Text(message),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('저장 방식'),
              subtitle: Text('휴대폰 GPS 취득 → 선택 과수원 확인 → 서버 DB 저장 → 저장값 재조회 검증까지 성공해야 완료로 표시합니다.'),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic value) {
    if (value is num) return value.toDouble().toStringAsFixed(6);
    return value?.toString() ?? '-';
  }
}
