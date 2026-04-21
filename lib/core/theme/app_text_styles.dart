import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle titleL = const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    color: AppColors.ink,
  );
  static TextStyle titleM = const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );
  static TextStyle heading = const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static TextStyle bodyL = const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static TextStyle bodyM = const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static TextStyle bodyS = const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );
  static TextStyle label = const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.sub,
  );
  static TextStyle caption = const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.5,
    color: AppColors.sub,
  );

  static TextStyle numeric({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.ink,
    double letterSpacing = -1.0,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
}
