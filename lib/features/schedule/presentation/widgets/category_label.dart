import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// 카테고리 원본 → 표시용 짧은 라벨.
///
/// 매칭 우선순위는 부분 일치 순서대로. 어떤 키워드에도 안 잡히면
/// 4글자 이내면 그대로, 5글자 이상이면 앞 4글자 + `…`.
/// 원본 값은 절대 가공해 저장하지 않음 — 표시 직전에만 호출.
String shortenCategory(String raw) {
  if (raw.isEmpty) return '';
  if (raw.contains('일과운영')) return '일과운영';
  if (raw.contains('교육과정')) return '교육과정';
  if (raw.contains('조직') || raw.contains('통계')) return '조직통계';
  if (raw.contains('학적')) return '학생학적';
  if (raw.contains('학교행사') || raw.contains('자율활동')) return '학교행사';
  if (raw.contains('포상') || raw.contains('수상')) return '포상수상';
  if (raw.contains('학교생활') || raw.contains('생활기록')) return '학교생활';
  if (raw.contains('학교운영') || raw.contains('운영계획')) return '학교운영';
  if (raw.contains('인사') || raw.contains('징계')) return '인사징계';
  if (raw.length <= 4) return raw;
  return '${raw.substring(0, 4)}…';
}

/// 카테고리 원본 → pill/뱃지 색상.
Color categoryColor(String raw) {
  if (raw.contains('일과운영')) return AppColors.categoryDailyOps;
  if (raw.contains('교육과정')) return AppColors.categoryCurriculum;
  if (raw.contains('조직') || raw.contains('통계')) {
    return AppColors.categoryOrganization;
  }
  if (raw.contains('학적')) return AppColors.categoryStudentRecord;
  return AppColors.categoryDefault;
}
