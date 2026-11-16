#!/usr/bin/env bash
# ============================================================================
# instalar.sh — Agency Agents Store, instalador de UMA LINHA (Linux/macOS)
#
#   curl -fsSL https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.sh | bash
#
# Baixa o driver (agency-install.py), os dados de tradução (dados/) e o guia
# para ~/.agency-agents-store e executa o instalador. Argumentos são
# repassados:   curl -fsSL … | bash -s -- --lang pt --tool zcode --squad treino
# ============================================================================
set -euo pipefail

STORE="$HOME/.agency-agents-store"
BASE="https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main"

say()  { printf '\033[0;32m[ok]\033[0m  %s\n' "$*"; }
warn() { printf '\033[0;33m[!!]\033[0m  %s\n' "$*"; }
die()  { printf '\033[0;31m[err]\033[0m %s\n' "$*" >&2; exit 1; }

fetch() { # fetch <url> <destino>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$1" -O "$2"
  else
    die "curl or wget not found / curl ou wget não encontrado. Install one and try again."
  fi
}

command -v python3 >/dev/null 2>&1 || die "Python 3 not found. Install: https://www.python.org / Python 3 não encontrado. Instale: https://www.python.org"
command -v git >/dev/null 2>&1 || die "Git not found. Install: https://git-scm.com / Git não encontrado. Instale: https://git-scm.com"

mkdir -p "$STORE/instaladores" "$STORE/dados"

say "Downloading the installer + guide to ~/.agency-agents-store ..."
fetch "$BASE/instaladores/agency-install.py" "$STORE/instaladores/agency-install.py"
fetch "$BASE/dados/i18n-instalador.json"     "$STORE/dados/i18n-instalador.json"
fetch "$BASE/dados/squads.json"              "$STORE/dados/squads.json" || warn "squads.json indisponível (use --squad all)"
fetch "$BASE/guia-especialistas-agencia.html" "$STORE/guia-especialistas-agencia.html" \
  || warn "guide download failed — the panel will not be written (guia não baixado — painel não será escrito)"

exec python3 "$STORE/instaladores/agency-install.py" "$@"
