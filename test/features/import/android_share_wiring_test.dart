import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android CSV 공유·열기 배선 가드.
///
/// 알림 M2-①(`android_wiring_test.dart`)과 같은 처지다 — `MainActivity`는 네이티브라
/// 단위 테스트로 못 밟으므로 **값과 소스를 검사**하고, 실제 동작은 에뮬레이터에서 본다.
///
/// **왜 필요한가**: Android는 `content://…/document/12`처럼 **확장자가 없는 URI**를 준다.
/// 그런데 Dart의 `_handleSharedFile`은 `.csv`로 끝나지 않는 경로를 **조용히 버린다** —
/// 공유 목록에는 뜨는데 탭하면 아무 일도 일어나지 않는, 알림 M1과 같은 증상 0의 실패가
/// 된다. 그래서 캐시로 복사할 때 확장자를 강제하는지까지 본다.
String _manifest() =>
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

String _mainActivity() => File(
  'android/app/src/main/kotlin/com/planroutine/app/MainActivity.kt',
).readAsStringSync();

String _appDart() => File('lib/app.dart').readAsStringSync();

/// `<intent-filter>` 블록 중 [action]을 담은 것만 돌려준다.
///
/// 필터별로 갈라 봐야 한다 — 매니페스트 전체에서 문자열을 찾으면 "VIEW는 넓게,
/// SEND는 좁게"라는 **필터마다 다른 규칙**을 검사할 수 없다.
List<String> _filtersWith(String action) =>
    RegExp(r'<intent-filter>(.*?)</intent-filter>', dotAll: true)
        .allMatches(_manifest())
        .map((m) => m.group(1)!)
        .where((f) => f.contains(action))
        .toList();

void main() {
  group('Android CSV 공유·열기 배선', () {
    test('열기(ACTION_VIEW) 필터가 넓다 — 확장자 없는 URI도 받는다', () {
      final views = _filtersWith('android.intent.action.VIEW');
      expect(views, isNotEmpty, reason: 'ACTION_VIEW 필터가 없다 — 파일 열기가 안 된다');

      final view = views.first;
      for (final mime in [
        'text/csv',
        'text/comma-separated-values',
        'application/csv',
        'text/plain',
        '*/*',
      ]) {
        expect(view, contains(mime), reason: '열기 필터에 $mime 이 없다');
      }
      // VIEW는 DEFAULT 카테고리가 없으면 열기 대상으로 뜨지 않는다.
      expect(view, contains('android.intent.category.DEFAULT'));
    });

    test('공유(ACTION_SEND) 필터는 좁다 — 공유 목록을 깨끗하게 유지한다', () {
      final sends = _filtersWith('android.intent.action.SEND');
      expect(sends, isNotEmpty, reason: 'ACTION_SEND 필터가 없다 — 공유 목록에 안 뜬다');

      final send = sends.first;
      expect(send, contains('text/csv'));
      expect(send, contains('android.intent.category.DEFAULT'));

      // 여기 `*/*`나 `text/plain`을 넣으면 메모·사진 공유에도 공직플랜이 뜬다.
      // CSV가 아니면 Dart가 조용히 버리므로 사용자에겐 "눌렀는데 아무 일도 없네"가 된다.
      expect(send, isNot(contains('*/*')), reason: '공유 필터가 넓어졌다');
      expect(send, isNot(contains('text/plain')), reason: '공유 필터가 넓어졌다');
    });

    test('채널 이름과 메서드가 Dart와 같다', () {
      // 양방향 — 한쪽만 고치면 채널이 조용히 안 붙는다.
      final kt = _mainActivity();
      final dart = _appDart();

      expect(dart, contains('planroutine/shared_file'));
      expect(kt, contains('planroutine/shared_file'));
      for (final method in ['getPending', 'onFileShared']) {
        expect(dart, contains(method), reason: 'Dart에 $method 이 없다');
        expect(kt, contains(method), reason: 'Kotlin에 $method 이 없다');
      }
    });

    test('확장자를 강제한다 — Dart가 .csv 아닌 경로를 버리기 때문이다', () {
      // 이 두 검사는 짝이다. Dart의 `.csv` 관문이 사라지면 Kotlin의 확장자 강제는
      // 이유를 잃고, Kotlin의 강제가 사라지면 Dart가 전부 버린다.
      expect(
        _appDart(),
        contains(".endsWith('.csv')"),
        reason: 'Dart의 .csv 관문이 없어졌다 — Kotlin의 확장자 강제 이유가 사라진다',
      );
      expect(
        _mainActivity(),
        contains('.csv'),
        reason: 'Kotlin이 캐시 파일에 .csv를 붙이지 않는다 — Dart가 조용히 버린다',
      );
    });

    test('파일 이름을 살린다 — 가져오기 화면에서 무슨 파일인지 보여야 한다', () {
      expect(
        _mainActivity(),
        contains('DISPLAY_NAME'),
        reason: 'ContentResolver로 이름을 읽지 않으면 캐시 파일명이 의미를 잃는다',
      );
    });

    test('running 상태의 두 번째 공유도 받는다', () {
      // `onNewIntent`가 없으면 앱이 이미 떠 있을 때 공유한 파일이 무시된다
      // (cold-start만 동작해 "한 번은 되고 두 번째는 안 되는" 증상이 된다).
      expect(_mainActivity(), contains('onNewIntent'));
      // ACTION_SEND는 data가 아니라 EXTRA_STREAM으로 온다.
      expect(_mainActivity(), contains('EXTRA_STREAM'));
    });

    test('cold-start 버퍼가 있다 — 엔진 준비 전에 도착한 경로를 잃지 않는다', () {
      // iOS `AppDelegate.pendingPath`와 같은 역할. 없으면 앱이 꺼진 상태에서 공유한
      // 파일이 사라진다 — 이때가 사용자가 가장 흔히 밟는 경로다.
      final kt = _mainActivity();
      expect(kt, contains('pendingPath'));
      expect(kt, contains('configureFlutterEngine'));
    });
  });
}
