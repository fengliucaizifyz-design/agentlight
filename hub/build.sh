#!/bin/bash
set -e

# Build the AgentLight hub from source.
# Prerequisites: macOS with Xcode Command Line Tools (swiftc).

cd "$(dirname "$0")"

APP="AgentLight.app"
BIN="$APP/Contents/MacOS/AgentLight"

echo "Building AgentLight hub..."
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -o "$BIN" main.swift

echo "Done → $BIN"
echo "Run: open $APP   (or ./$BIN to see logs in the terminal)"
