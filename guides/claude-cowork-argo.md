# Claude Cowork + Argo

**Goal:** run Anthropic's **Claude Desktop** app (**Cowork** + **Code** tabs) against
Argonne's **Argo Gateway** as the inference provider, so your code and data stay within
Argonne's internal, data-secure LLM infrastructure.

> **Source:** The primary setup below follows Argonne's official *"Vibe Coding with Argo"*
> instructions for Claude Desktop (last updated 2026-08-17). Questions/feedback on the official
> instructions go to Matthew Dearing (mdearing@anl.gov). An optional
> [advanced appendix](#appendix-advanced--3p-config-file--mdm-fleet-deployment) covers
> config-file / MDM fleet deployment for locked-down rollouts.

---

## Prerequisites

- **Claude Desktop** for your OS (Windows, macOS, Linux): <https://claude.com/download>
- **Active Argonne credentials** — your **ANL domain username and password**.
- Argo access **approved** by your DOO / AI Rep (see
  [reference](reference.md#access-approval-do-this-first)).
- You must connect from an **Argonne-managed computer on the Argonne network** — either
  **on-site** or through the **Argonne VPN**. Argo (`apps.inside.anl.gov`) is ANL-internal and
  is not reachable off-network.

> 📌 **Reminder:** Using Argo requires connecting your computer directly to the Argonne network,
> either through VPN (working remotely) or being on-site.

> ⚠️ **Installing Claude Desktop requires local admin rights.** Per Argonne's official
> instructions, **local admin privileges must be granted during installation** — you're
> accepting the risk of giving Claude deeper access to your computer, so admin permission is
> necessary to enable these capabilities. On a managed machine, **first try your own ANL login
> and password** at the installer's admin prompt (some managed machines grant the assigned user
> admin rights). If that doesn't work, ask your **local IT/desktop support** to install it;
> don't enter credentials you weren't given. If you can't get admin rights at all, the terminal
> path — **[Claude Code + Argo](claude-code-argo.md)** — installs without a system-level admin
> prompt and is a good fallback.

---

## Step 1 — Install Claude Desktop

Download and install the Claude Desktop app for your operating system from
<https://claude.com/download>. Grant local admin during installation (see the note above).

Only install from the official source. Do **not** use a personal Claude subscription for
Argonne-related work — you'll point the app at Argo instead.

---

## Step 2 — Open the Inference Configuration

In Claude Desktop, open the **Inference Configuration** from the **lower-left menu** on the
screen, and select the option to **connect to your own gateway**.

---

## Step 3 — Configure the Argo gateway

Fill in the gateway settings for Argo:

| Field | Value |
|---|---|
| **base URL** | `https://apps.inside.anl.gov/argoapi` |
| **API key** | your **ANL domain username** (or service-account username) |
| **auth scheme** | select **`x-api-key`** from the option list |

Enter your bare ANL username in the API key field — **no email address, no quotation marks**.

Click **Apply changes** at the bottom of the configuration window. Claude will restart, and
your Argo LLM access will be enabled.

> **Why `x-api-key` here (not `bearer`)?** This is what Argonne's official Claude Desktop
> instructions specify for the Argo gateway. (Ask Sage, configured as a second gateway below,
> uses `bearer` instead — see the [Cowork + Ask Sage guide](claude-cowork-asksage.md).)

---

## Step 4 — (Optional) Add Ask Sage as a second gateway

Claude Desktop can hold **multiple named gateway configurations** and let you switch between
them, so you can keep both **Argo** and **Ask Sage** available in the same app.

To add Ask Sage alongside Argo, follow the **[Cowork + Ask Sage guide](claude-cowork-asksage.md)** —
it walks through the "Default" dropdown → **New configuration** → name it **"Ask Sage"** flow
and its `bearer` / `api.asksage.anl.gov` settings. Once both exist, you can **manually switch
between the Argo and Ask Sage gateways** from the dropdown in the top-right of the Inference
Configuration window at any time. Click **Apply changes** after switching; Claude restarts
automatically.

---

## Step 5 — Pick a model and start

After the app restarts, select an **Argo-provided Claude model** in the model picker (Cowork
and Code are Claude-oriented). Argo exposes Claude models under slugs such as `claudesonnet46`,
`claudeopus48`, and `claudeopus5` — see the
[reference](reference.md#model-names-argo-slugs) for the current list.

Start Vibe Working with Claude Cowork + Argo!

---

## Verify Argo is reachable (optional sanity check)

If the model picker is empty or inference hangs, confirm Argo answers from the same machine
before touching the app again. Argo's Anthropic-compatible endpoints:

```bash
# model list (what populates the picker)
curl -s -H "Authorization: Bearer YOUR_ANL_USERNAME" \
  https://apps.inside.anl.gov/argoapi/v1/models | jq '.data[].id' | head

# a minimal Anthropic Messages call (stream to avoid the max_tokens>21000 500)
curl -N -X POST "https://apps.inside.anl.gov/argoapi/v1/messages" \
  -H "Authorization: Bearer YOUR_ANL_USERNAME" \
  -H "Content-Type: application/json" \
  -d '{"model":"claudesonnet46","max_tokens":64,"stream":true,"messages":[{"role":"user","content":"hi"}]}'
```

If the first command hangs, you're not reaching Argo — check that you're on the Argonne network
(on-site or VPN). Fix that before re-checking the app.

> The curl uses `Authorization: Bearer <username>` because that's the raw Argo API convention.
> In the Claude Desktop UI you select **`x-api-key`** as the auth scheme and put the same
> username in the key field — the app handles the header for you.

---

## Argo Claude parameter quirks that matter in Cowork

Cowork **streams** by default, which conveniently avoids Argo's non-stream
`max_tokens > 21000` → HTTP 500 rule. But note the per-model constraints (enforced server-side,
see [reference](reference.md#per-model-parameter-quirks-these-bite-people)):

- **Opus 4.7 / 4.8 / Opus 5** silently strip `temperature`/`top_p`/`top_k` and **require**
  `max_tokens`.
- **Sonnet 4.5/4.6, Haiku 4.5** accept only one of `temperature`/`top_p`.

If a model errors immediately in Cowork, it's most likely one of these parameter rules — try a
different Claude slug (e.g. `claudesonnet46`) to isolate it.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Can't install / installer blocks | No local admin rights | Try your own ANL login at the admin prompt; else ask local IT. See the admin note above |
| Empty model picker | `GET /argoapi/v1/models` unreachable or failed | Run the verify curl from the same machine; confirm you're on VPN / on-site; check the username |
| `401` / username validation error | Wrong value in the key field | Use your bare ANL username (no email, no quotes) |
| Auth rejected despite correct username | Wrong auth scheme | Argo uses **`x-api-key`** in the Claude Desktop UI, not `bearer` |
| Immediate model error on send | Argo per-model parameter rule | Switch to `claudesonnet46`; see quirks above |
| HTTP 500 "Streaming is required" | A non-streaming path hit `max_tokens > 21000` | Cowork streams by default; if it appears, report it — see [reference](reference.md#the-streaming--max_tokens-rule-for-claude-on-argo-important) |
| claude.ai sign-in screen appears | Gateway config not applied | Reopen Inference Configuration, re-enter the gateway, **Apply changes**, let Claude restart |

If Cowork + Argo can't be made to work in your environment, fall back to the
[Claude **Code** + Argo](claude-code-argo.md) path.

---

## Appendix (advanced) — 3P config-file / MDM fleet deployment

> ⚠️ **Most users should use the in-app Inference Configuration above.** This appendix documents
> the lower-level **third-party ("3P") deployment mode** — editing
> `claude_desktop_config.json` directly or pushing it via MDM. It's useful for **fleet
> rollouts, locked-down/air-gapped profiles, and the Windows MSIX sandbox path**, but the field
> names and mechanics here are derived from Anthropic's general 3P documentation rather than
> Argonne's Claude Desktop instructions — **verify against your environment.** The auth scheme
> below (`bearer`) reflects the 3P config-file convention; the in-app UI for Argo uses
> `x-api-key` (Step 3).

### Config file location (macOS)

Per-user config at `~/Library/Application Support/Claude-3p/claude_desktop_config.json`:

```json
{
  "deploymentMode": "3p",
  "enterpriseConfig": {
    "inferenceProvider": "gateway",
    "inferenceGatewayBaseUrl": "https://apps.inside.anl.gov/argoapi",
    "inferenceGatewayApiKey": "YOUR_ANL_USERNAME",
    "inferenceGatewayAuthScheme": "bearer",
    "deploymentOrganizationUuid": "REPLACE-WITH-A-GENERATED-UUID",
    "disableDeploymentModeChooser": true
  }
}
```

(MDM-managed config, which **wins** over per-user if present, lives at
`/Library/Managed Preferences/<user>/com.anthropic.claude*`.)

For the **Windows MSIX** path, the full end-to-end walkthrough (finding your publisher ID,
initializing the sandboxed folders, the exact config path, Notepad gotchas, log locations)
lives in the [Cowork + Ask Sage guide's Windows section](claude-cowork-asksage.md#windows-msix--end-to-end-setup) —
substitute the Argo base URL (`https://apps.inside.anl.gov/argoapi`) and your ANL username for
the key.

### Locked-down / telemetry-disabled profile

The 3P mode also supports disabling Anthropic-bound telemetry and pinning egress for regulated
deployments. See the
[Cowork + Ask Sage telemetry section](claude-cowork-asksage.md#locking-down-telemetry-to-anthropic)
for the full field list — the same settings apply, with the Argo base URL substituted.

> **Encoding rule (MDM/plist/registry):** every value is delivered as a **string**, including
> booleans and JSON arrays. See the
> [Ask Sage guide's note](claude-cowork-asksage.md#the-config-file-path-macos).

### Networking note for 3P / sandbox deployments

In 3P mode each Cowork session provisions a **sandboxed VM workspace** that fetches a bundle
from `downloads.claude.ai` at session start, so a locked-down deployment must allowlist both
`downloads.claude.ai` (public) **and** `apps.inside.anl.gov` (Argo) on HTTPS 443. On the
standard on-VPN setup this is handled for you; it only matters when you're building a
restricted egress profile.

---

**Next:** to add or switch to Ask Sage in the same app, see
[Cowork + Ask Sage](claude-cowork-asksage.md).
