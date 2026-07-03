import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppGradients {
  AppGradients._();

  /// 골드 CTA 채움. 라이트에선 밝은 브랜드골드 두 톤(위에 네이비 텍스트).
  static LinearGradient get gold => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.goldCtaStart, AppColors.goldCtaEnd],
      );

  static LinearGradient get navyCard => LinearGradient(
        begin: const Alignment(-0.77, -0.64),
        end: const Alignment(0.77, 0.64),
        colors: [AppColors.navyMid, AppColors.navySoft],
      );

  static LinearGradient get navySheet => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.navyMid, AppColors.background],
      );

  static LinearGradient get progress => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [AppColors.goldCtaStart, AppColors.goldCtaEnd],
      );
}
