import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../providers/today_providers.dart';

/// 앱이 켜진 채 자정을 넘겼을 때 "오늘" 기준일을 갱신한다.
///
/// [todayReferenceProvider]는 부팅 시점의 `DateTime.now()`를 캐시한다. autoDispose가
/// 아니라 탭을 옮겨도 살아 있어서, 그대로 두면 자정을 넘긴 뒤에도 오늘 탭이 계속 어제를
/// 기준으로 조회한다(`todayViewProvider`가 재조회돼도 기준일이 어제라 결과가 어제다).
///
/// 앱이 다시 활성화되는 순간에만 날짜를 비교하고, **바뀌었을 때만** 무효화한다 —
/// 복귀마다 무효화하면 같은 날에도 DB 재조회가 매번 일어난다.
class MidnightWatcher extends ConsumerStatefulWidget {
  const MidnightWatcher({
    super.key,
    required this.child,
    this.clock = DateTime.now,
  });

  final Widget child;

  /// 현재 시각 공급자. 테스트에서 가짜 시계를 주입한다.
  final DateTime Function() clock;

  @override
  ConsumerState<MidnightWatcher> createState() => _MidnightWatcherState();
}

class _MidnightWatcherState extends ConsumerState<MidnightWatcher>
    with WidgetsBindingObserver {
  /// 마지막으로 확인한 날짜(`YYYY-MM-DD`). 시각이 아니라 날짜만 비교한다.
  ///
  /// **반드시 initState에서 즉시 채운다.** 필드 초기화식(`late x = ...`)으로 두면 첫
  /// 읽기 시점(= 복귀 콜백 안)까지 지연돼, 이미 자정을 넘긴 시각으로 초기화되면서
  /// "날짜가 안 바뀌었다"고 판단해 버린다.
  late String _lastSeenDate;

  @override
  void initState() {
    super.initState();
    _lastSeenDate = formatDate(widget.clock());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final today = formatDate(widget.clock());
    if (today == _lastSeenDate) return;

    _lastSeenDate = today;
    ref.invalidate(todayReferenceProvider);
  }

  /// **여기에 `ref.watch`를 넣지 말 것.** 이 위젯은 `MaterialApp` 위에 있어서
  /// 리빌드되면 앱 전체가 다시 그려진다. 갱신은 `ref.invalidate`로만 한다.
  @override
  Widget build(BuildContext context) => widget.child;
}
