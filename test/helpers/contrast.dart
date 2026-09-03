import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG 상대 휘도 대비. **대비를 재는 곳은 전부 이 함수를 쓴다.**
///
/// 한동안 이 계산이 세 벌 있었고(`picker_contrast_test` · `system_overlay_style_test`
/// · `faint_contrast_test`) **알파 처리가 서로 달랐다** — 두 벌은 `.r/.g/.b`만 읽어
/// 알파를 조용히 무시했다. 이 리포의 다크 팔레트는 `sub`(`0xB3F0EAD9`)·
/// `faint`(`0x99F0EAD9`)·`line`처럼 **알파 토큰이 많아**, 합성하지 않고 재면
/// 실제보다 좋은 값이 나온다. 즉 알파 토큰의 대비 결함을 잡으려고 만든 가드가
/// 정확히 그 토큰에서 눈을 감는다.
///
/// [fg]가 반투명이면 [bg] 위에 합성한 뒤 잰다 — `Color.computeLuminance()`는
/// 알파를 보지 않으므로 이 단계를 건너뛸 수 없다.
double contrastRatio(Color fg, Color bg) {
  final composited = Color.alphaBlend(fg, bg);
  final a = composited.computeLuminance();
  final b = bg.computeLuminance();
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}
