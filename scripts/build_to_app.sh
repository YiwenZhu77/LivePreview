#!/usr/bin/env zsh
set -euo pipefail

IDENTITY=${IDENTITY:-"LivePreview Local Dev"}
DERIVED=${DERIVED:-"/tmp/LivePreviewBuild"}
APP_PATH="$DERIVED/Build/Products/Release/LivePreview.app"
DEST_APP="/Applications/LivePreview.app"

printf "Using identity: %s\n" "$IDENTITY"

xcodebuild \
  -scheme LivePreview \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= \
  OTHER_CODE_SIGN_FLAGS="--deep" \
  build

ditto "$APP_PATH" "$DEST_APP"

# Show a short signature summary to confirm the app stayed consistent
codesign -dv --verbose=2 "$DEST_APP" 2>&1 | head -n 5

echo "Built and copied to $DEST_APP"