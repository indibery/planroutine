import 'dart:async';

import 'package:flutter/material.dart';

/// 키보드가 가리는 만큼 아래 여백을 주되, **포커스가 옮겨가는 찰나의 인셋 붕괴는
/// 따라가지 않는다.**
///
/// 왜 필요한가 — `Padding(bottom: MediaQuery.viewInsets.bottom)`을 그대로 쓰면
/// 입력칸 사이로 포커스를 옮길 때 시트가 키보드 높이만큼 떨어졌다 올라온다.
/// 포커스가 옮겨가는 순간 iOS가 키보드를 내렸다 다시 올리기 때문이다
/// (실측: 인셋 335 → 6 → 335, 시트 진폭 334.8 / iPhone 17 Pro 시뮬레이터).
/// 스크롤과는 무관하다 — 그때 `maxScrollExtent`는 0이었다.
///
/// 순수 Flutter 위젯만으로도 재현되고 **단선 → 단선 전환에서도 난다**(다행
/// 입력칸과 무관). 그래서 입력칸 설정이 아니라 여백 쪽에서 막는다.
/// 안드로이드에서는 이 붕괴가 관찰되지 않았다(인셋이 312로 일정) — iOS 증상이다.
///
/// 규칙:
///   - 인셋이 **늘어나면** 즉시 따라간다 (키보드가 올라온다 — 가려지면 안 된다).
///   - 인셋이 **줄어들 때** 포커스가 없으면 즉시 자리를 돌려준다.
///   - 포커스가 있는데 줄어들면 [_grace]만큼 기다린다. 그 안에 되돌아오면
///     포커스 전환이었고(무시), 계속 낮으면 진짜로 내려간 것이라 자리를 돌려준다.
///
/// 유예가 필요한 이유는 실측으로 나왔다 — 안드로이드에서 **뒤로 키를 누르면
/// 키보드만 내려가고 포커스는 남는다.** 포커스만 보고 붙들면 버튼 아래에 292pt
/// 빈 공간이 남는다(실측). 두 경우를 가르는 신호는 시간뿐이다: 전환 붕괴는
/// 100ms 안에 복구되고, 뒤로 키는 0에 머문다.
class KeyboardInset extends StatefulWidget {
  const KeyboardInset({super.key, required this.child});

  final Widget child;

  /// 전환 붕괴(실측 100ms 이내 복구)보다 넉넉하고, 진짜 내려갔을 때 빈 공간이
  /// 눈에 남지 않을 만큼 짧게.
  static const grace = Duration(milliseconds: 200);

  @override
  State<KeyboardInset> createState() => _KeyboardInsetState();
}

class _KeyboardInsetState extends State<KeyboardInset> {
  /// 자손이 포커스를 가지면 `hasFocus`가 true가 된다. 스스로는 포커스를 받지
  /// 않으므로 traversal에도 끼어들지 않는다.
  late final FocusNode _node = FocusNode(
    debugLabel: 'KeyboardInset',
    canRequestFocus: false,
    skipTraversal: true,
  )..addListener(_onFocusChanged);

  double _reserved = 0;
  Timer? _release;

  /// 포커스를 놓는 순간에도 다시 그려야 자리를 돌려준다 — 인셋 변화만으로는
  /// 이 시점에 rebuild가 보장되지 않는다.
  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _release?.cancel();
    _node
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    if (inset >= _reserved) {
      // 키보드가 올라온다(또는 그대로) — 즉시 따라가고 유예를 취소한다.
      _release?.cancel();
      _release = null;
      _reserved = inset;
    } else if (!_node.hasFocus) {
      _release?.cancel();
      _release = null;
      _reserved = inset;
    } else {
      // 포커스는 남아 있는데 인셋이 줄었다 — 전환 찰나인지 진짜 내림인지
      // 아직 모른다. 유예가 끝난 뒤에도 낮으면 그때 돌려준다.
      _release ??= Timer(KeyboardInset.grace, () {
        _release = null;
        if (!mounted) return;
        final now = MediaQuery.viewInsetsOf(context).bottom;
        if (now < _reserved) setState(() => _reserved = now);
      });
    }

    return Focus(
      focusNode: _node,
      child: Padding(
        padding: EdgeInsets.only(bottom: _reserved),
        child: widget.child,
      ),
    );
  }
}
