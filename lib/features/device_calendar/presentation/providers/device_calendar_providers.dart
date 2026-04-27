import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/device_calendar_service.dart';

/// 시스템 캘린더 서비스 싱글톤.
final deviceCalendarServiceProvider = Provider<DeviceCalendarService>((ref) {
  return DeviceCalendarService();
});

/// 캘린더 권한 상태. 화면 진입/refresh 시마다 갱신.
final devicePermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(deviceCalendarServiceProvider);
  return service.hasPermissions();
});
