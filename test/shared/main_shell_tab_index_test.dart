import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/shared/widgets/main_shell.dart';

/// 탭 순서 — `MainShell._tabs`와 같다.
const _today = 0;
const _calendar = 1;
const _schedule = 2;
const _settings = 3;

void main() {
  group('탭 하이라이트 — 탭 라우트', () {
    test('네 탭은 자기 자신을 켠다', () {
      expect(MainShell.indexForLocation(AppRoutes.today), _today);
      expect(MainShell.indexForLocation(AppRoutes.calendar), _calendar);
      expect(MainShell.indexForLocation(AppRoutes.schedule), _schedule);
      expect(MainShell.indexForLocation(AppRoutes.settings), _settings);
    });
  });

  group('탭 하이라이트 — push 라우트', () {
    // 이 넷이 전부 `오늘`을 켜던 것이 고친 버그다(실측 2026-07-30).
    test('휴지통은 설정을 켠다', () {
      expect(MainShell.indexForLocation(AppRoutes.trash), _settings);
    });

    test('가져오기는 입력을 켠다', () {
      expect(MainShell.indexForLocation(AppRoutes.import), _schedule);
    });

    test('버스 설정은 설정을 켠다', () {
      expect(MainShell.indexForLocation(AppRoutes.busSettings), _settings);
    });

    test('정류장 검색은 설정을 켠다', () {
      // 실제 진입은 `?slot=toWork`가 붙지만 `MainShell`은 `uri.path`만 본다 —
      // 쿼리는 경로에 포함되지 않으므로 판정에 영향이 없다.
      expect(MainShell.indexForLocation(AppRoutes.busStops), _settings);
    });

    test('접두가 겹치는 짝이 서로를 가리지 않는다', () {
      // `/bus/settings`와 `/bus/stops`는 `/bus/`를 공유한다. 짧은 쪽이 먼저
      // 걸리는 순회였다면 한쪽이 다른 쪽의 소속을 가져간다 — 지금은 둘 다
      // 설정이라 증상이 안 보이지만, 소속이 갈리는 순간 조용히 틀린다.
      expect(
        MainShell.indexForLocation(AppRoutes.busSettings),
        MainShell.indexForLocation(AppRoutes.busStops),
      );
    });
  });

  group('탭 하이라이트 — 모르는 곳', () {
    test('매핑에 없으면 오늘로 폴백한다', () {
      expect(MainShell.indexForLocation('/nope'), _today);
    });
  });
}
