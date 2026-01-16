#!/bin/bash

# Configuration
REMOTE_HOST="homes.cels.anl.gov"
REMOTE_PROXY_DIR="~/lmtools-main"
LOCAL_PORT=8082
MAX_PORT_ATTEMPTS=5
ARGO_USER="jchilders"
MODEL="claudeopus45"

# SSH ControlMaster settings
CONTROL_PATH="/tmp/ssh-control-argonne-%r@%h:%p"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    
    # Kill the proxy SSH connection
    if [ ! -z "${SSH_PID}" ]; then
        kill ${SSH_PID} 2>/dev/null
    fi
    
    # Kill any remaining apiproxy processes
    ssh -o ControlPath="${CONTROL_PATH}" ${REMOTE_HOST} "pkill -f apiproxy" 2>/dev/null || true
    
    # Close the control master connection
    ssh -O exit -o ControlPath="${CONTROL_PATH}" ${REMOTE_HOST} 2>/dev/null || true
    
    sleep 1
    echo -e "${GREEN}Done!${NC}"
    exit 0
}

# Trap Ctrl+C and other exit signals
trap cleanup SIGINT SIGTERM EXIT

echo -e "${GREEN}Starting Argonne Claude proxy setup...${NC}"

# Establish ControlMaster connection
echo -e "${YELLOW}Establishing SSH connection to ${REMOTE_HOST}...${NC}"
echo -e "${YELLOW}(You may need to complete MFA authentication)${NC}"

# Start the control master in the background
ssh -fN \
    -o ControlMaster=yes \
    -o ControlPath="${CONTROL_PATH}" \
    -o ControlPersist=10m \
    ${REMOTE_HOST}

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to establish SSH connection. Check your credentials and MFA.${NC}"
    exit 1
fi

echo -e "${GREEN}SSH connection established!${NC}"

# Kill any existing SSH tunnels on this port
echo -e "${YELLOW}Cleaning up any existing tunnels...${NC}"
pkill -f "ssh.*-L.*:localhost:.*${REMOTE_HOST}" 2>/dev/null || true

# Kill any existing apiproxy processes on remote server
echo -e "${YELLOW}Cleaning up any existing remote proxy processes...${NC}"
ssh -o ControlPath="${CONTROL_PATH}" ${REMOTE_HOST} "pkill -f apiproxy" 2>/dev/null || true
sleep 2

# Try to start proxy with incremental port numbers
SUCCESS=false
ATTEMPT=0
CURRENT_PORT=${LOCAL_PORT}

while [ ${ATTEMPT} -lt ${MAX_PORT_ATTEMPTS} ] && [ "${SUCCESS}" = "false" ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    echo -e "${YELLOW}Attempt ${ATTEMPT}/${MAX_PORT_ATTEMPTS}: Trying port ${CURRENT_PORT}...${NC}"
    
    # Create log file with timestamp and port
    LOG_FILE="/tmp/argonne-proxy-${CURRENT_PORT}-$(date +%Y%m%d-%H%M%S).log"
    
    # Start SSH tunnel with remote proxy in background (using ControlMaster)
    echo -e "${YELLOW}Starting SSH tunnel and remote proxy...${NC}"
    echo -e "${YELLOW}Proxy output logging to: ${LOG_FILE}${NC}"
    ssh -o ControlPath="${CONTROL_PATH}" \
        -L ${CURRENT_PORT}:localhost:${CURRENT_PORT} \
        ${REMOTE_HOST} \
        "cd ${REMOTE_PROXY_DIR} && ./bin/apiproxy --argo-user=${ARGO_USER} -model ${MODEL} --port ${CURRENT_PORT}" \
        > "${LOG_FILE}" 2>&1 &
    
    SSH_PID=$!
    
    # Give the proxy time to start
    echo -e "${YELLOW}Waiting for proxy to initialize...${NC}"
    sleep 4
    
    # Check if SSH tunnel is still running
    if ! kill -0 ${SSH_PID} 2>/dev/null; then
        echo -e "${RED}SSH tunnel failed to start${NC}"
        
        # Check if it was a port conflict
        if grep -q "address already in use" "${LOG_FILE}" 2>/dev/null; then
            echo -e "${YELLOW}Port ${CURRENT_PORT} is already in use, trying next port...${NC}"
            CURRENT_PORT=$((CURRENT_PORT + 1))
            continue
        else
            echo -e "${YELLOW}Check the log file for details: ${LOG_FILE}${NC}"
            if [ -f "${LOG_FILE}" ]; then
                echo -e "${YELLOW}Last few lines of log:${NC}"
                tail -10 "${LOG_FILE}"
            fi
            exit 1
        fi
    fi
    
    # Test if proxy is responding
    echo -e "${YELLOW}Testing proxy connection...${NC}"
    if curl -s --max-time 5 http://localhost:${CURRENT_PORT}/v1/models >/dev/null 2>&1; then
        echo -e "${GREEN}Proxy is responding on port ${CURRENT_PORT}!${NC}"
        SUCCESS=true
    else
        echo -e "${YELLOW}Proxy may still be starting up (this is normal)${NC}"
        SUCCESS=true
    fi
done

if [ "${SUCCESS}" = "false" ]; then
    echo -e "${RED}Failed to start proxy after ${MAX_PORT_ATTEMPTS} attempts${NC}"
    exit 1
fi

# Launch Claude Code
echo -e "${GREEN}Launching Claude Code with proxy on port ${CURRENT_PORT}...${NC}"
CLAUDE_CODE_TMPDIR="/tmp/${USER}" ANTHROPIC_AUTH_TOKEN=$USER ANTHROPIC_BASE_URL=http://localhost:${CURRENT_PORT} claude

# The cleanup function will be called automatically by the trap on exit
