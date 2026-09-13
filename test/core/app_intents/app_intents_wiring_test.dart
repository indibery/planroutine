// 단축어 배선 가드.
//
// Swift는 위젯 테스트로 밟을 수 없으므로 **소스를 읽어 검사한다**
// (`android_wiring_test.dart`와 같은 방법). 실제 동작 확인은
// 시뮬레이터·실기기의 몫이고, 여기가 잡는 것은 **조용히 무너지는 전제들**이다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/app_intents/app_intents_contract.dart';

String _swift() =>
    File('ios/Runner/AppIntents/PlanRoutineIntents.swift').readAsStringSync();

/// 주석을 걷어낸 Swift 코드.
///
/// ⚠️ **이 저장소에서 다섯 번째로 밟은 함정이다** — 스캐너는 낱말의 *언급*과
/// *사용*을 구별하지 못한다. `openAppWhenRun`을 쓰지 말라고 **설명하는 주석**이
/// 금지어 검사에 걸려 정상인 코드가 실패했다. 주석을 지우는 것이 아니라
/// 검사가 코드만 보게 한다 — 그 주석은 다음 사람이 읽어야 할 근거다.
String _swiftCodeOnly() => _swift()
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join('\n');

String _appDelegate() =>
    File('ios/Runner/AppDelegate.swift').readAsStringSync();

void main() {
  group('채널 계약이 Swift와 Dart에서 같다', () {
    test('채널 이름과 메서드·인자 이름이 양쪽에 그대로 있다', () {
      final src = _swift();
      final shared = <String, String>{
        '채널 이름': AppIntentsContract.channelName,
        '등록 메서드': AppIntentsContract.methodRegister,
        '조회 메서드': AppIntentsContract.methodQuery,
        '준비 신호': AppIntentsContract.methodReady,
        '텍스트 인자': AppIntentsContract.argText,
        '종류 인자': AppIntentsContract.argKind,
        '기간 인자': AppIntentsContract.argRange,
      };

      for (final entry in shared.entries) {
        expect(
          src,
          contains('"${entry.value}"'),
          reason:
              '${entry.key}가 Swift에 없다. Dart에서만 바꾸면 '
              '**런타임에 조용히 무응답**이 된다',
        );
      }
    });

    test('준비 신호를 AppDelegate가 받는다', () {
      // 이것이 빠지면 Swift가 5초를 기다린 뒤 "준비되지 않았다"만 답한다.
      expect(
        _appDelegate(),
        contains('markReady'),
        reason: 'AppDelegate가 ready를 처리하지 않는다',
      );
    });
  });

  group('앱을 열지 않는다는 전제', () {
    test('openAppWhenRun을 쓰지 않는다', () {
      // 기본값이 false다. 명시하는 순간 누군가 true로 바꿀 자리가 생기고,
      // true가 되면 조회할 때마다 화면이 앱으로 전환돼 기능의 뜻이 사라진다.
      expect(
        _swiftCodeOnly(),
        isNot(contains('openAppWhenRun')),
        reason:
            'openAppWhenRun이 등장한다. 기본값(false)에 맡기고 쓰지 않는 것이 '
            '이 기능의 전제다',
      );
    });

    test('인텐트가 앱 타깃에 있다 — 별도 확장 타깃을 만들지 않았다', () {
      // App Extension으로 옮기면 Flutter 엔진을 띄울 수 없어 Dart 호출이
      // 통째로 죽는다(flutter/flutter#152799).
      expect(
        File('ios/Runner/AppIntents/PlanRoutineIntents.swift').existsSync(),
        isTrue,
      );
      final pbx = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(
        pbx,
        contains('PlanRoutineIntents.swift'),
        reason: 'Xcode 프로젝트에 등록되지 않으면 빌드는 통과하는데 인텐트만 없다',
      );
    });
  });

  group('경계 — Swift에 업무 규칙을 두지 않는다', () {
    test('SQL과 컬럼 이름이 등장하지 않는다', () {
      final src = _swiftCodeOnly();
      // ⚠️ 테이블 이름 `schedules`는 여기 넣지 않는다 — 메서드 이름
      // `registerSchedules`와 대소문자만 달라서 오탐과 헛통과가 함께 가능하다.
      // 스네이크 케이스 컬럼 이름들이 실질적인 몫을 진다.
      const forbidden = [
        'SELECT',
        'INSERT',
        'UPDATE ',
        'DELETE',
        'sqflite',
        'calendar_events',
        'deleted_at',
        'scheduled_date',
        'completed_at',
      ];

      for (final word in forbidden) {
        expect(
          src,
          isNot(contains(word)),
          reason:
              '"$word"가 Swift에 있다. 스키마 지식이 두 곳으로 갈라지면 '
              'v9 마이그레이션 때 한쪽만 고쳐 조용히 어긋난다',
        );
      }
    });

    test('종류 값이 EntryKind의 DB 값과 같다', () {
      // Swift가 넘기는 rawValue가 Dart의 `EntryKind.fromValue`와 맞아야 한다.
      // 어긋나면 폴백(업무)으로 조용히 떨어져 행사가 오늘 탭에 뜬다.
      final src = _swift();
      expect(src, contains('case event'));
      expect(src, contains('case task'));
    });
  });
}
