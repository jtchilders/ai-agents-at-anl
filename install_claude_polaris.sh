#!/bin/bash
# Install Claude Code on Polaris (ALCF)
#
# The native installer's "claude install" subcommand crashes (SIGABRT) on the
# SLES 15 login nodes. This script downloads the binary, verifies its checksum,
# and places it manually.
#
# Usage: bash install_claude_polaris.sh

set -e

GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
DOWNLOAD_DIR="$HOME/.claude/downloads"
INSTALL_DIR="$HOME/.local/share/claude"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$DOWNLOAD_DIR" "$INSTALL_DIR" "$BIN_DIR"

# 1. Get latest version
echo "Fetching latest version..."
VERSION=$(curl -fsSL "$GCS_BUCKET/latest")
echo "Latest version: ${VERSION}"

# 2. Download the binary
BINARY="$DOWNLOAD_DIR/claude-${VERSION}-linux-x64"
if [ -f "$BINARY" ]; then
  echo "Binary already downloaded."
else
  echo "Downloading Claude Code v${VERSION}..."
  curl -fsSL -o "$BINARY" "$GCS_BUCKET/${VERSION}/linux-x64/claude"
fi
chmod +x "$BINARY"

# 3. Verify checksum
echo "Verifying checksum..."
MANIFEST=$(curl -fsSL "$GCS_BUCKET/${VERSION}/manifest.json")
if command -v jq >/dev/null 2>&1; then
  EXPECTED=$(echo "$MANIFEST" | jq -r '.platforms["linux-x64"].checksum')
else
  # Fallback: extract checksum with grep/sed
  EXPECTED=$(echo "$MANIFEST" | grep -o '"linux-x64"[^}]*"checksum"[[:space:]]*:[[:space:]]*"[a-f0-9]\{64\}"' | grep -o '[a-f0-9]\{64\}')
fi

ACTUAL=$(sha256sum "$BINARY" | cut -d' ' -f1)

if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "ERROR: Checksum mismatch!" >&2
  echo "  Expected: $EXPECTED" >&2
  echo "  Actual:   $ACTUAL" >&2
  rm -f "$BINARY"
  exit 1
fi
echo "Checksum OK."

# 4. Install
cp "$BINARY" "$INSTALL_DIR/claude"
chmod +x "$INSTALL_DIR/claude"
ln -sf "$INSTALL_DIR/claude" "$BIN_DIR/claude"

# 5. Verify
if command -v claude >/dev/null 2>&1; then
  echo ""
  echo "Claude Code $(claude --version) installed successfully."
  echo "Binary: $INSTALL_DIR/claude"
  echo "Symlink: $BIN_DIR/claude"
else
  echo ""
  echo "Installed, but 'claude' is not on PATH."
  echo "Add this to your ~/.bashrc:"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# 6. Cleanup download
rm -f "$BINARY"
echo "Done."
