# Claude Cowork + Ask Sage

**Goal:** run Anthropic's **Claude Desktop** app (the **Cowork** and **Code** tabs) against
**Ask Sage** as the inference provider, instead of Anthropic's first-party API. You get the
full agentic Cowork experience — file creation, multi-step research, sub-agent coordination,
the Code tab — with inference and billing handled by Ask Sage.

This uses Cowork's **"3P" (third-party) mode** with the **Gateway** provider. Ask Sage
implements exactly the Anthropic-compatible API that the Gateway provider expects
(`POST /v1/messages` + `GET /v1/models`), so you point Cowork directly at Ask Sage — no
LiteLLM/Portkey proxy in between.

> **Reference:** Anthropic's canonical 3P docs are at
> <https://claude.com/docs/cowork/3p/overview> and
> <https://claude.com/docs/cowork/3p/configuration>. This guide is the Ask Sage-specific
> version.

---

## Prerequisites

- **Claude Desktop** installed (macOS or Windows), on a build that supports **Cowork on 3P**:
  <https://claude.com/download>
- An **Ask Sage API key** from Argonne's ANL-hosted instance. Get it at
  **<https://chat.asksage.anl.gov/>**: log in with **ANL SSO** → click your **user profile
  (bottom left)** to open **Settings** → **API Keys** tab → **generate** a key and **copy** it.
  Treat it like a password. (These docs use `api.asksage.anl.gov`; match the base URL to the
  instance you get your key from.)

---

## The fast path (macOS, in-app config window)

The quickest working setup uses Claude Desktop's built-in configuration window — no
hand-editing of plist files.

1. **Enable Developer Mode:** in Claude Desktop, go to **Help → Troubleshooting → Enable
   Developer Mode**. A **Developer** menu appears in the menu bar.
2. Open **Developer → Configure third-party inference**.
3. Choose **Gateway** as the inference provider.
4. Set the fields:
   - **Base URL:** `https://api.asksage.anl.gov/server/anthropic` (**no trailing slash**)
   - **API key:** your Ask Sage user API key
   - **Auth scheme:** `bearer`
5. (Recommended) Apply the [telemetry-disable settings](#locking-down-telemetry-to-anthropic)
   before saving.
6. Click **Apply Locally**, then **fully quit and reopen** Claude Desktop (config is read
   once at launch).

The model picker auto-discovers available models from
`https://api.asksage.anl.gov/server/anthropic/v1/models` — you do **not** have to list models
manually.

---

## The config-file path (macOS)

For MDM fleets or if you prefer editing a file, the per-user config lives at:

```
~/Library/Application Support/Claude-3p/claude_desktop_config.json
```

(MDM-managed config, which **wins** over per-user if present, lives at
`/Library/Managed Preferences/<user>/com.anthropic.claude*`.)

Minimal working config:

```json
{
  "deploymentMode": "3p",
  "enterpriseConfig": {
    "inferenceProvider": "gateway",
    "inferenceGatewayBaseUrl": "https://api.asksage.anl.gov/server/anthropic",
    "inferenceGatewayApiKey": "YOUR_ASKSAGE_API_KEY",
    "inferenceGatewayAuthScheme": "bearer",
    "deploymentOrganizationUuid": "REPLACE-WITH-A-GENERATED-UUID",
    "disableDeploymentModeChooser": true
  }
}
```

Generate the UUID with `uuidgen` (macOS has it built in). **Fully quit and reopen** after any
change.

> ⚠️ **Encoding rule for MDM/plist/registry delivery:** every value is stored as a **string**,
> including booleans (`"true"`/`"false"`) and arrays (JSON-encoded into a single string). The
> most common mistake is writing `inferenceModels` or `coworkEgressAllowedHosts` as a native
> array — that won't work. In a `.mobileconfig` it must be `<string>[...]</string>` with the
> JSON inside. The in-app config window (Developer → Configure third-party inference) can
> export the correctly-encoded format for you.

---

## Enabling Opus 4.8 with the 1M-token context window

Models auto-discover, so you only need `inferenceModels` when you want to **curate** the
picker, **set a default** (first entry wins), or **surface a 1M-context variant**.

Add `supports1m: true` to the models that support it. On Ask Sage today that's **Opus 4.8,
4.7, and 4.6** (they forward the `context-1m-2025-08-07` beta header):

```json
"inferenceModels": [
  { "name": "claude-opus-4-8", "supports1m": true },
  { "name": "claude-opus-4-7", "supports1m": true },
  { "name": "claude-opus-4-6", "supports1m": true },
  { "name": "claude-sonnet-4-6" },
  { "name": "claude-sonnet-4-5" },
  { "name": "claude-haiku-4-5" }
]
```

> `supports1m` is a **capability assertion you make** — Cowork does not verify it against Ask
> Sage. Only set it on models you've confirmed support 1M, or sessions will fail once the
> conversation grows past the model's real limit. With it set on Opus 4.8, you'll see a
> separate **"Opus 4.8 (1M context)"** entry in the picker.

(In MDM/plist form this whole array becomes a single JSON-in-a-string value, per the encoding
rule above.)

---

## Locking down telemetry to Anthropic

By default Cowork sends some operational telemetry to Anthropic-operated hosts. For regulated
or air-gapped Argonne deployments you'll typically disable all of it, so the **only** outbound
traffic is to Ask Sage. Set all four to `true`:

| Setting | Blocks |
|---|---|
| `disableEssentialTelemetry` | Crash reports, stack traces, perf timings (Sentry, Datadog) |
| `disableNonessentialTelemetry` | Product-usage analytics |
| `disableNonessentialServices` | Favicon fetches, artifact-preview iframe (cosmetic UI only) |
| `disableAutoUpdates` | Update checks/downloads (your IT distributes builds) |

> **Trade-off:** with `disableEssentialTelemetry: true`, Anthropic has zero remote visibility
> into failures, so support becomes a manual "collect and send logs" model. Consider leaving
> it `false` during initial rollout, then enabling it once stable.

### Recommended locked-down profile (Ask Sage)

```json
{
  "inferenceProvider":            "gateway",
  "inferenceGatewayBaseUrl":      "https://api.asksage.anl.gov/server/anthropic",
  "inferenceGatewayApiKey":       "YOUR_ASKSAGE_API_KEY",
  "inferenceGatewayAuthScheme":   "bearer",
  "deploymentOrganizationUuid":   "REPLACE-WITH-A-GENERATED-UUID",
  "disableDeploymentModeChooser": "true",
  "inferenceModels":              "[{\"name\":\"claude-opus-4-8\",\"supports1m\":true}]",
  "disableEssentialTelemetry":    "true",
  "disableNonessentialTelemetry": "true",
  "disableNonessentialServices":  "true",
  "disableAutoUpdates":           "true",
  "isLocalDevMcpEnabled":         "false",
  "isDesktopExtensionEnabled":    "false",
  "disabledBuiltinTools":         "[\"WebSearch\",\"WebFetch\"]",
  "coworkEgressAllowedHosts":     "[]",
  "allowedWorkspaceFolders":      "[\"~/Documents/AskSage\"]"
}
```

### Required firewall egress (allowlist on HTTPS 443)

Even fully locked down, Cowork needs these three:

- `downloads.claude.ai` — the VM workspace bundle + Claude CLI binary, fetched at session
  start. **Without this, Cowork sessions cannot start.**
- `api.asksage.anl.gov` (or your instance host) — model inference.
- Host of your `otlpEndpoint` — only if you configure your own OTLP telemetry collector
  (optional; see below).

Everything else can be denied.

### Optional: send your own telemetry to your collector

Independent of Anthropic-bound telemetry, you can export full session activity (prompts, tool
calls, token counts, errors) to your own OpenTelemetry collector for an audit trail:

```json
"otlpEndpoint":  "https://otel.your-org.com",
"otlpProtocol":  "http/protobuf",
"otlpHeaders":   "x-api-key=...,x-org=argonne"
```

---

## Windows (MSIX) — end-to-end setup

Claude Desktop on Windows ships as an **MSIX package**, which sandboxes all filesystem writes.
Anthropic's public docs point at `%APPDATA%\Claude-3p\` — **that path does not work on MSIX
builds.** Use the real sandboxed path below. All commands use Command Prompt (`cmd.exe`).

### Step 1 — Install and find your publisher ID

Download the `.msix` from <https://claude.com/download> and double-click to install. Then:

```cmd
dir "C:\Program Files\WindowsApps" | findstr /i claude
```

Example output: `Claude_1.3883.0.0_x64__pzs8sxrjxfjjc`. The last segment (`pzs8sxrjxfjjc`) is
your **publisher ID** — substitute yours everywhere you see `pzs8sxrjxfjjc` below.

### Step 2 — Initialize the sandboxed folders (first launch)

```cmd
start shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude
REM wait ~15-20 seconds, then kill ALL Claude processes:
taskkill /F /IM claude.exe /T
```

MSIX apps leave child processes running — closing the window isn't enough. Multiple "SUCCESS"
lines from `taskkill` is normal.

### Step 3 — Generate a deployment UUID

```cmd
REM Git for Windows:
"C:\Program Files\Git\usr\bin\uuidgen.exe"
REM or PowerShell:
powershell -Command "[guid]::NewGuid().ToString()"
```

> Don't skip this. Without a real UUID your install is pooled with every other unconfigured
> install worldwide under a shared placeholder, and Anthropic can't identify your org on
> support tickets.

### Step 4 — Create the config file at the MSIX path

```cmd
mkdir "%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude-3p"
notepad "%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude-3p\claude_desktop_config.json"
```

Paste this, replacing the two placeholders:

```json
{
  "deploymentMode": "3p",
  "enterpriseConfig": {
    "inferenceProvider": "gateway",
    "inferenceGatewayBaseUrl": "https://api.asksage.anl.gov/server/anthropic",
    "inferenceGatewayApiKey": "YOUR_ASKSAGE_TOKEN_HERE",
    "inferenceGatewayAuthScheme": "bearer",
    "deploymentOrganizationUuid": "REPLACE-WITH-GENERATED-UUID",
    "disableDeploymentModeChooser": true,
    "disableEssentialTelemetry": true,
    "disableNonessentialTelemetry": true,
    "disableNonessentialServices": true
  },
  "_cfprefsMigrated": true,
  "preferences": {
    "coworkScheduledTasksEnabled": true,
    "ccdScheduledTasksEnabled": false,
    "coworkWebSearchEnabled": true
  }
}
```

> **Two Notepad gotchas:**
> 1. If a *Save As* dialog appears, set **Save as type → All Files**, or Notepad appends
>    `.txt` and creates `claude_desktop_config.json.txt`, which the app ignores.
> 2. Encoding must be **UTF-8** (default on Win 11), **not** "UTF-8 with BOM."

### Step 5 — Validate the file

```cmd
dir "%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude-3p\"
REM if you see .json.txt, rename it:
ren "...\claude_desktop_config.json.txt" claude_desktop_config.json
type "...\claude_desktop_config.json"
```

### Step 6 — Launch fresh and verify

```cmd
taskkill /F /IM claude.exe /T
start shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude
```

Claude should open **directly into a chat interface with a model picker** — not a claude.ai
sign-in screen. The 3P log is at:

```
%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude-3p\logs\main.log
```

(Note: this is different from the standard-mode log under `...\Claude\logs\main.log`.) A
healthy session logs lines like `[Lifecycle] Session ...: initializing → running` and
`model: 'claude-...'`.

### Step 7 — Test inference

Type "hi" and send — you should get a response within a few seconds. If it hangs, test the
endpoint directly:

```cmd
curl -N -X POST "https://api.asksage.anl.gov/server/anthropic/v1/messages" ^
  -H "Authorization: Bearer YOUR_ASKSAGE_TOKEN" ^
  -H "Content-Type: application/json" ^
  -d "{\"model\":\"claude-sonnet-4-5\",\"max_tokens\":64,\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}"
```

### Windows bad-signs cheat sheet

| Log shows | Means | Fix |
|---|---|---|
| `Failed to parse enterprise config ... invalid_string` | URL validation rejected | Remove trailing slash from base URL |
| Empty/missing model picker | `GET /v1/models` discovery failed | Verify token, or pin models with `inferenceModels` |
| `claude.ai/login` / "User logged out" | Config not read — standard mode | Verify config is at the sandboxed path, JSON valid, all processes killed before launch |
| `Not main instance, returning early` | Zombie processes intercepted launch | `taskkill /F /IM claude.exe /T` then relaunch |

---

## Verifying no traffic leaks to Anthropic

With the locked-down profile applied, check your firewall logs / a packet capture for
connections to `*.sentry.io`, `browser-intake-us5-datadoghq.com`, `a-cdn.anthropic.com`,
`a-api.anthropic.com`, `api.anthropic.com`, or `www.claudeusercontent.com`. The only
Anthropic-domain traffic should be the one-time `downloads.claude.ai` fetch at session start.

---

**Next:** the [Cowork + Argo guide](claude-cowork-argo.md) applies this same 3P Gateway
mechanism but points it at Argonne's Argo instead of Ask Sage.
