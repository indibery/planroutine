import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/data_source_agencies.dart';

/// 스토어 등록정보 ↔ 실제 호출 · 정책 요건.
///
/// Play가 `versionCode 143`을 이 결함으로 거부했다(2026-08-04):
/// `혼동을 야기하는 주장 관련 정책 위반 — 정부 정보의 출처 링크 누락`.
/// 요구는 둘이다 — ① 유효한 출처 URL을 **앱 설명**에 명시 ② 정부 기관을 대표하지
/// 않는다는 **면책조항**을 앱 설명에 표시. 제휴 여부와 무관하게 적용된다.
///
/// **앱 안 문구는 `data_source_credit_test.dart`가 지킨다. 이 가드는 스토어 등록정보를
/// 본다** — 거부 당시 지적된 영역은 `자세한 설명 (ko-KR)` 한 곳이었고 바이너리는
/// 무관했는데, 어떤 테스트도 그 파일을 보지 않았다. CLAUDE.md가 "재발하면 가드로 올릴
/// 후보"라고 적어둔 항목이 이것이다.
///
/// 못 하는 것: URL이 **지금도 200인지**는 검사하지 않는다(네트워크가 필요하다).
/// 그 몫은 가드가 아니라 스킬이다.
const _docs = {
  'Play': 'docs/play_store_description.md',
  'App Store': 'docs/app_store_description.md',
};

const _sourceHeading = '■ 정보 출처와 면책조항';

/// 면책조항의 실체. 문구를 그대로 베끼지 않고 **정책이 요구하는 주장**만 고정한다 —
/// 문장을 다듬는 것은 막지 않고, 주장이 사라지는 것은 막는다.
const _disclaimerClaims = {
  '정부 기관을 대표하지 않는다': '어떤 정부 기관도 대표하지 않으며',
  '제휴·후원 관계가 없다': '제휴',
  '정부 시스템에 접속하지 않는다': '정부 시스템에 접속하거나',
};

/// 출처 절만 잘라낸다.
///
/// ⚠️ **첫 등장만 쓴다.** `app_store_description.md`는 변경 이력 표 안에서 같은 절
/// 제목을 한 번 더 쓴다(`정부 정보 출처 URL 없음 | ■ 정보 출처와 면책조항 절 추가`) —
/// 마지막 등장을 잡으면 절이 아니라 표를 검사하고, 그러면 URL이 하나도 없는데 통과한다.
String _sourceSection(String path) {
  final text = File(path).readAsStringSync();
  final start = text.indexOf(_sourceHeading);
  expect(start, isNot(-1), reason: '$path 에 "$_sourceHeading" 절이 없다');

  final rest = text.substring(start + _sourceHeading.length);
  final end = rest.indexOf('\n■ ');
  return end == -1 ? rest : rest.substring(0, end);
}

Set<String> _urlsIn(String section) =>
    RegExp(r'https://[^\s)]+').allMatches(section).map((m) => m.group(0)!).toSet();

void main() {
  group('스토어 등록정보 — 정부 정보 출처 의무', () {
    test('두 스토어 설명에 면책조항이 있다', () {
      for (final (store, path) in _docs.entries.map((e) => (e.key, e.value))) {
        final section = _sourceSection(path);
        for (final claim in _disclaimerClaims.entries) {
          expect(
            section,
            contains(claim.value),
            reason: '$store 설명($path)에 "${claim.key}"는 주장이 없다 — '
                'Play가 versionCode 143을 이 결함으로 거부했다',
          );
        }
      }
    });

    test('출처 절에 데이터셋 URL 넷 + 포털 + 법령이 있다', () {
      for (final (store, path) in _docs.entries.map((e) => (e.key, e.value))) {
        final urls = _urlsIn(_sourceSection(path));
        final datasets =
            urls.where((u) => RegExp(r'data\.go\.kr/data/\d+').hasMatch(u)).toSet();

        expect(datasets.length, greaterThanOrEqualTo(4),
            reason: '$store 설명의 데이터셋 URL이 $datasets 뿐이다');
        expect(urls, contains('https://www.data.go.kr'),
            reason: '$store 설명에 공공데이터포털 링크가 없다');
        expect(urls.any((u) => u.contains('law.go.kr')), isTrue,
            reason: '$store 설명에 공휴일 근거 법령 링크가 없다');
      }
    });

    test('두 문서의 출처 URL 집합이 같다', () {
      // 실제로 어긋났던 지점이다. Play는 고쳤는데 iOS 설명은 한동안 URL이 없었고
      // (CLAUDE.md가 "다음 iOS 제출 때 함께 넣을 것"으로 남겨 뒀다), 그 상태를
      // 알려주는 것은 사람의 기억뿐이었다.
      final sets = _docs.map((store, path) =>
          MapEntry(store, _urlsIn(_sourceSection(path))));

      expect(sets['App Store'], equals(sets['Play']),
          reason: '두 스토어 설명의 출처 URL이 다르다 — 한쪽만 고친 상태다');
    });

    test('호출하는 기관이 두 문서의 출처 절에 적혀 있다', () {
      final src = busApiClientSource();

      for (final (store, path) in _docs.entries.map((e) => (e.key, e.value))) {
        final section = _sourceSection(path);
        for (final agency in kDataSourceAgencies.entries) {
          if (!src.contains(agency.key)) continue;
          expect(section, contains(agency.value),
              reason: '${agency.key}(을)를 호출하는데 $store 설명의 출처 절에 '
                  '${agency.value}이 없다 — 라이선스 위반이다');
        }
      }
    });

    test('출처 절에 적힌 기관은 전부 실제로 호출한다', () {
      // 안 쓰는 기관을 출처로 적는 것도 거짓이다. 서울 API는 신청·승인됐지만
      // 아직 호출하지 않는다(`ws.bus.go.kr`이 호출부에 없다).
      final src = busApiClientSource();

      for (final (store, path) in _docs.entries.map((e) => (e.key, e.value))) {
        final section = _sourceSection(path);
        for (final agency in kDataSourceAgencies.entries) {
          if (src.contains(agency.key)) continue;
          expect(section, isNot(contains(agency.value)),
              reason: '$store 설명의 출처 절에 ${agency.value}을 적었는데 '
                  '${agency.key}를 호출하지 않는다');
        }
      }
    });

    test('검사가 살아 있다 — 절을 실제로 잘라냈고 기관 표가 호출부와 맞물린다', () {
      // 절을 못 찾아 빈 문자열을 검사하면 위 전부가 조용히 통과한다.
      for (final path in _docs.values) {
        expect(_sourceSection(path).trim(), isNotEmpty, reason: '$path 절이 비었다');
      }

      final src = busApiClientSource();
      expect(kDataSourceAgencies.keys.where(src.contains), isNotEmpty,
          reason: '기관 표의 마커가 호출부에서 하나도 안 잡힌다 — 표가 낡았다');
    });
  });
}
