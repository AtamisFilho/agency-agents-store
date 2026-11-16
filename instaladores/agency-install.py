#!/usr/bin/env python3
"""agency-install.py — driver comum dos instaladores do Agency Agents Store.

Linux/macOS: chamado por instalar-linux.sh (wrapper fino) ou pelo one-liner
                (instalar.sh baixa este driver + dados/ para ~/.agency-agents-store).
Windows:      a lógica nativa vive em instalar-windows.ps1, mas LÊ A MESMA fonte
              de traduções (dados/i18n-instalador.json) — mensagens nunca divergem.

Modo:
  --plan [FILE]   usa o plano do guia (FILE opcional: busca automática em
                  ./ ../ ~/Downloads ~/Documentos ~/Documents por agency-plan.json)
  --tool a,b,c    ferramentas sem perguntar (ids válidos: --list)
  --squad pre|treino|all   quantos especialistas (não-interativo/CI)
  --status        só detectar + atualizar o painel (NUNCA usa rede)
  --status --json / --json  status em JSON no stdout (não escreve nada)
  --list          catálogo/ferramentas/squads em JSON (não usa rede)
  --dry-run       pré-visualiza o que seria tocado (não escreve nada)
  --uninstall     remove especialistas da agência (backup antes; --tool p/ escolher)
  --dir PASTA     instala dentro de um projeto (Cursor/Aider/Windsurf e cia.)
  --lang en|pt|es|fr|de     idioma (persistido em ~/.agency-agents/config)
"""
from __future__ import annotations  # PEP 604 (`X | None`) em anotações: compatível com Python 3.8+

import json
import os
import re
import shutil
import stat as statmod
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
HOME = Path.home()
CATALOG_DIR = HOME / ".agency-agents"
CATALOG_REPO = "https://github.com/msitarzewski/agency-agents.git"
BACKUP_DIR = HOME / ".agency-agents-backup"
STORE_DIR = HOME / ".agency-agents-store"          # one-liner baixa tudo aqui
CONFIG_FILE = CATALOG_DIR / "config"               # lang=xx persistida
GUIDE_NAME = "guia-especialistas-agencia.html"
LANGS = ["en", "pt", "es", "fr", "de"]
PLAN_NAMES = ["agency-plan.json", "plano-agencia.json"]  # novo + nome legado

# ---------- fonte única de dados ----------
# dados/ do repo quando existir (wrapper no repo, ou ~/.agency-agents-store do one-liner);
# embutido em inglês como fallback para o driver rodar sozinho.


def find_repo_root() -> Path | None:
    """Sobe a partir do script procurando dados/i18n-instalador.json."""
    d = SCRIPT_DIR
    for _ in range(4):
        if (d / "dados" / "i18n-instalador.json").is_file():
            return d
        if d.parent == d:
            break
        d = d.parent
    return None


REPO = find_repo_root()

_FALLBACK_EN = {
    "pick_lang": "Choose your language:",
    "need_git": "Git not found. Install it first: https://git-scm.com (Ubuntu: sudo apt install git · macOS: xcode-select --install)",
    "need_python": "Python 3 not found, and this installer needs it. Install it first: https://www.python.org",
    "cat_update": "Updating the catalog in {0}...",
    "cat_clone": "Downloading the official agent catalog (~/.agency-agents)...",
    "cat_fail": "Failed to clone the catalog. Check your internet connection.",
    "cat_status_missing": "Catalog not found at {0} — detection only, nothing was downloaded. Run again without --status to install.",
    "found": "Tools found on this machine:",
    "installed_ok": "installed ✓",
    "not_installed": "not installed (I can still configure it)",
    "pick_tools": "Comma-separated numbers (Enter = all):",
    "pick_squad": "How many specialists to install?",
    "squad1": "1) Pre-launch squad (12 — recommended)",
    "squad2": "2) Training squad (4)",
    "squad3": "3) Everyone (the whole agency)",
    "installing": "Installing specialists into {0}...",
    "install_ok": "Specialists installed in {0} ✓ ({1} at the destination)",
    "install_partial": "Only {0} of {1} requested specialists are present in {2} — missing: {3}",
    "install_fail": "NO specialist found in {0} after installation — see warnings above.",
    "roster_note": "{0}: single roster file with the whole agency (per-specialist filtering is not possible).",
    "roster_ok": "Roster updated: {0} ✓ ({1})",
    "panel_updated": "Guide panel updated: {0}",
    "status_fail": "Could not write the guide panel (guia-status.js) — check the folder permissions. Everything else succeeded.",
    "guia_not_found": "guia-especialistas-agencia.html not found next to the installer — panel not written.",
    "done": "Done! Real state of this machine:",
    "detected": "detected",
    "absent": "absent",
    "specialists": "agency specialist(s)",
    "opening": "Opening the guide...",
    "rerun": "Tip: run again anytime — it is safe (backs up before overwriting).",
    "err_plan": "Plan file not found: {0}",
    "err_lang": "Invalid language: {0} (use en, pt, es, fr or de)",
    "err_bad_plan": "Invalid plan file: {0}",
    "err_notty": "Interactive mode needs a terminal. Use: --plan agency-plan.json, or --tool/--squad for scripts.",
    "err_need_squad": "Non-interactive install needs --squad (pre, treino or all) or --plan.",
    "err_squad": "Invalid squad: {0} (use pre, treino or all)",
    "err_dir": "Project directory not found: {0}",
    "err_no_data": "Installer data files (dados/) were not found. Use the one-line installer from the README, or download the full repository.",
    "unsupported": "Tool {0} not supported by this installer yet (use the Agency Agents App).",
    "unsupported_os": "Tool {0} is not available for {1}.",
    "tool_unknown": "Unknown tool: {0} — skipped (use --list to see the valid ids).",
    "dry_run_banner": "DRY-RUN: nothing will be written — preview only.",
    "dry_run_action": "[dry-run] {0}: would install {1} specialist(s) into {2}",
    "dry_run_remove": "[dry-run] {0}: would remove {1} specialist(s)",
    "dry_run_panel": "[dry-run] guide panel not written.",
    "uninstall_ok": "{0} specialist(s) removed from {1} — backup saved in {2}",
    "uninstall_none": "No agency specialist found in {0} — nothing to remove.",
    "uninstall_skip": "{0}: roster file not removed automatically — delete {1} by hand if you want.",
    "plan_autodetected": "Plan found automatically: {0}",
    "dir_note": "Installing into project directory: {0}",
}

_I18N = {"en": dict(_FALLBACK_EN)}
if REPO:
    try:
        _data = json.loads((REPO / "dados" / "i18n-instalador.json").read_text(encoding="utf-8"))
        for _lang in LANGS:
            if _lang in _data and isinstance(_data[_lang], dict):
                # overlay: faltou chave num idioma → fallback inglês, nunca a chave crua
                merged = dict(_FALLBACK_EN)
                merged.update(_data[_lang])
                _I18N[_lang] = merged
    except (OSError, ValueError):
        pass

LANG_SEL = "en"


def msg(key, *args):
    table = _I18N.get(LANG_SEL) or _I18N["en"]
    s = table.get(key) or _I18N["en"].get(key) or key
    return s.format(*args) if args else s


# ---------- saída ----------
_USE_COLOR = sys.stdout.isatty() and os.environ.get("TERM") != "dumb"
_JSON_MODE = False  # --list/--json: stdout é dado estruturado, avisos vão p/ stderr

# console em locale não-UTF-8 (ex.: ssh antigo) não pode derrubar o instalador no "✓"
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(errors="replace")
    except (AttributeError, OSError):
        pass
try:  # consumidor de pipe fechado (ex.: `--list | head`) não vira BrokenPipeError no fim
    import signal
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except (ImportError, AttributeError, OSError):
    pass


def say(text):
    print(("\033[0;32m[ok]\033[0m  " if _USE_COLOR else "[ok]  ") + text,
          file=sys.stderr if _JSON_MODE else sys.stdout)


def warn(text):
    print(("\033[0;33m[!!]\033[0m  " if _USE_COLOR else "[!!]  ") + text,
          file=sys.stderr if _JSON_MODE else sys.stdout)


def err_out(text):
    print(("\033[0;31m[err]\033[0m " if _USE_COLOR else "[err] ") + text, file=sys.stderr)


def die(text):
    err_out(text)
    sys.exit(1)


# ---------- ferramentas ----------
# kind: identity (copia o .md oficial) | rendered (convert.sh) | roster (arquivo único)
TOOLS = [
    {"id": "claudeCode", "label": "Claude Code", "kind": "identity", "rel": ".claude/agents",
     "compat": {"linux": "sim", "macos": "sim", "windows": "sim"}, "project_only": False,
     "detect_dirs": [".claude"], "detect_bin": "claude"},
    {"id": "zcode", "label": "ZCode", "kind": "rendered", "kebab": "zcode",
     "rel": ".zcode/agents", "sub": "agents", "mode": "arquivo",
     "compat": {"linux": "sim", "macos": "sim", "windows": "sim"}, "project_only": False,
     "detect_dirs": [".zcode"], "detect_bin": None},
    {"id": "codex", "label": "Codex CLI", "kind": "rendered", "kebab": "codex",
     "rel": ".codex/agents", "sub": "agents", "mode": "arquivo",
     "compat": {"linux": "sim", "macos": "sim", "windows": "wsl"}, "project_only": False,
     "detect_dirs": [".codex"], "detect_bin": "codex"},
    {"id": "geminiCli", "label": "Gemini CLI", "kind": "rendered", "kebab": "gemini-cli",
     "rel": ".gemini/agents", "sub": "agents", "mode": "arquivo",
     "compat": {"linux": "sim", "macos": "sim", "windows": "sim"}, "project_only": False,
     "detect_dirs": [".gemini"], "detect_bin": None},
    {"id": "copilot", "label": "GitHub Copilot", "kind": "identity", "rel": ".github/agents",
     "compat": {"linux": "sim", "macos": "sim", "windows": "sim"}, "project_only": False,
     "detect_dirs": [".github/agents", ".copilot"], "detect_bin": None},
    {"id": "qwen", "label": "Qwen Code", "kind": "rendered", "kebab": "qwen",
     "rel": ".qwen/agents", "sub": "agents", "mode": "arquivo",
     "compat": {"linux": "sim", "macos": "sim", "windows": "sim"}, "project_only": False,
     "detect_dirs": [".qwen"], "detect_bin": None},
    {"id": "opencode", "label": "opencode", "kind": "rendered", "kebab": "opencode",
     "rel": ".config/opencode/agents", "sub": "agents", "mode": "arquivo",
     "compat": {"linux": "sim", "macos": "sim", "windows": "sim"}, "project_only": False,
     "detect_dirs": [".config/opencode"], "detect_bin": None},
    {"id": "antigravity", "label": "Antigravity", "kind": "rendered", "kebab": "antigravity",
     "rel": ".gemini/config/skills", "sub": "skills", "mode": "pasta",
     "compat": {"linux": "sim", "macos": "sim", "windows": "sim"}, "project_only": False,
     "detect_dirs": [".gemini/config"], "detect_bin": None},
    {"id": "osaurus", "label": "Osaurus", "kind": "rendered", "kebab": "osaurus",
     "rel": ".osaurus/skills", "sub": "skills", "mode": "pasta",
     "compat": {"linux": "nao", "macos": "sim", "windows": "nao"}, "project_only": False,
     "detect_dirs": [".osaurus"], "detect_bin": None},
    {"id": "kimi", "label": "Kimi CLI", "kind": "rendered", "kebab": "kimi",
     "rel": ".config/kimi/agents", "sub": "agents", "mode": "pasta",
     "compat": {"linux": "sim", "macos": "sim", "windows": "wsl"}, "project_only": False,
     "detect_dirs": [".config/kimi"], "detect_bin": None},
    {"id": "cursor", "label": "Cursor", "kind": "rendered", "kebab": "cursor",
     "rel": ".cursor/rules", "sub": "rules", "mode": "arquivo",
     "compat": {"linux": "sim", "macos": "sim", "windows": "sim"}, "project_only": True,
     "detect_dirs": [".cursor"], "detect_bin": None},
    {"id": "aider", "label": "Aider", "kind": "roster", "kebab": "aider",
     "rel": "CONVENTIONS.md", "roster_file": "CONVENTIONS.md",
     "compat": {"linux": "sim", "macos": "sim", "windows": "wsl"}, "project_only": True,
     "detect_dirs": [], "detect_bin": "aider"},
    {"id": "windsurf", "label": "Windsurf", "kind": "roster", "kebab": "windsurf",
     "rel": ".windsurfrules", "roster_file": ".windsurfrules",
     "compat": {"linux": "sim", "macos": "sim", "windows": "sim"}, "project_only": True,
     "detect_dirs": [".windsurf"], "detect_bin": None},
]
TOOL_BY_ID = {t["id"]: t for t in TOOLS}

OSF, OSL = ("macos", "macOS") if sys.platform == "darwin" else ("linux", "Linux")
ARCH = os.uname().machine if hasattr(os, "uname") else ""


def os_compat(tool):
    return tool["compat"].get(OSF, "nao")


# ---------- catálogo ----------

def catalog_divisions(cat: Path) -> list[str]:
    """Divisões oficiais: divisões do divisions.json do catálogo (fonte upstream);
    fallback: diretórios de topo exceto osKnown não-divisão. O upstream também
    varre strategy/ (docs NEXUS sem frontmatter, filtradas por is_agent_file)."""
    divs: list[str] = []
    dj = cat / "divisions.json"
    if dj.is_file():
        try:
            text = dj.read_text(encoding="utf-8", errors="replace")
            m = re.search(r'"divisions"\s*:\s*\{', text)
            if m:
                divs = re.findall(r'"([a-z0-9-]+)"\s*:\s*\{', text[m.end():])
        except OSError:
            pass
    if not divs:
        exclude = {"scripts", "integrations", "examples", ".git", ".github", "i18n"}
        divs = sorted(p.name for p in cat.iterdir() if p.is_dir() and p.name not in exclude)
    if "strategy" not in divs:  # varrido pelo install.sh upstream (docs NEXUS)
        divs = divs + ["strategy"]
    return divs


def is_agent_file(p: Path) -> bool:
    """Regra oficial do catálogo: .md cuja 1ª linha é a cerca de frontmatter."""
    try:
        with p.open(encoding="utf-8", errors="replace") as fh:
            return fh.readline().strip() == "---"
    except OSError:
        return False


def catalog_agents(cat: Path) -> list[Path]:
    out = []
    for d in catalog_divisions(cat):
        dd = cat / d
        if not dd.is_dir():
            continue
        out.extend(p for p in sorted(dd.rglob("*.md")) if is_agent_file(p))
    return out


def _frontmatter_name(p: Path) -> str | None:
    """Campo name: do bloco de frontmatter (mesma fonte do convert.sh)."""
    try:
        with p.open(encoding="utf-8", errors="replace") as fh:
            if fh.readline().strip() != "---":
                return None
            for line in fh:
                if line.strip() == "---":
                    break
                m = re.match(r"^name:\s*(.+?)\s*$", line)
                if m:
                    return m.group(1).strip().strip("\"'")
    except OSError:
        pass
    return None


def _slugify(name: str) -> str:
    """slugify oficial do catálogo (lib.sh): minúsculas, não-alnum → '-', colapsa."""
    s = re.sub(r"[^a-z0-9]", "-", name.lower())
    return re.sub(r"-{2,}", "-", s).strip("-")


def catalog_keys(cat: Path) -> set[str]:
    """Chaves de match da agência: stems dos arquivos (identity copia <stem>.md)
    E slugs oficiais (renderizados nomeiam por slug: code-reviewer.md, <slug>/SKILL.md…)."""
    keys = set()
    for p in catalog_agents(cat):
        keys.add(p.stem)
        n = _frontmatter_name(p)
        if n:
            keys.add(_slugify(n))
    return keys


SLUG_MAP = {}  # slug oficial → stem do arquivo (para "faltando" honesto e uninstall por plano)


def _slug_map(cat: Path) -> dict[str, str]:
    out = {}
    for p in catalog_agents(cat):
        n = _frontmatter_name(p)
        if n:
            out[_slugify(n)] = p.stem
    return out


def run_git(*args, cwd=None) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


def ensure_catalog(allow_network: bool) -> bool:
    """True se o catálogo está disponível. --status/--list/--json nunca clonam."""
    if (CATALOG_DIR / ".git").is_dir():
        if allow_network:
            say(msg("cat_update", str(CATALOG_DIR)))
            if run_git("-C", str(CATALOG_DIR), "pull", "--ff-only").returncode != 0:
                warn(msg("catalog_update_skipped"))
        return True
    if (CATALOG_DIR / "divisions.json").is_file():
        return True  # clone sem .git (ex.: fixture de teste) — usa como está
    if not allow_network:
        warn(msg("cat_status_missing", str(CATALOG_DIR)))
        return False
    say(msg("cat_clone"))
    if not shutil.which("git"):
        die(msg("need_git"))
    # clona em irmão temporário e mescla: ~/.agency-agents pode já existir
    # (ex.: config de idioma salvo antes do clone) e git clone exige dir vazio
    tmp = CATALOG_DIR.with_name(f".agency-agents.new-{os.getpid()}")
    shutil.rmtree(tmp, ignore_errors=True)
    if run_git("clone", "--depth", "1", CATALOG_REPO, str(tmp)).returncode != 0:
        shutil.rmtree(tmp, ignore_errors=True)
        die(msg("cat_fail"))
    CATALOG_DIR.mkdir(parents=True, exist_ok=True)
    for item in tmp.iterdir():  # preserva o que já existe localmente (config etc.)
        dst = CATALOG_DIR / item.name
        if dst.exists():
            shutil.rmtree(item, ignore_errors=True) if item.is_dir() else item.unlink(missing_ok=True)
        else:
            shutil.move(str(item), str(dst))
    shutil.rmtree(tmp, ignore_errors=True)
    return True


def catalog_meta():
    if not (CATALOG_DIR / ".git").is_dir():
        return "?", "?"
    c = run_git("-C", str(CATALOG_DIR), "rev-parse", "--short", "HEAD")
    d = run_git("-C", str(CATALOG_DIR), "log", "-1", "--format=%cs")
    commit = c.stdout.strip() if c.returncode == 0 and c.stdout.strip() else "?"
    date = d.stdout.strip() if d.returncode == 0 and d.stdout.strip() else "?"
    return commit, date


# ---------- detecção ----------

def tool_installed(tool) -> bool:
    if tool["detect_bin"] and shutil.which(tool["detect_bin"]):
        return True
    return any((HOME / d).exists() for d in tool["detect_dirs"])


def count_agents_rel(rel: str) -> int:
    """Resumo (arquivo de agente qualquer no destino — semântica do resumo antigo)."""
    d = HOME / rel
    if not d.exists():
        return 0
    if d.is_file():
        return 1 if d.suffix in {".md", ".toml", ".mdc"} or d.name in {"SKILL.md", "agent.yaml", ".windsurfrules"} else 0
    n = 0
    for p in d.rglob("*"):
        if p.is_file() and (p.suffix in {".md", ".toml", ".mdc"} or p.name in {"SKILL.md", "agent.yaml"}):
            n += 1
    return n


def agency_count(tool, base: Path, stems: set[str] | None) -> int:
    """Contagem honesta: só arquivos que batem com o catálogo da agência."""
    if not stems:
        return 0
    d = base / tool["rel"]
    if not d.exists():
        return 0
    if tool.get("kind") == "roster":
        return 1 if d.is_file() else 0  # roster = 1 arquivo-índice (B2)
    if d.is_file():
        return 1 if d.stem in stems else 0
    n = 0
    for p in d.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix in {".md", ".toml", ".mdc"} and (p.stem in stems or p.name.rsplit(".", 1)[0] in stems):
            n += 1
        elif p.parent.name in stems and p.name in {"SKILL.md", "agent.yaml", "SOUL.md", "prompt.md"}:
            n += 1  # pastas de skill (antigravity/osaurus/kimi/…)
    return n


# ---------- backup ----------

_TS = datetime.now().strftime("%Y%m%d-%H%M%S")


def backup_path(src: Path, base_dir: Path, sub: str = "") -> Path:
    b = BACKUP_DIR / _TS / sub
    try:
        rel = src.relative_to(base_dir)
    except ValueError:
        rel = Path(src.name)
    return b / rel


def backup_file(dst: Path, base_dir: Path, ref: Path | None = None, sub: str = ""):
    """Só salva quando existe e o conteúdo vai mudar de verdade."""
    if not dst.exists():
        return
    if ref is not None and ref.is_file():
        try:
            if dst.read_bytes() == ref.read_bytes():
                return
        except OSError:
            pass
    b = backup_path(dst, base_dir, sub)
    b.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dst, b)


def backup_dir(dst: Path, base_dir: Path, sub: str = ""):
    if not dst.is_dir():
        return
    b = backup_path(dst, base_dir, sub)
    b.parent.mkdir(parents=True, exist_ok=True)
    if not b.exists():
        shutil.copytree(dst, b)


# ---------- plano ----------

def autodetect_plan() -> Path | None:
    search = [Path.cwd(), Path.cwd().parent, SCRIPT_DIR]
    if REPO:
        search.append(REPO)
    search += [HOME / "Downloads", HOME / "Documentos", HOME / "Documents"]
    for d in search:
        if not d.is_dir():
            continue
        for name in PLAN_NAMES:
            cand = d / name
            if cand.is_file():
                return cand
    return None


def validate_plan(path: Path):
    try:
        p = json.loads(path.read_text(encoding="utf-8"))
        assert isinstance(p, dict) and isinstance(p.get("agentes"), list) and isinstance(p.get("ferramentas"), list)
        assert all(isinstance(t, str) and t.strip() for t in p["ferramentas"]), "ferramentas"
        for a in p["agentes"]:
            f, s = a["file"], a["slug"]
            assert isinstance(f, str) and f and not f.startswith(("/", "\\")) and ".." not in f.split("/") \
                and not re.match(r"^[A-Za-z]:", f), f"unsafe path: {f}"
            assert isinstance(s, str) and s.strip() and "/" not in s and "\\" not in s, f"unsafe slug: {s}"
        return p
    except Exception:
        die(msg("err_bad_plan", str(path)))


# ---------- seleção ----------

class NoTTY(Exception):
    pass


def _stdin_is_pipe() -> bool:
    """stdin vindo de pipe (ex.: `curl … | bash`) — dá para perguntar via /dev/tty.
    /dev/null e arquivos redirecionados NÃO contam (comportamento = sem TTY)."""
    try:
        return statmod.S_ISFIFO(os.fstat(0).st_mode)
    except OSError:
        return False


def interactive_ok() -> bool:
    if sys.stdin.isatty():
        return True
    return _stdin_is_pipe() and os.access("/dev/tty", os.R_OK | os.W_OK)


def ask(prompt: str) -> str:
    """Lê do stdin se for TTY; senão do /dev/tty (permite `curl | bash` interativo)."""
    if sys.stdin.isatty():
        return input(prompt)
    try:
        with open("/dev/tty", encoding="utf-8", errors="replace") as tty:
            sys.stdout.write(prompt)
            sys.stdout.flush()
            return tty.readline().rstrip("\n")
    except OSError:
        raise NoTTY()


def load_squads() -> dict | None:
    for root in (REPO, STORE_DIR):
        if root:
            f = root / "dados" / "squads.json"
            if f.is_file():
                try:
                    return json.loads(f.read_text(encoding="utf-8"))
                except (OSError, ValueError):
                    return None
    return None


def squad_slugs(name: str) -> list[str] | None:
    """None = todas. Erro se dados de squad não estiverem disponíveis."""
    key = {"pre": "pre-lancamento", "pre-lancamento": "pre-lancamento",
           "treino": "treino", "all": None, "todas": None, "todos": None}.get(name)
    if name not in {"pre", "pre-lancamento", "treino", "all", "todas", "todos"}:
        die(msg("err_squad", name))
    if key is None:
        return None
    squads = load_squads()
    if not squads or key not in squads:
        die(msg("err_no_data"))
    return [a["slug"] for a in squads[key]["agentes"]]


# ---------- instalação ----------

DRY_RUN = False
BASE_DIR = HOME  # --dir muda a base (instalar por projeto)


def render(tool, out_dir: Path) -> Path | None:
    """Roda o conversor oficial; devolve <out>/<kebab>/ (ou None com aviso honesto)."""
    if not shutil.which("bash"):
        die(msg("bash_required"))
    script = CATALOG_DIR / "scripts" / "convert.sh"
    if not script.is_file():
        warn(msg("render_missing", tool["kebab"], "scripts/convert.sh"))
        return None
    r = subprocess.run(["bash", str(script), "--tool", tool["kebab"], "--out", str(out_dir)],
                       cwd=str(CATALOG_DIR), capture_output=True, text=True)
    base = out_dir / tool["kebab"]
    if r.returncode != 0 or not base.is_dir():
        warn(msg("render_failed", tool["kebab"]))
        return None
    return base


def wanted(stem: str) -> bool:
    return SLUGS is None or stem in SLUGS


def install_identity(tool, plan_agentes: list[dict] | None, stems: set[str]):
    dest = BASE_DIR / tool["rel"]
    if DRY_RUN:
        return
    dest.mkdir(parents=True, exist_ok=True)
    cat = CATALOG_DIR.resolve()
    if plan_agentes is None:  # todos
        for src in catalog_agents(CATALOG_DIR):
            backup_file(dest / src.name, BASE_DIR, ref=src, sub=tool["id"])
            shutil.copy2(src, dest / src.name)
    else:
        for ag in plan_agentes:
            src = (cat / ag["file"]).resolve()
            if cat not in src.parents and src.parent != cat:
                warn(msg("unsafe_path", ag["file"]))
                continue
            if src.exists() and src.suffix == ".md":
                backup_file(dest / src.name, BASE_DIR, ref=src, sub=tool["id"])
                shutil.copy2(src, dest / src.name)


def install_rendered(tool, work: Path):
    dest = BASE_DIR / tool["rel"]
    if DRY_RUN:
        return
    base = render(tool, work / "out")
    if base is None:
        return
    src_root = base / tool["sub"]
    if not src_root.is_dir():
        warn(msg("render_missing", tool["kebab"], tool["sub"]))
        return
    dest.mkdir(parents=True, exist_ok=True)
    if tool["mode"] == "arquivo":
        for f in sorted(src_root.rglob("*")):
            if not f.is_file() or not wanted(f.stem):
                continue
            backup_file(dest / f.name, BASE_DIR, ref=f, sub=tool["id"])
            shutil.copy2(f, dest / f.name)
    else:  # pasta por slug
        for d in sorted(src_root.iterdir()):
            if not d.is_dir() or not wanted(d.name):
                continue
            target = dest / d.name
            backup_dir(target, BASE_DIR, sub=tool["id"])
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(d, target)


def install_roster(tool, work: Path):
    dest = BASE_DIR / tool["rel"]
    if DRY_RUN:
        return
    base = render(tool, work / "out")
    if base is None:
        return
    src = base / tool["roster_file"]
    if not src.is_file():
        warn(msg("render_missing", tool["kebab"], tool["roster_file"]))
        return
    if SLUGS is not None:
        warn(msg("roster_note", tool["label"]))
    dest.parent.mkdir(parents=True, exist_ok=True)
    backup_file(dest, BASE_DIR, ref=src, sub=tool["id"])
    shutil.copy2(src, dest)


def install_one(tool, work: Path, stems: set[str]):
    if os_compat(tool) == "nao":
        warn(msg("unsupported_os", tool["label"], OSL))
        return
    label = tool["label"]
    dest = BASE_DIR / tool["rel"]
    if tool.get("project_only") and BASE_DIR == HOME:
        warn(msg("project_only_note", label))  # B4: instala em HOME, mas deixa claro
    if DRY_RUN:
        n = len(SLUGS) if SLUGS is not None else len(catalog_agents(CATALOG_DIR))
        say(msg("dry_run_action", label, n, str(dest)))
        return
    say(msg("installing", label))
    if tool["kind"] == "identity":
        install_identity(tool, PLAN_AGENTES, stems)
    elif tool["kind"] == "roster":
        install_roster(tool, work)
    else:
        install_rendered(tool, work)
    # verificação honesta: quantos dos pedidos estão mesmo no destino
    if tool["kind"] == "roster":
        if dest.is_file():
            say(msg("roster_ok", tool["label"], str(dest)))
        else:
            warn(msg("install_fail", label))
        return
    present = agency_count(tool, BASE_DIR, stems)
    if present == 0:
        warn(msg("install_fail", label))
        return
    requested = len(SLUGS) if SLUGS is not None else len(catalog_agents(CATALOG_DIR))
    if present < requested:
        have = {p.stem for p in (dest.rglob("*") if dest.is_dir() else []) if p.is_file()}
        # match honesto: um slug pedido está "presente" se o destino tem o arquivo
        # com o slug OU com o stem oficial correspondente (identity copia <stem>.md)
        have_expanded = have | {s for s, st in SLUG_MAP.items() if st in have}
        missing = sorted((SLUGS if SLUGS is not None else stems) - have_expanded)[:5]
        warn(msg("install_partial", present, requested, label, ", ".join(missing)))
    say(msg("install_ok", label, present))


def uninstall_one(tool, stems: set[str]):
    if os_compat(tool) == "nao":
        warn(msg("unsupported_os", tool["label"], OSL))
        return
    dest = BASE_DIR / tool["rel"]
    if DRY_RUN:
        # dry-run também vale para remoção: NADA é movido, só pré-visualizado
        n = agency_count(tool, BASE_DIR, stems)
        say(msg("dry_run_remove", tool["label"], n))
        return
    if tool["kind"] == "roster":
        if dest.is_file():
            warn(msg("uninstall_skip", tool["label"], str(dest)))
        else:
            warn(msg("uninstall_none", tool["label"]))
        return
    if not dest.is_dir():
        warn(msg("uninstall_none", tool["label"]))
        return
    bdir = BACKUP_DIR / f"uninstall-{_TS}" / tool["id"]
    moved = 0
    if tool.get("mode") != "pasta":
        for p in sorted(dest.rglob("*")):
            if not p.is_file():
                continue
            if p.suffix in {".md", ".toml", ".mdc"} and p.stem in stems:
                b = bdir / p.relative_to(dest)
                b.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(p), str(b))
                moved += 1
    # pastas de skill (antigravity/osaurus/kimi)
    for d in sorted((x for x in dest.iterdir() if x.is_dir()), reverse=True):
        if d.name in stems:
            b = bdir / d.name
            b.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(d), str(b))
            moved += 1
    if moved:
        say(msg("uninstall_ok", moved, tool["label"], str(BACKUP_DIR / f"uninstall-{_TS}")))
    else:
        warn(msg("uninstall_none", tool["label"]))


# ---------- painel / status ----------

def status_object(stems: set[str] | None):
    commit, date = catalog_meta()
    tools = []
    for t in TOOLS:
        tools.append({
            "id": t["id"],
            "installed": tool_installed(t),
            "agentCount": agency_count(t, HOME, stems) if stems else 0,
        })
    return {
        "version": 1,
        "lang": LANG_SEL,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "os": {"family": OSF, "label": OSL, "arch": ARCH},
        "catalog": ({"path": str(CATALOG_DIR), "commit": commit, "updated": date}
                    if (CATALOG_DIR / ".git").is_dir() or (CATALOG_DIR / "divisions.json").is_file() else None),
        "tools": tools,
    }


def find_guia() -> Path | None:
    # guia ao lado do instalador (repo, ZIP ou pasta baixada pelo one-liner) e locais comuns
    for d in filter(None, [SCRIPT_DIR.parent, REPO, STORE_DIR,
                           HOME / "Documentos", HOME / "Documents", HOME / "Downloads"]):
        cand = d / GUIDE_NAME
        if cand.is_file():
            return d
    return None


def write_panel(status: dict):
    gu = find_guia()
    if not gu:
        warn(msg("guia_not_found"))
        return
    try:
        (gu / "guia-status.js").write_text(
            "window.GUIA_STATUS = " + json.dumps(status) + ";\n", encoding="utf-8")
        say(msg("panel_updated", str(gu / "guia-status.js")))
    except OSError:
        warn(msg("status_fail"))  # instalação já feita: não aborta por causa do painel


def open_guide():
    gu = find_guia()
    if not gu:
        return
    target = gu / GUIDE_NAME
    attempts = [
        ["xdg-open", str(target)],
        ["open", str(target)],
        ["osascript", "-e", f'open location "{target.as_uri()}"'],  # macOS sem open() no PATH
    ]
    for cmd in attempts:
        try:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        except OSError:
            continue


# ---------- idioma ----------

def read_saved_lang() -> str | None:
    try:
        # utf-8-sig: tolera BOM que o PowerShell 5.1 deixa ao gravar o config
        for line in CONFIG_FILE.read_text(encoding="utf-8-sig").splitlines():
            if line.startswith("lang="):
                v = line[5:].strip()
                return v if v in LANGS else None
    except OSError:
        pass
    return None


def save_lang(lang: str):
    try:
        CATALOG_DIR.mkdir(parents=True, exist_ok=True)
        CONFIG_FILE.write_text(f"lang={lang}\n", encoding="utf-8")
    except OSError:
        pass


def detect_locale_lang() -> str | None:
    for var in ("LC_ALL", "LC_MESSAGES", "LANG"):
        val = os.environ.get(var, "")
        m = re.match(r"^(pt|es|fr|de|en)", val.lower().replace("_", "-"))
        if m and m.group(1) in LANGS:
            return m.group(1)
    return None


def resolve_lang(cli_lang: str, can_prompt: bool):
    global LANG_SEL
    if cli_lang:
        if cli_lang not in LANGS:
            die(f"Invalid language: {cli_lang} (use en, pt, es, fr or de) / "
                f"Idioma inválido: {cli_lang} (use en, pt, es, fr ou de)")
        LANG_SEL = cli_lang
        if not DRY_RUN:  # B13: dry-run não escreve nada — nem o config de idioma
            save_lang(cli_lang)
        return
    saved = read_saved_lang()
    if saved:
        LANG_SEL = saved
        return
    loc = detect_locale_lang()
    default = loc or "en"
    if not can_prompt:
        LANG_SEL = default  # sem terminal (ou saída JSON): locale do SO ou inglês
        return
    print(msg("pick_lang"))
    print("  1) English   2) Português   3) Español   4) Français   5) Deutsch")
    try:
        ln = ask(f"1-5 [{default}]: ") or default
        LANG_SEL = {"1": "en", "2": "pt", "3": "es", "4": "fr", "5": "de"}.get(ln, default)
        if not DRY_RUN:  # B13
            save_lang(LANG_SEL)
    except NoTTY:
        LANG_SEL = default


# ---------- CLI ----------

USAGE = """agency-install — Agency Agents Store (Linux/macOS)

Uso:
  instalar-linux.sh                          interativo (pergunta idioma/ferramentas/squad)
  instalar-linux.sh --plan [agency-plan.json]  plano do guia (busca automática se o caminho for omitido)
  instalar-linux.sh --tool zcode,codex --squad pre    não-interativo (CI/scripts)
  instalar-linux.sh --tool cursor --dir ./meu-projeto --squad treino   instala por projeto
  instalar-linux.sh --status                 só detectar + atualizar painel (sem rede)
  instalar-linux.sh --status --json          status em JSON no stdout (não escreve nada)
  instalar-linux.sh --list                   catálogo/ferramentas/squads em JSON (sem rede)
  instalar-linux.sh --dry-run --tool zcode --squad treino   pré-visualiza sem escrever
  instalar-linux.sh --uninstall --tool zcode remove (com backup antes)
  instalar-linux.sh --lang en|pt|es|fr|de    idioma (persistido em ~/.agency-agents/config)

Ferramentas: """ + ",".join(t["id"] for t in TOOLS) + """
Squads: pre | treino | all"""


def main():
    global DRY_RUN, BASE_DIR, SLUGS, PLAN_AGENTES, _JSON_MODE
    SLUGS = None
    PLAN_AGENTES = None

    plan_arg = None
    plan_given = False
    cli_lang = ""
    status_only = False
    as_json = False
    do_list = False
    do_uninstall = False
    tool_arg = ""
    squad_arg = ""
    dir_arg = ""

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        nxt = args[i + 1] if i + 1 < len(args) else None
        if a in ("--plan", "--plano"):
            plan_given = True
            if nxt and not nxt.startswith("--"):
                plan_arg = nxt
                i += 1
        elif a in ("--lang", "--lingua"):
            if nxt and not nxt.startswith("--"):
                cli_lang = nxt
                i += 1
        elif a == "--status":
            status_only = True
        elif a == "--json":
            as_json = True
        elif a == "--list":
            do_list = True
        elif a == "--uninstall":
            do_uninstall = True
        elif a == "--dry-run":
            DRY_RUN = True
        elif a == "--tool":
            if nxt and not nxt.startswith("--"):
                tool_arg = nxt
                i += 1
        elif a == "--squad":
            if nxt and not nxt.startswith("--"):
                squad_arg = nxt
                i += 1
        elif a == "--dir":
            if nxt and not nxt.startswith("--"):
                dir_arg = nxt
                i += 1
        elif a in ("--help", "-h", "--ajuda"):
            print(USAGE)
            return
        else:
            die(f"Unknown option: {a} (use --help) / Opção desconhecida: {a} (use --help)")
        i += 1

    if as_json or do_list:
        _JSON_MODE = True
    resolve_lang(cli_lang, can_prompt=interactive_ok() and not (as_json or do_list))

    if dir_arg:
        d = Path(dir_arg).expanduser()
        if not d.is_dir():
            die(msg("err_dir", str(d)))
        BASE_DIR = d.resolve()
        say(msg("dir_note", str(BASE_DIR)))

    # ---- plano: caminho explícito ou busca automática ----
    plan = None
    if plan_given:
        if plan_arg:
            p = Path(plan_arg).expanduser()
            if not p.is_file():
                die(msg("err_plan", str(p)))
            plan = validate_plan(p)
        else:
            found = autodetect_plan()
            if not found:
                die(msg("err_plan", "agency-plan.json (searched ./ ../ ~/Downloads ~/Documentos ~/Documents)"))
            say(msg("plan_autodetected", str(found)))
            plan = validate_plan(found)

    # ---- --list: JSON puro, nunca rede ----
    if do_list:
        squads = load_squads()
        have_cat = (CATALOG_DIR / ".git").is_dir() or (CATALOG_DIR / "divisions.json").is_file()
        out = {
            "version": 1,
            "catalog": ({"path": str(CATALOG_DIR), "agents": len(catalog_agents(CATALOG_DIR))}
                        if have_cat else None),  # dir só com config de idioma NÃO é catálogo
            "tools": [{"id": t["id"], "label": t["label"], "compat": t["compat"],
                       "projectOnly": t["project_only"], "dest": t["rel"],
                       "installed": tool_installed(t)} for t in TOOLS],
            "squads": ({k: {"label": v.get("label", k), "slugs": [a["slug"] for a in v["agentes"]]}
                        for k, v in squads.items()} if squads else None),
        }
        print(json.dumps(out, ensure_ascii=False))
        return

    # ---- catálogo (status/json nunca usam rede) ----
    have_catalog = ensure_catalog(allow_network=not (status_only or as_json))
    stems = catalog_keys(CATALOG_DIR) if have_catalog else set()
    global SLUG_MAP
    SLUG_MAP = _slug_map(CATALOG_DIR) if have_catalog else {}

    # ---- seleção de ferramentas/squad ----
    tools_to_do: list[dict] = []

    def pick_tools_interactive() -> list[dict]:
        print()
        say(msg("found"))
        opts = []
        n = 1
        for t in TOOLS:
            if os_compat(t) == "nao":
                continue
            st = msg("installed_ok") if tool_installed(t) else msg("not_installed")
            print(f"  {n:2d}) {t['id']:<14} {st}")
            opts.append(t)
            n += 1

        def parse(resp: str) -> list[str] | None:
            """ids escolhidos; None = resposta inválida não-vazia (reprompt, B18)."""
            ids: list[str] = []
            toks = resp.replace(",", " ").split()
            if not toks:
                return []
            for tok in toks:
                if tok.isdigit() and 1 <= int(tok) <= len(opts):
                    ids.append(opts[int(tok) - 1]["id"])
            return ids or None

        for _ in range(3):
            resp = ask(msg("pick_tools") + " ")
            got = parse(resp)
            if got is not None:
                return [TOOL_BY_ID[i] for i in (got or [t["id"] for t in opts])]
            print("  ?!")  # entrada inválida: pede de novo (nunca "instala tudo" por engano)
        return [TOOL_BY_ID[t["id"]] for t in opts]  # 3 tentativas inválidas → todas (padrão do Enter)

    def pick_squad_interactive() -> list[str] | None:
        print()
        say(msg("pick_squad"))
        print("  " + msg("squad1"))
        print("  " + msg("squad2"))
        print("  " + msg("squad3"))
        s = ask("1-3 [1]: ") or "1"
        return squad_slugs({"2": "treino", "3": "all"}.get(s, "pre"))

    if plan:
        PLAN_AGENTES = plan["agentes"] or None  # vazio = todos (semântica única)
        SLUGS = {a["slug"] for a in plan["agentes"]} or None
        tools_to_do = []
        for tid in (t.strip() for t in plan["ferramentas"]):
            t = TOOL_BY_ID.get(tid)
            if t:
                tools_to_do.append(t)
            elif tid in ("vibe", "dsh", "openclaw", "hermes"):
                warn(msg("unsupported", tid))
            else:
                warn(msg("tool_unknown", tid))
    elif tool_arg:
        ids = [x.strip() for x in tool_arg.split(",") if x.strip()]
        tools_to_do = []
        known_unsupported = False
        for tid in ids:
            t = TOOL_BY_ID.get(tid)
            if t:
                tools_to_do.append(t)
            elif tid in ("vibe", "dsh", "openclaw", "hermes"):
                warn(msg("unsupported", tid))
                known_unsupported = True
            else:
                warn(msg("tool_unknown", tid))
        if not tools_to_do:
            if known_unsupported:
                # pedido reconhecido e avisado (existe no catálogo, não integrado) — nada a fazer, rc=0
                return
            die(msg("tool_unknown", ids[-1] if ids else "?"))
        if do_uninstall or status_only:
            pass  # squad é irrelevante aqui
        elif squad_arg:
            slugs = squad_slugs(squad_arg)
            SLUGS = set(slugs) if slugs is not None else None
        elif interactive_ok():
            SLUGS = pick_squad_interactive()
        else:
            die(msg("err_need_squad"))
    elif not status_only and not as_json:
        if not interactive_ok():
            die(msg("err_notty"))
        tools_to_do = pick_tools_interactive()
        if not do_uninstall:
            # --squad sem --tool: usa a squad pedida em vez de perguntar de novo
            if squad_arg:
                slugs = squad_slugs(squad_arg)
                SLUGS = set(slugs) if slugs is not None else None
            else:
                SLUGS = pick_squad_interactive()

    # ---- executar ----
    if DRY_RUN:
        say(msg("dry_run_banner"))

    work = None
    if not status_only and not as_json and tools_to_do:
        work = Path(tempfile.mkdtemp(prefix="agency-install-"))
    try:
        if do_uninstall:
            if not stems:
                die(msg("cat_status_missing", str(CATALOG_DIR)))
            # B3: com plano, remove SÓ o que o plano pede (slugs + stems equivalentes);
            # sem plano, remove a agência inteira da ferramenta
            keys = set(stems)
            if SLUGS is not None:
                keys = set(SLUGS) | {SLUG_MAP[s] for s in SLUGS if s in SLUG_MAP}
            for t in tools_to_do:
                uninstall_one(t, keys)
        elif not status_only and not as_json and tools_to_do:
            for t in tools_to_do:
                install_one(t, work, stems)
    finally:
        if work:
            shutil.rmtree(work, ignore_errors=True)

    # ---- painel / status ----
    status = status_object(stems or None)
    if as_json:
        print(json.dumps(status, ensure_ascii=False))
        return
    if DRY_RUN:
        say(msg("dry_run_panel"))
    else:
        write_panel(status)

    # ---- resumo ----
    print()
    say(msg("done"))
    for t in TOOLS:
        c = count_agents_rel(t["rel"])
        print(f"  {t['label']:<16} {msg('detected') if tool_installed(t) else msg('absent'):<12} {c} {msg('specialists')}")
    # abre o guia apenas em uso interativo E com algum opener disponível — nunca em CI/scripts
    openers = any(shutil.which(c) for c in ("xdg-open", "open", "osascript"))
    if not status_only and not DRY_RUN and interactive_ok() and openers:
        say(msg("opening"))
        open_guide()
    print()
    say(msg("rerun"))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
