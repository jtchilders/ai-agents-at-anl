# Claude Cowork + Argo

**Goal:** run Anthropic's **Claude Desktop** app (**Cowork** / **Code** tabs) against
Argonne's **Argo Gateway** as the inference provider.

> ⚠️ **Read this first — status of this combination.**
> The other three guides in this repo follow vendor-documented paths. This one **combines**
> two documented mechanisms:
> 1. Cowork's **3P "Gateway" provider** (documented by Anthropic and in the
>    [Cowork + Ask Sage guide](claude-cowork-asksage.md)), and
> 2. Argo's **Anthropic-compatible endpoints** (`/argoapi/v1/messages`, `/argoapi/v1/models`,
>    documented by Argonne).
>
> The Gateway provider is backend-agnostic: it targets any Anthropic-compatible gateway that
> serves `GET /v1/models` + `POST /v1/messages`, which Argo does. So this *should* work the
> same way pointing at Argo. But this specific pairing is **not** in either vendor's official
> docs — treat it as the recommended configuration to try, and verify end-to-end before
> relying on it. Where a step is inference rather than documented fact, it's flagged inline.
> If you hit a wall, the [Code + Argo guide](claude-code-argo.md) is the fully-proven Argo
> path.

---

## The networking catch (understand this before configuring)

Cowork is not a thin API client — each session spins up a **sandboxed VM workspace** that it
provisions by fetching a bundle from `downloads.claude.ai` at session start, and that
workspace is what makes the model calls. So for Cowork + Argo to work, the environment must be
able to reach **both**:

- `downloads.claude.ai` (public internet) — to start any session at all, **and**
- `apps.inside.anl.gov` (Argo, ANL-internal) — for inference.

This is the crux. A machine on the ANL network can reach Argo but may be firewalled off from
`downloads.claude.ai`; a laptop off-network can reach `downloads.claude.ai` but not Argo.

**Recommended setup:** run Claude Desktop on an **Argonne-managed machine connected via VPN**
that has outbound HTTPS to both hosts, and point the gateway base URL straight at
`https://apps.inside.anl.gov/argoapi`. Confirm with your network admin that
`downloads.claude.ai` is reachable — this is the single most likely thing to block you.

> **"Can I just use argo-shim here, like in the Code guide?"** No — not as-is. argo-shim is
> built for **Claude Code**: its convenience comes from auto-writing `~/.claude/settings.json`,
> which **Cowork doesn't read** (Cowork uses the 3P `inferenceGateway*` config below). It also
> exposes a **plain-HTTP** proxy on `127.0.0.1`, whereas Cowork's Gateway base URL wants HTTPS
> and its sandboxed session VM may not even see your host's `127.0.0.1`. On VPN you don't need
> a shim at all — Argo is directly reachable over HTTPS. See the off-network note below for the
> (undocumented, untested) laptop case.

> **Off-network laptop option (advanced, unverified):** you'd need Argo reachable at an
> HTTPS URL the Cowork sandbox can dial. [argo-shim](https://github.com/n-getty/argo-shim) —
> the tool the [Code + Argo guide](claude-code-argo.md) uses — won't directly work here,
> because (a) it exposes a local **HTTP** proxy while the Cowork Gateway base URL should be
> HTTPS, and (b) the sandbox VM's network namespace may not see your host's `127.0.0.1`.
> Making this work would require exposing the tunnel as a TLS endpoint the sandbox can reach
> and adding its host to `coworkEgressAllowedHosts`. This is not documented or tested — prefer
> the on-VPN setup above, or use [Code + Argo](claude-code-argo.md) off-network.

---

## Prerequisites

- **Claude Desktop** with **Cowork on 3P** support: <https://claude.com/download>
- Argo access **approved** by your DOO / AI Rep (see [reference](reference.md#access-approval-do-this-first)).
- Your **ANL domain username** (this is your Argo credential).
- The machine must reach **both** `apps.inside.anl.gov` and `downloads.claude.ai` (see above).

---

## Step 1 — Confirm Argo speaks the Gateway protocol

Cowork's Gateway provider needs `GET /v1/models` and `POST /v1/messages`. Verify both from
the machine that will run Claude Desktop:

```bash
# model list (what populates Cowork's picker)
curl -s -H "Authorization: Bearer YOUR_ANL_USERNAME" \
  https://apps.inside.anl.gov/argoapi/v1/models | jq '.data[].id' | head

# a minimal Anthropic Messages call (stream to avoid the max_tokens>21000 500)
curl -N -X POST "https://apps.inside.anl.gov/argoapi/v1/messages" \
  -H "Authorization: Bearer YOUR_ANL_USERNAME" \
  -H "Content-Type: application/json" \
  -d '{"model":"claudesonnet46","max_tokens":64,"stream":true,"messages":[{"role":"user","content":"hi"}]}'
```

If both succeed, Cowork can use Argo. If the first hangs, you're not reaching Argo (network);
fix that before touching Claude Desktop.

---

## Step 2 — Configure Cowork's Gateway provider (macOS, in-app)

1. **Help → Troubleshooting → Enable Developer Mode**, then **Developer → Configure
   third-party inference**.
2. Choose **Gateway** as the provider.
3. Set:
   - **Base URL:** `https://apps.inside.anl.gov/argoapi` (**no trailing slash**)
   - **API key:** your **ANL domain username** (e.g. `alice`) — *inferred:* Argo treats
     the bearer token as the username, exactly as Claude Code does, so this is what goes in
     the key field.
   - **Auth scheme:** `bearer`
4. Apply the [telemetry-disable settings](claude-cowork-asksage.md#locking-down-telemetry-to-anthropic)
   if you want a locked-down profile.
5. **Apply Locally**, then fully quit and reopen Claude Desktop.

The picker should auto-discover Argo's models via `GET /argoapi/v1/models`.

---

## Step 2 (alt) — Config file

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

For the **Windows MSIX** path, follow the same 7 steps as the
[Cowork + Ask Sage Windows section](claude-cowork-asksage.md#windows-msix--end-to-end-setup),
substituting the Argo base URL and your ANL username for the key.

> **Encoding rule still applies:** in MDM/plist/registry delivery, all values are strings,
> including booleans and JSON arrays. See the
> [Ask Sage guide's note](claude-cowork-asksage.md#the-config-file-path-macos).

---

## Step 3 — Firewall egress

If you apply a locked-down profile, allowlist these on HTTPS 443:

- `downloads.claude.ai` — **required** for sessions to start.
- `apps.inside.anl.gov` — Argo inference. (Replace `api.asksage.anl.gov` from the Ask Sage
  profile with this host.)
- Your `otlpEndpoint` host — only if you set one.

---

## Step 4 — Pick a model

Use Argo **slugs** in the picker: `claudesonnet46`, `claudeopus48`, `claudeopus5`, etc.
Cowork/Code are Claude-oriented, so choose a Claude slug. See the
[reference](reference.md#model-names-argo-slugs).

### Argo Claude parameter quirks that matter in Cowork

Cowork **streams** by default, which conveniently avoids Argo's non-stream `max_tokens > 21000`
→ HTTP 500 rule. But note the per-model constraints (enforced server-side, see
[reference](reference.md#per-model-parameter-quirks-these-bite-people)):

- **Opus 4.7 / 4.8 / Opus 5** silently strip `temperature`/`top_p`/`top_k` and **require**
  `max_tokens`.
- **Sonnet 4.5/4.6, Haiku 4.5** accept only one of `temperature`/`top_p`.

If a model errors immediately in Cowork, it's most likely one of these parameter rules — try a
different Claude slug (e.g. `claudesonnet46`) to isolate it.

---

## 1M context on Argo

Argo's Opus 4.7 / 4.8 / Opus 5 and Sonnet 4.6 advertise 1M-token input windows. If you want
Cowork to surface a 1M variant explicitly, add an `inferenceModels` entry with
`supports1m: true` (see the
[Ask Sage 1M section](claude-cowork-asksage.md#enabling-opus-48-with-the-1m-token-context-window)) —
but use the Argo slug as the `name`. *Inferred:* Argo forwards the long-context capability, so
this should behave like the Ask Sage case; verify with a genuinely long session.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Sessions never start / spinner forever | `downloads.claude.ai` blocked | Allowlist it; confirm outbound HTTPS to the public internet |
| Empty model picker | `GET /argoapi/v1/models` unreachable or failed | Run the Step 1 curl from the same machine; fix network/username |
| `401` / username validation error | Wrong value in the key field | Use bare ANL username (no email, no quotes) |
| `Failed to parse enterprise config` | Trailing slash on base URL | Remove it |
| Immediate model error on send | Argo per-model parameter rule | Switch to `claudesonnet46`; see quirks above |
| HTTP 500 "Streaming is required" | A non-streaming path hit `max_tokens > 21000` | Cowork streams by default; if it appears, report it — see [reference](reference.md#the-streaming--max_tokens-rule-for-claude-on-argo-important) |
| claude.ai sign-in screen appears | Config not detected | Verify path, valid JSON, all Claude processes killed before relaunch |

If Cowork + Argo can't be made to work in your network environment, fall back to the proven
[Claude **Code** + Argo](claude-code-argo.md) path — it has no sandbox-VM egress requirement
beyond reaching Argo itself.
