import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// 텍스트 스타일 — 색은 AppColors getter를 참조하므로 각 스타일도 getter로 둔다.
/// (static final이면 클래스 로드 시 1회 평가돼 테마 전환이 반영되지 않는다)
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get titleL => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.6,
        color: AppColors.ink,
      );
  static TextStyle get titleM => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.ink,
      );
  static TextStyle get heading => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      );
  static TextStyle get bodyL => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );
  static TextStyle get bodyM => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );
  static TextStyle get bodyS => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      );
  static TextStyle get label => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.sub,
      );
  static TextStyle get caption => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.5,
        color: AppColors.sub,
      );

  static TextStyle numeric({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = -1.0,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.ink,
        letterSpacing: letterSpacing,
      );
}
