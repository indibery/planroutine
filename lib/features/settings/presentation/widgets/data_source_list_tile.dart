import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

/// 공공데이터 출처 표시 — 정보성, 탭 비활성([AppInfoListTile]과 같은 형태).
///
/// **라이선스 의무를 이행하는 화면이다.** 서울특별시 버스 API의 이용허락범위가
/// `저작자표시`(CC BY) + 공공누리 제1유형(출처표시)이고, 실제로 호출하는 기관을
/// 밝히지 않으면 그 조건을 지키지 않는 것이 된다.
///
/// 문구는 [SettingsStrings.dataSourceBody] 하나에 있다 — 기관 이름을 위젯에 박으면
/// 소스가 바뀔 때(서울 API 추가 예정) 문구와 실제 호출이 어긋난다.
class DataSourceListTile extends StatelessWidget {
  const DataSourceListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.public_outlined, color: AppColors.textSecondary),
      title: const Text(SettingsStrings.dataSourceTitle),
      subtitle: Text(SettingsStrings.dataSourceBody),
    );
  }
}
