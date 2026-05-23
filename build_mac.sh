#!/bin/bash
set -euo pipefail
echo "=== SummerCal v2 — Mac Builder ==="
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-expo}"

if [ "$MODE" = "expo" ]; then
    echo "==> Building Expo (React Native) version..."
    cd "$PROJECT_DIR/SummerCalExpo"
    npm install
    npx expo prebuild --platform ios --clean
    cd ios && pod install || true && cd ..
    
    echo "==> Compiling..."
    xcodebuild -workspace ios/SummerCalExpo.xcworkspace \
      -scheme SummerCalExpo -configuration Release \
      -sdk iphoneos -destination 'generic/platform=iOS' \
      -derivedDataPath build \
      CODE_SIGNING_ALLOWED=No CODE_SIGNING_REQUIRED=No \
      CODE_SIGN_IDENTITY="" ONLY_ACTIVE_ARCH=NO
    
    APP_PATH=$(find build/Build/Products/Release-iphoneos -name "*.app" -type d | head -1)
    mkdir -p Payload && cp -R "$APP_PATH" Payload/
    zip -r "$PROJECT_DIR/SummerCal.ipa" Payload
    rm -rf Payload
    echo "IPA: $PROJECT_DIR/SummerCal.ipa"

elif [ "$MODE" = "swift" ]; then
    echo "==> Building Swift version..."
    cd "$PROJECT_DIR/SummerCal"
    command -v xcodegen || brew install xcodegen
    xcodegen generate
    xcodebuild -project SummerCal.xcodeproj \
      -scheme SummerCal -configuration Release \
      -sdk iphoneos -destination 'generic/platform=iOS' \
      -derivedDataPath build -allowProvisioningUpdates \
      CODE_SIGNING_ALLOWED=No CODE_SIGNING_REQUIRED=No \
      CODE_SIGN_IDENTITY="" ONLY_ACTIVE_ARCH=NO
    
    APP_PATH=$(find build/Build/Products/Release-iphoneos -name "*.app" -type d | head -1)
    mkdir -p Payload && cp -R "$APP_PATH" Payload/
    zip -r "$PROJECT_DIR/SummerCal.ipa" Payload
    rm -rf Payload
    echo "IPA: $PROJECT_DIR/SummerCal.ipa"
fi

echo "Done. Transfer SummerCal.ipa to your Windows machine."
