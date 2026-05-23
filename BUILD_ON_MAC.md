# Build SummerCal IPA on a Mac

## Quick Build (Expo/React Native - Recommended)

Requires: Node.js 20+, Xcode 16+

```bash
cd SummerCalExpo
npm install
npx expo run:ios --device
```

This installs SummerCal directly to your connected iPhone via USB.
Free Apple ID works — the app runs for 7 days.

## Build Unsigned IPA (For AltStore/Sideloadly)

```bash
cd SummerCalExpo
npm install
npx expo prebuild --platform ios --clean
cd ios && pod install && cd ..
xcodebuild -workspace ios/SummerCalExpo.xcworkspace \
  -scheme SummerCalExpo \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=No \
  CODE_SIGNING_REQUIRED=No \
  CODE_SIGN_IDENTITY="" \
  ONLY_ACTIVE_ARCH=NO

# Package as IPA
APP_PATH=$(find build/Build/Products/Release-iphoneos -name "*.app" -type d | head -1)
mkdir -p Payload && cp -R "$APP_PATH" Payload/ && zip -r SummerCal.ipa Payload
```

The unsigned IPA is at `SummerCal.ipa` — sign with AltStore/Sideloadly.

## Build Original Swift Version

```bash
brew install xcodegen
cd SummerCal
xcodegen generate
xcodebuild -project SummerCal.xcodeproj \
  -scheme SummerCal \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  -allowProvisioningUpdates
```

## After Getting the IPA on Windows

1. Download **Sideloadly** from sideloadly.io
2. Connect iPhone via USB
3. Drag SummerCal.ipa into Sideloadly
4. Sign in with your free Apple ID
5. On iPhone: Settings → General → VPN & Device Management → Trust
