import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/device_calendar_service.dart';

/// 시스템 캘린더 서비스 싱글톤.
final deviceCalendarServiceProvider = Provider<DeviceCalendarService>((ref) {
  return DeviceCalendarService();
});

/// 캘린더 권한 status (denied / permanentlyDenied / granted 등 세부 상태).
///
/// iOS는 한 번도 권한 요청 안 했으면 `denied` (request 가능),
/// 한 번 거부 후엔 `permanentlyDenied` (다이얼로그 안 뜸 → 설정 앱).
/// granted 여부는 `status.isGranted`로 파생 가능하므로 별도 bool provider는 두지 않음.
final calendarPermissionStatusProvider =
    FutureProvider<PermissionStatus>((ref) async {
  return Permission.calendarFullAccess.status;
});
