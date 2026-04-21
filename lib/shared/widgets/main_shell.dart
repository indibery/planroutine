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
      route: AppRoutes.calendar,
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
      label: AppStrings.tabCalendar,
    ),
    (
      route: AppRoutes.schedule,
      icon: Icons.checklist_rtl_outlined,
      activeIcon: Icons.checklist_rtl,
      label: AppStrings.tabSchedule,
    ),
    (
      route: AppRoutes.settings,
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: AppStrings.settingsTitle,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabs.indexWhere((tab) => location.startsWith(tab.route));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      extendBody: true,
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
