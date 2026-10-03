// 고정 탭 상수 — 기능 화면을 모른다. MainShell이 이 파일만 본다.
import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../router/app_router.dart';
import 'app_module.dart';

const todayTab = ModuleTab(
  route: AppRoutes.today,
  icon: Icons.check_circle_outline,
  activeIcon: Icons.check_circle,
  label: AppStrings.tabToday,
);

const calendarTab = ModuleTab(
  route: AppRoutes.calendar,
  icon: Icons.calendar_month_outlined,
  activeIcon: Icons.calendar_month,
  label: AppStrings.tabCalendar,
);

const scheduleTab = ModuleTab(
  route: AppRoutes.schedule,
  // 이 탭의 주 동작은 검토가 아니라 넣기 — 체크리스트 아이콘은 어긋난다.
  icon: Icons.note_add_outlined,
  activeIcon: Icons.note_add,
  label: AppStrings.tabSchedule,
);

const settingsTab = ModuleTab(
  route: AppRoutes.settings,
  icon: Icons.settings_outlined,
  activeIcon: Icons.settings,
  label: SettingsStrings.title,
);

/// 등록부가 아직 로딩 중일 때와 `MainShell`의 기본값.
const defaultTabs = [todayTab, calendarTab, scheduleTab, settingsTab];
