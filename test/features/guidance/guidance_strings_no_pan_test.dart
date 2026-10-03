import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 화면에 `판`이라는 말을 쓰지 않는다(사용자 결정 2026-10-03) — 판은 화면에서 `처음 작성`·
/// `수정 버전 N`이다. `GuidanceStrings` 소스의 **문자열 리터럴만** 훑는다.
///
/// ⚠️ 주석은 보지 않는다. 그 파일의 주석이 바로 이 결정을 `판`이라는 낱말로 설명하고 있어,
/// 소스 전체를 grep하면 정상인 코드가 실패한다(이 리포의 "언급과 사용" 함정).
/// `판단`(`판단·조치`)은 다른 낱말이라 허용한다.
void main() {
  final src = File(
    'lib/core/constants/strings/guidance_strings.dart',
  ).readAsStringSync();
  final literals = stringLiterals(src);

  test('리터럴을 실제로 읽어 낸다(스캐너 생존 확인)', () {
    expect(literals, contains('지도 기록'));
    expect(literals, contains('판단·조치'));
    expect(literals.any((s) => s.contains('처음 작성')), isTrue);
  });

  test('주석은 리터럴로 읽지 않는다', () {
    final got = stringLiterals("// '판'\n/// `판` 'x'\nconst a = '가'; // '판'");
    expect(got, ['가']);
  });

  test('문자열 보간 안의 따옴표에 걸려 리터럴이 끊기지 않는다', () {
    final got = stringLiterals(
      r"""f(s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')} 판';""",
    );
    expect(got.any((s) => s.contains('판')), isTrue);
  });

  test('GuidanceStrings의 문자열에 `판`이 없다(`판단`은 허용)', () {
    final offenders = [
      for (final s in literals)
        if (s.replaceAll('판단', '').contains('판')) s,
    ];
    expect(offenders, isEmpty, reason: '화면 문구에 `판` 대신 `저장된 내용`·`수정 버전`을 쓴다');
  });
}

/// Dart 소스에서 문자열 리터럴을 뽑는다. 주석(`//`·`/* */`)은 건너뛰고,
/// 보간(`${…}`) 안의 중첩 문자열은 바깥 리터럴의 일부로 둔다.
List<String> stringLiterals(String src) {
  final out = <String>[];
  var i = 0;

  // [start]는 여는 따옴표 위치. 닫는 따옴표 다음 위치를 돌려준다.
  int readString(int start, StringBuffer buf) {
    final q = src[start];
    final triple = src.startsWith(q * 3, start);
    final close = triple ? q * 3 : q;
    var j = start + close.length;
    while (j < src.length) {
      if (src.startsWith(close, j)) return j + close.length;
      final c = src[j];
      if (c == r'\' && j + 1 < src.length) {
        buf.write(src[j + 1]);
        j += 2;
        continue;
      }
      if (c == r'$' && j + 1 < src.length && src[j + 1] == '{') {
        // 보간: 짝이 맞는 `}`까지, 안의 문자열은 통째로 건너뛴다.
        var depth = 1;
        j += 2;
        while (j < src.length && depth > 0) {
          final d = src[j];
          if (d == "'" || d == '"') {
            final inner = StringBuffer();
            j = readString(j, inner);
            buf.write(inner);
            continue;
          }
          if (d == '{') depth++;
          if (d == '}') depth--;
          j++;
        }
        continue;
      }
      buf.write(c);
      j++;
    }
    return j;
  }

  while (i < src.length) {
    if (src.startsWith('//', i)) {
      final nl = src.indexOf('\n', i);
      i = nl < 0 ? src.length : nl + 1;
      continue;
    }
    if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      i = end < 0 ? src.length : end + 2;
      continue;
    }
    final c = src[i];
    if (c == "'" || c == '"') {
      final buf = StringBuffer();
      i = readString(i, buf);
      out.add(buf.toString());
      continue;
    }
    i++;
  }
  return out;
}
