# 🧭 Agency Agents Store — Specialist Guide & Installers

**An HTML guide + installers that bring 283 AI specialists into your coding tools** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity and more).

Built for "vibe coders" who want a team of digital specialists working alongside them — no jargon, no fuss.

> Based on the open source catalog [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) and the [Agency Agents App](https://github.com/msitarzewski/agency-agents-app). This project packages, translates and simplifies them for beginners.

**🌐 Read this in:** [English](README.md) · [Português](README.pt-BR.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md)

---

## What's inside

| File/folder | What it is |
|---|---|
| `guia-especialistas-agencia.html` | **The guide.** Double-click to open — works offline. Search, filters, a "your machine" panel, and every specialist explained in plain language with 4 real-world usage situations. Available in English, Portuguese, Spanish, French and German. |
| `instaladores/instalar-linux.sh` | Installer for **Linux and macOS**. |
| `instaladores/instalar-windows.ps1` | Installer for **Windows** (requires only Git for Windows). |
| `gerador/build.py` | Rebuilds the guide from `dados/` (for maintenance). |
| `dados/` | Translated catalog + real-world situations (JSON). |

## Getting started (5 minutes)

### 1. Get the guide
Click **Code → Download ZIP** (or clone the repository) and open `guia-especialistas-agencia.html` — you can browse all 283 specialists without installing anything. Pick your language in the top-right selector.

### 2. Run the installer (once)
It detects which tools you have (Claude Code, ZCode, Codex…), **asks your language**, asks where to install and how many specialists to bring, **backs up** anything it touches, and the guide's machine panel updates itself at the end.

**Linux/macOS:**
```bash
cd instaladores
./instalar-linux.sh
```

**Windows** (PowerShell — prerequisite: [Git for Windows](https://git-scm.com/download/win)):
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # if prompted
.\instalar-windows.ps1
```

### 3. Install from inside the guide (optional)
In the guide, the button **"➕ Install specialists into a tool"** asks *where* and *who* (pre-launch squad, training squad, all 283, or by division) and generates an `agency-plan.json`. Then run:

```bash
./instalar-linux.sh --plan agency-plan.json        # Linux/macOS
.\instalar-windows.ps1 -Plan agency-plan.json      # Windows
```

You can also pick the language non-interactively: `--lang en|pt|es|fr|de` (or `-Lang` on Windows).

## What the installer does (and doesn't)

✅ Detects installed tools and your operating system
✅ Asks your language — everything follows it, including the specialists' descriptions
✅ Downloads/updates the official catalog to `~/.agency-agents`
✅ Converts agents with the **official converter** (byte-identical output)
✅ **Backs up** to `~/.agency-agents-backup/` before overwriting anything
✅ Writes `guia-status.js` next to the guide (it feeds the machine panel)
❌ **Does not** install tools you don't have (only configures existing/compatible ones)
❌ **Does not** send anything to the internet (only the guide, when you ask, checks GitHub releases)

## Automatic updates

The guide checks (every 24h or when you click **🔄 Check for updates**) the official releases of the catalog, the app and this project. If something new ships, a badge appears at the top.

## Using the specialists

Once installed, specialists show up in your tools:

- **Claude Code / ZCode / Codex / Gemini CLI…** — mention the name in your prompt: *"use the code-reviewer to review this change"*.
- **In ZCode**, open a session in the project folder and check **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — install per *project* (inside the repository folder).

The guide itself has the full playbook: how to call, examples, and the five golden rules.

## Supported tools

| Tool | Scope | Destination |
|---|---|---|
| Claude Code | user | `~/.claude/agents/*.md` |
| ZCode | user | `~/.zcode/agents/*.md` |
| Codex CLI | user | `~/.codex/agents/*.toml` (Windows: WSL) |
| Gemini CLI | user | `~/.gemini/agents/*.md` |
| GitHub Copilot | user | `~/.github/agents/*.md` |
| Qwen Code | user | `~/.qwen/agents/*.md` |
| opencode | user | `~/.config/opencode/agents/*.md` |
| Antigravity | user | `~/.gemini/config/skills/<slug>/SKILL.md` |
| Osaurus | user | `~/.osaurus/skills/…` (macOS only) |
| Kimi CLI | user | `~/.config/kimi/agents/<slug>/` (Windows: WSL) |
| Cursor / Aider / Windsurf | per project | inside the repository folder |

Other catalog integrations (Mistral Vibe, DeepSeek Harness, OpenClaw…) work through the official converter; for those, prefer the [Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Languages

The guide and both installers ship in **English, Portuguese, Spanish, French and German** — including every specialist description and all real-world usage situations. Pick the language during installation, or switch anytime in the guide (top-right selector).

## Licenses & credits

- This project: **MIT** (see `LICENSE`).
- Catalog and converter: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, by Michael Sitarzewski. This project only packages, translates and simplifies it for beginners.
- Descriptions and usage situations were translated/adapted; the original English text is available in each card's details.
