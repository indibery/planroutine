import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/dev/screenshot_seed.dart';
import 'features/notifications/presentation/providers/notification_providers.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/trash/presentation/providers/trash_providers.dart';

/// `--dart-define=SCREENSHOT_MODE=true` 로 실행되면 앱 시작 시 seed 데이터를
/// 주입해 App Store 스크린샷 촬영을 자연스럽게 만든다. 일반/릴리즈 빌드에선 false.
const bool kScreenshotMode =
    bool.fromEnvironment('SCREENSHOT_MODE');

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

  // 온보딩 완료 여부를 부팅 시 1회 읽어 router에 주입.
  // 실패 시에는 "완료된 것으로" 간주해 기본 화면(calendar)로 진입.
  var onboardingDone = true;
  try {
    onboardingDone = await OnboardingRepository().isDone();
  } catch (_) {}

  // 스크린샷 모드면 seed 데이터 주입. 일반 실행에선 skip.
  if (kScreenshotMode) {
    try {
      await seedScreenshotData(container);
    } catch (_) {}
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PlanRoutineApp(onboardingDone: onboardingDone),
    ),
  );
}
