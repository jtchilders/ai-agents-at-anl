# Installing Claude Code on Polaris (ALCF)

The native installer's `claude install` subcommand crashes (SIGABRT) on the SLES 15 login nodes. The `install_claude_polaris.sh` script works around this by downloading the binary, verifying its checksum, and placing it manually.

## Quick Start

```bash
bash install_claude_polaris.sh
```

This will:
1. Download the latest Claude Code binary
2. Verify the SHA-256 checksum
3. Install to `~/.local/share/claude/claude`
4. Create a symlink at `~/.local/bin/claude`

`~/.local/bin` should already be on your `PATH` on Polaris. If not, add to your `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Updating

Re-run the script to download and install the latest version.

## Cleanup

Remove any core dumps from failed native installer attempts:

```bash
rm -f ~/core.* ~/claude-code-debug/core.*
```
