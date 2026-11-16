# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions are tagged `vX.Y.Z` and **must equal** `version` in `dados/meta.json`
(that is also the version the guide's update badge compares against).

## [2.2.0] — 2026-11-16

### Fixed
- **Installer depends on Python 3 without checking** — Linux/macOS wrapper now verifies
  `python3` (and `git`) up front with a clear, localized message instead of dying with a
  cryptic error under `set -euo pipefail` (fresh macOS without Python was the common case).
- **macOS without Homebrew never opened the guide** — `osascript -e 'open location …'`
  added as the third fallback after `xdg-open`/`open`.
- **`--status` downloaded the catalog anyway** — status (and `--list`/`--json`) no longer
  touch the network: they use the local catalog when present and clearly say so when not.
- **Unknown tool names in a plan created junk directories** (e.g. `~/.claude/agents/empty`
  from `basename ""`): the Python driver validates every id/path before touching anything.
- **Windows: `guia-status.js` was written as ASCII** — corrupted ✓ marks and accents;
  now written as UTF-8 without BOM.
- **Windows: panel showed today's date as the catalog date** — now uses the real
  `git log -1 --format=%cs` commit date, same as bash.
- **Windows: hand-built MSYS path broke on non-C: drives, spaces and `&`** — all
  conversions now go through `cygpath -u/-w` from Git's own bash, with arguments passed
  positionally (never inside a quoted `-c` string).
- **~200 lines of i18n duplicated (and diverging) between the two installers** — both now
  read the single source `dados/i18n-instalador.json`; a missing key in one language falls
  back to English instead of printing the raw key.
- **Tests hard-coded upstream counts (283/18)** — the suite now derives expectations from
  the catalog's own rule (divisions.json + frontmatter) and from `dados/`, so upstream
  growth no longer breaks CI. This was real: the catalog already gained a `strategy`
  division that the old hard-coded list silently skipped.
- `.gitignore` listed `plano-agencia.json` but the wizard saves `agency-plan.json` —
  both names are ignored now.
- Wizard command ran `../instaladores/…` while telling users to open the terminal where
  the guide lives (one directory above the plan) — command now runs from the repo root,
  and the installer also finds the plan automatically.

### Added
- **One-line installers** (no need to know where the ZIP is):
  - Linux/macOS: `curl -fsSL https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.sh | bash`
  - Windows: `irm https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.ps1 | iex`
- **Unified installer core** — `instaladores/agency-install.py` (Linux/macOS driver);
  `instalar-linux.sh` became a thin prerequisite-checking wrapper. Windows keeps native
  PowerShell (no Python required there) but shares the same translation source.
- **New flags** (both platforms): `--tool a,b,c` and `--squad pre|treino|all`
  (non-interactive, CI-friendly), `--dry-run`, `--list` (catalog/tools/squads as JSON),
  `--uninstall` (removes only agency files, backing them up first), `--dir <project>`
  (per-project installs — Cursor rules, Aider roster, Windsurf rules finally supported),
  `--status --json` (machine status as JSON on stdout, writes nothing).
- **Plan auto-detection**: `--plan` without a value searches `.`, `..`, the installer
  folder, `~/Downloads`, `~/Documentos`, `~/Documents` for `agency-plan.json`
  (and the legacy `plano-agencia.json`).
- **Language persistence**: the chosen language is saved to `~/.agency-agents/config`
  and the OS locale is used as the first-run default (no more asking every run).
- **Honest post-install verification**: counts only files that actually match the
  catalog (by file stem *or* official slug) and reports how many of the requested
  specialists are missing — before, "failure" only fired when *zero* appeared.
- **Project tools**: Cursor (`.cursor/rules/*.mdc`), Aider (`CONVENTIONS.md` roster)
  and Windsurf (`.windsurfrules`) via `--dir`.
- **CI (GitHub Actions)**: `bash -n`, PowerShell parser, `py_compile`, JSON validation,
  guide static tests, a "guide is up to date with dados/" gate and the full adversarial
  installer suite on every push/PR.
- **`dados/meta.json`** — single source of truth for the generator (version, divisions,
  tags, expected tool count) with declarative validation, replacing the dead
  hard-coded lists in `build.py`.
- This CHANGELOG — the guide's update badge needs tagged releases; release flow:
  bump `dados/meta.json` version → regenerate the guide → commit → tag `vX.Y.Z` → publish
  the GitHub release.

## [2.1.1] — 2026-11-15
- Fixed update badge: the JS queried `getElementById("updBadge")` but the element
  did not exist in the HTML — added, with a regression test.

## [2.1.0] — 2026-11-15
- Five languages (EN/PT/ES/FR/DE) across the whole flow — guide UI, every specialist
  description, 4 real-world situations per agent, installer messages.
- Adversarial review pass over installer and guide.

## [2.0.0] — 2026-11-15
- Specialist guide (self-contained offline HTML), machine panel, plan wizard and
  Linux/Windows installers on top of the open source agency-agents catalog.
