import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';

/// 탭 화면 머리 — 영문 eyebrow 위에 제목을 쌓는다(`AppBar.title`에 넣는다).
///
/// 오늘·입력·포스트잇·지도 기록이 같은 코드를 각자 복사해 쓰고, 캘린더·설정에는 eyebrow가
/// 없었다. 모든 탭이 이 위젯 하나를 쓴다(2026-10-04 디자인 점검, 사용자 결정 A).
/// push 화면(기능 관리·휴지통 등)은 뒤로 + 제목만 둔다.
class TabHeaderTitle extends StatelessWidget {
  const TabHeaderTitle({super.key, required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 장식용 영문 소제목 — 스크린리더가 "CALENDAR 캘린더"처럼 읽지 않게 뺀다.
        ExcludeSemantics(child: Text(eyebrow, style: AppTextStyles.eyebrow)),
        const SizedBox(height: 2),
        Text(title, style: AppTextStyles.heading),
      ],
    );
  }
}
