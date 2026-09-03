// `AppColors.faint`는 **본문 글씨로 읽혀야 한다** — 양 테마 AA(4.5:1).
//
// 하단 탭바의 미선택 라벨(`오늘`·`캘린더`·`입력`·`설정`, 10px w400)이 `faint`다.
// Android 16 실측(2026-09-03)에서 **양 테마 모두 미달**이었다:
//   라이트 `#7E8696` on 흰 탭바 → **3.66:1**
//   다크   35% 크림 on 네이비  → **2.76:1**  ← 더 나쁘다
//
// **이번엔 다크가 더 나쁘다.** 이 리포의 다른 대비 결함(날짜 선택·공휴일 행·종류
// 배지)은 전부 "라이트로 봐야 보인다"였는데 여기는 반대다 — 다크의 `faint`가
// **알파 크림**이라 진한 배경과 섞여 회색으로 주저앉는다. 알파 기반 토큰은
// 배경이 진할수록 대비를 잃으므로, **한 값으로 두 테마를 맞출 수 없다**
// (라이트는 색을 진하게, 다크는 알파를 올린다).
//
// 10px 작은 글씨라 큰 글씨 예외(3:1)가 적용되지 않는다.
//
// ⚠️ 최악 배경은 `surface`(흰 카드)가 아니라 **`surfaceVariant`** 다.
// `app_theme.dart`가 입력칸을 `fillColor: surfaceVariant`로 칠하면서
// `hintStyle`에 `faint`를 주므로(:155, :169) 그 조합이 실재한다. 셋 다 검사한다.


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';

import '../../helpers/contrast.dart';

/// `faint`가 실제로 글씨로 놓이는 배경들.
Map<String, Color> _backgrounds() => {
  'surface(흰 카드/탭바)': AppColors.surface,
  'background(스캐폴드)': AppColors.background,
  'surfaceVariant(입력칸 채움)': AppColors.surfaceVariant,
};

void main() {
  group('AppColors.faint 대비', () {
    for (final brightness in Brightness.values) {
      final themeName = brightness == Brightness.light ? '라이트' : '다크';

      test('$themeName — 모든 배경에서 AA(4.5:1)', () {
        AppColors.applyBrightness(brightness);
        _backgrounds().forEach((name, bg) {
          final ratio = contrastRatio(AppColors.faint, bg);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$themeName · $name 위에서 faint가 ${ratio.toStringAsFixed(2)}:1 이다. '
                '탭바 미선택 라벨이 이 색이고 10px라 큰 글씨 예외가 없다',
          );
        });
      });

      test('$themeName — 위계는 faint < sub < ink, 그리고 눈에 띄게 벌어져 있다', () {
        // 순서만 잡으면 부족하다. `faint`는 **감쇠 신호**를 스무 곳쯤에서 진다 —
        // `isDone ? faint : ink`(완료 도장 흐리게) · `selected ? gold : faint`
        // (탭바 미선택) · `active ? gold : faint`(가져오기 스테퍼). 다음 AA 상향이
        // 순서를 지키면서 `faint ≈ sub`까지 올라가면 "완료됨/비활성"이
        // "미완료/활성"과 구별되지 않는데, 순서 조건은 그때도 통과한다.
        // 그래서 **천장**을 함께 못박는다(현재 최악은 다크 navySoft 0.81).
        const maxRatioOfSub = 0.85;
        AppColors.applyBrightness(brightness);
        _backgrounds().forEach((name, bg) {
          final faint = contrastRatio(AppColors.faint, bg);
          final sub = contrastRatio(AppColors.sub, bg);
          final ink = contrastRatio(AppColors.ink, bg);
          expect(
            faint,
            lessThan(sub),
            reason:
                '$themeName · $name — faint ${faint.toStringAsFixed(2)}:1 이 '
                'sub ${sub.toStringAsFixed(2)}:1 보다 진하다. 위계가 뒤집혔다',
          );
          expect(
            faint / sub,
            lessThanOrEqualTo(maxRatioOfSub),
            reason:
                '$themeName · $name — faint가 sub의 '
                '${(faint / sub * 100).toStringAsFixed(0)}%까지 올라왔다. '
                '순서는 맞지만 감쇠 신호(완료 흐리게·미선택·비활성)가 구별되지 않는다',
          );
          expect(
            sub,
            lessThan(ink),
            reason: '$themeName · $name — sub가 ink보다 진하다',
          );
        });
      });
    }
  });
}
