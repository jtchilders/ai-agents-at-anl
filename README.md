# AI Agents at Argonne: Claude Code & Cowork with Argo / Ask Sage

Start-up guides for running Anthropic's agentic coding tools — **Claude Code** (terminal) and
**Claude Cowork** (the Claude Desktop app) — against Argonne's approved inference backends
instead of Anthropic's default cloud API.

These guides were written for the Anthropic-led tutorial for Argonne staff. They assume no
prior experience with these tools **or** with Argo/Ask Sage. Pick your combination below and
follow that one guide end-to-end.

---

## The two tools

- **Claude Code** — a coding agent that runs in your terminal. Best for working inside a repo,
  running commands, and scripting. Lightweight to configure (three environment variables).
- **Claude Cowork** — the Claude Desktop app (Cowork + Code tabs). A full agentic workspace
  with file creation, multi-step research, sub-agent coordination, and a GUI. Configured via
  its "3P" (third-party) mode.

## The two backends

- **Argo** — Argonne's internal LLM gateway (`apps.inside.anl.gov`). Auth is your **ANL
  username**. Requires the **ANL network/VPN** (or an SSH tunnel) and **DOO/AI-Rep approval**.
  Also serves OpenAI and Google models.
- **Ask Sage** — a gov-authorized gateway; ANL runs its own instance (`api.asksage.anl.gov`,
  key via ANL SSO at `chat.asksage.anl.gov`). Auth is a real **API key**. Works over **HTTPS
  from anywhere** — no VPN. Claude models only.

Full endpoint/auth/model details for both: **[guides/reference.md](guides/reference.md)**.

---

## Pick your guide (the 4 combinations)

| | **Argo** (ANL username, on-network) | **Ask Sage** (API key, anywhere) |
|---|---|---|
| **Claude Code** (terminal) | [→ Code + Argo](guides/claude-code-argo.md) | [→ Code + Ask Sage](guides/claude-code-asksage.md) |
| **Claude Cowork** (desktop app) | [→ Cowork + Argo](guides/claude-cowork-argo.md) ⚠️ | [→ Cowork + Ask Sage](guides/claude-cowork-asksage.md) |

**Not sure which?**

- On an ANL machine / login node and want a terminal agent → **Code + Argo**.
- Have an Ask Sage key and want zero networking setup → **Code + Ask Sage** or
  **Cowork + Ask Sage**.
- Want the desktop GUI and have an Ask Sage key → **Cowork + Ask Sage** (best-documented
  desktop path).
- Want the desktop GUI on Argo → **Cowork + Argo** (⚠️ combines documented mechanisms but is
  not an officially vendor-documented pairing — read the caveats in that guide).

---

## Before you start

1. **Install the tool** you want:
   - Claude Code: <https://docs.anthropic.com/en/docs/claude-code/overview>
   - Claude Desktop (for Cowork): <https://claude.com/download>
     - ⚠️ **Managed/locked-down machine?** The Claude Desktop installer may ask for an **admin
       username and password**. If you don't have admin rights the install stops here — first
       **try your own ANL login** (some managed machines grant it), and if that fails ask your
       **local IT** to install it. Claude Code (terminal) needs no admin install, so it's a
       good fallback. Details in the Cowork guides.
2. **Get your credential:**
   - Argo → get access **approved** by your DOO / AI Rep
     (<https://my.anl.gov/ai-at-argonne>), then use your **ANL domain username**.
   - Ask Sage → an **API key** from Argonne's ANL Ask Sage instance
     (<https://chat.asksage.anl.gov/>, ANL SSO → Settings → API Keys).
3. **Read [guides/reference.md](guides/reference.md)** once for the endpoints, auth rules, and
   model names — every guide links back to it.

---

## Repo layout

```
.
├── README.md                        # you are here
├── guides/
│   ├── reference.md                 # endpoints, auth, model names, gotchas (shared)
│   ├── claude-code-argo.md          # Claude Code  ->  Argo   (on-network + argo-shim off-network)
│   ├── claude-code-asksage.md       # Claude Code  ->  Ask Sage
│   ├── claude-cowork-asksage.md     # Claude Cowork -> Ask Sage (macOS + Windows MSIX)
│   └── claude-cowork-argo.md        # Claude Cowork -> Argo    (3P Gateway pointed at Argo)
└── scripts/
    └── asksage-claude.sh            # optional one-command Claude Code launcher (Ask Sage)
```

For off-network / on-node access to **Argo**, the guides use
[**argo-shim**](https://github.com/n-getty/argo-shim) (`pip install argo-shim`), a maintained
SSH-tunnel proxy — we no longer ship our own proxy scripts. **Ask Sage** (ANL instance,
`api.asksage.anl.gov`) is a plain HTTPS endpoint and needs no proxy at all.

---

## A note on accuracy

Three of the four combinations follow paths documented by Anthropic and/or Argonne. The
**Cowork + Argo** combination composes two documented mechanisms (Cowork's backend-agnostic 3P
Gateway provider + Argo's Anthropic-compatible endpoints) into a pairing that neither vendor
documents explicitly. That guide flags which steps are documented fact vs. reasoned inference,
and points to the proven Code + Argo path as a fallback. **Verify any configuration in your own
network environment before relying on it** — firewall egress (especially to
`downloads.claude.ai` for Cowork) is the most common thing that blocks a setup.
