import 'package:go_router/go_router.dart';

import '../../features/bus/domain/commute_direction.dart';
import '../../features/bus/presentation/screens/bus_stop_search_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/import/presentation/screens/import_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../../features/settings/presentation/screens/bus_settings_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/today/presentation/screens/today_screen.dart';
import '../../features/trash/presentation/screens/trash_screen.dart';
import '../../shared/widgets/main_shell.dart';

/// 라우트 경로 상수
class AppRoutes {
  AppRoutes._();

  static const onboarding = '/onboarding';
  static const today = '/today';
  static const calendar = '/calendar';
  static const schedule = '/schedule';
  static const settings = '/settings';
  static const trash = '/trash';
  static const import = '/import';
  static const busStops = '/bus/stops';
  static const busSettings = '/bus/settings';
}

/// 외부 앱이 CSV로 앱을 열었을 때 Flutter가 초기 라우트로 넘기는 URL인지.
///
/// 그 URL에 맞는 라우트는 없으므로 가로채지 않으면 **Page Not Found**가 뜬다.
/// 실제 파일 경로는 별도 채널(`planroutine/shared_file`)로 오고 `app.dart`가 처리한다 —
/// 이 함수는 화면이 깨지지 않게 `/import`로 보내는 몫만 한다.
///
/// **플랫폼마다 모양이 다르다**:
/// - iOS `file:///private/var/…/작년업무.csv` — scheme과 확장자 둘 다 있다
/// - Android `content://media/external/file/1000000018` — **둘 다 없다.**
///   확장자로도 파일명으로도 걸러지지 않아 `content` scheme을 따로 봐야 한다.
///   에뮬레이터에서 `GoException: no routes for location: content://…`로 실측했다
///   (2026-08-14). 가드·빌드·네이티브 복사가 전부 통과한 뒤에도 화면은 Page Not Found였고,
///   **에뮬레이터를 띄우기 전까지 아무 신호가 없었다.**
bool isExternalFileIntent(Uri uri) =>
    uri.scheme == 'file' ||
    uri.scheme == 'content' ||
    uri.path.toLowerCase().endsWith('.csv');

/// GoRouter 팩토리 — 부팅 시 onboarding 완료 여부에 따라 initial 라우트 결정.
///
/// 외부 파일 인텐트는 [isExternalFileIntent]가 판정해 `/import`로 보낸다.
GoRouter createRouter({
  required bool onboardingDone,
  String? initialLocation,
}) => GoRouter(
  initialLocation:
      initialLocation ??
      (onboardingDone ? AppRoutes.today : AppRoutes.onboarding),
  redirect: (context, state) {
    if (isExternalFileIntent(state.uri)) {
      return AppRoutes.import;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.today,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TodayScreen()),
        ),
        GoRoute(
          path: AppRoutes.calendar,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CalendarScreen()),
        ),
        GoRoute(
          path: AppRoutes.schedule,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ScheduleScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.trash,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TrashScreen()),
        ),
        GoRoute(
          path: AppRoutes.import,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ImportScreen()),
        ),
        // 설정 탭에서 push. `/bus/stops`와 같은 Shell에 둬야
        // `설정 › 버스 도착 › 정류장 검색`이 순서대로 쌓이고 탭바가 남는다.
        GoRoute(
          path: AppRoutes.busSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BusSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.busStops,
          pageBuilder: (context, state) => NoTransitionPage(
            child: BusStopSearchScreen(
              slot: CommuteDirection.fromName(
                state.uri.queryParameters['slot'],
              ),
            ),
          ),
        ),
      ],
    ),
  ],
);
