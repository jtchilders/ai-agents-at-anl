# Claude Code + Argo

**Goal:** run [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) (the
terminal-based coding agent) against Argonne's Argo Gateway instead of Anthropic's cloud, so
all inference stays inside Argonne's data-secure gateway.

Claude Code talks to an Anthropic-style Messages API. Argo exposes exactly that at
`/argoapi/v1/messages`. The complexity is entirely **networking**: Argo lives on
`apps.inside.anl.gov`, reachable only from inside Argonne. This guide has two paths:

- **On the Argonne network / VPN** → point Claude Code straight at Argo (no proxy).
- **Off-network, or on an ALCF login/compute node** → use **[argo-shim](https://github.com/n-getty/argo-shim)**,
  a maintained tool that builds the SSH tunnel, runs a local proxy, and wires up Claude Code
  for you.

> **Why argo-shim instead of a hand-rolled proxy?** We previously shipped our own SSH-tunnel +
> proxy scripts here. `argo-shim` (published on PyPI, `pip install argo-shim`) does the same
> job and more, and is actively maintained, so we now recommend it and no longer ship our own
> scripts. Beyond tunneling it: auto-writes `~/.claude/settings.json`, forces `stream:true` to
> dodge Argo's non-stream 500, derives a stable per-user port, supports compute nodes and a
> Mac relay — and, importantly, has **SSH-failure protection** that stops a restart loop from
> getting a shared login node's IP blocked by CSPO (see the safety note below).

---

## Prerequisites

- Argo access **approved** by your DOO / AI Rep (see [reference](reference.md#access-approval-do-this-first)).
- Your **ANL domain username** (this is your Argo credential — not a secret).
- **Claude Code** installed: `curl -fsSL https://claude.ai/install.sh | bash`
- For the argo-shim path: **SSH access to CELS** with a key uploaded to
  <https://accounts.cels.anl.gov>, and Python 3.8+.

---

## Option A — On the Argonne network (or VPN)

If your machine can already reach `apps.inside.anl.gov` (on-site, or VPN from an
Argonne-managed computer), point Claude Code straight at Argo — no tunnel, no shim.

First verify reachability:

```bash
curl -s -H "Authorization: Bearer $USER" \
  https://apps.inside.anl.gov/argoapi/v1/models | jq '.data[].id' | head
```

Then launch:

```bash
ANTHROPIC_BASE_URL="https://apps.inside.anl.gov/argoapi/" \
ANTHROPIC_AUTH_TOKEN="$USER" \
CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1 \
claude
```

- `ANTHROPIC_AUTH_TOKEN` is your **ANL username** (`$USER` if your shell user matches; set it
  explicitly otherwise, e.g. `ANTHROPIC_AUTH_TOKEN=jchilders`).
- `CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1` disables the normal claude.ai OAuth login.

---

## Option B — Off-network, or on an ALCF node (use argo-shim)

[argo-shim](https://github.com/n-getty/argo-shim) reaches Argo over an SSH tunnel to CELS,
runs a local HTTP→HTTPS proxy, and configures Claude Code automatically.

### One-time SSH setup (do this first — do not skip)

argo-shim's tunnel only works if CELS recognizes your SSH key. Set it up **and verify it**
before running argo-shim:

```bash
ssh-keygen -t ed25519          # press Enter at every prompt
cat ~/.ssh/id_ed25519.pub      # copy this, paste into the SSH Keys section at
                               #   https://accounts.cels.anl.gov  (public key only!)
ssh-add                        # load the key into your agent
# Must log in WITHOUT a password prompt (exit 0, no output):
ssh -o BatchMode=yes -J logins.cels.anl.gov homes.cels.anl.gov true
```

If that last command fails, fix it here — argo-shim cannot work until it succeeds.

> ⚠️ **Do not restart argo-shim in a loop if it fails.** ALCF login nodes are shared; too many
> failed SSH logins from one IP get the **whole node blocked** by CSPO security, breaking Argo
> for everyone on it. argo-shim reads the actual SSH error, tells you the one thing to fix, and
> enforces a cooldown/lockout after repeated auth failures (`argo-shim --status` to inspect,
> `argo-shim --reset` to clear after you've fixed auth). Read the error, fix that, try once.

### Run it

**Terminal 1 — start the shim:**

```bash
uvx argo-shim         # no install needed
# or: pip install argo-shim && argo-shim
```

On startup it finds/creates the SSH tunnel to `apps.inside.anl.gov:443`, starts a local proxy
on a port derived from your username, writes the correct `ANTHROPIC_BASE_URL` + auth token into
`~/.claude/settings.json`, and runs health checks. If your **ALCF username differs from your
CELS username**, set `CELS_USERNAME` to the CELS one.

**Terminal 2 — start Claude Code** (same node):

```bash
claude
```

That's it — argo-shim already configured Claude Code's settings. Rerunning `argo-shim` is safe:
if a healthy shim is already running it just re-syncs settings and exits without touching SSH
(so an accidental second launch never triggers another Duo prompt). Force a clean restart with
`argo-shim --restart`.

### Running from an ALCF compute node

Compute nodes have no outbound network, so create the tunnel on a UAN and point the shim at it:

```bash
# On a UAN:
argo-shim --tunnel
# On the compute node (use the UAN hostname it prints):
argo-shim --tunnel-host <uan-hostname>
# Then, since HPC nodes usually set proxy vars, bypass them for localhost:
no_proxy=localhost,127.0.0.1 NO_PROXY=localhost,127.0.0.1 claude
```

If the UAN can't SSH to CELS (e.g. Aurora restrictions), relay through your Mac with
`argo-shim --relay <uan-hostname>` on the Mac. See the
[argo-shim README](https://github.com/n-getty/argo-shim#running-from-compute-nodes) for the
relay details.

### VS Code users

There's a companion **VS Code extension** ("Argonne: Start Proxy") that wraps argo-shim with a
one-click UI and an interactive Duo prompt — see the
[argo-shim repo](https://github.com/n-getty/argo-shim/tree/main/vscode-extension).

---

## Installing Claude Code on ALCF login nodes

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

Ensure `~/.local/bin` is on your `PATH`. On a login node, use **Option B** (argo-shim) to reach
Argo.

---

## Picking a model

argo-shim writes Claude Code's settings but defaults it to Sonnet. To pin a model, add a
`"model"` field with an **Argo slug** to `~/.claude/settings.json`:

```json
{ "model": "claudeopus48" }
```

Or use `/model` inside Claude Code. Good starting points: `claudesonnet46` (fast, 1M context)
or `claudeopus48` (strongest for complex agentic work). Full list in the
[reference](reference.md#model-names-argo-slugs).

---

## Optional: add the PBS MCP server

To let Claude Code submit and monitor PBS jobs on Aurora/Polaris:

```bash
git clone --recursive git@github.com:jtchilders/pbs-mcp-demo.git
```

Add to `~/.claude.json`:

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

Restart Claude Code; you can now drive PBS jobs via the `pbs` MCP server.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `connection refused` / hangs (Option A) | Not on ANL network | Use Option B (argo-shim) |
| `401` / username validation error | Wrong `ANTHROPIC_AUTH_TOKEN` | Bare ANL username — no email, no quotes |
| argo-shim prints "No SSH key found" and exits | SSH key not set up | Do the [one-time SSH setup](#one-time-ssh-setup-do-this-first--do-not-skip) |
| `Permission denied (publickey)` | Public key not on CELS account | Upload `~/.ssh/id_ed25519.pub` at accounts.cels.anl.gov, then `ssh-add` |
| "SSH attempts are paused / HARD-LOCKED" | Repeated auth failures | Fix SSH auth, wait out cooldown, then `argo-shim --reset` |
| Claude Code won't pick up new port/token | It reads settings only at startup | Restart Claude Code after (re)starting the shim |
| `[SSL: WRONG_VERSION_NUMBER]` | Stale SSH ControlMaster tunnel | `ssh -O exit homes.cels.anl.gov` then `argo-shim` |
| `401` with a project-level `.claude/settings.json` | Project `env` overrides the global one the shim wrote | Run `argo-shim --no-auth` (safe; shim binds `127.0.0.1` only) |
| HTTP 500 "Streaming is required" | Non-stream call, big payload | argo-shim forces `stream:true`; update to the latest shim — see [reference](reference.md#the-streaming--max_tokens-rule-for-claude-on-argo-important) |

More: the [argo-shim README](https://github.com/n-getty/argo-shim#troubleshooting) is the
authoritative troubleshooting reference.

---

**Next:** compare with the [Ask Sage variant](claude-code-asksage.md) if you have an Ask Sage
key and want to work from anywhere without a VPN or tunnel (no shim needed there).
