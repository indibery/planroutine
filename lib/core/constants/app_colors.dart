import 'package:flutter/material.dart';

/// 테마 팔레트 — 다크/라이트 각각의 원천 토큰 값.
///
/// 파생 색(primary=gold, background 등)은 [AppColors] getter에서 조합한다.
@immutable
class _Palette {
  const _Palette({
    required this.navy,
    required this.navyMid,
    required this.navySoft,
    required this.background,
    required this.gold,
    required this.goldGlow,
    required this.goldMuted,
    required this.goldCtaStart,
    required this.goldCtaEnd,
    required this.goldFill,
    required this.onGold,
    required this.ink,
    required this.sub,
    required this.faint,
    required this.line,
    required this.lineStrong,
    required this.glass,
    required this.inkRed,
    required this.inkGreen,
    required this.info,
    required this.eventAccent,
    required this.calendarToday,
    required this.calendarSelected,
    required this.calendarSaturday,
    required this.categoryDailyOps,
    required this.categoryCurriculum,
  });

  /// 브랜드 네이비 — 배경이 아니라 "골드/밝은 면 위의 전경 텍스트·아이콘" 의미.
  /// 다크·라이트 모두 어두운 네이비(골드 CTA·오늘 셀·배지 위 글씨).
  final Color navy;
  final Color navyMid; // surface
  final Color navySoft; // surfaceVariant
  final Color background; // scaffold/appBar 면
  final Color gold; // 액센트: 배경 위 아이콘/텍스트/보더/토요일 (라이트에선 딥골드)
  final Color goldGlow; // 밝은 골드
  final Color goldMuted;
  final Color goldCtaStart; // 골드 CTA 그라디언트 시작(밝은 채움)
  final Color goldCtaEnd;
  final Color goldFill; // 골드 채움 면(배지/pill/버튼/오늘 셀) — 밝은 골드
  final Color onGold; // goldFill 채움 위의 텍스트·아이콘 (네이비)
  final Color ink; // 본문 텍스트
  final Color sub;
  final Color faint;
  final Color line;
  final Color lineStrong;
  final Color glass;
  final Color inkRed;
  final Color inkGreen;
  final Color info;
  final Color eventAccent;
  final Color calendarToday;
  final Color calendarSelected;
  final Color calendarSaturday;
  final Color categoryDailyOps;
  final Color categoryCurriculum;
}

const _dark = _Palette(
  navy: Color(0xFF0A1628),
  navyMid: Color(0xFF142847),
  navySoft: Color(0xFF1E3558),
  background: Color(0xFF0A1628),
  gold: Color(0xFFE0B96A),
  goldGlow: Color(0xFFF5D98F),
  goldMuted: Color(0xFF8A7144),
  goldCtaStart: Color(0xFFE0B96A),
  goldCtaEnd: Color(0xFFF5D98F),
  goldFill: Color(0xFFE0B96A),
  onGold: Color(0xFF0A1628),
  ink: Color(0xFFF0EAD9),
  sub: Color(0xB3F0EAD9),
  faint: Color(0x59F0EAD9),
  line: Color(0x2DE0B96A),
  lineStrong: Color(0x59E0B96A),
  glass: Color(0x0FFFFFFF),
  inkRed: Color(0xFFE08978),
  inkGreen: Color(0xFF7FD4A5),
  info: Color(0xFF5B8FD4),
  eventAccent: Color(0xFF4A6FA5),
  calendarToday: Color(0xFFE0B96A),
  calendarSelected: Color(0x29E0B96A),
  calendarSaturday: Color(0xFFF5D98F),
  categoryDailyOps: Color(0xFF8BA8D4),
  categoryCurriculum: Color(0xFFB89AE0),
);

/// 라이트 팔레트 — 쿨 미스트 화이트(옅은 블루톤 화이트 + 네이비 잉크 + 골드 포인트).
/// 산뜻하고 밝은 사무 톤. 골드 채움(goldFill)은 밝게, 배경 위 골드 텍스트는 딥골드.
const _light = _Palette(
  navy: Color(0xFF17253D), // goldFill 채움 위 전경 네이비(= onGold)
  navyMid: Color(0xFFFFFFFF), // surface (흰 카드)
  navySoft: Color(0xFFEBEFF5), // surfaceVariant (옅은 블루그레이)
  background: Color(0xFFF6F8FB), // 쿨 미스트 배경
  gold: Color(0xFF9A7415), // 딥골드 — 배경 위 아이콘/텍스트/보더/토요일
  goldGlow: Color(0xFFE6B95C), // 밝은 골드
  goldMuted: Color(0xFFA8925C),
  goldCtaStart: Color(0xFFE6B95C), // CTA 밝은 골드 채움 + 네이비 텍스트
  goldCtaEnd: Color(0xFFF0CE7E),
  goldFill: Color(0xFFE6B95C), // 배지/pill/버튼/오늘 셀 채움
  onGold: Color(0xFF17253D), // 채움 위 네이비 텍스트 (goldFill 위 7:1+)
  ink: Color(0xFF17253D), // 네이비 잉크 본문
  sub: Color(0xFF48566E),
  faint: Color(0xFF7E8696),
  line: Color(0xFFE4E9F0), // 옅은 블루그레이 hairline
  lineStrong: Color(0xFFD4DBE6),
  glass: Color(0xFFFFFFFF), // 흰 카드 면 (배경보다 밝게 떠보임)
  inkRed: Color(0xFFC0392B),
  inkGreen: Color(0xFF1E9E63),
  info: Color(0xFF3E6BB0),
  eventAccent: Color(0xFF3E6BB0), // 이벤트 레일(밝은 블루)
  calendarToday: Color(0xFFE6B95C), // 밝은 골드 원 + 네이비 텍스트
  calendarSelected: Color(0x1FE6B95C),
  calendarSaturday: Color(0xFF9A7415), // 배경 위 딥골드
  categoryDailyOps: Color(0xFF3F5F94),
  categoryCurriculum: Color(0xFF6B4E9E),
);

/// 앱 전체 색상 팔레트 (다크 네이비+골드 / 라이트 크림+네이비 전환).
///
/// [applyBrightness]로 현재 팔레트를 교체한 뒤 앱을 rebuild하면 모든 getter가
/// 새 팔레트 값을 반환한다. (app.dart가 themeMode 변경 시 동기화)
class AppColors {
  AppColors._();

  static _Palette _current = _dark;

  /// 현재 팔레트를 밝기에 맞춰 교체. app.dart build에서 매 프레임 동기화.
  static void applyBrightness(Brightness brightness) {
    _current = brightness == Brightness.light ? _light : _dark;
  }

  // ── 브랜드 토큰 ──────────────────────────────────────────────
  static Color get navy => _current.navy;
  static Color get navyMid => _current.navyMid;
  static Color get navySoft => _current.navySoft;
  static Color get gold => _current.gold;
  static Color get goldGlow => _current.goldGlow;
  static Color get goldMuted => _current.goldMuted;
  static Color get goldCtaStart => _current.goldCtaStart;
  static Color get goldCtaEnd => _current.goldCtaEnd;

  /// 골드 채움 면(배지·pill·버튼·오늘 셀 배경). 위 텍스트는 [onGold].
  static Color get goldFill => _current.goldFill;

  /// [goldFill] 채움 위의 텍스트·아이콘 색(네이비).
  static Color get onGold => _current.onGold;

  static Color get ink => _current.ink;
  static Color get sub => _current.sub;
  static Color get faint => _current.faint;
  static Color get line => _current.line;
  static Color get lineStrong => _current.lineStrong;
  static Color get glass => _current.glass;
  static Color get inkRed => _current.inkRed;
  static Color get inkGreen => _current.inkGreen;

  // ── 파생 (기존 이름 유지) ──────────────────────────────────────
  static Color get primary => _current.gold;
  static Color get primaryLight => _current.goldGlow;
  static Color get primaryDark => _current.goldMuted;

  static Color get secondary => _current.gold;
  static Color get secondaryLight => _current.goldGlow;
  static Color get secondaryDark => _current.goldMuted;

  static Color get background => _current.background;
  static Color get surface => _current.navyMid;
  static Color get surfaceVariant => _current.navySoft;

  static Color get textPrimary => _current.ink;
  static Color get textSecondary => _current.sub;
  static Color get textHint => _current.faint;

  static Color get success => _current.inkGreen;
  static Color get warning => _current.gold;
  static Color get error => _current.inkRed;
  static Color get info => _current.info;

  static Color get statusPending => _current.goldMuted;
  static Color get statusConfirmed => _current.inkGreen;

  static Color get categoryDailyOps => _current.categoryDailyOps;
  static Color get categoryCurriculum => _current.categoryCurriculum;
  static Color get categoryOrganization => _current.inkRed;
  static Color get categoryStudentRecord => _current.inkGreen;
  static Color get categoryDefault => _current.sub;

  static Color get calendarToday => _current.calendarToday;
  static Color get calendarSelected => _current.calendarSelected;
  static Color get calendarWeekend => _current.inkRed;
  static Color get calendarSaturday => _current.calendarSaturday;

  /// 이벤트 점·막대 공통 액센트색.
  static Color get eventAccent => _current.eventAccent;

  static Color get divider => _current.line;
  static Color get border => _current.lineStrong;
}
