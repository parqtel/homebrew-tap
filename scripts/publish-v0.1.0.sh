#!/usr/bin/env bash
# ── publish-v0.1.0.sh ───────────────────────────────────────────────────
# One-shot bootstrap script: publishes the v0.1.0 tap release with the
# four prebuilt parqtel-oss tarballs. Run this once after the formula
# is on `main`. Subsequent versions are published automatically by
# .github/workflows/build-tarballs.yml.
#
# Prereqs: `gh auth login` (or any PAT with `repo` scope on
# parqtel/homebrew-tap), and the v0.1.0 release assets staged in
# /tmp/parqtel-release/v0.1.0/ (or any directory you point ASSETS at).
#
# Usage:
#   ./scripts/publish-v0.1.0.sh                 # default asset path
#   ASSETS=/path/to/assets ./scripts/publish-v0.1.0.sh
#
# After this script, the audit CI will go green and the formula can
# be tested by `brew install --build-from-source parqtel/parqtel/parqtel-oss`.

set -euo pipefail

REPO="parqtel/homebrew-tap"
VERSION="${VERSION:-0.1.0}"
ASSETS="${ASSETS:-/tmp/parqtel-release/v${VERSION}}"

if [ ! -d "$ASSETS" ]; then
  echo "::error::Asset directory not found: $ASSETS"
  echo "Set ASSETS=/path/to/tarballs to override."
  exit 1
fi

REQUIRED=(
  "parqtel-oss-darwin-arm64.tar.gz"
  "parqtel-oss-darwin-amd64.tar.gz"
  "parqtel-oss-linux-arm64.tar.gz"
  "parqtel-oss-linux-amd64.tar.gz"
)
for f in "${REQUIRED[@]}"; do
  if [ ! -f "$ASSETS/$f" ]; then
    echo "::error::Missing asset: $ASSETS/$f"
    exit 1
  fi
done

echo "==> Checking gh auth"
if ! gh auth status >/dev/null 2>&1; then
  echo "::error::gh is not authenticated. Run: gh auth login"
  exit 1
fi

echo "==> Creating release v${VERSION} in $REPO"
UPSTREAM_REF=$(git ls-remote https://github.com/parqtel/parqtel-oss.git "refs/tags/v${VERSION}" 2>/dev/null | awk '{print $1}' | head -c 12 || echo "unknown")
gh release create "v${VERSION}" \
  --repo "$REPO" \
  --title "parqtel-oss v${VERSION} binaries" \
  --notes "$(cat <<EOF
Prebuilt parqtel-oss binaries for the Homebrew tap.

These tarballs are consumed by the \`parqtel-oss\` Homebrew formula in
${REPO}. After this release is published, \`brew audit --online\`
will go green and \`brew install parqtel/parqtel/parqtel-oss\`
will download the matching platform tarball.

Built from parqtel/parqtel-oss @ v${VERSION} (commit ${UPSTREAM_REF}…).

Subsequent versions are published automatically by
.github/workflows/build-tarballs.yml when an upstream \`v*\` tag
is pushed to parqtel/parqtel-oss (or daily via the schedule poll).
EOF
)" \
  --target main \
  "${REQUIRED[@]/#/$ASSETS/}" \
  "${REQUIRED[@]/#/$ASSETS/.sha256}"

echo
echo "==> Verifying"
sleep 2
curl -sSI "https://github.com/${REPO}/releases/download/v${VERSION}/parqtel-oss-darwin-arm64.tar.gz" \
  | head -1

echo
echo "==> Done. Next steps:"
echo "  1. Visit https://github.com/${REPO}/releases/tag/v${VERSION} to confirm assets"
echo "  2. brew tap ${REPO%/*}/$(basename "$REPO") && brew install parqtel-oss"
echo "  3. From v0.2.0 onward the build-tarballs workflow does this automatically"
