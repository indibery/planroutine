import 'package:flutter/material.dart';

/// 앱 전체 색상 팔레트 (다크 네이비 + 골드 디자인 시스템)
class AppColors {
  AppColors._();

  // ── 새 브랜드 토큰 ──────────────────────────────────────────────
  static const navy = Color(0xFF0A1628);
  static const navyMid = Color(0xFF142847);
  static const navySoft = Color(0xFF1E3558);
  static const gold = Color(0xFFE0B96A);
  static const goldGlow = Color(0xFFF5D98F);
  static const goldMuted = Color(0xFF8A7144);
  static const ink = Color(0xFFF0EAD9);
  static const sub = Color(0xB3F0EAD9);
  static const faint = Color(0x59F0EAD9);
  static const line = Color(0x2DE0B96A);
  static const lineStrong = Color(0x59E0B96A);
  static const glass = Color(0x0FFFFFFF);
  static const inkRed = Color(0xFFE08978);
  static const inkGreen = Color(0xFF7FD4A5);

  // ── 기존 이름 유지 (다크 팔레트로 리매핑) ──────────────────────
  static const primary = gold;
  static const primaryLight = goldGlow;
  static const primaryDark = goldMuted;

  static const secondary = gold;
  static const secondaryLight = goldGlow;
  static const secondaryDark = goldMuted;

  static const background = navy;
  static const surface = navyMid;
  static const surfaceVariant = navySoft;

  static const textPrimary = ink;
  static const textSecondary = sub;
  static const textHint = faint;

  static const success = inkGreen;
  static const warning = gold;
  static const error = inkRed;
  static const info = Color(0xFF5B8FD4);

  static const statusPending = goldMuted;
  static const statusConfirmed = inkGreen;

  static const categoryDailyOps = Color(0xFF8BA8D4);
  static const categoryCurriculum = Color(0xFFB89AE0);
  static const categoryOrganization = inkRed;
  static const categoryStudentRecord = inkGreen;
  static const categoryDefault = sub;

  static const calendarToday = gold;
  static const calendarSelected = Color(0x29E0B96A);
  static const calendarWeekend = inkRed;
  static const calendarSaturday = goldGlow;

  static const eventPresets = [
    gold,
    inkGreen,
    inkRed,
    goldGlow,
    Color(0xFF8BA8D4),
    Color(0xFFB89AE0),
    Color(0xFF7FC4D4),
    Color(0xFFD4A87F),
  ];

  static const divider = line;
  static const border = lineStrong;
}
