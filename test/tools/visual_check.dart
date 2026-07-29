// 눈으로 보면 "괜찮아 보인다"로 끝나는 것을 숫자로 확정하는 수동 검사 도구.
//
//   ① 대비(WCAG contrast ratio) + 색 거리 — 팔레트를 바꿨을 때 무엇이 안 읽히게 되는지
//   ② 폭별 오버플로 — 320pt(화면 확대를 켠 아이폰 · 배포 타깃 iOS 13이 포함하는 SE 1세대)
//      부터 430pt까지. 이 리포는 좁은 폭을 한 번도 검증한 적이 없다.
//
// **자동 스위트에 들어가지 않는다** — 파일명에 `_test`가 없어 `flutter test` 스캔에서 제외된다
// (`test/tools/gen_app_icon.dart`와 같은 관례). 색·레이아웃을 손댔을 때 사람이 직접 돌린다:
//
//     flutter test test/tools/visual_check.dart
//
// 실측으로 찾은 것(2026-07-29): `stale` 카드 제목줄이 320pt에서 21px 넘쳤다. 그 회귀는
// 이제 `test/features/bus/bus_arrival_card_test.dart`의 영구 가드가 잡는다 — 여기서 찾고
// 저기서 고정하는 것이 이 도구의 용도다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_arrival_card.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';
import 'package:planroutine/shared/widgets/confirm_dialog.dart';
import 'package:planroutine/shared/widgets/pill_chip.dart';

/// WCAG 2.1 상대 휘도.
double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// 대비비 1.0(같은 색) ~ 21.0(흑백).
double _contrast(Color fg, Color bg) {
  final a = _luminance(fg), b = _luminance(bg);
  final hi = math.max(a, b), lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// 두 색의 지각 거리 근사(sRGB 가중 유클리드). 나란히 놓고 구별되는지 볼 때 쓴다.
double _distance(Color x, Color y) {
  final dr = (x.r - y.r) * 255, dg = (x.g - y.g) * 255, db = (x.b - y.b) * 255;
  return math.sqrt(2 * dr * dr + 4 * dg * dg + 3 * db * db);
}

/// 카드가 실제로 놓이는 면 = glass를 화면 배경 위에 합성한 색.
Color _cardSurface() => Color.alphaBlend(AppColors.glass, AppColors.background);

BusArrival _a(String id, String no, int min) =>
    BusArrival(routeId: id, routeNo: no, arrMin: min);

BusCardView _view(BusCardState state, {int hidden = 0}) => BusCardView(
      state: state,
      visible: [_a('A', '82-1', 2), _a('B', '92', 8), _a('C', '720', 14)],
      hiddenCount: hidden,
      fetchedAt: DateTime(2026, 7, 29, 7, 32),
    );

void main() {
  group('① 대비·색 거리', () {
    for (final b in [Brightness.dark, Brightness.light]) {
      test('$b 대비', () {
        AppColors.applyBrightness(b);
        final surface = _cardSurface();
        final chipFill =
            Color.alphaBlend(AppColors.goldFill.withValues(alpha: 0.15), AppColors.background);

        final pairs = <String, double>{
          'N개 더·기준시각 (sub / 카드 면)': _contrast(AppColors.sub, surface),
          '본문 (ink / 카드 면)': _contrast(AppColors.ink, surface),
          '선택 칩 라벨 (ink / 칩 면)': _contrast(AppColors.ink, chipFill),
          '선택 칩 테두리 (gold / 배경)': _contrast(AppColors.gold, AppColors.background),
          'stale 기준시각 (inkRed / 카드 면)': _contrast(AppColors.inkRed, surface),
        };
        pairs.forEach((k, v) => debugPrint('  [$b] $k → ${v.toStringAsFixed(2)}:1'));

        // 작은 글씨가 3:1 미만이면 읽기 어렵다(AA 큰글씨 기준선).
        pairs.forEach((k, v) => expect(v, greaterThan(3.0), reason: '[$b] $k'));
      });
    }

    test('시간 축 세 점이 서로, 그리고 골드와 구별된다', () {
      for (final b in [Brightness.dark, Brightness.light]) {
        AppColors.applyBrightness(b);
        final near = AppColors.busSignalNear;
        final soon = AppColors.busSignalSoon;
        final far = AppColors.busSignalFar;
        debugPrint('  [$b] near-soon ${_distance(near, soon).toStringAsFixed(0)} / '
            'soon-far ${_distance(soon, far).toStringAsFixed(0)} / '
            'near-far ${_distance(near, far).toStringAsFixed(0)} / '
            'soon-gold ${_distance(soon, AppColors.gold).toStringAsFixed(0)}');
        expect(_distance(near, soon), greaterThan(60), reason: '$b 임박·곧');
        expect(_distance(soon, far), greaterThan(60), reason: '$b 곧·여유');
        expect(_distance(near, far), greaterThan(60), reason: '$b 임박·여유');
        // 스펙 §3이 우려한 지점 — 노랑이 골드와 같으면 골드의 의미가 하나 더 늘어난다.
        expect(_distance(soon, AppColors.gold), greaterThan(40), reason: '$b 곧·골드');
      }
    });
  });

  group('② 폭별 오버플로', () {
    // 320: 화면 확대 켠 390pt 기기 · SE 1세대 / 375: SE 2·3 / 390: 14·15 / 430: Pro Max
    const widths = [320.0, 375.0, 390.0, 430.0];

    Future<void> pumpAt(WidgetTester tester, double w, Widget child) async {
      tester.view.physicalSize = Size(w * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.applyBrightness(Brightness.dark);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.of(Brightness.dark),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ));
      await tester.pumpAndSettle();
    }

    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 카드 5상태 · 축 · 칩 20개', (tester) async {
        for (final st in [
          BusCardState.ok,
          BusCardState.stale,
          BusCardState.closed,
          BusCardState.down,
          BusCardState.noStop,
        ]) {
          await pumpAt(
            tester,
            w,
            BusArrivalCard(
              view: _view(st, hidden: 2),
              style: BusCardStyle.text,
              direction: CommuteDirection.toWork,
              stopName: st == BusCardState.noStop ? '' : '수원시청.수원일자리센터',
              expanded: true,
              onToggleExpanded: st == BusCardState.noStop ? null : () {},
              onFlipDirection: () {},
              onRetry: () {},
            ),
          );
          final e = tester.takeException();
          debugPrint('  ${w.toInt()}pt ${st.name.padRight(7)} → ${e ?? "OK"}');
          expect(e, isNull, reason: '${w.toInt()}pt ${st.name}');
        }

        await pumpAt(tester, w, BusBodyAxis(view: _view(BusCardState.ok, hidden: 2)));
        expect(tester.takeException(), isNull, reason: '${w.toInt()}pt 시간 축');
        debugPrint('  ${w.toInt()}pt 시간 축 높이 '
            '${tester.getSize(find.byType(BusBodyAxis)).height.toStringAsFixed(1)}pt');

        await pumpAt(
          tester,
          w,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < 20; i++)
                PillChip(label: i == 0 ? '수원시' : '도시$i', selected: i == 0),
            ],
          ),
        );
        expect(tester.takeException(), isNull, reason: '${w.toInt()}pt 도시 칩');
        debugPrint('  ${w.toInt()}pt 도시 칩 20개 높이 '
            '${tester.getSize(find.byType(Wrap)).height.toStringAsFixed(1)}pt');
      });
    }

    testWidgets('320pt — 초기화 확인 다이얼로그', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.applyBrightness(Brightness.dark);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.of(Brightness.dark),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ConfirmDialog.show(
              context: context,
              title: SettingsStrings.resetAllConfirmTitle,
              message: SettingsStrings.resetAllConfirmMessage,
              confirmLabel: SettingsStrings.resetAllConfirm,
            ),
            child: const Text('열기'),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      debugPrint('  초기화 문구: ${SettingsStrings.resetAllConfirmMessage}');
    });
  });
}
