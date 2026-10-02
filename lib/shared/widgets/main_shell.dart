import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/app_module.dart';
import '../../core/modules/module_catalog.dart';
import '../../core/router/app_router.dart';
import 'floating_tab_bar.dart';

/// 플로팅 탭바를 감싸는 메인 Shell
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child, this.tabs = defaultTabs});

  final Widget child;

  /// 탭 순서대로. 등록부가 정하고 라우터가 넘긴다 — 이 위젯은 feature를 모른다.
  final List<ModuleTab> tabs;

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
    AppRoutes.modules: AppRoutes.settings,
  };

  /// 지금 켜야 할 탭. 테스트가 직접 부를 수 있게 static으로 둔다.
  ///
  /// push 라우트의 주인 탭이 [tabs]에 없으면 **설정**을 켠다. -1을 그대로 쓰면
  /// 어느 탭도 켜지지 않는다. 설정은 항상 있고 push 화면 대부분이 설정 소속이라
  /// 가장 덜 어긋난다.
  static int indexForLocation(
    String location, {
    List<ModuleTab> tabs = defaultTabs,
  }) {
    final direct = tabs.indexWhere((tab) => location.startsWith(tab.route));
    if (direct >= 0) return direct;

    // 가장 긴 것부터 본다 — `/bus/settings`와 `/bus/stops`처럼 접두가 겹치는
    // 짝이 있으면 짧은 쪽이 먼저 걸려 엉뚱한 탭을 켠다.
    final keys = _pushOwner.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (location.startsWith(key)) {
        final owner = tabs.indexWhere((tab) => tab.route == _pushOwner[key]);
        if (owner >= 0) return owner;
        return tabs.indexWhere((tab) => tab.route == AppRoutes.settings);
      }
    }
    return 0;
  }

  int _currentIndex(BuildContext context) =>
      indexForLocation(GoRouterState.of(context).uri.path, tabs: tabs);

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: FloatingTabBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(tabs[index].route),
        tabs: tabs
            .map(
              (tab) => FloatingTabItem(
                icon: tab.icon,
                activeIcon: tab.activeIcon,
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
