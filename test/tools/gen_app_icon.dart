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
// 테두리가 잘린다 — 전경은 60%로 더 작게 그린다.

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

  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
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
    // 배경 없이(투명) 로고 60%. adaptive 전경은 **안전 영역이 66%뿐**이라
    // iOS의 90% 배치를 그대로 쓰면 원형 마스크에서 테두리가 잘린다.
    await _writeIcon('assets/icon/app_icon_foreground.png',
        drawBackground: false, markScale: 0.6);
  });

  test('generate adaptive background PNG', () async {
    // navy 단색 한 장. 색의 출처를 AppColors 하나로 남기기 위한 것이다 —
    // pubspec에 hex를 박으면 팔레트를 손볼 때 아이콘 배경만 옛 색으로 남는다.
    await _writeIcon('assets/icon/app_icon_background.png',
        drawBackground: true, markScale: 0);
  });
}
