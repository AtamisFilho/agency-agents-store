#!/usr/bin/env bash
# ============================================================================
# instalar-linux.sh — Agency Agents Store (Linux & macOS)
#
# Wrapper fino: toda a lógica vive em agency-install.py (driver comum, mesma
# fonte de traduções que o instalador Windows). Este arquivo só verifica os
# pré-requisitos com mensagens claras e repassa os argumentos.
#
# Usage:
#   ./instalar-linux.sh                            # interactive (asks language)
#   ./instalar-linux.sh --plan agency-plan.json    # guide plan (path optional: auto-search)
#   ./instalar-linux.sh --tool zcode,codex --squad pre    # non-interactive (CI/scripts)
#   ./instalar-linux.sh --tool cursor --dir ~/my/project --squad treino
#   ./instalar-linux.sh --status [--json]          # detect only (--json: no files, no network)
#   ./instalar-linux.sh --list                     # catalog/tools/squads as JSON (no network)
#   ./instalar-linux.sh --dry-run --tool zcode --squad treino
#   ./instalar-linux.sh --uninstall --tool zcode   # remove (backs up first)
#   ./instalar-linux.sh --help
#
# Languages: en | pt | es | fr | de   (persisted in ~/.agency-agents/config)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVER="$SCRIPT_DIR/agency-install.py"

need() {
  printf '\033[0;31m[err]\033[0m %s\n' "$1" >&2
  exit 1
}

# ---------- pré-requisitos (verificados ANTES de qualquer uso — bug do python3 ausente) ----------
if ! command -v git >/dev/null 2>&1; then
  need "Git not found. Install it first: https://git-scm.com (Ubuntu: sudo apt install git · macOS: xcode-select --install) / \
Git não encontrado. Instale antes: https://git-scm.com (Ubuntu: sudo apt install git · macOS: xcode-select --install)"
fi

if ! command -v python3 >/dev/null 2>&1; then
  need "Python 3 not found, and this installer needs it. Install it first: https://www.python.org (Ubuntu: sudo apt install python3 · macOS: xcode-select --install) / \
Python 3 não encontrado, e este instalador precisa dele. Instale antes: https://www.python.org (Ubuntu: sudo apt install python3 · macOS: xcode-select --install)"
fi

if [[ ! -f "$DRIVER" ]]; then
  need "agency-install.py not found next to this script — download the full repository (or use the one-line installer from the README) / \
agency-install.py não encontrado junto deste script — baixe o repositório completo (ou use o instalador de uma linha do README)."
fi

exec python3 "$DRIVER" "$@"
