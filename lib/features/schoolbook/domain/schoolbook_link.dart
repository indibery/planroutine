/// 스쿨북 학교 주소의 호스트. 학교 링크는 `https://schoolbook.zzolab.com/<코드>`이고,
/// 교실을 고른 채 복사하면 `/<코드>/room/12`처럼 뒤에 경로가 붙는다.
const schoolbookHost = 'schoolbook.zzolab.com';

final _codePattern = RegExp(r'^[a-z0-9]{13}$');

/// 붙여 넣은 글에서 학교 코드(13자)를 뽑는다. 코드만 붙여 넣어도 된다.
///
/// 링크면 **첫 경로 조각**이 코드다. 다른 호스트의 링크는 받지 않는다.
String? parseSchoolCode(String input) {
  final text = input.trim();
  if (_codePattern.hasMatch(text)) return text;

  final withScheme = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.toLowerCase() != schoolbookHost) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty);
  if (segments.isEmpty) return null;
  final code = segments.first;
  return _codePattern.hasMatch(code) ? code : null;
}
