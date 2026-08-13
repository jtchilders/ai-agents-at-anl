# Reference: Endpoints, Authentication, and Models

This page is the shared factual reference for every guide in this repo. If you are new,
start with the [main README](../README.md) and pick a guide; come back here when you need
the exact endpoint URL, the authentication rule, or a model name.

There are **two inference backends** covered in these guides, and they are completely
separate systems with different endpoints, different authentication, and different access
requirements.

| | **Argo** | **Ask Sage** |
|---|---|---|
| Operator | Argonne (internal) | Ask Sage (external SaaS, gov-authorized) |
| Base host | `https://apps.inside.anl.gov/argoapi` | `https://api.asksage.anl.gov/server/anthropic` |
| Auth credential | Your **ANL domain username** (not a secret) | A real **Ask Sage API key** |
| Network requirement | ANL internal network or VPN (or SSH tunnel) | Public internet |
| Access approval | DOO / Directorate AI Rep approval required | Ask Sage account + API key |
| Model naming | Argo slugs (`gpt5`, `claudeopus48`, `gemini35flash`) | Anthropic model IDs (`claude-opus-4-8`) |

---

## Argo

Argo is Argonne's internal "LLM-as-a-service" gateway. It fronts models from OpenAI,
Anthropic, and Google behind one Argonne-controlled, data-secure API.

### Access approval (do this first)

As of **2026-07-01**, using the Argo Gateway API — including connecting AI coding tools —
requires approval by your **DOO or Directorate AI Representative**. Find your rep at
<https://my.anl.gov/ai-at-argonne> under the AI Representative "Contact List".

### Network requirement

The machine making API calls must be on the **Argonne internal network**, or connected via
**VPN from an Argonne-managed computer**. If your internal machine cannot reach
`apps.inside.anl.gov`, you can request a firewall conduit via a Vector ticket (object group
`BIS_Argo_Access`). To use Argo from a personal laptop off-network, use the SSH tunnel +
proxy approach in the [Claude Code + Argo guide](claude-code-argo.md).

### Authentication

Argo does **not** issue API keys. You authenticate by passing your **ANL domain username**
wherever a tool asks for an API key or token.

- Use just the username (e.g. `alice`), **not** your full email address.
- Do **not** wrap it in quotes or add special characters.
- `ac.` accounts are not authorized.
- The username is validated against a directory lookup (cached 24 h) and is logged for
  per-division usage tracking.
- Optionally, register a **service account** (max 10 chars, prepended with `svc`) via
  <https://vector.anl.gov> → "Service Accounts" for application/automation calls.

### Endpoints

Base URL (production): `https://apps.inside.anl.gov/argoapi`

| Purpose | Method + Path |
|---|---|
| Anthropic Messages API (native) | `POST /v1/messages` |
| OpenAI-compatible chat | `POST /v1/chat/completions` |
| OpenAI-compatible model list | `GET  /v1/models` |
| OpenAI-compatible embeddings | `POST /v1/embeddings` |
| Legacy chat | `POST /api/v1/resource/chat/` |
| Legacy embeddings | `POST /api/v1/resource/embed/` |
| Swagger UI (browse/test in browser) | `GET  /docs` |

> **Dev vs. prod:** Use production (`apps.inside.anl.gov`, **no** `-dev`) unless you are
> explicitly helping test beta features. The `apps-dev.inside.anl.gov` endpoint is unstable
> and changes without notice.

### Model names (Argo slugs)

Query the live list any time:

```bash
curl -s -H "Authorization: Bearer YOUR_ANL_USERNAME" \
  https://apps.inside.anl.gov/argoapi/v1/models | jq
```

Common current slugs (as of Aug 2026 — always verify against `/v1/models`):

- **OpenAI:** `gpt4o`, `gpt41`, `gpt5`, `gpt5mini`, `gpt51`, `gpt52`, `gpt54`, `gpt55`,
  `gpt56sol`, `gpt56terra`, `gpt56luna`, `gpto3`, `gpto4mini`
- **Anthropic:** `claudeopus5`, `claudeopus48`, `claudeopus47`, `claudeopus46`,
  `claudeopus45`, `claudesonnet5`, `claudesonnet46`, `claudesonnet45`, `claudehaiku45`
- **Google:** `gemini35flash`, `gemini31flashlite`
- **Embeddings:** `ada002`, `v3large`, `v3small` (OpenAI names also accepted)

### Per-model parameter quirks (these bite people)

These are enforced server-side and will cause errors or silently dropped parameters:

- **Claude Opus 4.7 / 4.8 / Opus 5:** do **not** accept `temperature`, `top_p`, or `top_k`
  (silently stripped). Require `max_tokens` to be set. Thinking is controlled via
  `output_config`.
- **Claude Sonnet 4.5 / 4.6 / Haiku 4.5:** accept **only one** of `temperature` or `top_p`,
  not both. If both are sent, `top_p` is ignored.
- **Older Claude (Opus 4.1/4.5/4.6, Sonnet 4, etc.):** require `max_tokens`, `temperature`,
  `top_p`; default to `max_tokens=21000, temperature=0.7, top_p=0.9` if omitted.
- **OpenAI o-series (`gpto3`, `gpto4mini`) and GPT-5 family:** use `max_completion_tokens`,
  **not** `max_tokens`. GPT-5.5 accepts `temperature=1` only.

### The streaming / `max_tokens` rule for Claude on Argo (important)

This is a hard, deterministic behavior verified empirically:

- A **non-streaming** Claude request with `max_tokens` **absent or greater than 21000**
  returns HTTP 500: *"Streaming is required for operations that may take longer than 10
  minutes."* The exact ceiling is 21000.
- **Fix:** stream the request (`stream: true`). Argo's `/v1/chat/completions` with streaming
  accepts unbounded `max_tokens` **and** supports tool calling. Only cap `max_tokens <=
  21000` on code paths that genuinely cannot stream.

Claude Code and Cowork stream by default, so this mostly affects hand-rolled API scripts.

---

## Ask Sage

Ask Sage is a government-authorized LLM gateway that exposes an **Anthropic-compatible** API.
Argonne runs an **ANL-hosted instance** (ANL SSO), which is what these docs use. It works over
HTTPS from anywhere — no ANL VPN required.

- Chat / key management UI: <https://chat.asksage.anl.gov/> (log in with **ANL SSO**)
- API base URL: `https://api.asksage.anl.gov/server/anthropic`

> **Instance note:** The `api.` prefix and the `/server/anthropic` path suffix are stable — only
> the host in the middle changes between deployments (e.g. the public `api.asksage.ai`). Always
> match the base URL to the instance you get your key from. For ANL, that's `api.asksage.anl.gov`.

### Authentication

You need a **valid Ask Sage user API key** (a real secret). Get it from the ANL Ask Sage portal:
**<https://chat.asksage.anl.gov/>** → log in with ANL SSO → click your **user profile (bottom
left)** to open **Settings** → **API Keys** tab → **generate** a key and **copy** it. Pass it
with the **`bearer`** auth scheme.

### Endpoints

Base URL: `https://api.asksage.anl.gov/server/anthropic`

| Purpose | Method + Path |
|---|---|
| Anthropic Messages API | `POST /v1/messages` |
| Model list | `GET  /v1/models` |

Verify reachability:

```bash
curl -s https://api.asksage.anl.gov/server/anthropic/v1/models \
  -H "x-api-key: YOUR_A...KEY" | jq
```

You should get a JSON `data` array with `claude-opus-4-8`, `claude-sonnet-5`, etc. A 404 on the
path means you're pointed at the wrong base URL.

### Model names (Anthropic IDs)

Ask Sage uses Anthropic's model IDs directly (e.g. `claude-opus-5`, `claude-opus-4-8`,
`claude-opus-4-7`, `claude-sonnet-5`). Run the model-list curl above to see the current set
offered by the ANL instance.

**1M-token context** is available on Opus 4.8, 4.7, and 4.6 (they forward the
`context-1m-2025-08-07` Anthropic beta header). Cowork surfaces this via a `supports1m` flag
— see the [Cowork + Ask Sage guide](claude-cowork-asksage.md).

---

## Which combination should I use?

| You have… | and you want… | Use |
|---|---|---|
| ANL network/VPN, want a terminal agent | Claude Code | [Code + Argo](claude-code-argo.md) |
| An Ask Sage key, want a terminal agent | Claude Code | [Code + Ask Sage](claude-code-asksage.md) |
| An Ask Sage key, want the desktop app | Claude Cowork | [Cowork + Ask Sage](claude-cowork-asksage.md) |
| ANL network/VPN, want the desktop app | Claude Cowork | [Cowork + Argo](claude-cowork-argo.md) |
