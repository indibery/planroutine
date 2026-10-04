import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';

/// 바텀 시트 제목 — 시트 폭 가운데에 `heading` 글자로 선다.
///
/// 시트마다 정렬(왼쪽·가운데)과 글자(16·18·heading)가 달랐다. 일정 편집 시트처럼 가운데로
/// 모은다(2026-10-04 디자인 점검, 사용자 결정 A). 왼쪽 정렬 칸 안에 넣어도 가운데에 오도록
/// 폭을 스스로 채운다.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.heading,
      ),
    );
  }
}
