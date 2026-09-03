import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

/// 화면 **맨 아래**에 시스템 바 스타일을 심는다 — 내비게이션 바 담당.
///
/// 프레임워크는 화면 위쪽과 아래쪽에서 `SystemUiOverlayStyle` 리전을 따로
/// 찾는다(`view.dart:429`). 이 앱에는 리전이 `AppBar`가 자동으로 만드는 것
/// 하나뿐이었고 그것은 **위쪽에만** 있어서, 아래쪽이 비어 있었다. 그러면
/// 프레임워크가 편의상 위쪽 것으로 내비게이션 바 속성까지 채우므로
/// (`view.dart:466`) **AppBar 하나가 내비게이션 바 색까지 정하고 있었다** —
/// 그것이 Android 15+ 내비게이션 버튼이 안 보이던 결함의 뿌리다.
///
/// 루트에 이 리전을 깔면 역할이 갈린다: 상태바는 각 화면의 `AppBar`,
/// 내비게이션 바는 여기. 덤으로 **`AppBar`가 없는 화면(온보딩)도 덮인다** —
/// 그 화면은 리전이 아예 없어 프레임워크가 이전 값을 그대로 유지했다
/// (`view.dart:443`의 조기 반환).
///
/// `app.dart`가 `MaterialApp`의 `builder`에서 감싼다. 그 자리여야 라우트와
/// 그 위에 뜨는 시트·다이얼로그까지 같은 Navigator 안에 들어온다.
class SystemOverlayRegion extends StatelessWidget {
  const SystemOverlayRegion({
    super.key,
    required this.brightness,
    required this.child,
  });

  /// 현재 effective 밝기 — `app.dart`가 테마 모드와 기기 밝기로 계산한 값.
  final Brightness brightness;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlayStyle(brightness),
      child: child,
    );
  }
}
