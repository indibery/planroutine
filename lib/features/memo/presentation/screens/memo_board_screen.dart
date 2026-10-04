import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/memo.dart';
import '../providers/memo_providers.dart';
import '../widgets/memo_card.dart';
import '../widgets/memo_sheet.dart';
import '../../../../shared/widgets/button_semantics.dart';

/// 포스트잇 탭 — 보드형(쪽지 2열 격자). 짧게 누르면 시트, **꾹 누르면 끌어서 순서 바꾸기**.
///
/// 끌기는 Flutter 내장 `LongPressDraggable` + `DragTarget`으로 직접 만든다(새 패키지 없음).
/// 놓은 자리의 순서는 `MemosNotifier.move`가 저장한다 — 화면만 바꾸면 다시 켰을 때 돌아간다.
class MemoBoardScreen extends ConsumerStatefulWidget {
  const MemoBoardScreen({super.key});

  static const quickFieldKey = Key('memo_quick_field');
  static const quickAddKey = Key('memo_quick_add');

  @override
  ConsumerState<MemoBoardScreen> createState() => _MemoBoardScreenState();
}

class _MemoBoardScreenState extends ConsumerState<MemoBoardScreen> {
  final _quick = TextEditingController();

  @override
  void dispose() {
    _quick.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _quick.text;
    _quick.clear();
    await ref.read(memosProvider.notifier).add(text);
  }

  @override
  Widget build(BuildContext context) {
    final memos = ref.watch(memosProvider).valueOrNull ?? const <Memo>[];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(MemoStrings.eyebrow, style: AppTextStyles.eyebrow),
            const SizedBox(height: 2),
            Text(MemoStrings.title, style: AppTextStyles.heading),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacing16, AppSizes.spacing4, AppSizes.spacing16, AppSizes.spacing12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: MemoBoardScreen.quickFieldKey,
                    controller: _quick,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(hintText: MemoStrings.quickHint),
                  ),
                ),
                const SizedBox(width: AppSizes.spacing8),
                IconButton.filled(
                  key: MemoBoardScreen.quickAddKey,
                  onPressed: _add,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.goldFill,
                    foregroundColor: AppColors.onGold,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(
                    Icons.add,
                    semanticLabel: MemoStrings.quickAdd,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: memos.isEmpty
                ? _empty()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.spacing16, 0, AppSizes.spacing16, AppSizes.spacing24,
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
          ),
        ],
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
      builder: (context, candidates, _) => LongPressDraggable<int>(
        data: id,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: (MediaQuery.sizeOf(context).width - AppSizes.spacing16 * 2 - AppSizes.spacing12) / 2,
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
      ),
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(MemoStrings.empty, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.sub)),
        const SizedBox(height: AppSizes.spacing4),
        Text(MemoStrings.emptyHint, style: TextStyle(fontSize: 14, color: AppColors.faint)),
      ],
    ),
  );
}
