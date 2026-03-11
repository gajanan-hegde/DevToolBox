#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/DevToolbox.xcodeproj"
SCHEME="DevToolbox"
DIST_DIR="$REPO_ROOT/dist"
BUILD_DIR="$REPO_ROOT/build"

# Read version from project settings
VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | grep '^\s*MARKETING_VERSION' | head -1 | awk -F'= ' '{print $2}' | xargs)

if [[ -z "$VERSION" ]]; then
  echo "Error: Could not read MARKETING_VERSION from project." >&2
  exit 1
fi

echo "Building DevToolbox $VERSION (self-signed, Release)..."

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH=$(find "$BUILD_DIR" -name "DevToolbox.app" -maxdepth 6 | head -1)

if [[ -z "$APP_PATH" ]]; then
  echo "Error: DevToolbox.app not found in build output." >&2
  exit 1
fi

echo "Self-signing DevToolbox.app (ad-hoc)..."
codesign --force --deep --sign - "$APP_PATH"

ZIP_NAME="DevToolbox-${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "Zipping $APP_PATH -> $ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')

echo ""
echo "Done!"
echo "  Output:  $ZIP_PATH"
echo "  SHA256:  $SHA256"
echo ""
echo "Next steps:"
echo "  1. Upload $ZIP_NAME to GitHub Releases as v${VERSION}"
echo "  2. Copy the SHA256 above into Casks/devtoolbox.rb"
echo "  3. Copy Casks/devtoolbox.rb into the homebrew-devtoolbox tap repo"
echo "  4. Commit and push the tap repo"
