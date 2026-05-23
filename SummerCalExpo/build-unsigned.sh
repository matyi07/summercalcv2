#!/bin/bash
set -euo pipefail

echo "=== SummerCal v2 — Build Unsigned IPA ==="
echo "This builds an IPA without signing (no developer account needed)."
echo "After building, use Sideloadly or AltStore on Windows to sign and install."
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build-unsigned"

echo "==> Installing dependencies..."
cd "${PROJECT_DIR}"
npm install

echo "==> Generating iOS native project..."
npx expo prebuild --platform ios --clean

echo "==> Installing CocoaPods..."
cd ios
pod install --verbose || true
cd ..

echo "==> Building unsigned .app (this takes 5-10 minutes)..."
xcodebuild \
  -workspace "ios/SummerCalExpo.xcworkspace" \
  -scheme SummerCalExpo \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${BUILD_DIR}" \
  CODE_SIGNING_ALLOWED=No \
  CODE_SIGNING_REQUIRED=No \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  ONLY_ACTIVE_ARCH=NO \
  BITCODE_GENERATION_MODE=bitcode

APP_PATH=$(find "${BUILD_DIR}/Build/Products/Release-iphoneos" -name "*.app" -type d | head -1)

if [ -z "${APP_PATH}" ]; then
  echo "ERROR: Build failed. .app not found."
  exit 1
fi

echo "==> Packaging as IPA..."
APP_NAME=$(basename "${APP_PATH}")
rm -rf Payload
mkdir -p Payload
cp -R "${APP_PATH}" "Payload/${APP_NAME}"
zip -r SummerCal-unsigned.ipa Payload
rm -rf Payload

echo ""
echo "=== DONE ==="
echo "Unsigned IPA: ${PROJECT_DIR}/SummerCal-unsigned.ipa"
echo ""
echo "Next steps on Windows:"
echo "1. Download Sideloadly from sideloadly.io"
echo "2. Connect iPhone via USB"
echo "3. Drag SummerCal-unsigned.ipa into Sideloadly"
echo "4. Sign in with your free Apple ID"
echo "5. On iPhone: Settings → General → VPN & Device Management → Trust"
