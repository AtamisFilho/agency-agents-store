#!/usr/bin/env bash
# ============================================================================
# instalar-linux.sh — Agency Agents Guia (Linux e macOS)
#
# Detecta suas ferramentas de código (Claude Code, ZCode, Codex, Gemini CLI…),
# instala especialistas da agência nelas (com backup do que já existe) e deixa
# o guia-especialistas-agencia.html informado (gera guia-status.js).
#
# Uso:
#   ./instalar-linux.sh                        # modo interativo (pergunta tudo)
#   ./instalar-linux.sh --plano plano.json     # usa o planinho gerado pelo guia
#   ./instalar-linux.sh --status               # só detecta e gera guia-status.js
#   ./instalar-linux.sh --ajuda                # esta ajuda
# ============================================================================
set -euo pipefail

CATALOG_DIR="${HOME}/.agency-agents"
CATALOG_REPO="https://github.com/msitarzewski/agency-agents.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say()  { printf '\033[0;32m[ok]\033[0m  %s\n' "$*"; }
warn() { printf '\033[0;33m[!!]\033[0m  %s\n' "$*"; }
err()  { printf '\033[0;31m[err]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- ajuda ----------
if [[ "${1:-}" == "--ajuda" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

# ---------- pré-requisitos ----------
command -v git >/dev/null 2>&1 || err "Git não encontrado. Instale com: sudo apt install git  (ou https://git-scm.com)"
command -v bash >/dev/null 2>&1 || err "bash é necessário."

# ---------- argumentos ----------
PLANO_FILE=""; STATUS_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plano)  PLANO_FILE="${2:-}"; shift 2;;
    --status) STATUS_ONLY=1; shift;;
    *) err "Opção desconhecida: $1 (use --plano, --status ou --ajuda)";;
  esac
done

# ---------- catálogo ----------
if [[ -d "$CATALOG_DIR/.git" ]]; then
  say "Atualizando o catálogo em $CATALOG_DIR…"
  git -C "$CATALOG_DIR" pull --ff-only >/dev/null 2>&1 || warn "Não consegui atualizar o catálogo (seguindo com o que existe)."
else
  say "Baixando o catálogo oficial de agentes (~.agency-agents)…"
  git clone --depth 1 "$CATALOG_REPO" "$CATALOG_DIR" >/dev/null 2>&1 || err "Falha ao clonar o catálogo. Verifique sua internet."
fi
CAT_COMMIT="$(git -C "$CATALOG_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"
CAT_DATE="$(git -C "$CATALOG_DIR" log -1 --format=%cs 2>/dev/null || echo '?')"

# ---------- sistema ----------
OSF="linux"; OSL="Linux"
if [[ "$(uname)" == "Darwin" ]]; then OSF="macos"; OSL="macOS"; fi
ARCH="$(uname -m)"

# ---------- detecção de ferramentas ----------
# fmt: id|kebab|destino-user(relativo ao HOME)|formato|compat(l/m/w: sim|wsl|nao)
TOOL_DEFS=(
  "claudeCode|claude-code|.claude/agents|identity|sim|sim|sim"
  "zcode|zcode|.zcode/agents|zcode-md|sim|sim|sim"
  "codex|codex|.codex/agents|toml|sim|sim|wsl"
  "geminiCli|gemini-cli|.gemini/agents|md|sim|sim|sim"
  "copilot|github-copilot|.github/agents|identity|sim|sim|sim"
  "qwen|qwen|.qwen/agents|md|sim|sim|sim"
  "opencode|opencode|.config/opencode/agents|opencode-md|sim|sim|sim"
  "antigravity|antigravity|.gemini/config/skills|skill-dir|sim|sim|sim"
  "osaurus|osaurus|.osaurus/skills|skill-dir|nao|sim|nao"
  "kimi|kimi|.config/kimi/agents|kimi-dir|sim|sim|wsl"
)
detect_tool() { # $1=dirs espaçados rel. HOME; $2=bin
  local dirs="$1" bin="${2:-}" d p
  [[ -n "$bin" ]] && command -v "$bin" >/dev/null 2>&1 && return 0
  for d in $dirs; do p="$HOME/$d"; [[ -e "$p" ]] && return 0; done
  return 1
}
count_agents() { # $1=agentsDir relativo; $2=extensões; $3=nomes possíveis (arquivos ou pastas)
  local dir="$HOME/$1" n=0 f
  [[ -d "$dir" ]] || { echo 0; return; }
  while IFS= read -r f; do n=$((n+1)); done < <(find "$dir" -maxdepth 2 \( -name "*.md" -o -name "*.toml" -o -name "SKILL.md" -o -name "agent.yaml" \) 2>/dev/null)
  echo "$n"
}
TOOLS_JSON="["  ; FIRST=1
declare -A T_INST T_COUNT T_COMPAT
for row in "${TOOL_DEFS[@]}"; do
  IFS='|' read -r id kebab rel fmt cl cm cw <<<"$row"
  key="$OSF"; [[ "$OSF" == "linux" ]] && key="l"; [[ "$OSF" == "macos" ]] && key="m"
  compat=$( [[ "$key" == "l" ]] && echo "$cl" || { [[ "$key" == "m" ]] && echo "$cm" || echo "$cw"; } )
  dirs=""; case "$id" in
    claudeCode) dirs=".claude"; bin="claude";;
    zcode)      dirs=".zcode";  bin="";;
    codex)      dirs=".codex";  bin="codex";;
    geminiCli)  dirs=".gemini"; bin="";;
    copilot)    dirs=".github/agents .copilot"; bin="";;
    qwen)       dirs=".qwen";   bin="";;
    opencode)   dirs=".config/opencode"; bin="";;
    antigravity)dirs=".gemini/config"; bin="";;
    osaurus)    dirs=".osaurus"; bin="";;
    kimi)       dirs=".config/kimi"; bin="";;
  esac
  if detect_tool "$dirs" "$bin"; then T_INST[$id]=1; else T_INST[$id]=0; fi
  T_COUNT[$id]=$(count_agents "${rel%/*}" "$fmt") || true
  T_COMPAT[$id]="$compat"
done

# ---------- helpers de render/cópia ----------
render() { # $1=kebab  -> gera em $WORK/out/$kebab
  bash "$CATALOG_DIR/scripts/convert.sh" --tool "$1" --out "$WORK/out" >/dev/null 2>&1
}
backup_dest() { # $1=arquivo destino
  local d="$1" b="$HOME/.agency-agents-backup/$(date +%Y%m%d-%H%M%S)"
  [[ -f "$d" ]] || return 0
  cmp -s "$d" "${2:-}" 2>/dev/null && return 0
  mkdir -p "$b/$(dirname "${d#$HOME/}")"; cp "$d" "$b/$(dirname "${d#$HOME/}")/"
}
install_identity() { # $1=plano.json|"all"; $2=dest rel (ex.: .claude/agents)
  local dest="$HOME/$2" src
  mkdir -p "$dest"
  if [[ "$1" == "all" ]]; then
    find "$CATALOG_DIR" -maxdepth 2 -name "*.md" \
      \( -path "*/academic/*" -o -path "*/design/*" -o -path "*/engineering/*" -o -path "*/finance/*" \
         -o -path "*/game-development/*" -o -path "*/gis/*" -o -path "*/healthcare/*" -o -path "*/marketing/*" \
         -o -path "*/paid-media/*" -o -path "*/product/*" -o -path "*/project-management/*" -o -path "*/research/*" \
         -o -path "*/sales/*" -o -path "*/security/*" -o -path "*/spatial-computing/*" -o -path "*/specialized/*" \
         -o -path "*/support/*" -o -path "*/testing/*" \) | while read -r src; do
      backup_dest "$dest/$(basename "$src")" "$src"
      cp "$src" "$dest/"
    done
  else
    python3 - "$1" "$dest" "$CATALOG_DIR" <<'PY'
import json, shutil, sys, pathlib
plano = json.load(open(sys.argv[1]))
dest = pathlib.Path(sys.argv[2]); cat = pathlib.Path(sys.argv[3])
for ag in plano.get("agentes", []):
    src = cat / ag["file"]
    if src.exists():
        dst = dest / src.name
        if dst.exists() and dst.read_bytes() != src.read_bytes():
            b = pathlib.Path.home()/".agency-agents-backup"
            b.mkdir(parents=True, exist_ok=True); shutil.copy2(dst, b/(dst.name+".bak"))
        shutil.copy2(src, dst)
PY
  fi
}
install_rendered() { # $1=kebab; $2=rel-pasta-fonte (dentro do render); $3=dest-rel; $4=modo(arquivo|pasta)
  render "$1"
  local srcRoot="$WORK/out/$1/$2" destRoot="$HOME/$3"
  [[ -d "$srcRoot" ]] || { warn "render de $1 não gerou $2"; return 0; }
  mkdir -p "$destRoot"
  if [[ "$4" == "arquivo" ]]; then
    find "$srcRoot" -type f | while read -r f; do
      backup_dest "$destRoot/$(basename "$f")" "$f"
      cp "$f" "$destRoot/"
    done
  else
    find "$srcRoot" -mindepth 1 -maxdepth 1 -type d | while read -r d; do
      local name dest="$destRoot/$(basename "$d")"
      backup_dest "$dest" 2>/dev/null || true
      rm -rf "$dest"; mkdir -p "$(dirname "$dest")"; cp -r "$d" "$dest"
    done
  fi
}

# ---------- instalar por ferramenta ----------
SLUGS_FILE="all"
if [[ "${PLANO_FILE:-}" != "" ]]; then
  [[ -f "$PLANO_FILE" ]] || err "Plano não encontrado: $PLANO_FILE"
  SLUGS_FILE="$PLANO_FILE"
fi
DO_TOOL=""    # ids separados por vírgula (vindo de --plano ou interativo)
if [[ "${PLANO_FILE:-}" != "" ]]; then
  DO_TOOL=$(python3 -c "import json,sys;print(','.join(json.load(open(sys.argv[1]))['ferramentas']))" "$PLANO_FILE")
fi

interactive() {
  echo; say "Ferramentas encontradas nesta máquina:"
  local i=1 opts=()
  for row in "${TOOL_DEFS[@]}"; do
    IFS='|' read -r id kebab rel fmt cl cm cw <<<"$row"
    local key=cw; [[ "$OSF" == "linux" ]] && key=cl; [[ "$OSF" == "macos" ]] && key=cm
    [[ "$key" == "nao" ]] && continue
    local st="não instalada (posso configurar mesmo assim)"
    [[ "${T_INST[$id]}" == "1" ]] && st="instalada ✓"
    printf '  %2d) %-14s %s\n' "$i" "$id" "$st"; opts+=("$id"); i=$((i+1))
  done
  read -rp "Números separados por vírgula (Enter = todas): " resp
  if [[ -z "${resp// /}" ]]; then DO_TOOL="$(IFS=,; echo "${opts[*]}")"; else
    DO_TOOL=""; for n in ${resp//,/ }; do DO_TOOL="${DO_TOOL:+$DO_TOOL,}${opts[$((n-1))]}"; done
  fi
  echo; echo "Quantos especialistas instalar?"
  echo "  1) Squad pré-lançamento (12 — recomendada)"
  echo "  2) Squad de treino (4)"
  echo "  3) Todos ($(( $(find "$CATALOG_DIR" -maxdepth 2 -name '*.md' -path '*/*/*' | grep -vc README || true) )) — a agência inteira)"
  read -rp "Escolha [1]: " s; s="${s:-1}"
  case "$s" in
    1) SLUGS_FILE="squad12";;
    2) SLUGS_FILE="squad4";;
    3) SLUGS_FILE="all";;
    *) SLUGS_FILE="squad12";;
  esac
}
[[ "${PLANO_FILE:-}" == "" && "${STATUS_ONLY:-}" != "1" ]] && interactive

install_one() { # $1=id
  case "$1" in
    claudeCode)
      if [[ "$SLUGS_FILE" == "all" ]]; then install_identity all ".claude/agents"
      else install_identity "$SLUGS_FILE" ".claude/agents"; fi ;;
    copilot)
      if [[ "$SLUGS_FILE" == "all" ]]; then install_identity all ".github/agents"; else install_identity "$SLUGS_FILE" ".github/agents"; fi ;;
    zcode)     install_rendered zcode agents .zcode/agents arquivo ;;
    codex)     install_rendered codex agents .codex/agents arquivo ;;
    geminiCli) install_rendered gemini-cli agents .gemini/agents arquivo ;;
    qwen)      install_rendered qwen agents .qwen/agents arquivo ;;
    opencode)  install_rendered opencode agents .config/opencode/agents arquivo ;;
    antigravity) install_rendered antigravity skills .gemini/config/skills pasta ;;
    osaurus)   install_rendered osaurus skills .osaurus/skills pasta ;;
    kimi)      install_rendered kimi agents .config/kimi/agents pasta ;;
    *) warn "Ferramenta $1 ainda não suportada pelo instalador (use o app Agency Agents)."; return 0;;
  esac
  local after
  case "$1" in
    claudeCode) after=$(count_agents ".claude/agents" x);;
    copilot)    after=$(count_agents ".github/agents" x);;
    zcode)      after=$(count_agents ".zcode/agents" x);;
    codex)      after=$(count_agents ".codex/agents" x);;
    geminiCli)  after=$(count_agents ".gemini/agents" x);;
    qwen)       after=$(count_agents ".qwen/agents" x);;
    opencode)   after=$(count_agents ".config/opencode/agents" x);;
    antigravity) after=$(count_agents ".gemini/config/skills" x);;
    osaurus)    after=$(count_agents ".osaurus/skills" x);;
    kimi)       after=$(count_agents ".config/kimi/agents" x);;
  esac
  if [[ "${after:-0}" == "0" ]]; then
    warn "Nenhum especialista em $1 após a instalação — veja avisos acima."
  else
    say "Instalados especialistas em $1 ✓ ($after no destino)"
  fi
}

# squads nomeadas -> plano temporário a partir de dados/squads.json do projeto
SQUADS_JSON="$SCRIPT_DIR/../dados/squads.json"
if [[ "$SLUGS_FILE" == "squad12" || "$SLUGS_FILE" == "squad4" ]]; then
  [[ -f "$SQUADS_JSON" ]] || err "dados/squads.json não encontrado junto ao instalador."
  KEY="$([[ "$SLUGS_FILE" == "squad12" ]] && echo pre-lancamento || echo treino)"
  python3 - "$SQUADS_JSON" "$KEY" "$WORK/plano.json" <<'PY'
import json, sys
sq = json.load(open(sys.argv[1]))[sys.argv[2]]
json.dump({"agentes": sq["agentes"]}, open(sys.argv[3], "w"))
PY
  SLUGS_FILE="$WORK/plano.json"
fi

if [[ "${STATUS_ONLY:-}" != "1" && -n "$DO_TOOL" ]]; then
  IFS=',' read -ra TOOLS <<<"$DO_TOOL"
  for t in "${TOOLS[@]}"; do install_one "$t"; done
fi

# ---------- guia-status.js ----------
find_guia() {
  for p in "$SCRIPT_DIR/../guia-especialistas-agencia.html" "$HOME/Documentos/guia-especialistas-agencia.html" "$HOME/Documents/guia-especialistas-agencia.html"; do
    [[ -f "$p" ]] && { dirname "$p"; return 0; }
  done
  return 1
}
GU_DIR="$(find_guia || true)"
if [[ -n "$GU_DIR" ]]; then
  python3 - "$CAT_COMMIT" "$CAT_DATE" "$OSF" "$OSL" "$ARCH" "$GU_DIR" <<'PY'
import json, sys, pathlib, datetime
commit, cdate, osf, osl, arch, gu = sys.argv[1:7]
tools = []
defs = [("claudeCode",".claude/agents"),("zcode",".zcode/agents"),("codex",".codex/agents"),
        ("geminiCli",".gemini/agents"),("copilot",".github/agents"),("qwen",".qwen/agents"),
        ("opencode",".config/opencode/agents"),("antigravity",".gemini/config/skills"),
        ("osaurus",".osaurus/skills"),("kimi",".config/kimi/agents")]
home = pathlib.Path.home()
# nomes oficiais do catálogo (para contar só especialistas da agência)
cat = home/".agency-agents"
agency = {p.name for p in cat.glob("*/*.md")} | {p.name for p in cat.glob("*/*/*.md")}
agency_stems = {p.stem for p in cat.glob("*/*.md")}
for tid, rel in defs:
    d = home/rel
    installed = d.exists()
    n = 0
    if installed:
        for p in d.rglob("*"):
            if p.suffix in {".md",".toml"} and (p.name in agency or p.stem in agency_stems):
                n += 1
    tools.append({"id": tid, "installed": installed, "agentCount": n})
status = {"version": 1, "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "os": {"family": osf, "label": osl, "arch": arch},
          "catalog": {"path": str(home/".agency-agents"), "commit": commit, "updated": cdate},
          "tools": tools}
out = pathlib.Path(gu) / "guia-status.js"
out.write_text("window.GUIA_STATUS = " + json.dumps(status) + ";\n", encoding="utf-8")
print(f"[ok]  Painel do guia atualizado: {out}")
PY
else
  warn "guia-especialistas-agencia.html não encontrado ao lado — guia-status.js não foi escrito."
fi

# ---------- resumo ----------
echo
say "Concluído! Resumo (estado real desta máquina):"
for row in "${TOOL_DEFS[@]}"; do
  IFS='|' read -r id kebab rel fmt cl cm cw <<<"$row"
  c=$(count_agents "${rel%/*}" "$fmt")
  i="${T_INST[$id]:-0}"
  printf '  %-14s %-12s %s especialista(s) da agência\n' "$id" "$([[ $i == 1 ]] && echo 'detectada' || echo 'ausente')" "$c"
done
[[ -n "$GU_DIR" ]] && { say "Abrindo o guia…"; (xdg-open "$GU_DIR/guia-especialistas-agencia.html" >/dev/null 2>&1 || open "$GU_DIR/guia-especialistas-agencia.html" >/dev/null 2>&1 || true); }
echo
say "Dica: rode de novo a qualquer momento — é seguro (faz backup antes de sobrescrever)."
