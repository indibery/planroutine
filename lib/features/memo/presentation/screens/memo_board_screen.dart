import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/memo.dart';
import '../../domain/memo_color.dart';
import '../providers/memo_providers.dart';
import '../widgets/memo_card.dart';
import '../widgets/memo_sheet.dart';
import '../../../../shared/widgets/button_semantics.dart';
import '../../../../shared/widgets/tab_header_title.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/gold_fab.dart';

/// 포스트잇 탭 — 보드형(쪽지 2열 격자). 짧게 누르면 시트, **꾹 누르면 끌어서 순서 바꾸기**.
///
/// 끌기는 Flutter 내장 `LongPressDraggable` + `DragTarget`으로 직접 만든다(새 패키지 없음).
/// 놓은 자리의 순서는 `MemosNotifier.move`가 저장한다 — 화면만 바꾸면 다시 켰을 때 돌아간다.
class MemoBoardScreen extends ConsumerStatefulWidget {
  const MemoBoardScreen({super.key});

  static const addKey = Key('memo_add');

  @override
  ConsumerState<MemoBoardScreen> createState() => _MemoBoardScreenState();
}

class _MemoBoardScreenState extends ConsumerState<MemoBoardScreen> {
  /// 오른쪽 아래 +(다른 탭과 같은 자리) — 빈 쪽지 시트를 연다. 보드 위의 줄글 입력칸은 없앴다
  /// (사용자 결정 2026-10-23: 줄글 칸은 포스트잇을 쓰는 느낌이 나지 않는다).
  /// 색은 맨 앞 쪽지와 다른 색 중 무작위([nextMemoColor]).
  void _add(List<Memo> memos) {
    final last = memos.isEmpty ? null : memos.first.color;
    final color = nextMemoColor(last, ref.read(memoColorRandomProvider));
    MemoSheet.show(context, Memo(text: '', color: color));
  }

  @override
  Widget build(BuildContext context) {
    final memos = ref.watch(memosProvider).valueOrNull ?? const <Memo>[];
    return Scaffold(
      appBar: AppBar(
        title: const TabHeaderTitle(
          eyebrow: MemoStrings.eyebrow,
          title: MemoStrings.title,
        ),
      ),
      body: memos.isEmpty
          ? _empty()
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacing16, AppSizes.spacing4, AppSizes.spacing16, AppSizes.spacing24 + AppSizes.fabSize,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSizes.spacing12,
                crossAxisSpacing: AppSizes.spacing12,
                mainAxisExtent: 168,
              ),
              itemCount: memos.length,
              itemBuilder: (context, i) => _slot(memos, i),
            ),
      floatingActionButton: GoldFab(
        key: MemoBoardScreen.addKey,
        onTap: () => _add(memos),
        semanticLabel: MemoStrings.addMemo,
      ),
    );
  }

  /// 자리 하나 = 받는 곳(DragTarget) + 끌리는 쪽지(LongPressDraggable).
  Widget _slot(List<Memo> memos, int index) {
    final memo = memos[index];
    final id = memo.id ?? -1;
    final card = MemoCard(key: MemoCard.cardKey(id), memo: memo);
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != id,
      onAcceptWithDetails: (d) =>
          ref.read(memosProvider.notifier).move(d.data, index),
      // 끌 때 뜨는 쪽지는 칸이 실제로 받은 크기를 그대로 쓴다 — 격자 설정을 여기서 다시 계산하지 않는다.
      builder: (context, candidates, _) => LayoutBuilder(builder: (context, cell) => LongPressDraggable<int>(
        data: id,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox.fromSize(
            size: cell.biggest,
            child: Transform.scale(scale: 1.05, child: MemoCard(memo: memo)),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        // 버튼으로 읽히게 한 노드로 묶는다 — 없으면 두 자동화 도구 모두 글자로만 잡았다.
        child: ButtonSemantics.gesture(label: memoCardSemanticsLabel(memo), onTap: () => MemoSheet.show(context, memo), child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: candidates.isEmpty ? Colors.transparent : AppColors.gold,
                width: 2,
              ),
            ),
            child: card,
          )),
      )),
    );
  }

  Widget _empty() => const EmptyState(
    icon: Icons.sticky_note_2_outlined,
    title: MemoStrings.empty,
    hint: MemoStrings.emptyHint,
  );
}
