#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TAP_REPO="https://github.com/gajanan-hegde/homebrew-devtoolbox.git"

cd "$REPO_ROOT"

# ── 1. Ensure on main with a clean working tree ───────────────────────────────

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "main" ]]; then
  echo "Switching to main..."
  git checkout main
fi

git pull origin main

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: uncommitted changes present. Commit or stash them first." >&2
  git status --short >&2
  exit 1
fi

# ── 2. Ask for version ────────────────────────────────────────────────────────

echo "Latest tag:     $(git describe --tags --abbrev=0 2>/dev/null || echo '(none)')"
echo "Latest release: $(gh release list --limit 1 --json tagName,publishedAt \
  --jq '.[0] | "\(.tagName)  \(.publishedAt | split("T")[0])"' 2>/dev/null || echo '(none)')"
echo ""

read -rp "Release version (e.g. 1.1): " VERSION
[[ -z "$VERSION" ]] && { echo "Error: version cannot be empty." >&2; exit 1; }

TAG="v${VERSION}"

if git tag --list | grep -qx "$TAG"; then
  echo "Error: tag $TAG already exists." >&2
  exit 1
fi

# Bump MARKETING_VERSION directly in project.pbxproj (avoids agvtool touching Info.plist)
echo "Setting MARKETING_VERSION → $VERSION"
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/" \
  DevToolbox.xcodeproj/project.pbxproj
git add DevToolbox.xcodeproj/project.pbxproj
git commit -m "Release $VERSION"

# ── 3 & 4. Tag and push ───────────────────────────────────────────────────────

git tag "$TAG"
git push origin main
git push origin "$TAG"

# ── 5. Build ──────────────────────────────────────────────────────────────────

echo ""
echo "Building $TAG..."

BUILD_LOG=$(mktemp)
TAP_DIR=$(mktemp -d)
trap 'rm -f "$BUILD_LOG"; rm -rf "$TAP_DIR"' EXIT

"$SCRIPT_DIR/build-release.sh" 2>&1 | tee "$BUILD_LOG"

SHA256=$(awk '/SHA256:/ {print $2}' "$BUILD_LOG")
ZIP_PATH=$(awk '/Output:/ {print $2}' "$BUILD_LOG")

[[ -z "$SHA256" ]]     && { echo "Error: could not extract SHA256 from build output." >&2; exit 1; }
[[ -z "$ZIP_PATH" ]]   && { echo "Error: could not extract zip path from build output." >&2; exit 1; }
[[ ! -f "$ZIP_PATH" ]] && { echo "Error: zip not found: $ZIP_PATH" >&2; exit 1; }

# ── 6. Create GitHub release ──────────────────────────────────────────────────

echo ""
echo "Creating GitHub release $TAG..."
gh release create "$TAG" "$ZIP_PATH" \
  --title "$TAG" \
  --generate-notes

# ── 7. Update homebrew tap ────────────────────────────────────────────────────

echo ""
echo "Updating homebrew tap..."
git clone "$TAP_REPO" "$TAP_DIR"

CASK="$TAP_DIR/Casks/devtoolbox.rb"
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK"
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$CASK"

git -C "$TAP_DIR" add Casks/devtoolbox.rb
git -C "$TAP_DIR" commit -m "DevToolbox $VERSION"
git -C "$TAP_DIR" push origin HEAD

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "Released $TAG successfully!"
echo "  Release: https://github.com/gajanan-hegde/DevToolbox/releases/tag/$TAG"
echo "  Install: brew tap gajanan-hegde/devtoolbox && brew install --cask devtoolbox"
