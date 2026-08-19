# Claude Cowork + Ask Sage

**Goal:** run Anthropic's **Claude Desktop** app (the **Cowork** and **Code** tabs) against
**Ask Sage** (Argonne's ANL-hosted instance) as the inference provider. You get the full
agentic Cowork experience — file creation, multi-step research, sub-agent coordination, the
Code tab — with inference handled by Ask Sage.

> **Source:** The primary setup below follows Argonne's official *"Vibe Coding with Argo"*
> instructions for Claude Desktop (last updated 2026-08-17), which add Ask Sage as a second
> gateway alongside Argo. An optional
> [advanced appendix](#appendix-advanced--3p-config-file--mdm-fleet-deployment) covers
> config-file / MDM fleet deployment for locked-down rollouts.

---

## Prerequisites

- **Claude Desktop** installed for your OS: <https://claude.com/download>
- An **Ask Sage API key** from Argonne's ANL-hosted instance. Get it at
  **<https://chat.asksage.anl.gov/>**: log in with **ANL SSO** → click your **user profile
  (bottom left)** to open **Settings** → **API Keys** tab → **generate** a key and **copy** it.
  Treat it like a password. (These docs use `api.asksage.anl.gov`; match the base URL to the
  instance you get your key from.)

> ⚠️ **Installing Claude Desktop requires local admin rights.** Per Argonne's official
> instructions, **local admin privileges must be granted during installation** — you're
> accepting the risk of giving Claude deeper access to your computer, so admin permission is
> necessary. On a managed machine, **first try your own ANL login and password** at the
> installer's admin prompt (some managed machines grant the assigned user admin rights). If
> that doesn't work, ask your **local IT/desktop support** to install it; don't enter
> credentials you weren't given. If you can't get admin rights at all, the terminal path —
> **[Claude Code + Ask Sage](claude-code-asksage.md)** — installs without a system-level admin
> prompt and is a good fallback.

---

## Step 1 — Install Claude Desktop

Download and install Claude Desktop from <https://claude.com/download>, granting local admin
during installation (see the note above). Install only from the official source.

---

## Step 2 — Open the Inference Configuration

In Claude Desktop, open the **Inference Configuration** from the **lower-left menu**, and select
the option to **connect to your own gateway**.

If you're setting up Ask Sage **alongside an existing Argo gateway** (see the
[Cowork + Argo guide](claude-cowork-argo.md)), instead click the **"Default" dropdown** in the
**top-right corner** of the Inference Configuration window, choose **New configuration**, and
enter **"Ask Sage"** into the name field. This keeps both gateways available so you can switch
between them.

---

## Step 3 — Configure the Ask Sage gateway

Fill in the gateway settings for Ask Sage:

| Field | Value |
|---|---|
| **base URL** | `https://api.asksage.anl.gov/server/anthropic/` |
| **API key** | your Ask Sage key (copy from **Ask Sage → Settings → API Keys**) |
| **auth scheme** | select **`bearer`** from the option list |

Click **Apply changes** at the bottom of the window. Claude will restart and your Ask Sage
access will be enabled.

The model picker auto-discovers available models from
`https://api.asksage.anl.gov/server/anthropic/v1/models` — you do **not** have to list models
manually.

---

## Step 4 — Switch between Argo and Ask Sage (if you have both)

If you configured both gateways, you can **manually switch between the Argo and Ask Sage
gateways** from the **dropdown in the top-right** of the Inference Configuration window at any
time. Be sure to click the **Apply changes** button when you switch — Claude will automatically
restart the app to activate the selected gateway.

---

## Step 5 — Pick a model and start

After the app restarts, select a Claude model in the picker. Start Vibe Working with Claude
Cowork + Ask Sage!

---

## Appendix (advanced) — 3P config-file / MDM fleet deployment

> ⚠️ **Most users should use the in-app Inference Configuration above.** This appendix documents
> the lower-level **third-party ("3P") deployment mode** — editing
> `claude_desktop_config.json` directly or pushing it via MDM. It's useful for **fleet
> rollouts, locked-down/air-gapped profiles, and the Windows MSIX sandbox path**. The field
> names and mechanics here are derived from Anthropic's general 3P documentation rather than
> Argonne's Claude Desktop instructions — **verify against your environment.**

### The config-file path (macOS)

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
> JSON inside. The in-app config window can export the correctly-encoded format for you.

### Enabling Opus 4.8 with the 1M-token context window

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

### Locking down telemetry to Anthropic

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

#### Recommended locked-down profile (Ask Sage)

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

#### Required firewall egress (allowlist on HTTPS 443)

Even fully locked down, Cowork needs these three:

- `downloads.claude.ai` — the VM workspace bundle + Claude CLI binary, fetched at session
  start. **Without this, Cowork sessions cannot start.**
- `api.asksage.anl.gov` (or your instance host) — model inference.
- Host of your `otlpEndpoint` — only if you configure your own OTLP telemetry collector
  (optional; see below).

Everything else can be denied.

#### Optional: send your own telemetry to your collector

Independent of Anthropic-bound telemetry, you can export full session activity (prompts, tool
calls, token counts, errors) to your own OpenTelemetry collector for an audit trail:

```json
"otlpEndpoint":  "https://otel.your-org.com",
"otlpProtocol":  "http/protobuf",
"otlpHeaders":   "x-api-key=...,x-org=argonne"
```

### Windows (MSIX) — end-to-end setup

Claude Desktop on Windows ships as an **MSIX package**, which sandboxes all filesystem writes.
Anthropic's public docs point at `%APPDATA%\Claude-3p\` — **that path does not work on MSIX
builds.** Use the real sandboxed path below. All commands use Command Prompt (`cmd.exe`).

#### Step 1 — Install and find your publisher ID

Download the `.msix` from <https://claude.com/download> and double-click to install. Then:

```cmd
dir "C:\Program Files\WindowsApps" | findstr /i claude
```

Example output: `Claude_1.3883.0.0_x64__pzs8sxrjxfjjc`. The last segment (`pzs8sxrjxfjjc`) is
your **publisher ID** — substitute yours everywhere you see `pzs8sxrjxfjjc` below.

#### Step 2 — Initialize the sandboxed folders (first launch)

```cmd
start shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude
REM wait ~15-20 seconds, then kill ALL Claude processes:
taskkill /F /IM claude.exe /T
```

MSIX apps leave child processes running — closing the window isn't enough. Multiple "SUCCESS"
lines from `taskkill` is normal.

#### Step 3 — Generate a deployment UUID

```cmd
REM Git for Windows:
"C:\Program Files\Git\usr\bin\uuidgen.exe"
REM or PowerShell:
powershell -Command "[guid]::NewGuid().ToString()"
```

> Don't skip this. Without a real UUID your install is pooled with every other unconfigured
> install worldwide under a shared placeholder, and Anthropic can't identify your org on
> support tickets.

#### Step 4 — Create the config file at the MSIX path

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

#### Step 5 — Validate the file

```cmd
dir "%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude-3p\"
REM if you see .json.txt, rename it:
ren "...\claude_desktop_config.json.txt" claude_desktop_config.json
type "...\claude_desktop_config.json"
```

#### Step 6 — Launch fresh and verify

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

#### Step 7 — Test inference

Type "hi" and send — you should get a response within a few seconds. If it hangs, test the
endpoint directly:

```cmd
curl -N -X POST "https://api.asksage.anl.gov/server/anthropic/v1/messages" ^
  -H "Authorization: Bearer YOUR_A...OKEN" ^
  -H "Content-Type: application/json" ^
  -d "{\"model\":\"claude-sonnet-4-5\",\"max_tokens\":64,\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}"
```

#### Windows bad-signs cheat sheet

| Log shows | Means | Fix |
|---|---|---|
| `Failed to parse enterprise config ... invalid_string` | URL validation rejected | Remove trailing slash from base URL |
| Empty/missing model picker | `GET /v1/models` discovery failed | Verify token, or pin models with `inferenceModels` |
| `claude.ai/login` / "User logged out" | Config not read — standard mode | Verify config is at the sandboxed path, JSON valid, all processes killed before launch |
| `Not main instance, returning early` | Zombie processes intercepted launch | `taskkill /F /IM claude.exe /T` then relaunch |

### Verifying no traffic leaks to Anthropic

With the locked-down profile applied, check your firewall logs / a packet capture for
connections to `*.sentry.io`, `browser-intake-us5-datadoghq.com`, `a-cdn.anthropic.com`,
`a-api.anthropic.com`, `api.anthropic.com`, or `www.claudeusercontent.com`. The only
Anthropic-domain traffic should be the one-time `downloads.claude.ai` fetch at session start.

---

**Next:** the [Cowork + Argo guide](claude-cowork-argo.md) configures the Argo gateway (and
lets you keep both Argo and Ask Sage in the same app).
