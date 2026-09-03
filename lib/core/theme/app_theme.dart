import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class AppTheme {
  AppTheme._();

  /// 시스템 바(상태바 · 내비게이션 바) 스타일 — **단일 출처**.
  ///
  /// `appBarTheme`(상태바 담당)과 `SystemOverlayRegion`(내비게이션 바 담당)이
  /// 같은 값을 봐야 한다. 프레임워크는 위/아래를 따로 샘플링해 위에서 상태바
  /// 속성을, 아래에서 내비게이션 바 속성을 가져간다(`view.dart:452`).
  ///
  /// **상태바 부분은 손대지 않는다** — Android 16 실측에서 양 테마 모두 정상이었다.
  /// 기존 상수를 base로 두고 내비게이션 바 세 필드만 덮는다.
  ///
  /// 그 셋이 왜 다 필요한지:
  /// - `systemNavigationBarIconBrightness` — `SystemUiOverlayStyle.dark`/`.light`는
  ///   **양쪽 다** 흰 아이콘을 담고 있다. API 34까지는 검정 바가 실제로 칠해져
  ///   맞았지만, API 35+는 `systemNavigationBarColor`를 무시하므로 흰 아이콘만
  ///   남는다 → 라이트 탭바(흰색) 위에서 **대비 1.00:1**(실측).
  /// - `systemNavigationBarContrastEnforced: false` — 3버튼 내비게이션에는 80%
  ///   스크림이 기본으로 깔린다. 켜두면 이 영역이 탭바 색이 아니게 되고
  ///   (실측 다크 `#D0D4DA`) 흰 아이콘이 1.49:1로 묻힌다.
  /// - `systemNavigationBarColor: transparent` — API 35+는 무시하지만 minSdk 24라
  ///   Android 7~14에서는 아직 칠해진다. 검정으로 두면 라이트의 어두운 아이콘이
  ///   검정 바 위에 놓여 **구버전이 대신 깨진다**.
  ///
  /// 셋을 함께 두면 내비게이션 바 영역 = 탭바 색(`AppColors.surface`)이 되어
  /// API 24~36이 한 규칙으로 통일된다. 가드는
  /// `test/core/theme/system_overlay_style_test.dart`.
  static SystemUiOverlayStyle systemOverlayStyle(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = isLight
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    return base.copyWith(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: isLight
          ? Brightness.dark
          : Brightness.light,
    );
  }

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
        // 스낵바 **액션 글자**가 이 색이다(M3 `_SnackbarDefaultsM3`). 주지 않으면
        // Flutter가 `onPrimary`로 폴백하는데, 라이트에서 그건 `navy`(#17253D)이고
        // 스낵바 배경(`inverseSurface` → `onSurface` → `ink`)도 **같은 #17253D**라
        // `실행취소`가 통째로 사라졌다(시뮬 실측 1.00:1, 2026-09-04). 다크는
        // `ink`가 크림이라 우연히 맞아 **라이트로만 보이는** 결함이었다.
        //
        // 스낵바 배경은 테마마다 반전되므로(라이트 네이비 / 다크 크림) 액션도
        // 방향이 갈린다 — 라이트는 밝은 골드(8.37:1), 다크는 폴백과 같은
        // 네이비(11.65:1)를 명시해 폴백 의존을 끊는다.
        inversePrimary: isLight ? AppColors.goldFill : AppColors.navy,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        systemOverlayStyle: systemOverlayStyle(brightness),
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
