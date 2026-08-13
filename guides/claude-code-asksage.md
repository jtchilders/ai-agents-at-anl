# Claude Code + Ask Sage

**Goal:** run [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) against
**Ask Sage** as the inference backend. Ask Sage exposes an Anthropic-compatible Messages API
over the public internet, so this works from anywhere — **no ANL VPN or SSH tunnel needed** —
as long as you have an Ask Sage API key.

This is the simplest of the four combinations: point Claude Code at Ask Sage's base URL and
authenticate with your Ask Sage key.

---

## Prerequisites

- An **Ask Sage account** and a valid **user API key** (this is a real secret — treat it like
  a password).
- **Claude Code** installed: <https://docs.anthropic.com/en/docs/claude-code/overview>
- Confirm which **instance** your organization approved. These docs use `api.asksage.ai`; if
  yours differs, substitute the instance segment in the base URL (see
  [reference](reference.md#ask-sage)).

---

## Step 1 — Verify your key and the endpoint

Before wiring up Claude Code, confirm the endpoint is reachable and your key works:

```bash
curl -s https://api.asksage.ai/server/anthropic/v1/models \
  -H "x-api-key: YOUR_ASKSAGE_API_KEY" | jq '.data[].id'
```

You should see a list including `claude-opus-4-8`, `claude-sonnet-4-5`, etc. A `401` means a
bad key; a `404` means the instance predates the model-list endpoint (contact Ask Sage
support).

---

## Step 2 — Launch Claude Code against Ask Sage

```bash
ANTHROPIC_BASE_URL="https://api.asksage.ai/server/anthropic" \
ANTHROPIC_AUTH_TOKEN="YOUR_ASKSAGE_API_KEY" \
CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1 \
claude
```

- `ANTHROPIC_BASE_URL` — Ask Sage's Anthropic-compatible root (**no trailing slash**).
- `ANTHROPIC_AUTH_TOKEN` — your **Ask Sage API key** (unlike Argo, this is a real secret).
- `CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1` — bypasses the normal claude.ai OAuth login.

> **Keep the key out of your shell history.** Put it in an env var loaded from a file that
> isn't committed, e.g.:
> ```bash
> export ASKSAGE_API_KEY="$(cat ~/.config/asksage/key)"   # file is chmod 600, gitignored
> ANTHROPIC_BASE_URL="https://api.asksage.ai/server/anthropic" \
> ANTHROPIC_AUTH_TOKEN="$ASKSAGE_API_KEY" \
> CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1 claude
> ```

### Convenience wrapper

A small launcher is included at [`scripts/asksage-claude.sh`](../scripts/asksage-claude.sh).
It reads your key from `ASKSAGE_API_KEY` (or `~/.config/asksage/key`) and launches Claude
Code wired to Ask Sage:

```bash
export ASKSAGE_API_KEY="sk-..."   # or drop it in ~/.config/asksage/key
./scripts/asksage-claude.sh
```

---

## Step 3 — Pick a model

Inside Claude Code use `/model` and enter an Anthropic model ID, e.g.:

- `claude-sonnet-4-5` — fast, strong default for coding
- `claude-opus-4-8` — strongest for complex, multi-step agentic work
- `claude-haiku-4-5` — cheapest/fastest for light tasks

Ask Sage uses standard Anthropic model IDs (see
[reference](reference.md#model-names-anthropic-ids)). For 1M-context Opus, see the note in
the reference on the `context-1m-2025-08-07` beta header.

---

## Argo vs. Ask Sage for Claude Code — which to use?

| | **Argo** | **Ask Sage** |
|---|---|---|
| Works off-VPN from a laptop | Only via SSH tunnel + proxy | ✅ Directly |
| Credential | ANL username (not secret) | Real API key (secret) |
| Requires DOO/AI-Rep approval | ✅ | Depends on your org's Ask Sage terms |
| Also serves OpenAI/Gemini models | ✅ | Anthropic (Claude) only |
| Best when | You're on-network / on a login node | You want zero networking setup |

Both use the same three Claude Code environment variables — only `ANTHROPIC_BASE_URL` and the
token change.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `401 Unauthorized` | Bad or missing key | Re-check `ANTHROPIC_AUTH_TOKEN`; test with the Step 1 curl |
| `404` on `/v1/models` | Old instance | Contact Ask Sage support to enable the model-list endpoint |
| Model picker empty | Discovery failed | Verify key; confirm the base URL has no trailing slash |
| Wrong instance / cert errors | Base URL instance segment mismatch | Match the base URL to the instance you authenticate against |
| Claude.ai login screen appears | `CLAUDE_CODE_SKIP_ANTHROPIC_AUTH` not set | Add `CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1` |

---

**Next:** if you want the desktop app instead of the terminal, see
[Cowork + Ask Sage](claude-cowork-asksage.md).
