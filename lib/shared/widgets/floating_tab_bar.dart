import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import 'button_semantics.dart';

/// 하단 고정 탭바.
///
/// 이름은 과거 플로팅 디자인의 잔재이나, 현재는 화면 폭을 꽉 채우는 불투명 바로
/// 동작한다. 뒤 콘텐츠가 비치지 않도록 navyMid 솔리드 배경 + 상단 구분선만 둔다.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  final int currentIndex;
  final List<FloatingTabItem> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // Theme.of를 참조해 테마(밝기) 변경 시 이 위젯이 확실히 리빌드되게 한다.
    // ShellRoute의 탭바는 라우트 전환에 유지돼, 이 의존이 없으면 AppColors 전역
    // 팔레트가 바뀌어도 리빌드되지 않아 이전(다크) 색이 남는다.
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: AppColors.line, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.tabBarHeight - 16,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final selected = i == currentIndex;
              return Expanded(
                // 이름 있는 버튼 + 선택 상태로 읽히게 한 노드로 묶는다. 없으면
                // 아이콘 글리프와 라벨이 따로 `Text`로 잡혀 VoiceOver·시뮬레이터
                // 자동화가 누를 대상도, 지금 탭도 알 수 없다.
                child: ButtonSemantics.gesture(
                  selected: selected,
                  label: tabs[i].label,
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? tabs[i].activeIcon : tabs[i].icon,
                        color: selected ? AppColors.gold : AppColors.faint,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tabs[i].label,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected ? AppColors.gold : AppColors.faint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class FloatingTabItem {
  const FloatingTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
