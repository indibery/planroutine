import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/import/presentation/screens/import_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/trash/presentation/screens/trash_screen.dart';
import '../../shared/widgets/main_shell.dart';

/// 라우트 경로 상수
class AppRoutes {
  AppRoutes._();

  static const onboarding = '/onboarding';
  static const calendar = '/calendar';
  static const schedule = '/schedule';
  static const settings = '/settings';
  static const trash = '/trash';
  static const import = '/import';
}

/// GoRouter 팩토리 — 부팅 시 onboarding 완료 여부에 따라 initial 라우트 결정.
///
/// 외부 앱(카카오톡/메일/파일 앱)이 CSV 파일로 앱을 열면 iOS가 file:// URL을
/// Flutter 초기 라우트로 넘긴다. GoRouter는 해당 URL과 매칭되는 라우트가
/// 없으므로 Page Not Found를 띄운다. redirect로 이를 가로채 /import로 보내면,
/// `receive_sharing_intent` 리스너가 별도 스트림으로 전달하는 실제 파일 경로는
/// app.dart의 _handleSharedFiles가 처리한다.
GoRouter createRouter({required bool onboardingDone}) => GoRouter(
      initialLocation:
          onboardingDone ? AppRoutes.calendar : AppRoutes.onboarding,
      redirect: (context, state) {
        final uri = state.uri;
        final isExternalFileIntent = uri.scheme == 'file' ||
            uri.path.toLowerCase().endsWith('.csv');
        if (isExternalFileIntent) {
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
              path: AppRoutes.calendar,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: CalendarScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.schedule,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ScheduleScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.settings,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.trash,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TrashScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.import,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ImportScreen(),
              ),
            ),
          ],
        ),
      ],
    );
