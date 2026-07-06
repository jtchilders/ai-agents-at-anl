#!/bin/bash

# Configuration
REMOTE_HOST=homes-gce #"homes.cels.anl.gov"
TUNNEL_LOCAL_PORT=8557
TUNNEL_REMOTE_HOST="apps-dev.inside.anl.gov"
TUNNEL_REMOTE_PORT=443
PROXY_PORT=8558
OPENCODE_EXECUTABLE="${OPENCODE_EXECUTABLE:-opencode}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# SSH ControlMaster settings
CONTROL_PATH="/tmp/ssh-argo-opencode-$$"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track PIDs for cleanup
PROXY_PID=""
CLEANUP_DONE=0

# Cleanup function
cleanup() {
    [ "${CLEANUP_DONE}" = "1" ] && return
    CLEANUP_DONE=1

    echo -e "\n${YELLOW}Cleaning up...${NC}"

    if [ -n "${PROXY_PID}" ]; then
        kill ${PROXY_PID} 2>/dev/null
    fi

    # Kill the SSH master by matching its unique ControlPath. Avoids `ssh -O exit`
    # because some OpenSSH builds prompt for the key passphrase even with BatchMode.
    pkill -f "ControlPath=${CONTROL_PATH}" 2>/dev/null
    rm -f "${CONTROL_PATH}" 2>/dev/null

    echo -e "${GREEN}Done!${NC}"
    exit 0
}

# Trap Ctrl+C and other exit signals
trap cleanup SIGINT SIGTERM EXIT

# First-time setup notice
echo -e "${YELLOW}NOTE: A sample opencode config is provided at:${NC}"
echo -e "${YELLOW}  ${SCRIPT_DIR}/opencode.json${NC}"
echo -e "${YELLOW}If you haven't already, copy it to ~/.config/opencode/opencode.json${NC}"
echo -e "${YELLOW}and edit the Authorization header to your Argonne domain username:${NC}"
echo -e "${YELLOW}  cp ${SCRIPT_DIR}/opencode.json ~/.config/opencode/opencode.json${NC}"
echo ""

echo -e "${GREEN}Starting Argonne opencode setup...${NC}"

# Check if tunnel port is already in use; auto-clean stale tunnels from prior runs
if lsof -i :${TUNNEL_LOCAL_PORT} >/dev/null 2>&1; then
    STALE_PIDS=$(pgrep -f "ssh.*-L ${TUNNEL_LOCAL_PORT}:${TUNNEL_REMOTE_HOST}")
    if [ -n "${STALE_PIDS}" ]; then
        echo -e "${YELLOW}Killing stale tunnel from previous run (PID ${STALE_PIDS})...${NC}"
        kill ${STALE_PIDS} 2>/dev/null
        sleep 1
    fi
    if lsof -i :${TUNNEL_LOCAL_PORT} >/dev/null 2>&1; then
        echo -e "${RED}Port ${TUNNEL_LOCAL_PORT} is still in use by something else.${NC}"
        echo -e "${YELLOW}Check: lsof -i :${TUNNEL_LOCAL_PORT}${NC}"
        exit 1
    fi
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

python3 "${SCRIPT_DIR}/opencode-argo-proxy.py" \
    --listen-port ${PROXY_PORT} \
    --target-port ${TUNNEL_LOCAL_PORT} &
PROXY_PID=$!

sleep 2

if ! kill -0 ${PROXY_PID} 2>/dev/null; then
    echo -e "${RED}Local proxy failed to start. Is aiohttp installed? (pip install aiohttp)${NC}"
    exit 1
fi

echo -e "${GREEN}Local proxy running (port ${PROXY_PORT})!${NC}"
echo -e "${YELLOW}Point your opencode config baseURL to: http://127.0.0.1:${PROXY_PORT}/argoapi/v1${NC}"

# Step 3: Launch opencode
echo -e "${GREEN}Launching opencode...${NC}"
OPENCODE_PROXY_PORT=${PROXY_PORT} ${OPENCODE_EXECUTABLE}

# The cleanup function will be called automatically by the trap on exit
