#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER_SRC="$SCRIPT_DIR/HelperDaemon.swift"
PROTOCOL_SRC="$PROJECT_DIR/MenuBarStats/Support/HelperProtocol.swift"
HELPER_NAME="com.startbar.MenuBarStats.helper"
HELPER_DEST="/Library/PrivilegedHelperTools/$HELPER_NAME"
PLIST_SRC="$SCRIPT_DIR/$HELPER_NAME.plist"
PLIST_DEST="/Library/LaunchDaemons/$HELPER_NAME.plist"

echo "Building helper daemon..."
swiftc -O -target arm64-apple-macos13.0 \
  -sdk "$(xcrun --show-sdk-path)" \
  -o "/tmp/$HELPER_NAME" \
  "$HELPER_SRC" \
  "$PROTOCOL_SRC"

echo "Installing helper (requires admin privileges)..."
sudo mkdir -p /Library/PrivilegedHelperTools
sudo cp "/tmp/$HELPER_NAME" "$HELPER_DEST"
sudo chown root:wheel "$HELPER_DEST"
sudo chmod 544 "$HELPER_DEST"

# Unload existing daemon if present
sudo launchctl bootout system/"$HELPER_NAME" 2>/dev/null || true

sudo cp "$PLIST_SRC" "$PLIST_DEST"
sudo chown root:wheel "$PLIST_DEST"
sudo chmod 644 "$PLIST_DEST"

echo "Loading daemon..."
sudo launchctl bootstrap system "$PLIST_DEST"

echo "Done. Helper daemon is running."
