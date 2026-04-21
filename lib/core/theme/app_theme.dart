import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          secondary: AppColors.goldGlow,
          surface: AppColors.navyMid,
          error: AppColors.inkRed,
          onPrimary: AppColors.navy,
          onSecondary: AppColors.navy,
          onSurface: AppColors.ink,
          onError: AppColors.navy,
        ),
        scaffoldBackgroundColor: AppColors.navy,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.ink,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        cardTheme: CardThemeData(
          color: AppColors.glass,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius14),
            side: const BorderSide(color: AppColors.line, width: 0.5),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.line,
          thickness: 0.5,
          space: 0,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.navyMid,
          modalBackgroundColor: AppColors.navyMid,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSizes.radius28),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.navySoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            borderSide: const BorderSide(color: AppColors.line, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            borderSide: const BorderSide(color: AppColors.line, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            borderSide: const BorderSide(color: AppColors.gold, width: 1),
          ),
          labelStyle: const TextStyle(color: AppColors.sub, fontFamily: 'Pretendard'),
          hintStyle: const TextStyle(color: AppColors.faint, fontFamily: 'Pretendard'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
            vertical: AppSizes.spacing12,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.navy,
            minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: const BorderSide(color: AppColors.gold),
            minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? AppColors.navy : AppColors.sub),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? AppColors.gold : AppColors.navySoft),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.line, width: 0.5),
          labelStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.sub,
          ),
          shape: const StadiumBorder(),
        ),
        fontFamily: 'Pretendard',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Pretendard', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
          bodyMedium: TextStyle(fontFamily: 'Pretendard', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink),
          bodySmall: TextStyle(fontFamily: 'Pretendard', fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.sub),
          titleLarge: TextStyle(fontFamily: 'Pretendard', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppColors.ink),
          titleMedium: TextStyle(fontFamily: 'Pretendard', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
          titleSmall: TextStyle(fontFamily: 'Pretendard', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
          labelLarge: TextStyle(fontFamily: 'Pretendard', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
          labelMedium: TextStyle(fontFamily: 'Pretendard', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.sub),
          labelSmall: TextStyle(fontFamily: 'Pretendard', fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 2.5, color: AppColors.sub),
        ),
      );

  // 하위 호환 alias
  static ThemeData get light => dark;
}
