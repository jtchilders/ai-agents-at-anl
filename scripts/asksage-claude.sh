#!/bin/bash
# Launch Claude Code against Ask Sage as the inference backend.
#
# Ask Sage exposes an Anthropic-compatible Messages API over the public internet, so no
# VPN or tunnel is needed. Reads your Ask Sage API key from $ASKSAGE_API_KEY, falling back
# to ~/.config/asksage/key.
#
# See guides/claude-code-asksage.md.
#
#   export ASKSAGE_API_KEY="sk-..."     # or put the key in ~/.config/asksage/key
#   ./scripts/asksage-claude.sh

# Match this to the instance your organization approved. Only the middle segment changes;
# the api. prefix and /server/anthropic suffix are stable across deployments.
ASKSAGE_BASE_URL="${ASKSAGE_BASE_URL:-https://api.asksage.anl.gov/server/anthropic}"
CLAUDE_EXECUTABLE="${CLAUDE_EXECUTABLE:-claude}"
KEY_FILE="${HOME}/.config/asksage/key"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Resolve the API key
if [ -z "${ASKSAGE_API_KEY}" ] && [ -f "${KEY_FILE}" ]; then
    ASKSAGE_API_KEY="$(cat "${KEY_FILE}")"
fi

if [ -z "${ASKSAGE_API_KEY}" ]; then
    echo -e "${RED}No Ask Sage API key found.${NC}"
    echo -e "${YELLOW}Set ASKSAGE_API_KEY, or write your key to ${KEY_FILE} (chmod 600).${NC}"
    exit 1
fi

# Quick reachability + auth check
echo -e "${YELLOW}Checking Ask Sage endpoint...${NC}"
http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 \
    "${ASKSAGE_BASE_URL}/v1/models" -H "x-api-key: ${ASKSAGE_API_KEY}")
if [ "${http_code}" != "200" ]; then
    echo -e "${RED}Ask Sage /v1/models returned HTTP ${http_code}.${NC}"
    echo -e "${YELLOW}401 = bad key; 404 = instance lacks the model-list endpoint; check the base URL.${NC}"
    exit 1
fi
echo -e "${GREEN}Ask Sage reachable. Launching Claude Code...${NC}"

ANTHROPIC_BASE_URL="${ASKSAGE_BASE_URL}" \
    ANTHROPIC_AUTH_TOKEN="${ASKSAGE_API_KEY}" \
    CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1 \
    ${CLAUDE_EXECUTABLE}
