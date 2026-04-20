import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/notifications/presentation/providers/notification_providers.dart';
import 'features/trash/presentation/providers/trash_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // 30일 이상 경과한 휴지통 항목을 앱 시작 시 1회 영구 삭제한다.
  // 실패해도 앱 기동은 차단하지 않음.
  try {
    await purgeExpiredTrash(container);
  } catch (_) {}

  // 알림 플랫폼 초기화 + 저장된 이벤트/설정으로 재예약.
  // 디바이스 재부팅 후나 앱 첫 실행 시 일관된 상태 보장.
  try {
    await container.read(notificationServiceProvider).init();
    await container.read(notificationSyncerProvider).sync();
  } catch (_) {}

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PlanRoutineApp(),
    ),
  );
}
