#!/bin/bash
# 이번 실행이 띄운 것만 내린다. 증거(~/.planroutine/verify/)는 지우지 않는다.
# 사용: cleanup.sh [--uninstall]   (--uninstall이면 앱과 그 데이터까지 지운다)
source "$(dirname "$0")/env.sh"
xcrun simctl terminate "$VERIFY_UDID" "$VERIFY_BUNDLE" 2>/dev/null || true
xcrun simctl terminate "$VERIFY_UDID" com.mobilenext.devicekit-iosUITests.xctrunner 2>/dev/null || true
[ "${1:-}" = "--uninstall" ] && xcrun simctl uninstall "$VERIFY_UDID" "$VERIFY_BUNDLE" 2>/dev/null || true
if [ -f "$VERIFY_EVIDENCE_ROOT/.booted-by-verify" ]; then
  xcrun simctl shutdown "$VERIFY_UDID" 2>/dev/null || true
  rm -f "$VERIFY_EVIDENCE_ROOT/.booted-by-verify"
  echo "이번 실행이 켠 시뮬레이터를 껐다"
fi
echo "증거는 남아 있다: $VERIFY_EVIDENCE_ROOT"
