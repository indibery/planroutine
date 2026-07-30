import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/bus_settings_tiles.dart';

/// `설정 › 버스 도착` 상세 화면.
///
/// **시트가 아니라 화면인 이유**: 이 안에서 정류장 검색(`/bus/stops`, 풀스크린)과
/// `showTimePicker`를 다시 띄운다. 시트 위에 풀스크린을 push하면 시트가 가려진 채
/// 뒤에 남고 돌아올 때 다시 나타난다. 화면이면 `설정 › 버스 도착 › 정류장 검색`으로
/// 쌓이고 뒤로가기 한 번씩이 순서대로 맞는다.
///
/// **[BusSettingsTiles]를 옮기지 않고 감싸기만 한다** — 그 위젯의 테스트 9건이
/// 그대로 남는다.
///
/// 이 화면은 `features/bus/`가 아니라 여기 산다. 위젯이 이미 settings 아래 있어
/// bus에 두면 bus → settings 역방향 import가 생긴다(지금은 settings → bus 한 방향).
class BusSettingsScreen extends StatelessWidget {
  const BusSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(BusStrings.section, style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing24),
        children: [
          // 설정 탭 섹션 부제가 여기로 옮겨 왔다. 걷어내면 기능 소개가 사라진다.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.spacing12,
              AppSizes.pagePadding,
              AppSizes.spacing8,
            ),
            child: Text(
              BusStrings.sectionDescription,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                height: 1.4,
                color: AppColors.sub,
              ),
            ),
          ),
          const BusSettingsTiles(),
        ],
      ),
    );
  }
}
