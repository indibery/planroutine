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

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/shared/widgets/brand_logo.dart';

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
}
