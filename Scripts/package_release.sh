#!/bin/zsh

set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-/Users/wxc/Coding/FocusShot/FocusShot.xcodeproj}"
SCHEME="${SCHEME:-FocusShot}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="${APP_NAME:-FocusShot}"
TEAM_ID="${TEAM_ID:-8VRNWZ2XFY}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$PWD/dist}"
ARCHIVE_PATH="$OUTPUT_ROOT/$APP_NAME.xcarchive"
EXPORT_PATH="$OUTPUT_ROOT/export"
DMG_PATH="$OUTPUT_ROOT/$APP_NAME.dmg"
EXPORT_OPTIONS_PLIST="$OUTPUT_ROOT/ExportOptions.plist"
ARCHIVED_APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
APP_PATH=""
IS_LOCAL_TEST_DMG=0

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$DMG_PATH"
mkdir -p "$OUTPUT_ROOT"

cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>$TEAM_ID</string>
</dict>
</plist>
PLIST

echo "==> Archiving $APP_NAME"
xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH"

echo "==> Checking Developer ID certificate"
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "==> Exporting Developer ID app"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

    APP_PATH="$EXPORT_PATH/$APP_NAME.app"
    if [[ ! -d "$APP_PATH" ]]; then
        echo "Exported app not found at $APP_PATH"
        exit 1
    fi
else
    echo "==> Developer ID certificate not found; creating a local testing DMG from the archive app"
    if [[ ! -d "$ARCHIVED_APP_PATH" ]]; then
        echo "Archived app not found at $ARCHIVED_APP_PATH"
        exit 1
    fi
    APP_PATH="$ARCHIVED_APP_PATH"
    IS_LOCAL_TEST_DMG=1
fi

echo "==> Creating DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

if [[ "$IS_LOCAL_TEST_DMG" -eq 1 ]]; then
    echo "==> Skipping notarization because this is a local testing DMG"
elif [[ -n "$NOTARY_PROFILE" ]]; then
    echo "==> Submitting DMG for notarization"
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

    echo "==> Stapling notarization ticket"
    xcrun stapler staple "$DMG_PATH"
else
    echo "==> Skipping notarization because NOTARY_PROFILE is empty"
fi

echo
echo "Done."
echo "Archive: $ARCHIVE_PATH"
echo "App:     $APP_PATH"
echo "DMG:     $DMG_PATH"
if [[ "$IS_LOCAL_TEST_DMG" -eq 1 ]]; then
    echo
    echo "Note: This DMG is for local/internal testing."
    echo "      Install on other Macs may still trigger Gatekeeper warnings until you use Developer ID + notarization."
fi
