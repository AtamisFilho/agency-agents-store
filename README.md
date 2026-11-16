# 🧭 Agency Agents Store — Specialist Guide & Installers

[![CI](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml/badge.svg)](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/AtamisFilho/agency-agents-store)](https://github.com/AtamisFilho/agency-agents-store/releases)
[![CHANGELOG](https://img.shields.io/badge/CHANGELOG-v2.2.1-blue)](CHANGELOG.md)

**An HTML guide + installers that bring 283 AI specialists into your coding tools** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity and more).

Built for "vibe coders" who want a team of digital specialists working alongside them — no jargon, no fuss.

> Based on the open source catalog [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) and the [Agency Agents App](https://github.com/msitarzewski/agency-agents-app). This project packages, translates and simplifies them for beginners.

**🌐 Read this in:** [English](README.md) · [Português](README.pt-BR.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md)

---

## Install in one line

**Linux/macOS** (needs `git` + `python3`):
```bash
curl -fsSL https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.sh | bash
```

**Windows** (PowerShell — needs [Git for Windows](https://git-scm.com/download/win)):
```powershell
irm https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.ps1 | iex
```

The one-liner downloads the installer, the translations and the guide to `~/.agency-agents-store` and runs everything from there. Prefer the full repository? **Code → Download ZIP** and keep reading.

## What's inside

| File/folder | What it is |
|---|---|
| `guia-especialistas-agencia.html` | **The guide.** Double-click to open — works offline. Search, filters, a "your machine" panel, and every specialist explained in plain language with 4 real-world usage situations. Available in English, Portuguese, Spanish, French and German. |
| `instaladores/instalar.sh` / `instalar.ps1` | **One-line bootstraps** (the commands above). |
| `instaladores/instalar-linux.sh` | Installer for **Linux and macOS** (thin wrapper — checks prerequisites, then calls the driver). |
| `instaladores/agency-install.py` | **The installer core** (all flags, all logic) for Linux/macOS. |
| `instaladores/instalar-windows.ps1` | Installer for **Windows** (native PowerShell, no Python needed; shares the same translation file). |
| `gerador/build.py` | Rebuilds the guide from `dados/` (for maintenance). |
| `dados/` | Translated catalog + real-world situations + `meta.json` (single source of truth) + `i18n-instalador.json` (installer messages, 5 languages). |

## Getting started (5 minutes)

### 1. Get the guide
Download the ZIP (or clone) and open `guia-especialistas-agencia.html` — you can browse all 283 specialists without installing anything. Pick your language in the top-right selector.

### 2. Run the installer (once)
It detects which tools you have (Claude Code, ZCode, Codex…), **asks your language** (then remembers it in `~/.agency-agents/config` and uses your OS locale as the first default), asks where to install and how many specialists to bring, **backs up** anything it touches, and the guide's machine panel updates itself at the end.

**Linux/macOS** (from the repository):
```bash
./instaladores/instalar-linux.sh
```

**Windows** (PowerShell — prerequisite: [Git for Windows](https://git-scm.com/download/win)):
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # if prompted
.\instalar-windows.ps1
```

### 3. Install from inside the guide (optional)
In the guide, the button **"➕ Install specialists into a tool"** asks *where* and *who* (pre-launch squad, training squad, all 283, or by division) and generates an `agency-plan.json`. Then, from the folder where you saved the plan:

```bash
./instaladores/instalar-linux.sh --plan          # path is optional: it finds agency-plan.json
.\instalar-windows.ps1 -PlanAuto                 # same on Windows (finds the plan automatically)
```

The installer searches `.`, `..`, the installer folder, `~/Downloads` and `~/Documents` for the plan automatically (the legacy name `plano-agencia.json` works too).

## Automation & fine control (same flags on both platforms)

| Linux/macOS | Windows | What it does |
|---|---|---|
| `--tool zcode,codex` | `-Tool zcode,codex` | Pick tools non-interactively (ids from `--list`) |
| `--squad pre\|treino\|all` | `-Squad pre\|treino\|all` | Pick the squad non-interactively (CI/scripts) |
| `--plan [FILE]` | `-Plan FILE` / `-PlanAuto` | Use the guide's plan (auto-search: `--plan` with no value, or `-PlanAuto`) |
| `--dry-run` | `-DryRun` | Preview everything that would be touched — writes nothing |
| `--list` | `-List` | Catalog/tools/squads as JSON on stdout (never touches the network) |
| `--status` | `-Status` | Detect only + refresh the guide panel (no network) |
| `--status --json` | `-Status -Json` | Machine status as JSON on stdout (writes nothing) |
| `--uninstall` | `-Uninstall` | Remove the agency specialists (backs up first; keeps your own files) |
| `--dir <path>` | `-Dir <path>` | Install into a **project** folder — enables Cursor/Aider/Windsurf |
| `--lang en\|pt\|es\|fr\|de` | `-Lang en\|pt\|es\|fr\|de` | Language (persisted for next runs) |

Examples:
```bash
./instaladores/instalar-linux.sh --tool cursor --dir ~/code/my-app --squad treino   # Cursor rules in a project
./instaladores/instalar-linux.sh --uninstall --tool zcode                           # remove (backup first)
./instaladores/instalar-linux.sh --dry-run --tool claudeCode --squad pre            # just look
./instaladores/instalar-linux.sh --list | jq '.tools[].id'                          # scripting
```

## What the installer does (and doesn't)

✅ Detects installed tools and your operating system
✅ Asks your language once — and remembers it (OS locale is the default)
✅ Downloads/updates the official catalog to `~/.agency-agents`
✅ Converts agents with the **official converter** (byte-identical output)
✅ **Backs up** to `~/.agency-agents-backup/` before overwriting anything
✅ **Verifies honestly**: reports how many of the requested specialists are really at the destination
✅ Writes `guia-status.js` next to the guide (it feeds the machine panel)
✅ Uninstalls cleanly (`--uninstall`) — only agency files, always with a backup
❌ **Does not** install tools you don't have (only configures existing/compatible ones)
❌ **Does not** use the network in `--status`/`--list`/`--json` modes (installs do, to fetch the catalog)
❌ **Does not** send anything anywhere else (only the guide, when you ask, checks GitHub releases)

## Automatic updates

The guide checks (every 24h or when you click **🔄 Check for updates**) the official releases of the catalog, the app and this project. If something new ships, a badge appears at the top. This project's releases follow [CHANGELOG.md](CHANGELOG.md) — the tag (`vX.Y.Z`) always matches the guide version.

## Using the specialists

Once installed, specialists show up in your tools:

- **Claude Code / ZCode / Codex / Gemini CLI…** — mention the name in your prompt: *"use the code-reviewer to review this change"*.
- **In ZCode**, open a session in the project folder and check **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — install per *project* with `--dir <project folder>` (rules/roster files live inside the repository).

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
| Cursor | per project (`--dir`) | `<project>/.cursor/rules/<slug>.mdc` |
| Aider | per project (`--dir`) | `<project>/CONVENTIONS.md` (roster) |
| Windsurf | per project (`--dir`) | `<project>/.windsurfrules` (roster) |

Other catalog integrations (Mistral Vibe, DeepSeek Harness, OpenClaw…) work through the official converter; for those, prefer the [Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Languages

The guide and both installers ship in **English, Portuguese, Spanish, French and German** — including every specialist description and all real-world usage situations. Pick the language during installation (it's remembered), or switch anytime in the guide (top-right selector).

## Development

- `python3 gerador/build.py` regenerates the guide from `dados/` — CI fails if the committed HTML doesn't match the data.
- `python3 tests/test_guide.py` — static guide tests (payload, i18n parity, XSS).
- `bash tests/run-tests.sh` — adversarial installer suite (dynamic catalog counts, all flags).
- CI runs everything on every push/PR (see [.github/workflows/ci.yml](.github/workflows/ci.yml)).

## Licenses & credits

- This project: **MIT** (see `LICENSE`).
- Catalog and converter: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, by Michael Sitarzewski. This project only packages, translates and simplifies it for beginners.
- Descriptions and usage situations were translated/adapted; the original English text is available in each card's details.
