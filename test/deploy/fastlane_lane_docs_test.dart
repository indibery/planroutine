// 배포 문서에 적힌 fastlane 명령이 실제 레인과 맞는지 지킨다.
//
// **왜 가드가 필요한가**: 1.3.0을 심사 제출한 뒤 스크린샷 장수를 확인하려고
// `./ios/bin/fastlane.sh check_screenshots`를 불렀는데 `Could not find lane`으로
// 끝났다(2026-08-06). CLAUDE.md와 deploy 스킬 런북이 `upload_screenshots`·
// `check_screenshots`·`dedupe_screenshots` 셋을 명령으로 적어두고 있었지만
// Fastfile에는 그런 레인이 없었다 — `dedupe_screenshots!`는 처음부터 `release`가
// 부르는 내부 **함수**였고, 문서가 그것을 레인으로 착각해 적은 것이었다.
//
// 문서와 Fastfile은 서로를 모르므로 갈라져도 아무 신호가 없다. 다음에 밟는
// 사람도 명령을 실행해 실패하기 전까지는 알 수 없다 — 그 왕복을 없앤다.
//
// 검사 방향은 `data_source_credit_test.dart`와 같은 **양방향**이다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 검사 대상 문서. **운영 문서만** 본다.
///
/// `docs/superpowers/specs/`는 일부러 제외한다 — 그 문서들은 특정 시점의 설계
/// 기록이라 "당시 계획했던 레인"을 적고 있을 수 있고, 지금 실물과 맞아야 할
/// 이유가 없다. 여기서 지키려는 것은 **사람이 명령을 복사해 실행하는 문서**다.
///
/// **스킬은 목록에 손으로 적지 않고 훑는다.** 처음에는 `deploy` 스킬 하나를 박아
/// 뒀는데, `store-listing` 스킬을 추가하면서 그 파일이 가드 밖이라는 사실이 드러났다
/// — 스킬은 사람과 Claude가 그대로 복사해 실행하는 런북이라 같은 의무를 진다.
/// 목록을 손으로 관리하면 새 스킬마다 이 사실을 다시 발견해야 한다.
List<String> _docPaths() => [
  'CLAUDE.md',
  ...(Directory('.claude/skills').listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      .map((d) => '${d.path}/SKILL.md')
      .where((p) => File(p).existsSync()),
];

/// 플랫폼별 Fastfile 경로 — 문서의 `<platform>/bin/fastlane.sh`와 짝이다.
const _fastfilePaths = {
  'ios': 'ios/fastlane/Fastfile',
  'android': 'android/fastlane/Fastfile',
};

/// 명령으로 적히지 않아도 되는 레인.
///
/// **다른 레인이 호출하는 내부 헬퍼만** 넣는다. 사람이 직접 부를 수 있는 레인을
/// 여기 넣으면 "문서에 없어도 통과"가 되어 역방향 검사가 무력해진다.
///
/// - `load_asc_api_key`: `beta`·`release`·`asc_state` 등이 앞머리에서 호출한다
///   (로그의 `Switch to ios load_asc_api_key lane`). 단독 실행은 인증만 하고
///   아무것도 하지 않아 의미가 없다.
const _internalLanes = {
  'ios': {'load_asc_api_key'},
  'android': <String>{},
};

/// `lane :beta do` / `lane :release do |options|` → `beta`, `release`
Set<String> _lanesIn(String fastfilePath) {
  final file = File(fastfilePath);
  // 파일을 못 읽으면 레인 집합이 비고, 그러면 "문서의 모든 명령이 없는 레인"이라
  // 판정돼 요란하게 깨진다. 조용한 통과가 되지 않으므로 여기서는 존재만 본다.
  expect(file.existsSync(), isTrue, reason: '$fastfilePath 가 없다');
  return RegExp(
    r'^\s*lane :(\w+)',
    multiLine: true,
  ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!).toSet();
}

/// 문서에서 `./ios/bin/fastlane.sh beta`, `./android/bin/fastlane.sh build_aab` 등을
/// 뽑아 플랫폼별로 모은다. `release build:115`처럼 인자가 붙어도 레인 이름만 딴다.
Map<String, Set<String>> _documentedCommands() {
  final found = {for (final p in _fastfilePaths.keys) p: <String>{}};
  final pattern = RegExp(r'(ios|android)/bin/fastlane\.sh\s+([a-z_]+)');

  for (final path in _docPaths()) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path 가 없다 — 검사 대상 문서다');
    for (final m in pattern.allMatches(file.readAsStringSync())) {
      found[m.group(1)!]!.add(m.group(2)!);
    }
  }
  return found;
}

void main() {
  group('fastlane 레인 ↔ 배포 문서', () {
    // 이 테스트가 없으면 아래 두 검사가 **집합이 비어서** 통과할 수 있다.
    // 정규식을 잘못 고치거나 문서 형식이 바뀌어 아무것도 못 뽑으면
    // "위반 0건"이 되는데, 그건 통과가 아니라 검사가 죽은 것이다.
    test('문서에서 명령을 실제로 뽑아냈다 (검사가 살아 있는지)', () {
      final documented = _documentedCommands();

      expect(
        documented['ios'],
        isNotEmpty,
        reason: 'iOS 명령을 하나도 못 뽑았다 — 정규식이나 문서 형식이 바뀌었다',
      );
      expect(
        documented['android'],
        isNotEmpty,
        reason: 'Android 명령을 하나도 못 뽑았다 — 정규식이나 문서 형식이 바뀌었다',
      );
      for (final entry in _fastfilePaths.entries) {
        expect(
          _lanesIn(entry.value),
          isNotEmpty,
          reason: '${entry.value}에서 레인을 하나도 못 뽑았다',
        );
      }

      // 스킬 훑기가 죽으면(디렉터리 이름이 바뀌거나 glob이 깨지면) 검사 대상이
      // CLAUDE.md 하나로 조용히 줄어든다 — 그때도 위 검사들은 통과한다.
      expect(
        _docPaths(),
        contains('.claude/skills/deploy/SKILL.md'),
        reason: '스킬 SKILL.md를 훑지 못했다 — 검사 대상이 CLAUDE.md로 줄었다',
      );
    });

    // **이것이 실제로 데인 방향이다.** 없는 명령을 적어두면 그것을 믿고 실행한
    // 사람이 `Could not find lane`까지 가야 알게 된다.
    test('문서에 적힌 명령은 전부 실존하는 레인이다', () {
      final documented = _documentedCommands();

      for (final entry in _fastfilePaths.entries) {
        final platform = entry.key;
        final real = _lanesIn(entry.value);
        final ghosts = documented[platform]!.difference(real);

        expect(
          ghosts,
          isEmpty,
          reason:
              '문서가 없는 $platform 레인을 명령으로 적었다: '
              '${ghosts.join(", ")} — 실존 레인은 ${real.toList()..sort()}',
        );
      }
    });

    // 반대 방향 — 레인을 추가하고 문서에 적지 않으면 아무도 그것이 있는 줄 모른다.
    // 내부 헬퍼는 [_internalLanes]로 면제하되, 면제 목록을 늘리는 것으로 이 검사를
    // 통과시키는 일이 없도록 목록에 이유를 함께 적는다.
    test('실존하는 레인은 전부 문서에 적혀 있다', () {
      final documented = _documentedCommands();

      for (final entry in _fastfilePaths.entries) {
        final platform = entry.key;
        final undocumented = _lanesIn(entry.value)
            .difference(documented[platform]!)
            .difference(_internalLanes[platform]!);

        expect(
          undocumented,
          isEmpty,
          reason:
              '$platform 레인이 문서에 없다: ${undocumented.join(", ")} — '
              '${_docPaths().first}의 배포 명령 목록에 추가하거나, '
              '다른 레인만 호출하는 내부 헬퍼라면 _internalLanes에 이유와 함께 넣을 것',
        );
      }
    });
  });
}
