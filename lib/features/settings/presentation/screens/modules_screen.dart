// lib/features/settings/presentation/screens/modules_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/modules/app_module.dart';
import '../../../../core/modules/installed_modules_provider.dart';
import '../../../../core/modules/module_rules.dart';
import '../../../../core/theme/app_text_styles.dart';

/// `설정 › 기능 관리` — 선택 기능을 켜고 끄고, 탭 순서를 바꾼다.
///
/// **켜고 꺼도 항목이 자리를 옮기지 않는다.** 아래 `기능` 목록은 켜짐과 무관하게
/// 등록부 순서 그대로다 — 버튼으로 "추가"하면 항목이 위 섹션으로 옮겨 가 누른
/// 자리에서 사라진다(오늘 탭 완료 토글을 재정렬하지 않는 것과 같은 원칙).
/// 끄더라도 데이터는 남으므로 확인 다이얼로그가 없다.
class ModulesScreen extends ConsumerWidget {
  const ModulesScreen({super.key});

  static Key switchKey(String id) => Key('module_switch_$id');
  static Key tabRowKey(String id) => Key('module_tab_$id');
  static const lockIconKey = Key('module_lock');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(moduleCatalogProvider);
    final resolved =
        ref.watch(installedModulesProvider).valueOrNull ??
        resolveModules(catalog, null);
    final notifier = ref.read(installedModulesProvider.notifier);

    final movable = [
      for (final m in resolved.tabs)
        if (m.id != ModuleIds.settings) m,
    ];
    final settings = resolved.tabs.last;
    final optional = [for (final m in catalog) if (!m.fixed) m];
    final tabsFull = resolved.tabs.length >= kMaxTabs;
    final installedIds = resolved.ids.toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(SettingsStrings.modulesTitle, style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing24),
        children: [
          _header(
            SettingsStrings.modulesMyTabs,
            trailing: SettingsStrings.modulesTabCount(
              resolved.tabs.length,
              kMaxTabs,
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // reorderTabs가 onReorder 규약(아래로 옮길 때 한 칸 큼)을 받는다.
            // ignore: deprecated_member_use
            onReorder: notifier.reorderTabs,
            children: [
              for (final (i, m) in movable.indexed)
                ListTile(
                  key: tabRowKey(m.id),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: Icon(Icons.drag_handle, color: AppColors.sub),
                  ),
                  title: Text(m.name),
                  trailing: m.fixed ? _lock() : null,
                ),
            ],
          ),
          // 설정은 드래그 목록 밖에 둔다 — 늘 맨 끝이라 옮길 수 없다.
          ListTile(
            key: tabRowKey(settings.id),
            leading: const SizedBox(width: 24),
            title: Text(settings.name),
            trailing: _lock(),
          ),
          const Divider(),
          _header(SettingsStrings.modulesFeatures),
          if (optional.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: Text(
                SettingsStrings.modulesEmpty,
                style: TextStyle(color: AppColors.sub),
              ),
            ),
          for (final m in optional)
            _moduleTile(
              m,
              installed: installedIds.contains(m.id),
              blocked:
                  tabsFull &&
                  m.placement == ModulePlacement.tab &&
                  !installedIds.contains(m.id),
              onChanged: (v) => notifier.setEnabled(m.id, v),
            ),
        ],
      ),
    );
  }

  Widget _lock() =>
      Icon(Icons.lock_outline, key: lockIconKey, size: 18, color: AppColors.faint);

  Widget _header(String title, {String? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.pagePadding,
      AppSizes.spacing16,
      AppSizes.pagePadding,
      AppSizes.spacing4,
    ),
    child: Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.eyebrow)),
        if (trailing != null)
          Text(trailing, style: TextStyle(fontSize: 14, color: AppColors.sub)),
      ],
    ),
  );

  /// 스위치에 `activeThumbColor`를 주지 않는다 — 전역 `switchTheme` 색 가드.
  Widget _moduleTile(
    AppModule m, {
    required bool installed,
    required bool blocked,
    required ValueChanged<bool> onChanged,
  }) {
    final placement = m.placement == ModulePlacement.tab
        ? SettingsStrings.placementTab
        : SettingsStrings.placementTodayCard;
    return SwitchListTile(
      key: switchKey(m.id),
      secondary: Icon(m.icon, color: AppColors.primary),
      title: Text(m.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$placement · ${m.description}'),
          if (blocked) Text(SettingsStrings.modulesTabsFull(kMaxTabs)),
        ],
      ),
      isThreeLine: blocked,
      value: installed,
      onChanged: blocked ? null : onChanged,
    );
  }
}
