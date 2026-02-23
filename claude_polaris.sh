#!/bin/bash
# Wrapper script to run Claude Code via Apptainer on Polaris
#
# Usage: bash claude_polaris.sh [claude arguments...]
# Example: bash claude_polaris.sh
# Example: bash claude_polaris.sh -p "hello"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SANDBOX="$SCRIPT_DIR/claude-sandbox"

# Load required modules
module use /soft/modulefiles 2>/dev/null
module load spack-pe-base 2>/dev/null
module load apptainer 2>/dev/null

# Build sandbox if it doesn't exist
if [ ! -d "$SANDBOX" ]; then
  echo "Building Claude Code container (one-time setup)..."
  apptainer build --sandbox "$SANDBOX" docker://node:22-slim
  apptainer exec --writable "$SANDBOX" npm install -g @anthropic-ai/claude-code
  echo "Done."
fi

exec apptainer exec \
  --bind $HOME:$HOME \
  --env ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
  --env ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-}" \
  --env ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-}" \
  --env CLAUDE_CODE_USE_BEDROCK="${CLAUDE_CODE_USE_BEDROCK:-}" \
  --env CLAUDE_CODE_TMPDIR="${CLAUDE_CODE_TMPDIR:-}" \
  --env TERM="${TERM:-xterm-256color}" \
  "$SANDBOX" \
  claude "$@"
