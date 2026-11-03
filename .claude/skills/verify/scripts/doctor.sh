#!/bin/bash
# 읽기 전용 점검: "이 인스턴스를 조작해도 되는가". 문제마다 ✗ 줄을 찍고 하나라도 있으면 exit 1.
source "$(dirname "$0")/env.sh"
fail=0
ok(){ echo "✓ $*"; }; bad(){ echo "✗ $*"; fail=1; }

xcrun simctl list devices | grep "$VERIFY_UDID" | grep -q "(Booted)" && ok "시뮬레이터 부팅됨 ($VERIFY_UDID)" || bad "시뮬레이터가 꺼져 있다 → launch.sh"

inst=$(wt 30 xcrun simctl get_app_container "$VERIFY_UDID" "$VERIFY_BUNDLE" 2>/dev/null || true)
if [ -z "$inst" ]; then bad "앱이 설치돼 있지 않다 → launch.sh"
else
  a=$(shasum "$inst/Frameworks/App.framework/App" 2>/dev/null | cut -c1-12)
  b=$(shasum "$VERIFY_APP/Frameworks/App.framework/App" 2>/dev/null | cut -c1-12)
  [ -n "$a" ] && [ "$a" = "$b" ] && ok "설치된 Dart 코드 = build/ 산출물 ($a)" || bad "설치본($a)과 build/ 산출물($b)이 다르다. integration_test가 테스트 빌드를 남겼을 수 있다 → launch.sh"
  [ -d "$inst/Frameworks/App.framework" ] && [ -e "$VERIFY_APP" ] && {
    newest=$(cd "$VERIFY_REPO" && find lib -name '*.dart' -newer "$VERIFY_APP/Frameworks/App.framework/App" | head -3)
    [ -z "$newest" ] && ok "빌드가 lib/ 최신 수정보다 새롭다" || bad "빌드 뒤에 고친 소스가 있다($(echo $newest | tr '\n' ' ')) → launch.sh"
  }
fi

pgrep -f "$VERIFY_UDID.*/Runner.app/Runner" >/dev/null && ok "앱 프로세스 실행 중" || bad "앱이 실행 중이 아니다 → xcrun simctl launch $VERIFY_UDID $VERIFY_BUNDLE"

pgrep -f GradleDaemon >/dev/null && bad "Gradle 데몬이 메모리를 잡고 있다 → (cd android && ./gradlew --stop)" || ok "Gradle 데몬 없음"
free=$(memory_pressure 2>/dev/null | awk -F': ' '/free percentage/{gsub("%","",$2);print $2}')
[ -n "$free" ] && { [ "$free" -ge 10 ] && ok "메모리 여유 ${free}%" || bad "메모리 여유 ${free}% — 다른 앱·에뮬레이터를 끈다"; }
# 부팅 직후 iOS 27 런타임이 데몬 수십 개를 한꺼번에 돌려 CPU가 포화되면 simctl 응답이 오지 않는다(2026-11-03 실측: load 266, 유휴 0.5%).
load=$(sysctl -n vm.loadavg | awk '{print int($2)}'); ncpu=$(sysctl -n hw.ncpu)
[ "$load" -le $((ncpu * 2)) ] && ok "CPU 부하 ${load} (코어 ${ncpu})" || bad "CPU 부하 ${load} (코어 ${ncpu}) — 부팅 직후 폭주. 가라앉을 때까지(10~15분) 기다린다"
exit $fail
