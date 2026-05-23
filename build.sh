#!/usr/bin/env bash
set -euo pipefail

INSTALL=false
if [[ "${1:-}" == "--install" ]]; then
    INSTALL=true
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

command -v xcodegen &>/dev/null  || err "xcodegen not found. Install it via: brew install xcodegen"
command -v xcodebuild &>/dev/null || err "xcodebuild not found. Ensure Xcode is installed."

info "Generating Xcode project from project.yml..."
xcodegen generate
ok "Xcode project generated."

info "Cleaning previous builds..."
rm -rf build
mkdir -p build

ARCHIVE_PATH="build/SummerCal.xcarchive"
info "Building and archiving (Release)..."
xcodebuild archive \
    -project SummerCal.xcodeproj \
    -scheme SummerCal \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -destination 'generic/platform=iOS' \
    CODE_SIGN_STYLE=Automatic
ok "Archive created at $ARCHIVE_PATH"

EXPORT_OPTIONS="build/exportOptions.plist"
info "Creating export options plist..."
cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
</dict>
</plist>
EOF

EXPORT_DIR="build/export"
info "Exporting IPA..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates
ok "IPA exported."

IPA_PATH=$(find "$EXPORT_DIR" -name "*.ipa" -maxdepth 1 | head -1)
if [[ -n "$IPA_PATH" ]]; then
    ok "IPA: $IPA_PATH"
else
    err "No IPA found in $EXPORT_DIR"
fi

if $INSTALL; then
    info "Looking for connected iPhone..."
    DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null | grep -E 'iPhone' | head -1 | grep -oE '[A-F0-9]{25,40}' || true)
    if [[ -z "$DEVICE_ID" ]]; then
        err "No connected iPhone found. Unlock your phone and trust this computer."
    fi
    info "Installing to device $DEVICE_ID..."
    xcrun devicectl device install app --device "$DEVICE_ID" "$IPA_PATH"
    ok "Installed on iPhone."
fi

echo ""
ok "Done."
