# ai-agents-at-anl
My notes for running against Argo at Argonne for IDE integration and agentic workflows.



# Using Argo in Claude Code on LCF Login Nodes

This assumes you have setup a valid SSH key for logging into `homes.cels.anl.gov` and have access to the Aurora login nodes.

## Setup proxy on CELS homes

Install go and add it to your path.

```bash
ssh homes.cels.anl.gov
wget https://go.dev/dl/go1.25.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.25.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

Install lmtools-main

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

This script will remotely launch the proxy on homes.cels.anl.gov and then launch Claude Code with the proxy configured.

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