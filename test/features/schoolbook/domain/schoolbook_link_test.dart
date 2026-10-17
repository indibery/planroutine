import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schoolbook/domain/schoolbook_link.dart';

// 실제 학교 코드는 쓰지 않는다(공개 리포) — 가짜 코드
const _code = 'abcdefghijk12';

void main() {
  group('parseSchoolCode — 붙여 넣은 링크에서 학교 코드', () {
    for (final input in [
      _code,
      ' https://schoolbook.zzolab.com/$_code ',
      'http://schoolbook.zzolab.com/$_code/',
      'https://SchoolBook.zzolab.com/$_code/room/12?x=1#a',
      'schoolbook.zzolab.com/$_code',
    ]) {
      test('코드를 뽑는다: "$input"', () {
        expect(parseSchoolCode(input), _code);
      });
    }

    for (final input in [
      '',
      'https://schoolbook.zzolab.com/',
      'abc',
      'https://example.com/$_code',
      'ABCDEFGHIJK12',
    ]) {
      test('코드가 아니면 null: "$input"', () {
        expect(parseSchoolCode(input), isNull);
      });
    }
  });
}
