#!/bin/bash
# 앱 샌드박스 DB(planroutine.db)에 읽기 전용 SQL을 실행한다. 사용: db.sh "SELECT ..."
source "$(dirname "$0")/env.sh"
data=$(wt 30 xcrun simctl get_app_container "$VERIFY_UDID" "$VERIFY_BUNDLE" data) || exit 1
db=$(find "$data" -name planroutine.db | head -1)
[ -n "$db" ] || { echo "planroutine.db가 아직 없다(앱이 첫 화면을 지나야 생긴다)" >&2; exit 1; }
sqlite3 -readonly -header -column "$db" "$1"
