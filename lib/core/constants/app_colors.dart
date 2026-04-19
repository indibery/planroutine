import 'package:flutter/material.dart';

/// 앱 전체 색상 팔레트
class AppColors {
  AppColors._();

  // 프라이머리 — 차분한 블루 (교사용 앱 톤)
  static const primary = Color(0xFF4A6FA5);
  static const primaryLight = Color(0xFF7B9DD4);
  static const primaryDark = Color(0xFF1B4478);

  // 세컨더리 — 따뜻한 오렌지 (액센트)
  static const secondary = Color(0xFFF5A623);
  static const secondaryLight = Color(0xFFFFCB6B);
  static const secondaryDark = Color(0xFFC67C00);

  // 배경
  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF0F2F5);

  // 텍스트
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFF9CA3AF);

  // 상태
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // 일정 상태별 색상
  static const statusPending = Color(0xFFFBBF24);
  static const statusConfirmed = Color(0xFF34D399);

  // 카테고리별 색상
  static const categoryDailyOps = Color(0xFF6366F1);
  static const categoryCurriculum = Color(0xFF8B5CF6);
  static const categoryOrganization = Color(0xFFEC4899);
  static const categoryStudentRecord = Color(0xFF14B8A6);
  static const categoryDefault = Color(0xFF6B7280);

  // 캘린더
  static const calendarToday = Color(0xFF4A6FA5);
  static const calendarSelected = Color(0xFFE3EDFA);
  static const calendarWeekend = Color(0xFFEF4444);
  static const calendarSaturday = Color(0xFF3B82F6);

  // 이벤트 프리셋 색상
  static const eventPresets = [
    Color(0xFF4A6FA5), // 블루
    Color(0xFFEF4444), // 레드
    Color(0xFF10B981), // 그린
    Color(0xFFF59E0B), // 옐로
    Color(0xFF8B5CF6), // 퍼플
    Color(0xFFEC4899), // 핑크
    Color(0xFF14B8A6), // 틸
    Color(0xFFF97316), // 오렌지
  ];

  // 구분선
  static const divider = Color(0xFFE5E7EB);
  static const border = Color(0xFFD1D5DB);
}
