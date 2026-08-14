// 배지·날짜 선택 미리보기 — **실제 위젯으로** 렌더해 PNG로 뽑는다.
//
// 손으로 베낀 조립으로 색을 고르면 실제와 어긋난다. 그래서 여기서는 진짜
// `KindBadge`와 진짜 `DatePickerDialog`를 `AppTheme` 아래에서 그린다.
//
// 파일명에 `_test`가 없어 `flutter test` 자동 스캔에서 제외된다 — 명시 지정할 때만 돈다.
//   flutter test test/tools/kind_badge_preview.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/constants/app_sizes.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/presentation/widgets/kind_badge.dart';

/// **폰트를 직접 싣는다.** `flutter test`는 pubspec 폰트를 안 실어 한글이 두부(□)로
/// 찍힌다. ⚠️ 파일은 **동기로** 읽는다 — `readAsBytes()`는 fake-async 존에서 안 끝나
/// 테스트가 타임아웃까지 멈춘다.
Future<void> _loadFont() async {
  final bytes = File('assets/fonts/PretendardVariable.ttf').readAsBytesSync();
  await (FontLoader(
    'Pretendard',
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

Future<void> _capture(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// `작년` 배지 — 테두리형. 행 오른쪽 끝에 붙는다(`event_list_section.dart:268`).
Widget _importBadge() => Container(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSizes.spacing8,
    vertical: 3,
  ),
  decoration: BoxDecoration(
    border: Border.all(color: AppColors.sub.withValues(alpha: 0.5)),
    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
  ),
  child: Text(
    '작년',
    style: TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: AppColors.sub,
    ),
  ),
);

Widget _row(EntryKind kind, String title, {bool fromImport = false}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: Row(
        children: [
          KindBadge(kind: kind),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          if (fromImport) ...[const SizedBox(width: 8), _importBadge()],
        ],
      ),
    );

void main() {
  // ⚠️ **테마마다 따로 뽑는다.** `AppColors`는 전역 팔레트라 위젯이 **빌드 시점의**
  // 값을 읽는다. 한 트리에 두 테마를 넣으면 마지막에 적용한 팔레트가 둘 다 칠해,
  // 다크 패널에 라이트 배지가 그려진다(실제로 그렇게 나왔다).
  for (final brightness in Brightness.values) {
    final name = brightness == Brightness.light ? 'light' : 'dark';
    testWidgets('종류 배지 — $name을 실제 위젯으로', (tester) async {
      await _loadFont();
      tester.view.physicalSize = const Size(390 * 3, 250 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AppColors.applyBrightness(brightness);

      // `Material`이 없으면 Flutter가 모든 텍스트에 노란 이중 밑줄을 그린다.
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Material(
            color: AppColors.background,
            child: RepaintBoundary(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _row(EntryKind.task, '학생생활지도 계획 검토', fromImport: true),
                    _row(EntryKind.event, '경기도교육청 발대식', fromImport: true),
                    _row(EntryKind.event, '2학기 개학식'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'build/kind_badge_$name.png');
    });
  }

  testWidgets('날짜 선택 — Material이 실제로 그리는 것', (tester) async {
    await _loadFont();
    tester.view.physicalSize = const Size(390 * 3, 560 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 라이트에서만 깨졌다 — 다크는 `gold`와 `goldFill`이 같은 값이라 우연히 맞았다.
    AppColors.applyBrightness(Brightness.light);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(Brightness.light),
        home: RepaintBoundary(
          child: DatePickerDialog(
            initialDate: DateTime(2026, 8, 14),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'build/date_picker_preview.png');
  });
}
