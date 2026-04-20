#!/bin/bash
# PlanRoutine TestFlight 배포 자동화 스크립트
# 사용법: ./scripts/deploy_testflight.sh [빌드번호]
#   빌드번호 생략 시 자동 증가

set -e

# ── App Store Connect API 인증 정보 ──
API_KEY_ID="D8W86CLKHY"
API_ISSUER_ID="69a6de72-97eb-47e3-e053-5b8c7c11a4d1"
API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"

# ── 프로젝트 루트로 이동 ──
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# ── API Key 파일 확인 ──
if [ ! -f "$API_KEY_PATH" ]; then
  echo "❌ API Key 파일을 찾을 수 없습니다: $API_KEY_PATH"
  exit 1
fi

# ── 빌드 번호 결정 ──
if [ -n "$1" ]; then
  BUILD_NUMBER=$1
else
  # 현재 pubspec.yaml에서 빌드 번호 읽어서 +1
  CURRENT=$(grep '^version:' pubspec.yaml | sed 's/.*+//')
  BUILD_NUMBER=$((CURRENT + 1))
fi

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')

echo "=========================================="
echo "  PlanRoutine TestFlight 배포"
echo "  버전: ${VERSION}+${BUILD_NUMBER}"
echo "=========================================="

# ── 1. 코드 생성 ──
echo ""
echo "📦 코드 생성 중..."
dart run build_runner build --delete-conflicting-outputs

# ── 2. IPA 빌드 ──
echo ""
echo "🔨 IPA 빌드 중..."
flutter build ipa --release --build-number="$BUILD_NUMBER"

IPA_PATH=$(find "$PROJECT_ROOT/build/ios/ipa" -name "*.ipa" | head -1)

if [ ! -f "$IPA_PATH" ]; then
  echo "❌ IPA 파일을 찾을 수 없습니다"
  exit 1
fi

echo "✅ IPA 빌드 완료: $IPA_PATH"

# ── 3. App Store Connect 검증 ──
echo ""
echo "🔍 App Store Connect 검증 중..."
xcrun altool --validate-app \
  --file "$IPA_PATH" \
  --type ios \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID"

echo "✅ 검증 통과"

# ── 4. App Store Connect 업로드 ──
echo ""
echo "🚀 App Store Connect 업로드 중..."
xcrun altool --upload-app \
  --file "$IPA_PATH" \
  --type ios \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID"

echo ""
echo "=========================================="
echo "  ✅ 배포 완료!"
echo "  버전: ${VERSION}+${BUILD_NUMBER}"
echo "  TestFlight에서 5~15분 후 확인 가능"
echo "=========================================="
