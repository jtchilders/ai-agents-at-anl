#!/bin/bash

# Configuration
REMOTE_HOST="homes.cels.anl.gov"
TUNNEL_LOCAL_PORT=8082
TUNNEL_REMOTE_HOST="apps.inside.anl.gov"
TUNNEL_REMOTE_PORT=443
PROXY_PORT=8083
CLAUDE_EXECUTABLE="${CLAUDE_EXECUTABLE:-claude}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# SSH ControlMaster settings
CONTROL_PATH="/tmp/ssh-argo-claude-$$"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track PIDs for cleanup
PROXY_PID=""

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"

    if [ -n "${PROXY_PID}" ]; then
        kill ${PROXY_PID} 2>/dev/null
    fi

    # Close the SSH tunnel via control socket
    ssh -O exit -o ControlPath="${CONTROL_PATH}" ${REMOTE_HOST} 2>/dev/null || true

    echo -e "${GREEN}Done!${NC}"
    exit 0
}

# Trap Ctrl+C and other exit signals
trap cleanup SIGINT SIGTERM EXIT

echo -e "${GREEN}Starting Argonne Claude setup...${NC}"

# Check if tunnel port is already in use
if lsof -i :${TUNNEL_LOCAL_PORT} >/dev/null 2>&1; then
    echo -e "${RED}Port ${TUNNEL_LOCAL_PORT} is already in use.${NC}"
    echo -e "${YELLOW}Check for an existing SSH tunnel: lsof -i :${TUNNEL_LOCAL_PORT}${NC}"
    exit 1
fi

# Step 1: Start SSH tunnel (ssh -f backgrounds after MFA authentication completes)
echo -e "${YELLOW}Starting SSH tunnel to ${TUNNEL_REMOTE_HOST}...${NC}"
echo -e "${YELLOW}(You may need to complete MFA authentication)${NC}"

ssh -f -N \
    -o ControlMaster=yes \
    -o ControlPath="${CONTROL_PATH}" \
    -L ${TUNNEL_LOCAL_PORT}:${TUNNEL_REMOTE_HOST}:${TUNNEL_REMOTE_PORT} \
    ${REMOTE_HOST}

if [ $? -ne 0 ]; then
    echo -e "${RED}SSH tunnel failed to start. Check your credentials and MFA.${NC}"
    exit 1
fi

echo -e "${GREEN}SSH tunnel established (port ${TUNNEL_LOCAL_PORT})!${NC}"

# Step 2: Start local proxy
echo -e "${YELLOW}Starting local proxy...${NC}"

python3 "${SCRIPT_DIR}/claude-argo-proxy.py" &
PROXY_PID=$!

sleep 2

if ! kill -0 ${PROXY_PID} 2>/dev/null; then
    echo -e "${RED}Local proxy failed to start. Is aiohttp installed? (pip install aiohttp)${NC}"
    exit 1
fi

echo -e "${GREEN}Local proxy running (port ${PROXY_PORT})!${NC}"

# Step 3: Launch Claude Code
echo -e "${GREEN}Launching Claude Code...${NC}"
ANTHROPIC_BASE_URL="http://127.0.0.1:${PROXY_PORT}/argoapi/" \
    ANTHROPIC_AUTH_TOKEN=$USER \
    CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1 \
    ${CLAUDE_EXECUTABLE}

# The cleanup function will be called automatically by the trap on exit
