# 🧭 Agency Agents Store — Spezialisten-Leitfaden & Installer

[![CI](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml/badge.svg)](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/AtamisFilho/agency-agents-store)](https://github.com/AtamisFilho/agency-agents-store/releases)
[![CHANGELOG](https://img.shields.io/badge/CHANGELOG-v2.2.2-blue)](CHANGELOG.md)

**Ein HTML-Leitfaden + Installer, die 283 KI-Spezialisten in deine Coding-Tools bringen** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity und mehr).

Gebaut für „Vibe Coder“, die ein Team digitaler Spezialisten an ihrer Seite haben möchten — ohne Fachchinesisch, ohne Aufwand.

> Basiert auf dem Open-Source-Katalog [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) und der [Agency Agents App](https://github.com/msitarzewski/agency-agents-app). Dieses Projekt verpackt, übersetzt und vereinfacht sie für Einsteiger.

**🌐 Lies dies in:** [English](README.md) · [Português](README.pt-BR.md) · [Español](README.es.md) · [Français](README.fr.md) · **[Deutsch](README.de.md)**

---

## Mit einer Zeile installieren

**Linux/macOS** (benötigt `git` + `python3`):
```bash
curl -fsSL https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.sh | bash
```

**Windows** (PowerShell — benötigt [Git for Windows](https://git-scm.com/download/win)):
```powershell
irm https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.ps1 | iex
```

Die Eine-Zeile-Installation lädt Installer, Übersetzungen und den Guide nach `~/.agency-agents-store` und führt alles von dort aus. Lieber das komplette Repository? **Code → Download ZIP** und weiterlesen.

## Was hier drin ist

| Datei/Ordner | Was es ist |
|---|---|
| `guia-especialistas-agencia.html` | **Der Guide.** Doppelklick zum Öffnen — funktioniert offline. Suche, Filter, Panel „deine Maschine“ und jeder Spezialist einfach erklärt, mit 4 echten Einsatzsituationen. Verfügbar in Englisch, Portugiesisch, Spanisch, Französisch und Deutsch. |
| `instaladores/instalar.sh` / `instalar.ps1` | **Eine-Zeile-Bootstraps** (die Befehle oben). |
| `instaladores/instalar-linux.sh` | Installer für **Linux und macOS** (schlanker Wrapper — prüft Voraussetzungen, ruft dann den Kern auf). |
| `instaladores/agency-install.py` | **Der Installations-Kern** (alle Flags, die ganze Logik) für Linux/macOS. |
| `instaladores/instalar-windows.ps1` | Installer für **Windows** (natives PowerShell, ohne Python; nutzt dieselbe Übersetzungsdatei). |
| `gerador/build.py` | Baut den Guide aus `dados/` neu (Wartung). |
| `dados/` | Übersetzter Katalog + echte Situationen + `meta.json` (Single Source of Truth) + `i18n-instalador.json` (Installer-Meldungen, 5 Sprachen). |

## Erste Schritte (5 Minuten)

### 1. Den Guide holen
Klicke auf **Code → Download ZIP** (oder klone das Repository) und öffne `guia-especialistas-agencia.html` — du kannst alle 283 Spezialisten durchstöbern, ohne etwas zu installieren. Sprache oben rechts wählen.

### 2. Installer einmal ausführen
Er erkennt, welche Tools du hast (Claude Code, ZCode, Codex…), **fragt deine Sprache** (und merkt sie sich in `~/.agency-agents/config`; die System-Locale gilt als erste Voreinstellung), fragt wohin und wie viele Spezialisten, **sichert** alles, was er anfasst, und am Ende aktualisiert sich das Maschinen-Panel des Guides von selbst.

**Linux/macOS** (aus dem Repository):
```bash
./instaladores/instalar-linux.sh
```

**Windows** (PowerShell — Voraussetzung: [Git for Windows](https://git-scm.com/download/win)):
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # falls nachgefragt
.\instalar-windows.ps1
```

### 3. Aus dem Guide heraus installieren (optional)
Im Guide fragt die Schaltfläche **„➕ Spezialisten in einem Tool installieren“** *wohin* und *wen* (Pre-Launch-Team, Trainings-Team, alle 283, oder nach Abteilung) und erzeugt eine `agency-plan.json`. Dann, aus dem Ordner, in dem du den Plan gespeichert hast:

```bash
./instaladores/instalar-linux.sh --plan          # Pfad ist optional: er findet agency-plan.json
.\instalar-windows.ps1 -PlanAuto                 # unter Windows genauso (findet den Plan automatisch)
```

Der Installer sucht den Plan automatisch in `.`, `..`, im Installer-Ordner, in `~/Downloads` und `~/Documents` (der alte Name `plano-agencia.json` funktioniert auch).

## Automatisierung & Feinsteuerung (dieselben Flags auf beiden Plattformen)

| Linux/macOS | Windows | Was es tut |
|---|---|---|
| `--tool zcode,codex` | `-Tool zcode,codex` | Tools ohne Rückfrage wählen (gültige ids: `--list`) |
| `--squad pre\|treino\|all` | `-Squad pre\|treino\|all` | Team ohne Rückfrage wählen (CI/Skripte) |
| `--plan [DATEI]` | `-Plan DATEI` / `-PlanAuto` | Plan des Guides verwenden (Auto-Suche: `--plan` ohne Pfad, oder `-PlanAuto`) |
| `--dry-run` | `-DryRun` | Zeigt alles, was angefasst würde — schreibt nichts |
| `--list` | `-List` | Katalog/Tools/Teams als JSON auf stdout (niemals Netz) |
| `--status` | `-Status` | Nur erkennen + Guide-Panel aktualisieren (ohne Netz) |
| `--status --json` | `-Status -Json` | Maschinenstatus als JSON auf stdout (schreibt nichts) |
| `--uninstall` | `-Uninstall` | Entfernt die Agentur-Spezialisten (Backup vorher; behält deine Dateien) |
| `--dir <pfad>` | `-Dir <pfad>` | Installiert in einen **Projekt**-Ordner — aktiviert Cursor/Aider/Windsurf |
| `--lang en\|pt\|es\|fr\|de` | `-Lang en\|pt\|es\|fr\|de` | Sprache (wird für künftige Läufe gemerkt) |

Beispiele:
```bash
./instaladores/instalar-linux.sh --tool cursor --dir ~/code/mein-app --squad treino   # Cursor-Regeln im Projekt
./instaladores/instalar-linux.sh --uninstall --tool zcode                           # entfernen (mit Backup)
./instaladores/instalar-linux.sh --dry-run --tool claudeCode --squad pre            # nur schauen
./instaladores/instalar-linux.sh --list | jq '.tools[].id'                          # für Skripte
```

## Was der Installer tut (und was nicht)

✅ Erkennt installierte Tools und dein Betriebssystem
✅ Fragt deine Sprache einmal — und merkt sie sich (System-Locale ist der Standard)
✅ Lädt/aktualisiert den offiziellen Katalog nach `~/.agency-agents`
✅ Konvertiert die Agents mit dem **offiziellen Konverter** (byte-identisch)
✅ **Sichert** nach `~/.agency-agents-backup/`, bevor etwas überschrieben wird
✅ **Prüft ehrlich**: meldet, wie viele der angeforderten Spezialisten wirklich am Ziel sind
✅ Schreibt `guia-status.js` neben den Guide (das füttert das Maschinen-Panel)
✅ Deinstalliert sauber (`--uninstall`) — nur Agentur-Dateien, immer mit Backup
❌ Installiert **keine** Tools, die du nicht hast (konfiguriert nur Vorhandenes/Kompatibles)
❌ Nutzt **kein** Netz in den Modi `--status`/`--list`/`--json` (Installieren ja, um den Katalog zu holen)
❌ Schickt **nichts** an irgendwen sonst (nur der Guide prüft auf Wunsch GitHub-Releases)

## Automatische Updates

Der Guide prüft (alle 24h oder bei Klick auf **🔄 Jetzt nach Updates suchen**) die offiziellen Releases des Katalogs, der App und dieses Projekts. Wenn etwas Neues erscheint, zeigt ein Badge oben. Die Releases dieses Projekts folgen [CHANGELOG.md](CHANGELOG.md) — der Tag (`vX.Y.Z`) entspricht immer der Guide-Version.

## Die Spezialisten benutzen

Nach der Installation tauchen die Spezialisten in deinen Tools auf:

- **Claude Code / ZCode / Codex / Gemini CLI…** — nenne den Namen in der Anfrage: *„nutze den code-reviewer, um diese Änderung zu reviewen“*.
- **In ZCode**: Sitzung im Projektordner öffnen und **Settings → Subagents** ansehen.
- **Cursor / Aider / Windsurf** — Installation *pro Projekt* mit `--dir <Projektordner>` (Regeln/Index leben im Repository).

Der Guide selbst enthält das komplette Playbook: Aufruf, Beispiele und die fünf goldenen Regeln.

## Unterstützte Tools

| Tool | Geltungsbereich | Ziel |
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
| Cursor | pro Projekt (`--dir`) | `<projekt>/.cursor/rules/<slug>.mdc` |
| Aider | pro Projekt (`--dir`) | `<projekt>/CONVENTIONS.md` (Index) |
| Windsurf | pro Projekt (`--dir`) | `<projekt>/.windsurfrules` (Index) |

Weitere Katalog-Integrationen (Mistral Vibe, DeepSeek Harness, OpenClaw…) laufen über den offiziellen Konverter; dafür bevorzuge die [Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Sprachen

Guide und beide Installer gibt es in **Englisch, Portugiesisch, Spanisch, Französisch und Deutsch** — inklusive aller Spezialisten-Beschreibungen und echten Einsatzsituationen. Sprache bei der Installation wählen (wird gemerkt) oder jederzeit im Guide wechseln (Selektor oben).

## Entwicklung

- `python3 gerador/build.py` baut den Guide aus `dados/` neu — die CI schlägt fehl, wenn das committete HTML nicht zu den Daten passt.
- `python3 tests/test_guide.py` — statische Guide-Tests (Payload, i18n-Parität, XSS).
- `bash tests/run-tests.sh` — adversarial-Installer-Suite (dynamische Katalog-Zählungen, alle Flags).
- Die CI führt alles bei jedem Push/PR aus (siehe [.github/workflows/ci.yml](.github/workflows/ci.yml)).

## Lizenzen & Credits

- Dieses Projekt: **MIT** (siehe `LICENSE`).
- Katalog und Konverter: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, von Michael Sitarzewski. Dieses Projekt verpackt, übersetzt und vereinfacht es nur für Einsteiger.
- Beschreibungen und Einsatzsituationen wurden übersetzt/angepasst; der englische Originaltext steht in den Details jeder Karte.
