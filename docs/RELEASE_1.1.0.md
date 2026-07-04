# 정식 배포 체크리스트 — v1.1.0

App Store 정식 배포(1.0.0 → 1.1.0) 단계별 가이드. `[x]`는 이 세션에서 완료.

- **앱**: 공직플랜 (Bundle `com.planroutine.app`, App ID `6761813798`)
- **App Store Connect**: https://appstoreconnect.apple.com/apps/6761813798
- **스토어 페이지**: https://apps.apple.com/kr/app/공직플랜/id6761813798

## 1. 코드/빌드 (완료)
- [x] 버전 1.1.0 (pubspec `1.1.0+52`) 커밋
- [x] Google 캘린더 연동 플래그 ON 유지 (verification 통과)
- [x] 게이트: `flutter analyze` clean · 유닛 246 · iPhone E2E 18/18
- [x] `./ios/bin/fastlane.sh release` — 바이너리 App Store Connect **업로드 성공**
  (빌드 번호 latest_testflight+1 자동. precheck IAP 에러는 업로드와 무관 — Fastfile에서 끔)

## 2. 스크린샷 (완료 시 갱신)
- [x] `flutter drive`로 iPhone 12 Pro Max(6.7", 다크) 4화면 자동 촬영
- **폴더**: `docs/screenshots/`
  - `1_calendar.png` — 캘린더(중요 ★·이벤트)
  - `2_schedule.png` — 검토(대기 목록 + 일괄 확정/삭제 pill)
  - `3_import.png` — 가져오기(CSV + AI 사진, 에듀파인 가이드)
  - `4_settings.png` — 설정(화면 테마·알림 등)
- 재촬영: `xcrun simctl ui <UDID> appearance dark && flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshot_test.dart -d <iPhone 12 Pro Max UDID>`

## 3. App Store Connect 수동 작업 (사용자)
> release 레인은 `submit_for_review: false` — 바이너리 업로드까지만. 아래는 ASC 웹에서.

1. **빌드 처리 대기** (40~60분) — `./ios/bin/fastlane.sh check_builds`로 1.1.0 빌드가 VALID로 뜨는지 확인
2. **새 버전 생성**: 앱 > (+) 버전 또는 플랫폼 → `1.1.0` 입력
3. **빌드 선택**: 처리 완료된 1.1.0 빌드 첨부
4. **스크린샷 업로드**: `docs/screenshots/`의 4장 (6.7" 슬롯). 필요 시 6.9"도
5. **이번 버전의 새로운 기능**(릴리즈 노트) — 초안 ↓
6. **연령 등급/개인정보/심사 정보** 변경 없으면 그대로
7. **저장** → **심사를 위해 제출**(Submit for Review)

### 릴리즈 노트 초안
```
• 밝게 / 어둡게 화면 테마를 추가했어요. (설정 > 화면 테마)
• 학교 행사표 사진을 AI로 변환해 일정으로 바로 가져올 수 있어요.
• 중요한 일정에 ★ 표시를 달아 눈에 띄게 했어요.
• 캘린더에서 날짜를 누르면 그 날짜 일정으로 목록이 이동해요.
• 검토 대기 일정을 한 번에 확정하거나 삭제할 수 있어요.
• 화면 곳곳의 가독성과 색 대비를 다듬었어요.
```

## 4. 배포 후
- [ ] 심사 통과 후 출시(수동/자동 출시 선택)
- [ ] 옵시디언 작업 로그에 1.1.0 출시 기록
- [ ] 메모리 `planroutine_state` 갱신 (1.1.0 출시)
