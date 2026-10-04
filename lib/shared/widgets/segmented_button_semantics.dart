import 'package:flutter/material.dart';

/// `SegmentedButton`의 시맨틱스를 세그먼트마다 **잎 노드 하나**로 다시 그린다.
///
/// Flutter 트리에는 세그먼트 이름이 있다(`MergeSemantics`로 합친 노드에 label·버튼·선택).
/// 그런데 mobile MCP(XCUITest)는 그 노드를 이름 없는 `Button selected`로 읽었다. 이름을
/// `Semantics`·`Text(semanticsLabel:)`로 바꿔 줘도 같았고, 같은 플래그를 단 직접 만든
/// 잎 노드만 이름이 보였다(2026-10-04 실측). `snapshot_ui`는 원래도 읽었다.
///
/// 겉모양과 손가락 터치는 [child]가 그대로 맡는다. 원래 시맨틱스는 숨기고, 그 위에
/// 같은 비율로 나눈 잎 노드를 겹친다 — `SegmentedButton`은 세그먼트 폭을 똑같이 나누므로
/// 자리가 맞는다. 겹친 노드는 그리지도 터치를 받지도 않는다.
///
/// 세그먼트 이름은 `ButtonSegment.label`의 `Text`에서 읽는다(사용처 전부가 `Text`다).
/// 가드: `segmented_button_semantics_test.dart`가 lib의 모든 `SegmentedButton`이 이 래퍼로
/// 감싸였는지 본다.
class SegmentedButtonSemantics<T> extends StatelessWidget {
  const SegmentedButtonSemantics({super.key, required this.child});

  final SegmentedButton<T> child;

  @override
  Widget build(BuildContext context) {
    // 사용처 전부가 하나만 고르는 선택기다. 다중 선택은 탭 동작이 "토글"이어야 해서
    // 아래 `onTap`이 맞지 않는다 — 필요해지면 그때 나눈다.
    assert(!child.multiSelectionEnabled, '단일 선택 SegmentedButton만 지원한다');
    return Stack(
      // 부모 제약을 그대로 넘긴다. 기본값(loose)은 꽉 찬 폭을 풀어 SegmentedButton을 글자 크기만큼
      // 쪼그라뜨리고, 폭 전체로 나뉜 노드가 실제 세그먼트와 어긋났다(verifier 2026-10-04).
      fit: StackFit.passthrough,
      children: [
        ExcludeSemantics(child: child),
        Positioned.fill(
          child: Row(
            children: [for (final segment in child.segments) _node(segment)],
          ),
        ),
      ],
    );
  }

  /// 세그먼트 하나의 잎 노드 — 그리지도 터치를 받지도 않는다.
  Widget _node(ButtonSegment<T> segment) {
    final onChanged = child.onSelectionChanged;
    final onTap = segment.enabled && onChanged != null
        ? () => onChanged({segment.value})
        : null;
    return Expanded(
      child: Semantics(
        button: true,
        selected: child.selected.contains(segment.value),
        inMutuallyExclusiveGroup: true,
        enabled: onTap != null,
        label: _labelOf(segment),
        onTap: onTap,
        excludeSemantics: true,
        child: const SizedBox.expand(),
      ),
    );
  }

  static String _labelOf<T>(ButtonSegment<T> segment) {
    final label = segment.label;
    final data = label is Text ? label.data : null;
    assert(
      data != null,
      'SegmentedButtonSemantics는 ButtonSegment.label이 Text일 때만 이름을 읽는다',
    );
    return data ?? '';
  }
}
