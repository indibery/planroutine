import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import 'floating_tab_bar.dart';

/// 플로팅 탭바를 감싸는 메인 Shell
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    (
      route: AppRoutes.today,
      icon: Icons.check_circle_outline,
      activeIcon: Icons.check_circle,
      label: AppStrings.tabToday,
    ),
    (
      route: AppRoutes.calendar,
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
      label: AppStrings.tabCalendar,
    ),
    (
      route: AppRoutes.schedule,
      // 이 탭의 주 동작은 검토가 아니라 넣기 — 체크리스트 아이콘은 어긋난다.
      icon: Icons.note_add_outlined,
      activeIcon: Icons.note_add,
      label: AppStrings.tabSchedule,
    ),
    (
      route: AppRoutes.settings,
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: SettingsStrings.title,
    ),
  ];

  /// push 라우트가 어느 탭 소속인지.
  ///
  /// **탭 넷은 이 라우트들 중 무엇으로도 시작하지 않는다.** `/trash`는 `/today`·
  /// `/calendar`·`/schedule`·`/settings` 어느 것으로도 `startsWith`가 참이 되지
  /// 않아 `indexWhere`가 -1을 주고, 그러면 폴백이 **오늘 탭**을 켠다 — 설정에서
  /// 휴지통에 들어갔는데 하단 탭은 오늘이 켜져 있었다(실측 2026-07-30).
  ///
  /// ⚠️ **한계: 진입점이 둘인 라우트는 한쪽이 틀린다.**
  /// - `/bus/stops`는 설정(`bus_settings_tiles`)과 **오늘 탭 카드**
  ///   (`bus_card_host`의 정류장 선택)에서 열린다. 오늘 탭에서 들어가면 설정이 켜진다.
  /// - `/import`는 입력 탭 히어로와 **외부 CSV 공유**(`app.dart`)에서 열린다.
  ///
  /// 진입점을 기억하는 안(직전 탭 유지)이 그 둘을 정확히 풀지만 `MainShell`을
  /// StatefulWidget으로 바꿔야 한다. 단순함을 택했다 — 하이라이트가 잠깐 어긋나는
  /// 것이지 이동이 깨지는 것은 아니다(사용자 결정 2026-07-30).
  static const _pushOwner = {
    AppRoutes.trash: AppRoutes.settings,
    AppRoutes.import: AppRoutes.schedule,
    AppRoutes.busSettings: AppRoutes.settings,
    AppRoutes.busStops: AppRoutes.settings,
  };

  /// 지금 켜야 할 탭. 테스트가 직접 부를 수 있게 static으로 둔다.
  static int indexForLocation(String location) {
    final direct = _tabs.indexWhere((tab) => location.startsWith(tab.route));
    if (direct >= 0) return direct;

    // 가장 긴 것부터 본다 — `/bus/settings`와 `/bus/stops`처럼 접두가 겹치는
    // 짝이 있으면 짧은 쪽이 먼저 걸려 엉뚱한 탭을 켠다.
    final keys = _pushOwner.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (location.startsWith(key)) {
        return _tabs.indexWhere((tab) => tab.route == _pushOwner[key]);
      }
    }
    return 0;
  }

  int _currentIndex(BuildContext context) =>
      indexForLocation(GoRouterState.of(context).uri.path);

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: FloatingTabBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_tabs[index].route),
        tabs: _tabs
            .map((tab) => FloatingTabItem(
                  icon: tab.icon,
                  activeIcon: tab.activeIcon,
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}
