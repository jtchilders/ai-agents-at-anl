# Running Claude Code on Polaris (ALCF)

The native Claude Code binary crashes (SIGABRT) on the SLES 15 login nodes due to a Bun runtime compatibility issue. The workaround is to run Claude Code inside an Apptainer container using the npm/Node.js version.

## Quick Start

```bash
bash claude_polaris.sh
```

On first run, this builds an Apptainer sandbox with Node.js and Claude Code (~30 seconds). Subsequent runs use the cached sandbox.

## Usage with argonne-claude.sh

Set the `CLAUDE_EXECUTABLE` environment variable to use the Apptainer wrapper:

```bash
export CLAUDE_EXECUTABLE=~/path/to/claude_polaris.sh
./argonne-claude.sh
```

Or add the export to your `~/.bashrc` on Polaris.

## Updating

Remove the sandbox and re-run to get the latest version:

```bash
rm -rf claude-sandbox
bash claude_polaris.sh
```

## Convenience Alias

Add to your `~/.bashrc` on Polaris:

```bash
alias claude='bash ~/path/to/claude_polaris.sh'
```
