# 🧭 Agency Agents Store — Spezialisten-Leitfaden & Installer

**Ein HTML-Leitfaden + Installer, die 283 KI-Spezialisten in deine Coding-Tools bringen** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity und mehr).

Gebaut für „Vibe Coder“, die ein Team digitaler Spezialisten an ihrer Seite haben möchten — ohne Fachchinesisch, ohne Aufwand.

> Basiert auf dem Open-Source-Katalog [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) und der [Agency Agents App](https://github.com/msitarzewski/agency-agents-app). Dieses Projekt verpackt, übersetzt und vereinfacht sie für Einsteiger.

**🌐 Lies dies in:** [English](README.md) · [Português](README.pt-BR.md) · [Español](README.es.md) · [Français](README.fr.md) · **[Deutsch](README.de.md)**

---

## Was drin ist

| Datei/Ordner | Was es ist |
|---|---|
| `guia-especialistas-agencia.html` | **Der Leitfaden.** Doppelklicken zum Öffnen — funktioniert offline. Suche, Filter, ein „deine Maschine“-Panel und jeder Spezialist in einfacher Sprache erklärt, mit 4 Praxis-Situationen aus dem echten Leben. Verfügbar auf Englisch, Portugiesisch, Spanisch, Französisch und Deutsch. |
| `instaladores/instalar-linux.sh` | Installer für **Linux und macOS**. |
| `instaladores/instalar-windows.ps1` | Installer für **Windows** (braucht nur Git for Windows). |
| `gerador/build.py` | Baut den Leitfaden aus `dados/` neu auf (für Wartung). |
| `dados/` | Übersetzter Katalog + Praxis-Situationen (JSON). |

## Loslegen (5 Minuten)

### 1. Hol dir den Leitfaden
Klicke auf **Code → Download ZIP** (oder klone das Repository) und öffne `guia-especialistas-agencia.html` — du kannst alle 283 Spezialisten durchstöbern, ohne etwas zu installieren. Wähle deine Sprache im Auswahlfeld oben rechts.

### 2. Starte den Installer (einmal)
Er erkennt, welche Tools du hast (Claude Code, ZCode, Codex…), **fragt deine Sprache ab**, fragt, wohin installiert werden soll und wie viele Spezialisten kommen sollen, **sichert** alles, was er anfasst, und das Maschinen-Panel des Leitfadens aktualisiert sich am Ende selbst.

**Linux/macOS:**
```bash
cd instaladores
./instalar-linux.sh
```

**Windows** (PowerShell — Voraussetzung: [Git for Windows](https://git-scm.com/download/win)):
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # if prompted
.\instalar-windows.ps1
```

### 3. Direkt im Leitfaden installieren (optional)
Im Leitfaden fragt die Schaltfläche **„➕ Install specialists into a tool“**, *wohin* und *wen* (Pre-Launch-Team, Schulungs-Team, alle 283 oder nach Abteilung) und erzeugt eine `agency-plan.json`. Dann führe aus:

```bash
./instalar-linux.sh --plan agency-plan.json        # Linux/macOS
.\instalar-windows.ps1 -Plan agency-plan.json      # Windows
```

Du kannst die Sprache auch nicht-interaktiv wählen: `--lang en|pt|es|fr|de` (oder `-Lang` unter Windows).

## Was der Installer tut (und was nicht)

✅ Erkennt installierte Tools und dein Betriebssystem
✅ Fragt deine Sprache ab — alles folgt ihr, auch die Beschreibungen der Spezialisten
✅ Lädt den offiziellen Katalog herunter bzw. aktualisiert ihn nach `~/.agency-agents`
✅ Wandelt Agents mit dem **offiziellen Konverter** um (byte-identische Ausgabe)
✅ **Sichert** nach `~/.agency-agents-backup/`, bevor irgendwas überschrieben wird
✅ Schreibt `guia-status.js` neben den Leitfaden (er speist das Maschinen-Panel)
❌ Installiert **keine** Tools, die du nicht hast (konfiguriert nur vorhandene/kompatible)
❌ Sendet **nichts** ins Internet (nur der Leitfaden prüft, wenn du es verlangst, die GitHub-Releases)

## Automatische Updates

Der Leitfaden prüft (alle 24 Stunden oder wenn du auf **🔄 Check for updates** klickst) die offiziellen Releases von Katalog, App und diesem Projekt. Wenn es etwas Neues gibt, erscheint oben ein Badge.

## Die Spezialisten benutzen

Nach der Installation erscheinen die Spezialisten in deinen Tools:

- **Claude Code / ZCode / Codex / Gemini CLI…** — nenne den Namen in deinem Prompt: *"use the code-reviewer, um diese Änderung zu prüfen"*.
- **In ZCode**, öffne eine Sitzung im Projektordner und schau unter **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — Installation pro *Projekt* (innerhalb des Repository-Ordners).

Der Leitfaden selbst enthält das komplette Playbook: wie man sie aufruft, Beispiele und die fünf goldenen Regeln.

## Unterstützte Tools

| Tool | Umfang | Ziel |
|---|---|---|
| Claude Code | Benutzer | `~/.claude/agents/*.md` |
| ZCode | Benutzer | `~/.zcode/agents/*.md` |
| Codex CLI | Benutzer | `~/.codex/agents/*.toml` (Windows: WSL) |
| Gemini CLI | Benutzer | `~/.gemini/agents/*.md` |
| GitHub Copilot | Benutzer | `~/.github/agents/*.md` |
| Qwen Code | Benutzer | `~/.qwen/agents/*.md` |
| opencode | Benutzer | `~/.config/opencode/agents/*.md` |
| Antigravity | Benutzer | `~/.gemini/config/skills/<slug>/SKILL.md` |
| Osaurus | Benutzer | `~/.osaurus/skills/…` (nur macOS) |
| Kimi CLI | Benutzer | `~/.config/kimi/agents/<slug>/` (Windows: WSL) |
| Cursor / Aider / Windsurf | pro Projekt | innerhalb des Repository-Ordners |

Andere Katalog-Integrationen (Mistral Vibe, DeepSeek Harness, OpenClaw…) funktionieren über den offiziellen Konverter; dafür nutze besser die [Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Sprachen

Der Leitfaden und beide Installer gibt es auf **Englisch, Portugiesisch, Spanisch, Französisch und Deutsch** — inklusive aller Spezialisten-Beschreibungen und aller Praxis-Situationen aus dem echten Leben. Wähle die Sprache bei der Installation oder wechsle jederzeit im Leitfaden (Auswahl oben rechts).

## Lizenzen & Credits

- Dieses Projekt: **MIT** (siehe `LICENSE`).
- Katalog und Konverter: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, von Michael Sitarzewski. Dieses Projekt verpackt, übersetzt und vereinfacht ihn nur für Einsteiger.
- Beschreibungen und Nutzungssituationen wurden übersetzt/angepasst; der englische Originaltext steht in den Details jeder Karte.
