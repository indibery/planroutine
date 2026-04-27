import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/device_calendar_service.dart';

/// 시스템 캘린더 서비스 싱글톤.
final deviceCalendarServiceProvider = Provider<DeviceCalendarService>((ref) {
  return DeviceCalendarService();
});

/// 캘린더 권한 보유 여부(허용됨인지). 화면 진입/refresh 시마다 갱신.
final devicePermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(deviceCalendarServiceProvider);
  return service.hasPermissions();
});

/// 캘린더 권한 status (denied / permanentlyDenied / granted 등 세부 상태).
///
/// iOS는 한 번도 권한 요청 안 했으면 `denied` (request 가능),
/// 한 번 거부 후엔 `permanentlyDenied` (다이얼로그 안 뜸 → 설정 앱).
final calendarPermissionStatusProvider =
    FutureProvider<PermissionStatus>((ref) async {
  return Permission.calendarFullAccess.status;
});
