import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class AppTheme {
  AppTheme._();

  /// 현재 [AppColors] 팔레트 기준 ThemeData.
  /// app.dart가 `AppColors.applyBrightness(effective)` 직후 `of(effective)`를
  /// 호출하므로, 아래 AppColors getter들은 그 밝기의 팔레트 값을 반환한다.
  static ThemeData of(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.gold,
        secondary: AppColors.goldGlow,
        surface: AppColors.surface,
        error: AppColors.inkRed,
        onPrimary: AppColors.navy,
        onSecondary: AppColors.navy,
        onSurface: AppColors.ink,
        onError: isLight ? Colors.white : AppColors.navy,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: AppColors.glass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius14),
          side: BorderSide(color: AppColors.line, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.line,
        thickness: 0.5,
        space: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radius28),
          ),
        ),
      ),
      // ── Material이 그리는 선택 UI ────────────────────────────
      // **`primary`를 채움으로 쓰면 안 된다.** `colorScheme.primary`는
      // `AppColors.gold`인데, 라이트에서 그건 **배경 위 텍스트·아이콘용 딥골드**
      // (`#9A7415`)다. 그 위에 `onPrimary`(네이비)를 얹으면 **3.57:1**로 날짜가
      // 안 읽힌다(사용자 신고 2026-08-14, 라이트 전용).
      //
      // 다크에서 안 드러난 이유: 다크는 `gold`와 `goldFill`이 같은 값이라 우연히
      // 맞았다(9.77:1). 라이트에서만 둘이 갈린다.
      //
      // 이 앱의 규칙은 이미 `골드 채움 = goldFill + onGold`다. 우리가 직접 그리는
      // 곳은 그 규칙을 지키는데, Material이 그리는 컴포넌트만 `primary`를 거쳐
      // 우회하고 있었다 → 여기서 명시적으로 물린다(**8.37:1**).
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        // ⚠️ **오늘이면서 선택된 날**은 채움을 `dayBackgroundColor`로 받고 글씨는
        // 여기서 받는다. 이걸 `gold` 고정으로 두면 **골드 채움 위 골드 글씨**가 돼
        // 숫자가 통째로 사라진다(실제 렌더로 확인 — 가드만으로는 못 잡았다).
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onGold
              : AppColors.gold,
        ),
        // ⚠️ **오늘 칸의 채움은 `dayBackgroundColor`가 아니라 여기서 온다.**
        // 안 주면 `primary`(딥골드)로 떨어져, 위 `todayForegroundColor`를 고쳐도
        // 원이 어두운 채로 남는다(실제 렌더로 확인).
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.goldFill : null,
        ),
        todayBorder: BorderSide(color: AppColors.gold),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onGold
              : AppColors.ink,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.goldFill : null,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        hourMinuteColor: AppColors.surfaceVariant,
        hourMinuteTextColor: AppColors.ink,
        dialHandColor: AppColors.goldFill,
        // 다이얼 위 숫자는 손잡이(골드 채움)에 걸치는 순간 `onGold`여야 읽힌다.
        dialTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onGold
              : AppColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          borderSide: BorderSide(color: AppColors.line, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          borderSide: BorderSide(color: AppColors.line, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          borderSide: BorderSide(color: AppColors.gold, width: 1),
        ),
        labelStyle: TextStyle(color: AppColors.sub, fontFamily: 'Pretendard'),
        hintStyle: TextStyle(color: AppColors.faint, fontFamily: 'Pretendard'),
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
          side: BorderSide(color: AppColors.gold),
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
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.navy
              : AppColors.sub,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.surfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: BorderSide(color: AppColors.line, width: 0.5),
        labelStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.sub,
        ),
        shape: const StadiumBorder(),
      ),
      fontFamily: 'Pretendard',
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.sub,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.sub,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 2.5,
          color: AppColors.sub,
        ),
      ),
    );
  }

  static ThemeData get dark => of(Brightness.dark);
  static ThemeData get light => of(Brightness.light);
}
