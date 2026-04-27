import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/device_calendar_service.dart';

/// 시스템 캘린더 서비스 싱글톤.
final deviceCalendarServiceProvider = Provider<DeviceCalendarService>((ref) {
  return DeviceCalendarService();
});

/// 캘린더 권한 status (denied / permanentlyDenied / granted 등 세부 상태).
///
/// **device_calendar(EKEventStore 직접)와 permission_handler가 iOS 17+에서
/// 캐시 동기화가 어긋나는 케이스가 있다.** 사용자가 슬라이드로 권한 받았더라도
/// `Permission.calendarFullAccess.status`만 보면 stale 결과(denied)가 잡힐 수
/// 있어, device_calendar service를 우선 체크하고 false일 때만 세부 status를 묻는다.
///
/// - service.hasPermissions == true → granted 반환
/// - service.hasPermissions == false → permission_handler로 세부(denied/permanentlyDenied)
final calendarPermissionStatusProvider =
    FutureProvider<PermissionStatus>((ref) async {
  final service = ref.watch(deviceCalendarServiceProvider);
  if (await service.hasPermissions()) {
    return PermissionStatus.granted;
  }
  return Permission.calendarFullAccess.status;
});
