// Gson을 쓰는 안드로이드 플러그인은 **R8 keep 규칙으로 보호돼 있어야 한다.**
//
// Gson은 필드 이름을 리플렉션으로 읽어 JSON 키를 만들고, Dart 쪽은 그 이름으로
// 값을 찾는다. R8이 이름을 줄이면 키가 `a`/`b`가 되어 **Dart가 받는 값이 전부
// null이 된다** — 컴파일도 통과하고 디버그에서도 멀쩡하며, **release에서만** 깨진다.
//
// 이 리포는 같은 함정을 두 번 밟았다:
//
//   1. `flutter_local_notifications` — 부팅 후 알림 재예약이 죽었다. SharedPreferences에
//      저장한 목록을 `TypeToken<ArrayList<NotificationDetails>>`로 되읽는데 R8
//      fullMode가 시그니처를 지웠다.
//   2. `device_calendar` — 기기 캘린더 저장이 `저장 실패`로 끝났다(Galaxy A34 실측
//      2026-08-06). `Calendar.isReadOnly`가 사라져 Dart가 null을 받고,
//      `isReadOnly == false`가 거짓이 되어 **쓰기 가능한 캘린더가 0개**로 보였다.
//      R8 매핑으로 확인: 수정 전 `models.Event.eventTitle -> a`, `models.Calendar`는
//      클래스 자체가 살아남지 못했다. 수정 후 전부 원래 이름 유지.
//
// **단위 테스트로는 이 결함을 재현할 수 없다** — R8은 release 빌드에서만 돈다.
// 그래서 재현이 아니라 **예방**을 검사한다: Gson을 쓰는 플러그인이 새로 들어오거나
// 기존 플러그인이 Gson을 쓰기 시작하면, keep 규칙을 잊었을 때 여기서 걸린다.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// keep 규칙이 없어도 되는 패키지 — **이유를 반드시 함께 적는다.**
///
/// 면제 목록을 늘려 통과시키면 이 가드는 아무것도 지키지 않는다.
const _exempt = <String, String>{
  // 이 플러그인은 자기 모델에 `@SerializedName`을 달고 TypeToken으로 되읽는다.
  // `proguard-rules.pro` 맨 위의 **범용 Gson 규칙 셋**(-keepattributes Signature /
  // TypeToken keep / @SerializedName 필드 keep)이 그 경로를 이미 덮는다.
  // ⚠️ 업그레이드로 애노테이션 없는 모델이 들어오면 그 규칙으로는 못 막는다.
  'flutter_local_notifications':
      '범용 @SerializedName·TypeToken 규칙으로 덮인다(proguard-rules.pro 상단)',
};

final _proguard =
    File('android/app/proguard-rules.pro').readAsStringSync();

/// 플러그인 이름 → 안드로이드 소스에서 읽은 최상위 패키지 네임스페이스.
Map<String, String> _gsonPlugins() {
  final configFile = File('.dart_tool/package_config.json');
  expect(
    configFile.existsSync(),
    isTrue,
    reason: '.dart_tool/package_config.json 이 없다 — `flutter pub get` 후 실행할 것. '
        '이 파일이 없으면 검사 대상이 0개가 되어 가드가 조용히 통과한다',
  );

  final packages = (jsonDecode(configFile.readAsStringSync())
      as Map<String, dynamic>)['packages'] as List<dynamic>;

  final found = <String, String>{};
  for (final raw in packages) {
    final pkg = raw as Map<String, dynamic>;
    final root = Uri.parse(pkg['rootUri'] as String).toFilePath();
    final srcDir = Directory('$root/android/src');
    if (!srcDir.existsSync()) continue;

    for (final entity in srcDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.kt') && !entity.path.endsWith('.java')) {
        continue;
      }
      final text = entity.readAsStringSync();
      if (!RegExp(r'\bGson\b|\bGsonBuilder\b').hasMatch(text)) continue;

      final namespace =
          RegExp(r'^package\s+([\w.]+)', multiLine: true).firstMatch(text)?.group(1);
      if (namespace == null) continue;
      // 가장 짧은(=최상위에 가까운) 네임스페이스를 그 플러그인의 대표로 삼는다.
      final name = pkg['name'] as String;
      final current = found[name];
      if (current == null || namespace.length < current.length) {
        found[name] = namespace;
      }
    }
  }
  return found;
}

void main() {
  group('Gson 플러그인 ↔ R8 keep 규칙', () {
    // 스캔이 죽으면 "위반 0건"이 되는데 그건 통과가 아니라 검사가 죽은 것이다.
    test('Gson을 쓰는 플러그인을 실제로 찾아냈다 (검사가 살아 있는지)', () {
      final plugins = _gsonPlugins();
      expect(
        plugins,
        isNotEmpty,
        reason: 'Gson을 쓰는 안드로이드 플러그인을 하나도 못 찾았다 — '
            '스캔 경로나 정규식이 깨졌다',
      );
      expect(
        _proguard,
        contains('-keep'),
        reason: 'proguard-rules.pro를 못 읽었거나 비어 있다',
      );
    });

    test('Gson을 쓰는 플러그인은 keep 규칙이 있거나 이유와 함께 면제돼 있다', () {
      final unprotected = <String, String>{};

      _gsonPlugins().forEach((name, namespace) {
        if (_exempt.containsKey(name)) return;
        // `-keep class <namespace>...` 형태로 그 네임스페이스가 언급되면 보호된 것으로 본다.
        final kept = RegExp('-keep[^\\n]*${RegExp.escape(namespace)}')
            .hasMatch(_proguard);
        if (!kept) unprotected[name] = namespace;
      });

      expect(
        unprotected,
        isEmpty,
        reason: 'Gson으로 모델을 직렬화하는데 R8 keep 규칙이 없다: $unprotected\n'
            '  → release에서만 Dart가 null을 받아 조용히 깨진다(디버그는 멀쩡하다).\n'
            '  → android/app/proguard-rules.pro 에 `-keep class <네임스페이스>.** { *; }` 추가,\n'
            '     또는 범용 규칙으로 덮인다면 이 테스트의 _exempt에 **이유와 함께** 등록할 것.',
      );
    });

    test('면제 목록에 이유가 비어 있지 않다', () {
      _exempt.forEach((name, reason) {
        expect(reason.trim(), isNotEmpty, reason: '$name 의 면제 사유가 비어 있다');
      });
    });
  });
}
