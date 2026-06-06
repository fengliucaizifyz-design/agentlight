#!/bin/bash
set -euo pipefail

# package-release.sh — Build a distributable, ad-hoc-signed AgentLight.app.
#
# Produces a universal (arm64 + x86_64) binary, ad-hoc signs the bundle, and
# packages it as a zip ready to attach to a GitHub Release. Maintainer-only.
#
# NOTE on signing: this project has no Apple Developer ID certificate, so the
# app is *ad-hoc* signed (`codesign -s -`), NOT notarized. Downloaders must
# clear the quarantine attribute on first launch — the install script and docs
# handle this. Ad-hoc signing still gives the bundle a stable code identity so
# macOS doesn't kill it the way it does an unsigned binary.
#
# Usage:  ./scripts/package-release.sh [version]
#   version  Optional tag for the output filename (default: dev).

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUB="$REPO_DIR/hub"
APP="$HUB/AgentLight.app"
BIN="$APP/Contents/MacOS/AgentLight"
DIST="$REPO_DIR/dist"
VERSION="${1:-dev}"
DEPLOY_TARGET="12.0"

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[package]${NC} $1"; }

command -v swiftc >/dev/null || { echo "swiftc not found (install Xcode CLT)"; exit 1; }

info "Building universal binary (arm64 + x86_64)…"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target "arm64-apple-macosx${DEPLOY_TARGET}"  -o /tmp/AgentLight-arm64  "$HUB/main.swift"
swiftc -O -target "x86_64-apple-macosx${DEPLOY_TARGET}" -o /tmp/AgentLight-x86_64 "$HUB/main.swift"
lipo -create -output "$BIN" /tmp/AgentLight-arm64 /tmp/AgentLight-x86_64
rm -f /tmp/AgentLight-arm64 /tmp/AgentLight-x86_64
info "Architectures: $(lipo -archs "$BIN")"

info "Ad-hoc signing the bundle…"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=2 "$APP"

info "Packaging zip…"
mkdir -p "$DIST"
# Version-less asset name so the GitHub "latest/download/<asset>" URL is stable
# across releases (the release tag carries the version).
ZIP="$DIST/AgentLight-macos.zip"
rm -f "$ZIP"
# Use `zip -X` rather than ditto: macOS stamps a SIP-protected
# com.apple.provenance xattr on every file, which ditto would archive as
# AppleDouble (._*) sidecars. `-X` drops extra attributes entirely. The code
# signature lives in the Mach-O and _CodeSignature/CodeResources (real files),
# so it survives the round-trip intact.
( cd "$HUB" && zip -r -X -q "$ZIP" "$(basename "$APP")" )

info "✅ Done → $ZIP"
ls -lh "$ZIP"
