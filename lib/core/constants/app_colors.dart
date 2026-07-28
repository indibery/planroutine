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
    required this.calendarWeekendTint,
    required this.calendarSaturdayTint,
    required this.categoryDailyOps,
    required this.categoryCurriculum,
    required this.busSignalNear,
    required this.busSignalSoon,
    required this.busSignalFar,
    required this.busSignalOff,
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
  /// 토요일 날짜·요일 글자 — **중립 파랑**. 골드는 오늘/선택/중요 강조 전용이라
  /// 토요일까지 골드로 쓰면 골드가 네 가지 의미를 동시에 져서 강조가 무너진다.
  final Color calendarSaturday;

  /// 주말 열 배경 tint — 일요일(붉은 기) / 토요일(파란 기).
  /// 요일 헤더부터 마지막 주까지 세로로 이어져 요일이 '열'로 읽히게 한다.
  final Color calendarWeekendTint;
  final Color calendarSaturdayTint;
  final Color categoryDailyOps;
  final Color categoryCurriculum;

  /// 버스 도착 신호색 — `시간 축` 카드 모양에서만 쓰인다.
  ///
  /// 기본 모양(`간단히`)은 이 토큰을 하나도 참조하지 않는다. 이름에 `bus`를 박은
  /// 이유가 있다 — 이 색들은 축 위 위치가 문맥을 줄 때만 유효하고, 다른 곳에서
  /// 강조색으로 갖다 쓰면 골드·붉은색·파랑이 이미 포화된 팔레트가 무너진다.
  final Color busSignalNear;
  final Color busSignalSoon;
  final Color busSignalFar;

  /// 시간 축의 레일 색.
  final Color busSignalOff;
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
  calendarSaturday: Color(0xFF8BA8D4), // 중립 파랑 (골드 강조와 분리)
  calendarWeekendTint: Color(0x1FE08978), // 일요일 열 — 붉은 기 12%
  calendarSaturdayTint: Color(0x1F8BA8D4), // 토요일 열 — 파란 기 12%
  categoryDailyOps: Color(0xFF8BA8D4),
  categoryCurriculum: Color(0xFFB89AE0),
  busSignalNear: Color(0xFFEF5F52),
  busSignalSoon: Color(0xFFF2B23C),
  busSignalFar: Color(0xFF5FC98A),
  busSignalOff: Color(0x33F0EAD9),
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
  calendarSaturday: Color(0xFF3F5F94), // 중립 파랑 (골드 강조와 분리)
  calendarWeekendTint: Color(0x12C0392B), // 일요일 열 — 붉은 기 7%
  calendarSaturdayTint: Color(0x143F5F94), // 토요일 열 — 파란 기 8%
  categoryDailyOps: Color(0xFF3F5F94),
  categoryCurriculum: Color(0xFF6B4E9E),
  // 라이트 노랑은 흰 배경 대비가 없어 딥 앰버로 잡는다. 라이트 gold(#9A7415)와
  // 색상이 인접하지만 축 위 위치가 문맥을 주므로 수용한다(실기기 확인 완료).
  busSignalNear: Color(0xFFCF3A2A),
  busSignalSoon: Color(0xFFC98A0E),
  busSignalFar: Color(0xFF1E9E63),
  busSignalOff: Color(0xFFD4DBE6),
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
  static Color get busSignalNear => _current.busSignalNear;
  static Color get busSignalSoon => _current.busSignalSoon;
  static Color get busSignalFar => _current.busSignalFar;
  static Color get busSignalOff => _current.busSignalOff;
  static Color get categoryOrganization => _current.inkRed;
  static Color get categoryStudentRecord => _current.inkGreen;
  static Color get categoryDefault => _current.sub;

  static Color get calendarToday => _current.calendarToday;
  static Color get calendarSelected => _current.calendarSelected;
  static Color get calendarWeekend => _current.inkRed;
  static Color get calendarSaturday => _current.calendarSaturday;

  /// 주말 열 배경 tint (일요일 / 토요일).
  static Color get calendarWeekendTint => _current.calendarWeekendTint;
  static Color get calendarSaturdayTint => _current.calendarSaturdayTint;

  /// 이벤트 점·막대 공통 액센트색.
  static Color get eventAccent => _current.eventAccent;

  static Color get divider => _current.line;
  static Color get border => _current.lineStrong;
}
