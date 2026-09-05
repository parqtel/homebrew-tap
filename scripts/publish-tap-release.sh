#!/usr/bin/env bash
# ── publish-tap-release.sh ──────────────────────────────────────────────
# Publish (or update) a parqtel-tap release with the four prebuilt
# parqtel-oss tarballs. Safe to re-run; will:
#   * create the release if it does not exist
#   * upload assets, overwriting any with the same name
#   * leave assets that do not conflict untouched
#
# Prereqs: `gh auth login` (or `GITHUB_TOKEN` in env with `repo` scope
# on parqtel/homebrew-tap), and the assets staged in a local
# directory (default /tmp/parqtel-release/v<version>).
#
# Usage:
#   ./scripts/publish-tap-release.sh                      # version 0.1.0
#   VERSION=0.2.0 ./scripts/publish-tap-release.sh
#   VERSION=0.2.0 ASSETS=/path/to/assets ./scripts/publish-tap-release.sh

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
  "parqtel-oss-v${VERSION}-darwin-arm64.tar.gz"
  "parqtel-oss-v${VERSION}-darwin-amd64.tar.gz"
  "parqtel-oss-v${VERSION}-linux-arm64.tar.gz"
  "parqtel-oss-v${VERSION}-linux-amd64.tar.gz"
)
for f in "${REQUIRED[@]}"; do
  if [ ! -f "$ASSETS/$f" ]; then
    echo "::error::Missing asset: $ASSETS/$f"
    exit 1
  fi
  if [ ! -f "$ASSETS/$f.sha256" ]; then
    echo "::error::Missing sha256 sidecar: $ASSETS/$f.sha256"
    exit 1
  fi
done

echo "==> Checking gh auth"
if ! gh auth status >/dev/null 2>&1; then
  echo "::error::gh is not authenticated. Run: gh auth login"
  exit 1
fi

# Pre-compute the full asset paths (tarballs + sha256 sidecars) so we
# don't depend on bash parameter-expansion tricks. The previous
# version used ${REQUIRED[@]/#/$ASSETS/.sha256} which substituted
# `$ASSETS/.sha256` at the *prefix* of each item, producing paths
# like `$ASSETS/.sha256parqtel-oss-...tar.gz` — clearly broken.
TARBALL_PATHS=()
SHASUM_PATHS=()
for f in "${REQUIRED[@]}"; do
  TARBALL_PATHS+=("$ASSETS/$f")
  SHASUM_PATHS+=("$ASSETS/$f.sha256")
done

# Inspect existing release
if gh release view "v${VERSION}" --repo "$REPO" >/dev/null 2>&1; then
  echo "==> Release v${VERSION} already exists; will overwrite assets of the same name"
  # `gh release upload` with --clobber overwrites any existing files of
  # the same name and is a no-op for new ones.
  gh release upload "v${VERSION}" --repo "$REPO" --clobber \
    "${TARBALL_PATHS[@]}" \
    "${SHASUM_PATHS[@]}"
else
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
    "${TARBALL_PATHS[@]}" \
    "${SHASUM_PATHS[@]}"
fi

# Delete obsolete assets from a previous scheme (parqtel-oss-<platform>.tar.gz
# without the version in the filename). These would otherwise confuse
# `brew audit --online` and manual `curl` users.
OBSOLETE=(
  "parqtel-oss-darwin-arm64.tar.gz"
  "parqtel-oss-darwin-amd64.tar.gz"
  "parqtel-oss-linux-arm64.tar.gz"
  "parqtel-oss-linux-amd64.tar.gz"
)
for f in "${OBSOLETE[@]}"; do
  # `gh release delete-asset` takes the asset NAME (not id) and fails
  # if the asset does not exist, so gate on its presence first.
  if gh release view "v${VERSION}" --repo "$REPO" --json assets \
     --jq ".assets[].name" 2>/dev/null | grep -qx "$f"; then
    echo "==> Deleting obsolete asset: $f"
    gh release delete-asset "v${VERSION}" "$f" --repo "$REPO" --yes || true
  fi
  if gh release view "v${VERSION}" --repo "$REPO" --json assets \
     --jq ".assets[].name" 2>/dev/null | grep -qx "$f.sha256"; then
    echo "==> Deleting obsolete asset: $f.sha256"
    gh release delete-asset "v${VERSION}" "$f.sha256" --repo "$REPO" --yes || true
  fi
done

echo
echo "==> Verifying"
sleep 2
curl -sSI "https://github.com/${REPO}/releases/download/v${VERSION}/parqtel-oss-v${VERSION}-darwin-arm64.tar.gz" \
  | head -1

echo
echo "==> Done. Next steps:"
echo "  1. Visit https://github.com/${REPO}/releases/tag/v${VERSION} to confirm assets"
echo "  2. brew tap ${REPO%/*}/$(basename "$REPO") && brew install parqtel-oss"
echo "  3. From v0.2.0 onward the build-tarballs workflow does this automatically"
