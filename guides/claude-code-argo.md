# Claude Code + Argo

**Goal:** run [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) (the
terminal-based coding agent) against Argonne's Argo Gateway instead of Anthropic's cloud, so
all inference stays inside Argonne's data-secure gateway.

Claude Code talks to an Anthropic-style Messages API. Argo exposes exactly that at
`/argoapi/v1/messages`. The only real complexity is **networking**: Argo lives on
`apps.inside.anl.gov`, which is only reachable from inside Argonne. This guide covers both
the on-network case and the off-network (laptop) case.

---

## Prerequisites

- Argo access **approved** by your DOO / AI Rep (see [reference](reference.md#access-approval-do-this-first)).
- Your **ANL domain username** (this is your Argo credential — not a secret).
- **Claude Code** installed: <https://docs.anthropic.com/en/docs/claude-code/overview>
- For the off-network path: SSH access to `homes.cels.anl.gov` and Python 3 with `aiohttp`
  (`pip install aiohttp`).

---

## Option A — On the Argonne network (or VPN)

If your machine can already reach `apps.inside.anl.gov` (on-site, or VPN from an
Argonne-managed computer), you can point Claude Code straight at Argo. No tunnel, no proxy.

```bash
ANTHROPIC_BASE_URL="https://apps.inside.anl.gov/argoapi/" \
ANTHROPIC_AUTH_TOKEN="$USER" \
CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1 \
claude
```

- `ANTHROPIC_BASE_URL` points Claude Code at Argo's Anthropic-compatible root.
- `ANTHROPIC_AUTH_TOKEN` is your **ANL username** (`$USER` if your shell user matches; set it
  explicitly otherwise, e.g. `ANTHROPIC_AUTH_TOKEN=jchilders`).
- `CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1` disables the normal claude.ai OAuth login.

Verify the endpoint is reachable first:

```bash
curl -s -H "Authorization: Bearer $USER" \
  https://apps.inside.anl.gov/argoapi/v1/models | jq '.data[].id' | head
```

### Pick a model

Inside Claude Code, use `/model` and enter an Argo slug (e.g. `claudeopus48`,
`claudesonnet46`). Claude Code works best with Claude models — start with `claudesonnet46`
(1M context, fast) or `claudeopus48` (strongest for complex agentic work). See the full list
in the [reference](reference.md#model-names-argo-slugs).

---

## Option B — Off the Argonne network (laptop)

From a personal laptop you cannot reach `apps.inside.anl.gov` directly. The pattern is:

```
Claude Code  →  local proxy (127.0.0.1:8083)  →  SSH tunnel (127.0.0.1:8082)  →  apps.inside.anl.gov:443
```

Why a proxy in front of the tunnel? The SSH tunnel terminates TLS at
`apps.inside.anl.gov`, but the local end is plain `127.0.0.1`. The small proxy
([`scripts/claude-argo-proxy.py`](../scripts/claude-argo-proxy.py)) rewrites the `Host`
header and forwards requests over the tunnel so Argo sees a correctly-addressed HTTPS
request.

### One-command setup

```bash
./scripts/argonne-claude.sh
```

This script opens the SSH tunnel (prompting for MFA), starts the local proxy, launches
Claude Code wired to it, and cleans everything up on exit. Set `ARGO_USER` if your ANL
username differs from your local `$USER`:

```bash
ARGO_USER=jchilders ./scripts/argonne-claude.sh
```

### Manual setup (three terminals)

If you'd rather see each piece, or the script fails:

**Terminal 1 — SSH tunnel** (forwards local `8082` → Argo through `homes.cels.anl.gov`):

```bash
ssh -L 8082:apps.inside.anl.gov:443 -N homes.cels.anl.gov
```

**Terminal 2 — local proxy** (listens on `8083`, forwards to the tunnel):

```bash
python3 scripts/claude-argo-proxy.py
```

**Terminal 3 — Claude Code**, pointed at the local proxy:

```bash
ANTHROPIC_BASE_URL="http://127.0.0.1:8083/argoapi/" \
ANTHROPIC_AUTH_TOKEN="$USER" \
CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1 \
claude
```

---

## Installing Claude Code on ALCF login nodes

You can also run Claude Code directly on Aurora or Polaris login nodes (Argo is reachable
from there, so no tunnel is needed — use Option A's environment variables).

**Aurora:**

```bash
module use /soft/modulefiles
module load frameworks
curl -fsSL https://claude.ai/install.sh | bash   # installs to ~/.local/bin
```

**Polaris:**

```bash
curl -fsSL https://claude.ai/install.sh | bash   # installs to ~/.local/bin
```

Make sure `~/.local/bin` is on your `PATH`, then launch with the Option A env vars.

---

## Optional: add the PBS MCP server

To let Claude Code submit and monitor PBS jobs on Aurora/Polaris, add the PBS MCP server:

```bash
git clone --recursive git@github.com:jtchilders/pbs-mcp-demo.git
```

Add it to `~/.claude.json`:

```json
{
  "mcpServers": {
    "pbs": {
      "command": "/path/to/pbs-mcp-demo/start_pbs_mcp.sh",
      "env": { "PBS_SYSTEM": "aurora" }
    }
  }
}
```

Restart Claude Code. You can now ask it to launch jobs, check queue status, etc. via the
`pbs` MCP server.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `connection refused` / hangs at startup | Not on ANL network (Option A) | Use Option B (tunnel + proxy) |
| `401` / validation error on username | Wrong `ANTHROPIC_AUTH_TOKEN` | Use your bare ANL username, no email, no quotes |
| Port `8082` already in use | Old tunnel still open | `lsof -i :8082` then kill it |
| Proxy won't start | `aiohttp` missing | `pip install aiohttp` |
| HTTP 500 "Streaming is required" | Non-streaming call with `max_tokens` > 21000 | Claude Code streams by default; if scripting, set `stream:true` — see [reference](reference.md#the-streaming--max_tokens-rule-for-claude-on-argo-important) |
| MFA prompt never appears | `ssh -f` backgrounded too early | Run the tunnel manually (Option B, Terminal 1) |

---

**Next:** compare with the [Ask Sage variant](claude-code-asksage.md) if you have an Ask Sage
key and want to work from anywhere without a VPN.
