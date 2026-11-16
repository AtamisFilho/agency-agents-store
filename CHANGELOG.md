# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions are tagged `vX.Y.Z` and **must equal** `version` in `dados/meta.json`
(that is also the version the guide's update badge compares against).

## [2.3.0] — 2026-11-16

### Added
- **PWA — o guia virou app instalável e offline** (nova minor):
  - `manifest.webmanifest` (nome, ícones, cores) + `sw.js` (service worker com cache
    por versão: release novo → sw muda → browser reinstala e apaga o cache antigo;
    navegação *network-first* para o guia propagar updates na hora, *cache-first*
    para estáticos; file:// ignora o registro — o guia baixado segue intacto)
  - `index.html` na raiz (redirect) — o GitHub Pages passa a abrir direto o guia
  - `pwa-icons/` — 4 ícones gerados por `gerador/gen_icons.py` (PNG puro, sem
    dependências; bússola nas cores do guia; variante maskable + Apple touch;
    regeneração determinística verificada na CI)
  - `gerador/package_pwa.py` — ZIP determinístico `agency-agents-pwa-vX.Y.Z.zip`
    (guia como `index.html`, manifest, sw, ícones, COMO-HOSPEDAR.md bilíngue)
    anexado como **asset do release** — solte na raiz de qualquer hospedagem
    estática HTTPS e instale pelo navegador
  - CI: determinismo dos ícones (regenera e exige zero diff), build do ZIP,
    gate de atualização estendido a manifest/sw/index; 14 checks novos no
    `tests/test_guide.py` (total 55+ verificações)


## [2.2.2] — 2026-11-16

Hotfix: a CI recém-adicionada (job Windows que executa o instalador de verdade) pegou um
bug **de máquina limpa presente desde a v2.2.0** que nenhum teste nem a revisão de código
cobriam — todos os cenários de teste pré-semeavam o catálogo.

### Fixed
- **Primeira instalação em máquina limpa falhava no clone** (Linux/macOS **e** Windows):
  a persistência do idioma criava `~/.agency-agents/` (com o `config`) *antes* do clone, e
  `git clone` exige diretório de destino vazio → `fatal: destination path already exists`.
  Agora o clone acontece num diretário irmão temporário e é **mesclado** ao destino,
  preservando arquivos locais (como o config de idioma). Novo teste de regressão
  "máquina limpa" na suíte (instalação real com `--lang` em HOME sem catálogo).
- CI: `IndentationError` no smoke Python 3.8 (código inline com indentação extra no YAML);
  strings do step Windows em ASCII puro (o 5.1 lê o script gerado como ANSI).
- Driver: consumidor de pipe fechado (`--list | head`) não gera mais `BrokenPipeError`
  no encerramento (`SIGPIPE` → `SIG_DFL`).

## [2.2.1] — 2026-11-16

Correções da revisão de código pós-lançamento da 2.2.0 (veredito: "precisa de correção" — 4 achados altos, 2 confirmados empiricamente).

### Fixed
- **`--dry-run --uninstall` removia arquivos de verdade** (driver e PS1) — violava o contrato
  "não escreve nada" da flag. Agora o uninstall em dry-run apenas pré-visualiza quantos
  seriam removidos (`[dry-run] …: would remove N`). Novo teste na suíte.
- **Driver quebrava na importação em Python 3.8/3.9** (PEP 604 `X | None` em assinaturas
  sem `from __future__ import annotations`) — público Debian 11/Mint antigo. Corrigido;
  CI agora roda smoke em Python 3.8 e 3.9.
- **Windows PowerShell 5.1: `$ErrorActionPreference=Stop` + stderr de comando nativo
  redirecionado (`2>$null`) derrubava o instalador** no primeiro `git clone`/`git pull`
  (eles sempre escrevem em stderr). Todo comando nativo agora passa por `Invoke-Native`
  (EAP Continue + `$LASTEXITCODE`); de quebra, falha do `git pull` deixou de ser silenciosa.
- **`-Plan` sem valor era impossível no PowerShell** (erro de binding "Missing an argument")
  embora documentado nos 5 READMEs — criado o switch `-PlanAuto` e a documentação corrigida.
- **PS1: `-Status -Json`/`-List` gravavam o config de idioma** — quebrava o contrato
  "writes nothing" (o driver Python já respeitava).
- **Driver: `say()` poluía o stdout em `--json`** (dir_note/plan_autodetected impressos antes
  do JSON) — agora vai para stderr, como os avisos. PS1: `Say`/`Warn` idem em `-Json`/`-List`.
- **PS1: menu de idioma crashava com input não numérico** (`[int]"abc"` com EAP Stop) e
  aceitava "0"/"6" silenciosamente — agora `TryParse` + range 1-5 + fallback para o padrão.
- **PS1: squads.json corrompido instalava TUDO em silêncio** (null → "todas") — agora morre
  com `err_no_data`, igual ao driver.
- **PS1 salvo sem BOM** — `powershell -File` (5.1) lê como ANSI e mostrava mojibake nos
  literais acentuados; agora UTF-8 com BOM (pwsh 7 aceita os dois).
- **Config de idioma**: PS1 agora grava UTF-8 sem BOM e o driver lê com `utf-8-sig`
  (tolera BOM deixado por versões antigas do PowerShell).
- Locale não-UTF-8 (ssh antigo) não derruba mais o driver (`stdout.reconfigure(errors="replace")`).
- Parsing de flags uniforme: `--lang/--tool/--squad/--dir` não engolem mais o token
  seguinte quando ele começa com `--`.
- `build.py` lê JSONs com `encoding="utf-8"` explícito (máquina de contribuidor em cp1252).
- PS1: diretório temporário do convert é limpo em `finally` mesmo com early-return;
  bootstraps e instalador com caminhos de temp não vazam mais.

### Added
- **CI Windows**: job `windows-latest` EXECUTA o instalador de verdade no PowerShell 5.1
  (`-List`, `-Status -Json`, instalação real com `-Plan`) — antes o PS1 só passava pelo
  parser, e era exatamente onde os bugs viviam.
- **CI Python antigo**: matrix 3.8/3.9 (ubuntu-22.04) com smoke de importação + `--status
  --json` + `--list`.
- Testes novos: `--dry-run --uninstall` (não remove nada), roster Aider via `--dir`
  (+ uninstall honesto do roster), idioma salvo respeitado na 2ª execução.

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
