#!/bin/bash
# 정적 화면 캡처. 사용: shot.sh <증거 폴더> <이름>
source "$(dirname "$0")/env.sh"
xcrun simctl io "$VERIFY_UDID" screenshot "$1/$2.png" >/dev/null 2>&1 && echo "$1/$2.png"
