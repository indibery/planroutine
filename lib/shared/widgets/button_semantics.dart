import 'package:flutter/material.dart';

/// 직접 만든 터치 영역을 **이름 있는 버튼 잎 노드 하나**로 읽히게 한다.
///
/// `GestureDetector`·`InkWell`만 두면 탭 동작은 있어도 버튼 표시가 없어, 시뮬레이터 자동화
/// 두 도구(`snapshot_ui`·mobile MCP)가 그 자리를 그냥 글자로 읽고 누를 대상으로 보지
/// 않았다. 안의 글자·아이콘이 따로 노드를 만들면 이름도 조각났다(2026-10-04 실측).
///
/// - [ButtonSemantics.gesture]: 탭 처리까지 맡는다 — 안에서 `GestureDetector`를 만든다.
///   잉크 효과가 없는 터치 영역은 이것을 쓴다(콜백을 한 번만 적는다).
/// - 기본 생성자: 잉크 효과가 필요한 `InkWell`·`InkResponse`를 [child]로 감싼다. 손가락 탭은
///   [child]가 받고 [onTap]은 시맨틱스 탭(스크린리더·자동화)용이라 둘에 같은 콜백을 넘긴다.
///
/// [child]의 시맨틱스는 숨기고 [label]로 대신한다 — 그래서 안에 **다른 버튼을 두면 안 된다**
/// (함께 숨는다). [onTap]이 null이면 비활성 버튼으로 읽힌다.
///
/// 가드: `test/shared/button_semantics_guard_test.dart`가 lib의 직접 만든 터치 영역이 이것으로
/// 감싸였는지 본다.
class ButtonSemantics extends StatelessWidget {
  const ButtonSemantics({
    super.key,
    required this.label,
    required this.onTap,
    this.selected,
    this.checked,
    this.toggled,
    required this.child,
  }) : _gesture = false,
       behavior = null;

  const ButtonSemantics.gesture({
    super.key,
    required this.label,
    required this.onTap,
    this.selected,
    this.checked,
    this.toggled,
    this.behavior,
    required this.child,
  }) : _gesture = true;

  final String label;
  final VoidCallback? onTap;

  /// 여러 개 중 하나를 고르는 것(탭·칩·날짜 칸)이면 선택 여부.
  final bool? selected;

  /// 체크하는 것(완료 체크)이면 켜짐 여부.
  final bool? checked;

  /// 스위치처럼 켜고 끄는 것(중요 표시)이면 켜짐 여부.
  final bool? toggled;

  /// [ButtonSemantics.gesture]의 `GestureDetector` 히트 판정. null이면 Flutter 기본값.
  final HitTestBehavior? behavior;

  final Widget child;
  final bool _gesture;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      checked: checked,
      toggled: toggled,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: _gesture
          // 시맨틱스 예외: 이 위젯 자신이 바로 위에서 버튼으로 감싼다.
          ? GestureDetector(behavior: behavior, onTap: onTap, child: child)
          : child,
    );
  }
}
