/// CSV 수식 인젝션(CWE-1236) 무해화.
///
/// 내보낸 CSV를 Excel/Sheets에서 열 때, 셀이 `=`,`+`,`-`,`@`(또는 선행 탭/CR/LF)로
/// 시작하면 수식으로 해석돼 피싱 링크·명령이 실행될 수 있다. 그런 셀 앞에 작은따옴표(`'`)를
/// 붙여 텍스트로 강제한다. 이미 `'`로 시작하면 그대로 두므로 재export 시 누적되지 않는다.
library;

const _dangerous = {'=', '+', '-', '@', '\t', '\r', '\n'};

/// 텍스트 셀을 CSV 수식 인젝션으로부터 무해화한다. (export 시점 전용)
String escapeCsvFormula(String cell) {
  if (cell.isEmpty) return cell;
  return _dangerous.contains(cell[0]) ? "'$cell" : cell;
}
