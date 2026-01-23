# ai-agents-at-anl
My notes for running against Argo at Argonne for IDE integration and agentic workflows.



# Using Argo in Claude Code on LCF Login Nodes

This assumes you have access to `homes.cels.anl.gov` and have access to the Aurora login nodes.

## Setup proxy on CELS homes

Install lmtools-main (I found `go` was already installed on `homes.cels.anl.gov`).

```bash

wget https://github.com/jxy/lmtools/archive/refs/heads/main.zip
unzip main.zip
cd lmtools-main
make
export PATH=$PATH:$(pwd)/bin
```

## Install Claude Code on Aurora Login Nodes

```bash
module use /soft/modulefiles
module load frameworks

# installs in .local/bin
curl -fsSL https://claude.ai/install.sh | bash
```

## Run Claude Code script

This script will remotely launch the proxy on `homes.cels.anl.gov` and then launch Claude Code with the proxy configured.

```bash
./argonne-claude.sh
```


## Run PBS MCP Server as well

```bash

git clone --recursivegit@github.com:jtchilders/pbs-mcp-demo.git

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
