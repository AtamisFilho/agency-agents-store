#!/usr/bin/env bash
# ============================================================================
# instalar-linux.sh — Agency Agents Store (Linux & macOS)
#
# Detects your coding tools (Claude Code, ZCode, Codex, Gemini CLI...),
# asks your language, installs agency specialists into them (backing up
# anything it touches) and updates the guide's machine panel.
#
# Usage:
#   ./instalar-linux.sh                          # interactive (asks language)
#   ./instalar-linux.sh --plan agency-plan.json  # uses the guide's plan file
#   ./instalar-linux.sh --lang pt --plan ...     # skip the language question
#   ./instalar-linux.sh --status                 # detect only, refresh panel
#   ./instalar-linux.sh --help
#
# Languages: en | pt | es | fr | de
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

# ---------- i18n ----------
LANG_SEL=""
msg() { # msg <key> [printf args...]
  local key="$1"; shift
  local s=""
  case "${LANG_SEL}:${key}" in
    en:pick_lang) s="Choose your language:";;
    en:need_git) s="Git not found. Install it first: https://git-scm.com (on Ubuntu: sudo apt install git)";;
    en:cat_update) s="Updating the catalog in %s...";;
    en:cat_clone) s="Downloading the official agent catalog (~/.agency-agents)...";;
    en:cat_fail) s="Failed to clone the catalog. Check your internet connection.";;
    en:found) s="Tools found on this machine:";;
    en:installed_ok) s="installed ✓";;
    en:not_installed) s="not installed (I can still configure it)";;
    en:pick_tools) s="Comma-separated numbers (Enter = all):";;
    en:pick_squad) s="How many specialists to install?";;
    en:squad1) s="1) Pre-launch squad (12 — recommended)";;
    en:squad2) s="2) Training squad (4)";;
    en:squad3) s="3) Everyone (the whole agency)";;
    en:installing) s="Installing specialists into %s...";;
    en:install_ok) s="Specialists installed in %s ✓ (%s at the destination)";;
    en:install_fail) s="NO specialist found in %s after installation — see warnings above.";;
    en:panel_updated) s="Guide panel updated: %s";;
    en:status_fail) s="Could not write the guide panel (guia-status.js) — check the folder permissions. Everything else succeeded.";;
    en:guia_not_found) s="guia-especialistas-agencia.html not found next to the installer — panel not written.";;
    en:done) s="Done! Real state of this machine:";;
    en:detected) s="detected";;
    en:absent) s="absent";;
    en:specialists) s="agency specialist(s)";;
    en:opening) s="Opening the guide...";;
    en:rerun) s="Tip: run again anytime — it is safe (backs up before overwriting).";;
    en:err_unknown) s="Unknown option: %s (use --plan, --lang, --status or --help)";;
    en:err_plan) s="Plan file not found: %s";;
    en:err_lang) s="Invalid language: %s (use en, pt, es, fr or de)";;
    en:err_bad_plan) s="Invalid plan file: %s";;
    en:err_notty) s="Interactive mode needs a terminal. Use: --plan agency-plan.json";;
    en:advanced) s="advanced";;
    en:unsupported) s="Tool %s not supported by this installer yet (use the Agency Agents App).";;
    pt:pick_lang) s="Escolha o seu idioma:";;
    pt:need_git) s="Git não encontrado. Instale antes: https://git-scm.com (no Ubuntu: sudo apt install git)";;
    pt:cat_update) s="Atualizando o catálogo em %s...";;
    pt:cat_clone) s="Baixando o catálogo oficial de agentes (~/.agency-agents)...";;
    pt:cat_fail) s="Falha ao clonar o catálogo. Verifique sua internet.";;
    pt:found) s="Ferramentas encontradas nesta máquina:";;
    pt:installed_ok) s="instalada ✓";;
    pt:not_installed) s="não instalada (posso configurar mesmo assim)";;
    pt:pick_tools) s="Números separados por vírgula (Enter = todas):";;
    pt:pick_squad) s="Quantos especialistas instalar?";;
    pt:squad1) s="1) Squad pré-lançamento (12 — recomendada)";;
    pt:squad2) s="2) Squad de treino (4)";;
    pt:squad3) s="3) Todos (a agência inteira)";;
    pt:installing) s="Instalando especialistas em %s...";;
    pt:install_ok) s="Especialistas instalados em %s ✓ (%s no destino)";;
    pt:install_fail) s="NENHUM especialista em %s após a instalação — veja os avisos acima.";;
    pt:panel_updated) s="Painel do guia atualizado: %s";;
    pt:status_fail) s="Não consegui escrever o painel do guia (guia-status.js) — verifique as permissões da pasta. Todo o resto funcionou.";;
    pt:guia_not_found) s="guia-especialistas-agencia.html não encontrado junto ao instalador — painel não escrito.";;
    pt:done) s="Concluído! Estado real desta máquina:";;
    pt:detected) s="detectada";;
    pt:absent) s="ausente";;
    pt:specialists) s="especialista(s) da agência";;
    pt:opening) s="Abrindo o guia...";;
    pt:rerun) s="Dica: rode de novo a qualquer momento — é seguro (faz backup antes de sobrescrever).";;
    pt:err_unknown) s="Opção desconhecida: %s (use --plan, --lang, --status ou --help)";;
    pt:err_plan) s="Plano não encontrado: %s";;
    pt:err_lang) s="Idioma inválido: %s (use en, pt, es, fr ou de)";;
    pt:err_bad_plan) s="Arquivo de plano inválido: %s";;
    pt:err_notty) s="O modo interativo precisa de um terminal. Use: --plan agency-plan.json";;
    pt:advanced) s="avançado";;
    pt:unsupported) s="Ferramenta %s ainda não suportada por este instalador (use o Agency Agents App).";;
    es:pick_lang) s="Elige tu idioma:";;
    es:need_git) s="Git no encontrado. Instálalo antes: https://git-scm.com (en Ubuntu: sudo apt install git)";;
    es:cat_update) s="Actualizando el catálogo en %s...";;
    es:cat_clone) s="Descargando el catálogo oficial de agentes (~/.agency-agents)...";;
    es:cat_fail) s="Error al clonar el catálogo. Verifica tu conexión.";;
    es:found) s="Herramientas encontradas en esta máquina:";;
    es:installed_ok) s="instalada ✓";;
    es:not_installed) s="no instalada (puedo configurarla igualmente)";;
    es:pick_tools) s="Números separados por comas (Enter = todas):";;
    es:pick_squad) s="¿Cuántos especialistas instalar?";;
    es:squad1) s="1) Escuadrón pre-lanzamiento (12 — recomendado)";;
    es:squad2) s="2) Escuadrón de entrenamiento (4)";;
    es:squad3) s="3) Todos (toda la agencia)";;
    es:installing) s="Instalando especialistas en %s...";;
    es:install_ok) s="Especialistas instalados en %s ✓ (%s en el destino)";;
    es:install_fail) s="NINGÚN especialista en %s tras la instalación — mira los avisos de arriba.";;
    es:panel_updated) s="Panel de la guía actualizado: %s";;
    es:status_fail) s="No pude escribir el panel de la guía (guia-status.js) — revisa los permisos de la carpeta. Todo lo demás funcionó.";;
    es:guia_not_found) s="guia-especialistas-agencia.html no encontrado junto al instalador — panel no escrito.";;
    es:done) s="¡Hecho! Estado real de esta máquina:";;
    es:detected) s="detectada";;
    es:absent) s="ausente";;
    es:specialists) s="especialista(s) de la agencia";;
    es:opening) s="Abriendo la guía...";;
    es:rerun) s="Consejo: ejecútalo cuando quieras — es seguro (hace backup antes de sobrescribir).";;
    es:err_unknown) s="Opción desconocida: %s (usa --plan, --lang, --status o --help)";;
    es:err_plan) s="Plan no encontrado: %s";;
    es:err_lang) s="Idioma inválido: %s (usa en, pt, es, fr o de)";;
    es:err_bad_plan) s="Archivo de plan inválido: %s";;
    es:err_notty) s="El modo interactivo necesita una terminal. Usa: --plan agency-plan.json";;
    es:advanced) s="avanzado";;
    es:unsupported) s="Herramienta %s aún no soportada por este instalador (usa el Agency Agents App).";;
    fr:pick_lang) s="Choisissez votre langue :";;
    fr:need_git) s="Git introuvable. Installez-le d'abord : https://git-scm.com (Ubuntu : sudo apt install git)";;
    fr:cat_update) s="Mise à jour du catalogue dans %s...";;
    fr:cat_clone) s="Téléchargement du catalogue officiel d'agents (~/.agency-agents)...";;
    fr:cat_fail) s="Échec du clonage du catalogue. Vérifiez votre connexion.";;
    fr:found) s="Outils trouvés sur cette machine :";;
    fr:installed_ok) s="installé ✓";;
    fr:not_installed) s="non installé (je peux le configurer quand même)";;
    fr:pick_tools) s="Numéros séparés par des virgules (Entrée = tous) :";;
    fr:pick_squad) s="Combien de spécialistes installer ?";;
    fr:squad1) s="1) Escouade pré-lancement (12 — recommandée)";;
    fr:squad2) s="2) Escouade d'entraînement (4)";;
    fr:squad3) s="3) Tout le monde (toute l'agence)";;
    fr:installing) s="Installation des spécialistes dans %s...";;
    fr:install_ok) s="Spécialistes installés dans %s ✓ (%s à destination)";;
    fr:install_fail) s="AUCUN spécialiste dans %s après l'installation — voir les avertissements ci-dessus.";;
    fr:panel_updated) s="Panneau du guide mis à jour : %s";;
    fr:status_fail) s="Impossible d'écrire le panneau du guide (guia-status.js) — vérifiez les permissions du dossier. Tout le reste a réussi.";;
    fr:guia_not_found) s="guia-especialistas-agencia.html introuvable à côté de l'installateur — panneau non écrit.";;
    fr:done) s="Terminé ! État réel de cette machine :";;
    fr:detected) s="détecté";;
    fr:absent) s="absent";;
    fr:specialists) s="spécialiste(s) de l'agence";;
    fr:opening) s="Ouverture du guide...";;
    fr:rerun) s="Astuce : relancez quand vous voulez — c'est sûr (sauvegarde avant d'écraser).";;
    fr:err_unknown) s="Option inconnue : %s (utilisez --plan, --lang, --status ou --help)";;
    fr:err_plan) s="Plan introuvable : %s";;
    fr:err_lang) s="Langue invalide : %s (utilisez en, pt, es, fr ou de)";;
    fr:err_bad_plan) s="Fichier de plan invalide : %s";;
    fr:err_notty) s="Le mode interactif nécessite un terminal. Utilisez : --plan agency-plan.json";;
    fr:advanced) s="avancé";;
    fr:unsupported) s="Outil %s pas encore pris en charge par cet installateur (utilisez l'Agency Agents App).";;
    de:pick_lang) s="Wählen Sie Ihre Sprache:";;
    de:need_git) s="Git nicht gefunden. Bitte zuerst installieren: https://git-scm.com (Ubuntu: sudo apt install git)";;
    de:cat_update) s="Aktualisiere den Katalog in %s...";;
    de:cat_clone) s="Lade den offiziellen Agentenkatalog herunter (~/.agency-agents)...";;
    de:cat_fail) s="Klonen des Katalogs fehlgeschlagen. Bitte Internetverbindung prüfen.";;
    de:found) s="Auf dieser Maschine gefundene Tools:";;
    de:installed_ok) s="installiert ✓";;
    de:not_installed) s="nicht installiert (ich kann sie trotzdem einrichten)";;
    de:pick_tools) s="Durch Kommas getrennte Nummern (Enter = alle):";;
    de:pick_squad) s="Wie viele Spezialisten installieren?";;
    de:squad1) s="1) Pre-Launch-Team (12 — empfohlen)";;
    de:squad2) s="2) Trainings-Team (4)";;
    de:squad3) s="3) Alle (die ganze Agentur)";;
    de:installing) s="Installiere Spezialisten in %s...";;
    de:install_ok) s="Spezialisten installiert in %s ✓ (%s am Zielort)";;
    de:install_fail) s="KEIN Spezialist in %s nach der Installation — siehe Warnungen oben.";;
    de:panel_updated) s="Guide-Panel aktualisiert: %s";;
    de:status_fail) s="Konnte das Guide-Panel (guia-status.js) nicht schreiben — bitte Ordnerberechtigungen prüfen. Alles andere war erfolgreich.";;
    de:guia_not_found) s="guia-especialistas-agencia.html neben dem Installer nicht gefunden — Panel nicht geschrieben.";;
    de:done) s="Fertig! Echter Zustand dieser Maschine:";;
    de:detected) s="erkannt";;
    de:absent) s="fehlt";;
    de:specialists) s="Agentur-Spezialist(en)";;
    de:opening) s="Öffne den Guide...";;
    de:rerun) s="Tipp: jederzeit erneut ausführen — sicher (Backup vor dem Überschreiben).";;
    de:err_unknown) s="Unbekannte Option: %s (verwende --plan, --lang, --status oder --help)";;
    de:err_plan) s="Plan nicht gefunden: %s";;
    de:err_lang) s="Ungültige Sprache: %s (verwende en, pt, es, fr oder de)";;
    de:err_bad_plan) s="Ungültige Plandatei: %s";;
    de:err_notty) s="Der interaktive Modus braucht ein Terminal. Verwende: --plan agency-plan.json";;
    de:advanced) s="fortgeschritten";;
    de:unsupported) s="Tool %s wird von diesem Installer noch nicht unterstützt (nutze die Agency Agents App).";;
    *) s="$key";;
  esac
  if [[ $# -gt 0 ]]; then printf "${s}\n" "$@"; else printf '%s\n' "$s"; fi
}

# ---------- argumentos ----------
PLAN_FILE=""; STATUS_ONLY=0; LANG_GIVEN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan|--plano) PLAN_FILE="${2:-}"; shift 2;;
    --lang|--lingua) LANG_GIVEN="${2:-}"; shift 2;;
    --status) STATUS_ONLY=1; shift;;
    --help|-h|--ajuda) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) err "Unknown option: $1 (use --plan, --lang, --status or --help) / Opção desconhecida: $1";;
  esac
done

# ---------- idioma ----------
LANGS_VALID="en pt es fr de"
if [[ -n "$LANG_GIVEN" ]]; then
  # mensagem fixa bilíngue: o idioma pedido pode ser inválido, então não há tradução confiável ainda
  case " $LANGS_VALID " in *" $LANG_GIVEN "*) LANG_SEL="$LANG_GIVEN";;
    *) err "Invalid language: $LANG_GIVEN (use en, pt, es, fr or de) / Idioma inválido: $LANG_GIVEN";; esac
elif [[ -t 0 ]]; then
  echo "$(msg pick_lang)"
  echo "  1) English   2) Português   3) Español   4) Français   5) Deutsch"
  read -rp "1-5 [1]: " ln; ln="${ln:-1}"
  case "$ln" in 2) LANG_SEL="pt";; 3) LANG_SEL="es";; 4) LANG_SEL="fr";; 5) LANG_SEL="de";; *) LANG_SEL="en";; esac
else
  LANG_SEL="en"  # sem terminal: inglês por padrão
fi

# ---------- pré-requisitos ----------
command -v git >/dev/null 2>&1 || err "$(msg need_git)"
command -v bash >/dev/null 2>&1 || err "bash required."
if [[ -n "$PLAN_FILE" ]]; then
  [[ -f "$PLAN_FILE" ]] || err "$(msg err_plan "$PLAN_FILE")"
  python3 - "$PLAN_FILE" <<'PY' || err "$(msg err_bad_plan "$PLAN_FILE")"
import json, sys
try:
    p = json.load(open(sys.argv[1]))
    assert isinstance(p, dict) and isinstance(p.get("agentes"), list) and isinstance(p.get("ferramentas"), list)
    assert all(isinstance(t, str) and t.strip() for t in p["ferramentas"]), "ferramentas"
    for a in p["agentes"]:
        f, s = a["file"], a["slug"]
        assert isinstance(f, str) and f and not f.startswith("/") and ".." not in f.split("/"), f"unsafe path: {f}"
        assert isinstance(s, str) and s.strip() and "/" not in s, f"unsafe slug: {s}"
except Exception:
    raise SystemExit(1)
PY
fi

# ---------- catálogo ----------
if [[ -d "$CATALOG_DIR/.git" ]]; then
  say "$(msg cat_update "$CATALOG_DIR")"
  git -C "$CATALOG_DIR" pull --ff-only >/dev/null 2>&1 || warn "catalog update skipped"
else
  say "$(msg cat_clone)"
  git clone --depth 1 "$CATALOG_REPO" "$CATALOG_DIR" >/dev/null 2>&1 || err "$(msg cat_fail)"
fi
CAT_COMMIT="$(git -C "$CATALOG_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"
CAT_DATE="$(git -C "$CATALOG_DIR" log -1 --format=%cs 2>/dev/null || echo '?')"

OSF="linux"; OSL="Linux"
[[ "$(uname)" == "Darwin" ]] && { OSF="macos"; OSL="macOS"; }
ARCH="$(uname -m)"

# ---------- detecção ----------
TOOL_DEFS=(
  "claudeCode|Claude Code|claude-code|.claude/agents|identity|sim|sim|sim|claude|\.claude"
  "zcode|ZCode|zcode|.zcode/agents|zcode-md|sim|sim|sim||\.zcode"
  "codex|Codex CLI|codex|.codex/agents|toml|sim|sim|wsl|codex|\.codex"
  "geminiCli|Gemini CLI|gemini-cli|.gemini/agents|md|sim|sim|sim||\.gemini"
  "copilot|GitHub Copilot|github-copilot|.github/agents|identity|sim|sim|sim||\.github/agents .copilot"
  "qwen|Qwen Code|qwen|.qwen/agents|md|sim|sim|sim||\.qwen"
  "opencode|opencode|.config/opencode/agents|opencode-md|sim|sim|sim||\.config/opencode"
  "antigravity|Antigravity|antigravity|.gemini/config/skills|skill-dir|sim|sim|sim||\.gemini/config"
  "osaurus|Osaurus|osaurus|.osaurus/skills|skill-dir|nao|sim|nao||\.osaurus"
  "kimi|Kimi CLI|kimi|.config/kimi/agents|kimi-dir|sim|sim|wsl||\.config/kimi"
)
detect_tool() { # $1 = dirs (espaçados, relativos ao HOME); $2 = bin opcional
  local d p
  [[ -n "${2:-}" ]] && command -v "$2" >/dev/null 2>&1 && return 0
  for d in $1; do p="$HOME/$d"; [[ -e "$p" ]] && return 0; done
  return 1
}
count_agents() { # $1 = dir relativo ao HOME (conta recursivo, só arquivos de agente)
  local dir="$HOME/$1" n=0 f
  [[ -d "$dir" ]] || { echo 0; return; }
  while IFS= read -r f; do n=$((n+1)); done < <(find "$dir" -type f \( -name "*.md" -o -name "*.toml" -o -name "SKILL.md" -o -name "agent.yaml" \) 2>/dev/null)
  echo "$n"
}
declare -A T_INST
for row in "${TOOL_DEFS[@]}"; do
  IFS='|' read -r id label kebab rel fmt cl cm cw bin dirs <<<"$row"
  if detect_tool "$dirs" "$bin"; then T_INST[$id]=1; else T_INST[$id]=0; fi
done

# ---------- helpers de instalação ----------
backup_dest() { # backup_dest <dest> [referencia]
  local d="$1" ref="${2:-}" b
  [[ -e "$d" ]] || return 0
  if [[ -n "$ref" && -f "$ref" ]] && cmp -s "$d" "$ref"; then return 0; fi
  b="$HOME/.agency-agents-backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$b/$(dirname "${d#"$HOME"/}")"
  if [[ -d "$d" ]]; then cp -r "$d" "$b/$(dirname "${d#"$HOME"/}")/"; else cp "$d" "$b/$(dirname "${d#"$HOME"/}")/"; fi
}
render() { bash "$CATALOG_DIR/scripts/convert.sh" --tool "$1" --out "$WORK/out" >/dev/null 2>&1; }
install_identity() { # $1=plano|"all"; $2=dest rel
  local dest="$HOME/$2" src
  mkdir -p "$dest"
  if [[ "$1" == "all" ]]; then
    # TODOS os .md das divisões (qualquer profundidade — divisões têm subpastas), exceto lixo conhecido
    find "$CATALOG_DIR" -type f -name "*.md" \
      \( -path "*/academic/*" -o -path "*/design/*" -o -path "*/engineering/*" -o -path "*/finance/*" \
         -o -path "*/game-development/*" -o -path "*/gis/*" -o -path "*/healthcare/*" -o -path "*/marketing/*" \
         -o -path "*/paid-media/*" -o -path "*/product/*" -o -path "*/project-management/*" -o -path "*/research/*" \
         -o -path "*/sales/*" -o -path "*/security/*" -o -path "*/spatial-computing/*" -o -path "*/specialized/*" \
         -o -path "*/support/*" -o -path "*/testing/*" \) \
      ! -iname "readme*" ! -iname "contributing*" ! -iname "*worklog*" | while read -r src; do
      backup_dest "$dest/$(basename "$src")" "$src"
      cp "$src" "$dest/"
    done
  else
    python3 - "$1" "$dest" "$CATALOG_DIR" <<'PY'
import json, shutil, sys, pathlib
plano = json.load(open(sys.argv[1]))
dest = pathlib.Path(sys.argv[2]); cat = pathlib.Path(sys.argv[3]).resolve()
for ag in plano.get("agentes", []):
    src = (cat / ag["file"]).resolve()
    if cat not in src.parents and src.parent != cat:
        print(f"[!!]  caminho inseguro ignorado: {ag['file']}", file=sys.stderr)
        continue
    if src.exists() and src.suffix == ".md":
        dst = dest / src.name
        if dst.exists() and dst.read_bytes() != src.read_bytes():
            b = pathlib.Path.home()/".agency-agents-backup"
            b.mkdir(parents=True, exist_ok=True); shutil.copy2(dst, b/(dst.name+".bak"))
        shutil.copy2(src, dst)
PY
  fi
}
install_rendered() { # $1=kebab; $2=subpasta-fonte; $3=dest rel; $4=arquivo|pasta
  render "$1"
  local srcRoot="$WORK/out/$1/$2" destRoot="$HOME/$3"
  [[ -d "$srcRoot" ]] || { warn "render $1: $2 missing"; return 0; }
  mkdir -p "$destRoot"
  # filtro pelo plano: copia só os slugs pedidos (all = tudo)
  local filter_slugs=""
  if [[ "$SLUGS_FILE" != "all" ]]; then
    # falha fechada: plano ilegível ⇒ NADA é instalado (nunca "instala tudo" por engano)
    if ! filter_slugs="$(python3 -c 'import json,sys; print("\n".join(sorted({a["slug"] for a in json.load(open(sys.argv[1]))["agentes"]})))' "$SLUGS_FILE" 2>/dev/null)"; then
      filter_slugs="__PLAN_FILTER_ERROR__"
      warn "plan filter error: installing nothing for safety"
    fi
  fi
  if [[ "$4" == "arquivo" ]]; then
    find "$srcRoot" -type f | while read -r f; do
      local base base_noext
      base="$(basename "$f")"; base_noext="${base%.*}"
      if [[ -n "$filter_slugs" ]] && ! grep -qxF "$base_noext" <<<"$filter_slugs"; then continue; fi
      backup_dest "$destRoot/$base" "$f"
      cp "$f" "$destRoot/"
    done
  else
    find "$srcRoot" -mindepth 1 -maxdepth 1 -type d | while read -r d; do
      local dest name
      name="$(basename "$d")"; dest="$destRoot/$name"
      if [[ -n "$filter_slugs" ]] && ! grep -qxF "$name" <<<"$filter_slugs"; then continue; fi
      backup_dest "$dest"
      rm -rf "$dest"; mkdir -p "$(dirname "$dest")"; cp -r "$d" "$dest"
    done
  fi
}

# ---------- squads nomeadas ----------
SQUADS_JSON="$SCRIPT_DIR/../dados/squads.json"
SLUGS_FILE="${PLAN_FILE:-all}"
if [[ -z "$PLAN_FILE" && "$STATUS_ONLY" != "1" ]]; then
  if [[ ! -t 0 ]]; then err "$(msg err_notty)"; fi
  echo; say "$(msg found)"
  local_opts=(); i=1
  for row in "${TOOL_DEFS[@]}"; do
    IFS='|' read -r id label kebab rel fmt cl cm cw bin dirs <<<"$row"
    key="$cw"; [[ "$OSF" == "linux" ]] && key="$cl"; [[ "$OSF" == "macos" ]] && key="$cm"
    [[ "$key" == "nao" ]] && continue
    st="$(msg not_installed)"; [[ "${T_INST[$id]}" == "1" ]] && st="$(msg installed_ok)"
    printf '  %2d) %-14s %s\n' "$i" "$id" "$st"; local_opts+=("$id"); i=$((i+1))
  done
  read -rp "$(msg pick_tools) " resp
  if [[ -z "${resp// /}" ]]; then DO_TOOL="$(IFS=,; echo "${local_opts[*]}")"; else
    DO_TOOL=""
    for n in ${resp//,/ }; do
      [[ "$n" =~ ^[0-9]+$ ]] || continue
      (( n >= 1 && n <= ${#local_opts[@]} )) || continue
      DO_TOOL="${DO_TOOL:+$DO_TOOL,}${local_opts[$((n-1))]}"
    done
    [[ -z "$DO_TOOL" ]] && DO_TOOL="$(IFS=,; echo "${local_opts[*]}")"
  fi
  echo; say "$(msg pick_squad)"; echo "  $(msg squad1)"; echo "  $(msg squad2)"; echo "  $(msg squad3)"
  read -rp "1-3 [1]: " s; s="${s:-1}"
  case "$s" in 2) SLUGS_FILE="squad4";; 3) SLUGS_FILE="all";; *) SLUGS_FILE="squad12";; esac
fi
if [[ "$SLUGS_FILE" == "squad12" || "$SLUGS_FILE" == "squad4" ]]; then
  [[ -f "$SQUADS_JSON" ]] || err "dados/squads.json missing"
  KEY="$([[ "$SLUGS_FILE" == "squad12" ]] && echo pre-lancamento || echo treino)"
  python3 - "$SQUADS_JSON" "$KEY" "$WORK/plano.json" <<'PY'
import json, sys
sq = json.load(open(sys.argv[1]))[sys.argv[2]]
json.dump({"agentes": sq["agentes"]}, open(sys.argv[2], "w"))
PY
  SLUGS_FILE="$WORK/plano.json"
fi
if [[ -n "$PLAN_FILE" ]]; then
  DO_TOOL="$(python3 -c 'import json,sys; print(",".join(json.load(open(sys.argv[1]))["ferramentas"]))' "$PLAN_FILE")"
fi

install_identity_pick() { # $1=dest rel — plano com agentes vazio = todos (mesma semântica das renderizadas)
  if [[ "$SLUGS_FILE" == "all" ]]; then install_identity all "$1"
  elif python3 -c 'import json,sys; sys.exit(0 if not json.load(open(sys.argv[1])).get("agentes") else 1)' "$SLUGS_FILE" 2>/dev/null; then
    install_identity all "$1"
  else
    install_identity "$SLUGS_FILE" "$1"
  fi
}
install_one() { # $1=id
  local dest_rel after row label=""
  # ferramenta incompatível com este SO? recusa com aviso (plano editado à mão, p.ex.)
  for row in "${TOOL_DEFS[@]}"; do
    local rid rlabel rcl rcm rcw
    IFS='|' read -r rid rlabel _ _ _ rcl rcm rcw _ _ <<<"$row"
    if [[ "$rid" == "$1" ]]; then
      label="$rlabel"
      local key="$rcw"; [[ "$OSF" == "linux" ]] && key="$rcl"; [[ "$OSF" == "macos" ]] && key="$rcm"
      if [[ "$key" == "nao" ]]; then
        warn "$(msg unsupported "$label") (${OSL})"
        return 0
      fi
      break
    fi
  done
  case "$1" in
    claudeCode) dest_rel=".claude/agents";  install_identity_pick "$dest_rel" ;;
    copilot)    dest_rel=".github/agents";  install_identity_pick "$dest_rel" ;;
    zcode)       dest_rel=".zcode/agents";         install_rendered zcode agents "$dest_rel" arquivo ;;
    codex)       dest_rel=".codex/agents";         install_rendered codex agents "$dest_rel" arquivo ;;
    geminiCli)   dest_rel=".gemini/agents";        install_rendered gemini-cli agents "$dest_rel" arquivo ;;
    qwen)        dest_rel=".qwen/agents";          install_rendered qwen agents "$dest_rel" arquivo ;;
    opencode)    dest_rel=".config/opencode/agents"; install_rendered opencode agents "$dest_rel" arquivo ;;
    antigravity) dest_rel=".gemini/config/skills"; install_rendered antigravity skills "$dest_rel" pasta ;;
    osaurus)     dest_rel=".osaurus/skills";       install_rendered osaurus skills "$dest_rel" pasta ;;
    kimi)        dest_rel=".config/kimi/agents";   install_rendered kimi agents "$dest_rel" pasta ;;
    *) warn "$(msg unsupported "$1")"; return 0;;
  esac
  after=$(count_agents "$dest_rel")
  if [[ "${after:-0}" == "0" ]]; then
    warn "$(msg install_fail "$label")"
  else
    say "$(msg install_ok "$label" "$after")"
  fi
}

if [[ "$STATUS_ONLY" != "1" && -n "${DO_TOOL:-}" ]]; then
  IFS=',' read -ra TOOLS_TO_DO <<<"$DO_TOOL"
  for t in "${TOOLS_TO_DO[@]}"; do install_one "$(echo "$t" | tr -d ' ')"; done
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
  if python3 - "$CAT_COMMIT" "$CAT_DATE" "$OSF" "$OSL" "$ARCH" "$GU_DIR" "$LANG_SEL" <<'PY'
import json, sys, pathlib, datetime
commit, cdate, osf, osl, arch, gu, lang = sys.argv[1:8]
tools = []
defs = [("claudeCode",".claude/agents"),("zcode",".zcode/agents"),("codex",".codex/agents"),
        ("geminiCli",".gemini/agents"),("copilot",".github/agents"),("qwen",".qwen/agents"),
        ("opencode",".config/opencode/agents"),("antigravity",".gemini/config/skills"),
        ("osaurus",".osaurus/skills"),("kimi",".config/kimi/agents")]
home = pathlib.Path.home()
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
status = {"version": 1, "lang": lang,
          "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "os": {"family": osf, "label": osl, "arch": arch},
          "catalog": {"path": str(cat), "commit": commit, "updated": cdate},
          "tools": tools}
out = pathlib.Path(gu) / "guia-status.js"
out.write_text("window.GUIA_STATUS = " + json.dumps(status) + ";\n", encoding="utf-8")
print(f"[ok]  {out}")
PY
  then
    say "$(msg panel_updated "$GU_DIR/guia-status.js")"
  else
    # degradação graciosa: a instalação já aconteceu; não aborta por causa do painel
    warn "$(msg status_fail)"
  fi
else
  warn "$(msg guia_not_found)"
fi

# ---------- resumo ----------
echo; say "$(msg done)"
for row in "${TOOL_DEFS[@]}"; do
  IFS='|' read -r id label kebab rel fmt cl cm cw bin dirs <<<"$row"
  c=$(count_agents "$rel")
  printf '  %-14s %-12s %s %s\n' "$label" "$([[ ${T_INST[$id]:-0} == 1 ]] && msg detected || msg absent)" "$c" "$(msg specialists)"
done
[[ -n "$GU_DIR" && "$STATUS_ONLY" != "1" ]] && { say "$(msg opening)"; (xdg-open "$GU_DIR/guia-especialistas-agencia.html" >/dev/null 2>&1 || open "$GU_DIR/guia-especialistas-agencia.html" >/dev/null 2>&1 || true); }
echo; say "$(msg rerun)"
