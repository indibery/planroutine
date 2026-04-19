import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/compare/presentation/screens/compare_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/widgets/main_shell.dart';

/// 라우트 경로 상수
class AppRoutes {
  AppRoutes._();

  static const calendar = '/calendar';
  static const schedule = '/schedule';
  static const compare = '/compare';
  static const settings = '/settings';
}

/// GoRouter 설정
final appRouter = GoRouter(
  initialLocation: AppRoutes.calendar,
  routes: [
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
          path: AppRoutes.compare,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CompareScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
  ],
);
