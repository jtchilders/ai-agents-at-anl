# ai-agents-at-anl
Notes for running Claude Code with Argo at Argonne for IDE integration and agentic workflows.


# Using Argo in Claude Code

This guide covers running Claude Code against the Argo LLM API from machines outside the ANL internal network (e.g., your laptop). It also covers installing Claude Code on Aurora and Polaris login nodes.

## Prerequisites

- SSH access to `homes.cels.anl.gov`
- Python 3 with `aiohttp` installed (`pip install aiohttp`)
- Claude Code installed ([install instructions](https://docs.anthropic.com/en/docs/claude-code/overview))

## Quick Start (3 steps)

Open three terminals:

**Terminal 1** — Start the SSH tunnel:
```bash
ssh -L 8082:apps.inside.anl.gov:443 -N homes.cels.anl.gov
```

**Terminal 2** — Start the local proxy:
```bash
python claude-argo-proxy.py
```

**Terminal 3** — Launch Claude Code:
```bash
ANTHROPIC_BASE_URL="http://127.0.0.1:8083/argoapi/" ANTHROPIC_AUTH_TOKEN=$USER CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1 claude
```

Or use the convenience script that handles all three steps:
```bash
./argonne-claude.sh
```

## How It Works

1. The SSH tunnel forwards local port 8082 to `apps.inside.anl.gov:443` through `homes.cels.anl.gov`
2. `claude-argo-proxy.py` listens on port 8083, rewrites requests, and forwards them through the tunnel on port 8082
3. Claude Code sends API requests to the local proxy, which routes them to the Argo API


## Install Claude Code on Aurora Login Nodes

```bash
module use /soft/modulefiles
module load frameworks

# installs in .local/bin
curl -fsSL https://claude.ai/install.sh | bash
```

## Install Claude Code on Polaris Login Nodes

```bash
# installs in .local/bin
curl -fsSL https://claude.ai/install.sh | bash
```


## Run PBS MCP Server as well

```bash
git clone --recursive git@github.com:jtchilders/pbs-mcp-demo.git
```

Need to add MCP to Claude config.

Edit `~/.claude.json` and add the following:

```json
{
   "mcpServers": {
      "pbs": {
         "command": "/path/to/pbs-mcp-demo/start_pbs_mcp.sh"
      },
      "env": {
         "PBS_SYSTEM": "aurora"
      }
   }
}
```

Then restart Claude Code.

Now you can use the `pbs` MCP server in Claude Code to launch jobs, check status, etc.
