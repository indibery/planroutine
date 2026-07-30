import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_features.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/settings_providers.dart';
import '../widgets/app_info_list_tile.dart';
import '../widgets/bus_summary_list_tile.dart';
import '../widgets/data_source_list_tile.dart';
import '../widgets/export_list_tile.dart';
import '../widgets/calendar_integration_section.dart';
import '../widgets/notification_settings_tiles.dart';
import '../widgets/reset_list_tile.dart';
import '../widgets/settings_section.dart';
import '../widgets/stamp_settings_tiles.dart';
import '../widgets/theme_mode_tile.dart';
import '../widgets/trash_list_tile.dart';

/// 설정 화면 (하단 탭).
///
/// 각 섹션은 `features/settings/presentation/widgets/` 하위의 개별 위젯으로
/// 분리돼 있다. 이 화면은 섹션을 조합하고 reset 완료/실패 시 스낵바를 띄우는
/// 역할만 맡는다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ResetState>(appResetProvider, (prev, next) {
      switch (next) {
        case ResetSuccess():
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(content: Text(SettingsStrings.resetAllDone)),
            );
        case ResetFailure(message: final msg):
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('${SettingsStrings.resetAllFailed}: $msg'),
                backgroundColor: AppColors.error,
              ),
            );
        case ResetIdle() || ResetInProgress():
          break;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          SettingsStrings.title,
          style: AppTextStyles.heading,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing24),
        children: [
          // **섹션 헤더를 두지 않는다**(실기기 신고 2026-07-30).
          //
          // 여덟 개 중 다섯은 행 제목의 축약이거나 같은 말이었고(`휴지통` 헤더 +
          // `휴지통` 행), 나머지도 행이 스스로를 설명해 헤더가 하는 일이 없었다.
          // 여덟 줄 약 200px — 화면 3분의 1이 라벨에 쓰이고 있었다.
          //
          // **설명은 버리지 않고 행 부제로 내렸다** — 헤더만 지우면
          // `30일 후 자동 영구 삭제` 같은, 이 화면에서만 볼 수 있는 규칙이
          // 함께 사라진다. 묶임은 `Divider`가 그대로 맡는다.
          const SettingsSection(child: ThemeModeTile()),
          const SettingsSection(child: StampSettingsTiles()),
          const SettingsSection(child: BusSummaryListTile()),
          const SettingsSection(child: ExportListTile()),
          if (AppFeatures.googleCalendarEnabled)
            const CalendarIntegrationSection(),
          const SettingsSection(child: NotificationSettingsTiles()),
          const SettingsSection(child: TrashListTile()),
          const SettingsSection(child: ResetListTile()),
          const SettingsSection(
            showDivider: false,
            // 출처 표시는 앱 정보 아래에 붙인다 — 둘 다 정보성이고 탭이 없다.
            child: Column(
              children: [AppInfoListTile(), DataSourceListTile()],
            ),
          ),
          const SizedBox(height: AppSizes.spacing24),
        ],
      ),
    );
  }
}
