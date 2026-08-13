// ignore_for_file: avoid_print
//
// 앱 아이콘 생성 스크립트.
//
// `flutter test`의 자동 스캔(`*_test.dart`)을 피하기 위해 파일명에 `_test`를
// 붙이지 않았다. 명시적으로 실행한다:
//
//   flutter test test/tools/gen_app_icon.dart
//
// BrandLogo(LogoHybrid)를 navy 배경 위에 90% 크기로 중앙 배치한 1024×1024
// PNG를 assets/icon/app_icon.png 에 덮어쓴다. 이후
// `dart run flutter_launcher_icons`로 각 사이즈를 재생성한다.
//
// Android adaptive icon용으로 전경/배경을 분리한 두 장도 함께 뽑는다
// (app_icon_foreground.png · app_icon_background.png). adaptive icon은
// 원형 마스크의 안전 영역이 66%뿐이라 iOS의 90% 배치를 그대로 쓰면
// 테두리가 잘린다 — 전경 markScale과 pubspec의 inset:0에 대한 근거는
// 'generate adaptive foreground PNG' 테스트 주석 참고.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/shared/widgets/brand_logo.dart';

/// 1024×1024 캔버스에 그려 PNG로 쓴다. [drawBackground]가 false면 알파가 남는다.
Future<void> _writeIcon(
  String path, {
  required bool drawBackground,
  required double markScale,
}) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  if (drawBackground) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = AppColors.navy,
    );
  }
  if (markScale > 0) {
    final markSize = size * markScale;
    final offset = (size - markSize) / 2;
    canvas.save();
    canvas.translate(offset, offset);
    const LogoHybridPainter().paint(canvas, Size(markSize, markSize));
    canvas.restore();
  }

  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(byteData, isNotNull);
  final bytes = byteData!.buffer.asUint8List();
  File(path).writeAsBytesSync(bytes);
  print('Wrote ${bytes.length} bytes → $path');
}

void main() {
  test('generate 1024x1024 app icon PNG', () async {
    const size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // 전체 navy 배경 — iOS는 바깥에 squircle 마스크를 자동으로 씌운다.
    // alpha 채널을 남기지 않도록 완전 불투명으로 덮어둔다.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = AppColors.navy,
    );

    // LogoHybrid Mark — 중앙 90% 크기. 기기 홈화면에서 squircle 외곽과의
    // 간격을 확보해 아이콘이 답답해 보이지 않게 한다.
    const markScale = 0.9;
    const markSize = size * markScale;
    const offset = (size - markSize) / 2;
    canvas.save();
    canvas.translate(offset, offset);
    const LogoHybridPainter().paint(canvas, const Size(markSize, markSize));
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(byteData, isNotNull);

    final bytes = byteData!.buffer.asUint8List();
    final file = File('assets/icon/app_icon.png');
    file.writeAsBytesSync(bytes);
    print('Wrote ${bytes.length} bytes → ${file.absolute.path}');
  });

  test('generate adaptive foreground PNG', () async {
    // 배경 없이(투명) 로고 85%.
    //
    // `LogoHybridPainter`는 [markSize] 정사각형 안에 로고를 꽉 채우지 않고
    // 자체 여백을 둔다(실측: 캔버스의 65.2%만 실제로 칠해진다) — 그래서 여기 쓰는
    // markScale은 "최종 로고 크기"가 아니라 그 안쪽의 스케일이다.
    //
    // adaptive icon 전경의 안전 영역은 원형 마스크 기준 66%(108dp 중 72dp)뿐이라
    // iOS의 90% 배치를 그대로 쓰면 잘린다 — 그래서 이 값이 **`pubspec.yaml`의
    // `adaptive_icon_foreground_inset: 0`과 짝**이다. `flutter_launcher_icons`가
    // 기본으로 16% inset을 추가로 넣는데, 안전 영역 맞춤을 markScale이 이미 전담하는
    // 상태에서 inset까지 겹치면 이중으로 줄어든다(실측: markScale 0.6 + inset 16% →
    // 최종 로고가 안전 영역의 44%만 채움 — 2026-08 신고).
    //
    // 0.85를 고른 근거(위 실측값으로 역산, inset은 0 고정):
    //   markScale 0.60 → 최종 26.6% (안전 영역의 44%, 지금까지의 버그)
    //   markScale 0.80 → 최종 52.1% (안전 영역의 85%)
    //   markScale 0.85 → 최종 55.4% (안전 영역의 91%) ← 채택
    //   markScale 0.90 → 최종 58.7% (안전 영역의 96%, 마스크 가장자리에 닿기 시작)
    //   markScale 0.95 → 최종 61.9% (안전 영역을 101% 넘겨 스퀴클·티어드롭에서 잘림)
    // 91%는 로고가 충분히 크면서도 런처별로 다른 마스크(원·스퀴클·티어드롭)에서
    // 공통으로 안전할 여유를 남긴다. iOS의 0.9와 값을 맞추고 싶어질 수 있는데,
    // iOS는 90% 배치를 자체 squircle 마스크(안전 영역 100%에 가까움) 기준으로
    // 잡은 값이라 여기 그대로 옮기면 다시 잘린다.
    await _writeIcon(
      'assets/icon/app_icon_foreground.png',
      drawBackground: false,
      markScale: 0.85,
    );
  });

  test('generate adaptive background PNG', () async {
    // navy 단색 한 장. 색의 출처를 AppColors 하나로 남기기 위한 것이다 —
    // pubspec에 hex를 박으면 팔레트를 손볼 때 아이콘 배경만 옛 색으로 남는다.
    await _writeIcon(
      'assets/icon/app_icon_background.png',
      drawBackground: true,
      markScale: 0,
    );
  });
}
