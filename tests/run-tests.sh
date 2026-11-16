#!/usr/bin/env bash
# ============================================================================
# run-tests.sh — suíte adversarial do instalador (Linux/macOS)
# Exercita branches REJECTED (planos maliciosos, idiomas inválidos, TTY
# ausente, ferramentas incompatíveis, HOME com espaço, backup, modo pasta)
# e as flags novas (--tool/--squad/--dry-run/--list/--uninstall/--dir/--json,
# autodetecção de plano, persistência de idioma, --status sem rede).
#
# Contagens de catálogo são DINÂMICAS (regra oficial: divisions.json +
# frontmatter "---"), então a suíte não quebra quando o catálogo upstream cresce.
# ============================================================================
set -u
export LC_ALL=C.UTF-8 LANG=C.UTF-8   # mensagens determinísticas em inglês
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
INSTALLER="$REPO/instaladores/instalar-linux.sh"
DRIVER="$REPO/instaladores/agency-install.py"
TESTCAT="/tmp/aa-test-catalog-$$"
PASS=0; FAIL=0; FAILED_NAMES=()

t() { # t <nome> <esperado:ok|fail> <cmd...>
  local name="$1" expect="$2"; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  if { [[ "$expect" == "ok" && $rc -eq 0 ]] || [[ "$expect" == "fail" && $rc -ne 0 ]]; }; then
    PASS=$((PASS+1)); echo "PASS $name"
  else
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$name"); echo "FAIL $name (rc=$rc, esperado=$expect)"; echo "$out" | head -5 | sed 's/^/    /'
  fi
}
assert_out() { # assert_out <nome> <padrão grep> <arquivo de saída>
  local name="$1" pat="$2" file="$3"
  if grep -q "$pat" "$file"; then PASS=$((PASS+1)); echo "PASS $name"
  else FAIL=$((FAIL+1)); FAILED_NAMES+=("$name"); echo "FAIL $name (padrão '$pat' ausente)"; head -5 "$file" | sed 's/^/    /'; fi
}
new_home() { # new_home <dir> — HOME isolado com catálogo via hardlinks
  local d="$1"
  rm -rf "$d"; mkdir -p "$d"
  cp -al "$TESTCAT" "$d/.agency-agents" 2>/dev/null || cp -r "$TESTCAT" "$d/.agency-agents"
}
spec_count() { # spec_count <catálogo> — contagem OFICIAL (divisions.json + frontmatter), independente do instalador
  python3 - "$1" <<'SPEC'
import re, sys, pathlib
cat = pathlib.Path(sys.argv[1])
divs = []
text = (cat / "divisions.json").read_text(encoding="utf-8", errors="replace")
m = re.search(r'"divisions"\s*:\s*\{', text)
if m:
    divs = re.findall(r'"([a-z0-9-]+)"\s*:\s*\{', text[m.end():])
if not divs:
    divs = [p.name for p in cat.iterdir() if p.is_dir() and p.name not in {"scripts","integrations","examples",".git",".github","i18n"}]
if "strategy" not in divs:
    divs.append("strategy")
n = 0
for d in divs:
    dd = cat / d
    if not dd.is_dir():
        continue
    for p in dd.rglob("*.md"):
        try:
            if p.open(encoding="utf-8", errors="replace").readline().strip() == "---":
                n += 1
        except OSError:
            pass
print(n)
SPEC
}
clean_repo_side_effects() { rm -f "$REPO/guia-status.js" "$REPO/agency-plan.json"; }

# ---------- catálogo compartilhado (clone único, hardlinks nos testes) ----------
rm -rf "$TESTCAT"
git clone --depth 1 -q https://github.com/msitarzewski/agency-agents.git "$TESTCAT" || { echo "FATAL: clone catálogo"; exit 1; }
clean_repo_side_effects
N_AGENTS="$(spec_count "$TESTCAT")"
echo "== catálogo de teste: $N_AGENTS agentes (contagem dinâmica) =="

# ---------- 1. sintaxe ----------
t "bash -n no instalador" ok bash -n "$INSTALLER"
t "bash -n no bootstrap" ok bash -n "$REPO/instaladores/instalar.sh"
t "py_compile no build.py" ok python3 -m py_compile "$REPO/gerador/build.py"
t "py_compile no driver" ok python3 -m py_compile "$DRIVER"

# ---------- 2. idioma inválido → rejected ----------
TH=/tmp/aa-h-lang; new_home "$TH"
out=$(HOME="$TH" bash "$INSTALLER" --lang xx --status </dev/null 2>&1) || true
if echo "$out" | grep -qi "invalid language\|idioma inválido\|Ungültige\|Langue invalide"; then PASS=$((PASS+1)); echo "PASS --lang inválido mostra erro"; else FAIL=$((FAIL+1)); FAILED_NAMES+=("--lang msg"); echo "FAIL --lang msg"; echo "$out" | head -3 | sed 's/^/    /'; fi
rm -rf "$TH"

# ---------- 3. plano inexistente → rejected ----------
TH=/tmp/aa-h-plan404; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --plan /tmp/aa-inexistente-$$ --status </dev/null >/tmp/aa-out-plan404 2>&1
assert_out "--plan inexistente → err" "not found\|não encontrado\|no encontrado\|introuvable\|nicht gefunden" /tmp/aa-out-plan404
rm -rf "$TH"

# ---------- 4. plano JSON inválido → rejected ----------
TH=/tmp/aa-h-badplan; new_home "$TH"
echo "{isto não é json" > /tmp/aa-badplan.json
HOME="$TH" bash "$INSTALLER" --plan /tmp/aa-badplan.json --status </dev/null >/tmp/aa-out-badplan 2>&1
assert_out "plano JSON inválido → err" "Invalid plan\|inválido\|invalide\|Ungültige" /tmp/aa-out-badplan
rm -rf "$TH"

# ---------- 5. plano com path traversal → rejected ----------
TH=/tmp/aa-h-trav; new_home "$TH"
cat > /tmp/aa-trav.json <<'EOF'
{"ferramentas":["claudeCode"],"agentes":[{"slug":"x","file":"../../../../etc/passwd"}]}
EOF
HOME="$TH" bash "$INSTALLER" --plan /tmp/aa-trav.json --status </dev/null >/tmp/aa-out-trav 2>&1
assert_out "path traversal no plano → recusado" "Invalid plan\|inválido\|Ungültige\|invalide" /tmp/aa-out-trav
[[ -f "$TH/claude/agents/passwd" || -f "$TH/.claude/agents/passwd" ]] && { FAIL=$((FAIL+1)); echo "FAIL traversal ESCAPOU"; } || { PASS=$((PASS+1)); echo "PASS traversal não escapou"; }
rm -rf "$TH"

# ---------- 6. interativo sem TTY → rejected limpo (não trava) ----------
TH=/tmp/aa-h-notty; new_home "$TH"
timeout 10 env HOME="$TH" bash "$INSTALLER" </dev/null >/tmp/aa-out-notty 2>&1
rc=$?
if [[ $rc -ne 0 && $rc -ne 124 ]] && grep -qi "terminal\|--plan" /tmp/aa-out-notty; then PASS=$((PASS+1)); echo "PASS sem TTY → erro orientado (rc=$rc)"
elif [[ $rc -eq 124 ]]; then FAIL=$((FAIL+1)); FAILED_NAMES+=("notty-travou"); echo "FAIL sem TTY TRAVOU (timeout)"
else PASS=$((PASS+1)); echo "PASS sem TTY termina sem travar (rc=$rc)"; fi
rm -rf "$TH"

# ---------- 7. instalação real: plano em zcode (HOME com espaço) ----------
TH="/tmp/aa h space"; new_home "$TH"   # HOME com ESPAÇO no nome
cat > "$TH/plan.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[{"slug":"code-reviewer","file":"engineering/engineering-code-reviewer.md"},{"slug":"reality-checker","file":"testing/testing-reality-checker.md"}]}
EOF
HOME="$TH" bash "$INSTALLER" --lang pt --plan "$TH/plan.json" </dev/null >/tmp/aa-out-real 2>&1
assert_out "instalação com HOME contendo espaço (msg pt)" "Especialistas instalados em ZCode" /tmp/aa-out-real
[[ -f "$TH/.zcode/agents/code-reviewer.md" ]] && { PASS=$((PASS+1)); echo "PASS destino .zcode/agents com espaço OK"; } || { FAIL=$((FAIL+1)); FAILED_NAMES+=("zcode-space"); echo "FAIL destino zcode"; }
[[ -f "$TH/.zcode/agents/reality-checker.md" ]] && { PASS=$((PASS+1)); echo "PASS 2º agente OK"; } || { FAIL=$((FAIL+1)); echo "FAIL 2º agente"; }
n_inst=$(ls "$TH/.zcode/agents/" 2>/dev/null | wc -l)
[[ "$n_inst" == "2" ]] && { PASS=$((PASS+1)); echo "PASS plano respeitado: exatamente 2 instalados"; } || { FAIL=$((FAIL+1)); FAILED_NAMES+=("plan-filter"); echo "FAIL plano não filtrado: $n_inst instalados (esperado 2)"; }
[[ -d "$TH/zcode" ]] && { FAIL=$((FAIL+1)); echo "FAIL lixo em ~/zcode (sem ponto)"; } || { PASS=$((PASS+1)); echo "PASS sem lixo sem-ponto"; }
# status com lang
[[ -f "$REPO/guia-status.js" ]] && grep -q '"lang": "pt"\|"lang":"pt"' "$REPO/guia-status.js" && { PASS=$((PASS+1)); echo "PASS status.lang propagado"; } || { FAIL=$((FAIL+1)); echo "FAIL status.lang"; }
# backup na 2ª rodada com conteúdo alterado
echo "modificado" >> "$TH/.zcode/agents/code-reviewer.md"
HOME="$TH" bash "$INSTALLER" --lang pt --plan "$TH/plan.json" </dev/null >/dev/null 2>&1
n_backup=$(find "$TH/.agency-agents-backup" -name "*.md" 2>/dev/null | wc -l)
[[ "$n_backup" -ge 1 ]] && { PASS=$((PASS+1)); echo "PASS backup criado na 2ª instalação ($n_backup arq.)"; } || { FAIL=$((FAIL+1)); echo "FAIL backup ausente"; }
# conteúdo restaurado (a 2ª instalação sobrescreve com o original)
grep -q "modificado" "$TH/.zcode/agents/code-reviewer.md" && { FAIL=$((FAIL+1)); echo "FAIL sobrescrita não restaurou"; } || { PASS=$((PASS+1)); echo "PASS sobrescrita restaurou o original"; }
rm -rf "$TH"; clean_repo_side_effects

# ---------- 8. identity "all" instala o catálogo INTEIRO (contagem dinâmica) ----------
TH=/tmp/aa-h-all; new_home "$TH"
cat > "$TH/plan-all.json" <<'EOF'
{"ferramentas":["claudeCode"],"agentes":[]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-all.json" </dev/null >/tmp/aa-out-all 2>&1
n_dest=$(find "$TH/.claude/agents" -type f -name "*.md" 2>/dev/null | wc -l)
if [[ "$n_dest" == "$N_AGENTS" ]]; then
  PASS=$((PASS+1)); echo "PASS identity all = $n_dest (= catálogo dinâmico, inclui subpastas e divisões novas)"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("all-dynamic"); echo "FAIL identity all = $n_dest (esperado $N_AGENTS)"; head -5 /tmp/aa-out-all | sed 's/^/    /'
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 9. modo pasta (antigravity) → SKILL.md no destino ----------
TH=/tmp/aa-h-agv; new_home "$TH"
cat > "$TH/plan-agv.json" <<'EOF'
{"ferramentas":["antigravity"],"agentes":[]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-agv.json" </dev/null >/tmp/aa-out-agv 2>&1
if grep -q "Specialists installed in Antigravity" /tmp/aa-out-agv; then
  n=$(find "$TH/.gemini/config/skills" -name "SKILL.md" 2>/dev/null | wc -l)
  [[ "$n" -ge 1 ]] && { PASS=$((PASS+1)); echo "PASS antigravity modo pasta: $n SKILL.md"; } || { FAIL=$((FAIL+1)); echo "FAIL antigravity: ✓ mas 0 SKILL.md"; }
elif grep -q "render antigravity" /tmp/aa-out-agv || grep -qi "\[!!\]" /tmp/aa-out-agv; then
  PASS=$((PASS+1)); echo "PASS antigravity: falha reportada com aviso honesto (não ✓ falso)"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("antigravity-silent"); echo "FAIL antigravity: resultado silencioso"; head -5 /tmp/aa-out-agv
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 10. ferramenta não suportada no plano → aviso, não crash ----------
TH=/tmp/aa-h-unsup; new_home "$TH"
cat > "$TH/plan-unsup.json" <<'EOF'
{"ferramentas":["hermes"],"agentes":[]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-unsup.json" </dev/null >/tmp/aa-out-unsup 2>&1
rc=$?
if [[ $rc -eq 0 ]] && grep -qi "not supported" /tmp/aa-out-unsup; then PASS=$((PASS+1)); echo "PASS hermes → aviso unsupported, rc=0"
else FAIL=$((FAIL+1)); echo "FAIL hermes (rc=$rc)"; fi
rm -rf "$TH"

# ---------- 11. ferramenta incompatível com o SO no plano → recusada ----------
TH=/tmp/aa-h-incomp; new_home "$TH"
cat > "$TH/plan-osaurus.json" <<'EOF'
{"ferramentas":["osaurus"],"agentes":[]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-osaurus.json" </dev/null >/tmp/aa-out-osaurus 2>&1
if grep -qi "not available for\|incompat\|macOS only\|not supported" /tmp/aa-out-osaurus; then
  PASS=$((PASS+1)); echo "PASS osaurus no Linux recusado com aviso"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("osaurus-incompat"); echo "FAIL osaurus no Linux deveria ser recusado"; head -5 /tmp/aa-out-osaurus
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 12. plano sem "slug" nos agentes → rejected na validação ----------
TH=/tmp/aa-h-noslug; new_home "$TH"
cat > "$TH/plan-noslug.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[{"file":"engineering/engineering-code-reviewer.md"}]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-noslug.json" </dev/null >/tmp/aa-out-noslug 2>&1
rc=$?
if [[ $rc -ne 0 ]] && grep -qi "Invalid plan\|inválido\|invalide\|Ungültige" /tmp/aa-out-noslug; then
  PASS=$((PASS+1)); echo "PASS plano sem slug → rejected na validação"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("no-slug"); echo "FAIL plano sem slug deveria ser rejeitado (rc=$rc)"; head -5 /tmp/aa-out-noslug
fi
[[ -d "$TH/.zcode/agents" && $(find "$TH/.zcode/agents" -type f 2>/dev/null | wc -l) -gt 0 ]] && { FAIL=$((FAIL+1)); echo "FAIL sem slug instalou algo"; } || { PASS=$((PASS+1)); echo "PASS sem slug não instalou nada"; }
rm -rf "$TH"

# ---------- 13. diretório do guia sem permissão de escrita → aviso honesto, não crash ----------
ROG="/tmp/aa-rog-$$"; TH=/tmp/aa-h-ro
rm -rf "$ROG" "$TH"; mkdir -p "$ROG/instaladores"
cp "$INSTALLER" "$DRIVER" "$ROG/instaladores/"   # instalador + driver (layout do repo)
echo "<html>guia fake</html>" > "$ROG/guia-especialistas-agencia.html"
chmod 555 "$ROG"
new_home "$TH"
HOME="$TH" bash "$ROG/instaladores/instalar-linux.sh" --lang en --status </dev/null >/tmp/aa-out-ro 2>&1
rc=$?
chmod 755 "$ROG"   # permite a limpeza
if [[ $rc -eq 0 ]] && grep -q "Done!" /tmp/aa-out-ro && ! grep -q "Guide panel updated" /tmp/aa-out-ro; then
  PASS=$((PASS+1)); echo "PASS escrita do status falha → aviso, resumo impresso, rc=0"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("status-ro"); echo "FAIL status read-only (rc=$rc) — crash ou sucesso falso"; head -8 /tmp/aa-out-ro
fi
rm -rf "$ROG" "$TH"; clean_repo_side_effects

# ---------- 14. agentes vazio = TODOS (contagem dinâmica; render zcode) ----------
TH=/tmp/aa-h-empty; new_home "$TH"
cat > "$TH/plan-empty.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-empty.json" </dev/null >/tmp/aa-out-empty 2>&1
rc=$?
n=$(find "$TH/.zcode/agents" -type f -name "*.md" 2>/dev/null | wc -l)
if [[ $rc -eq 0 && "$n" == "$N_AGENTS" ]]; then
  PASS=$((PASS+1)); echo "PASS agentes vazio = todos ($n no destino, dinâmico)"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("empty=all"); echo "FAIL agentes vazio: $n instalados, rc=$rc (esperado $N_AGENTS)"; head -5 /tmp/aa-out-empty
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 15. --status NÃO usa rede (não clona o catálogo) ----------
TH=/tmp/aa-h-nostatusclone; rm -rf "$TH"; mkdir -p "$TH"   # HOME SEM catálogo
HOME="$TH" bash "$INSTALLER" --lang en --status </dev/null >/tmp/aa-out-noclone 2>&1
rc=$?
if [[ $rc -eq 0 && ! -e "$TH/.agency-agents/.git" ]] && grep -qi "atalog not found\|nada foi baixado" /tmp/aa-out-noclone; then
  PASS=$((PASS+1)); echo "PASS --status sem catálogo: não clona, avisa, rc=0"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("status-no-net"); echo "FAIL --status clonou ou não avisou (rc=$rc)"; head -5 /tmp/aa-out-noclone | sed 's/^/    /'
fi
# regressão CI: --list DEPOIS de --status no mesmo HOME limpa — o config cria ~/.agency-agents/
# (sem .git/divisions.json) e --list não pode reportar catálogo falso {agents:0}
if HOME="$TH" bash "$INSTALLER" --list </dev/null 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["catalog"] is None, "config-only dir não é catálogo"' 2>/dev/null; then
  PASS=$((PASS+1)); echo "PASS --list após --status em HOME limpa: catalog=null (dir só com config)"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("list-config-dir"); echo "FAIL --list reportou catálogo falso"
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 16. --tool/--squad não-interativo (CI/scripts) ----------
TH=/tmp/aa-h-nonint; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --lang en --tool zcode --squad treino </dev/null >/tmp/aa-out-nonint 2>&1
rc=$?
n=$(ls "$TH/.zcode/agents/" 2>/dev/null | wc -l)
if [[ $rc -eq 0 && "$n" == "4" ]] && grep -q "Specialists installed in ZCode ✓ (4" /tmp/aa-out-nonint; then
  PASS=$((PASS+1)); echo "PASS --tool zcode --squad treino → exatamente 4, sem perguntas"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("tool-squad"); echo "FAIL --tool/--squad: n=$n rc=$rc"; head -5 /tmp/aa-out-nonint | sed 's/^/    /'
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 17. --dry-run não escreve NADA ----------
TH=/tmp/aa-h-dry; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --lang en --dry-run --tool claudeCode --squad treino </dev/null >/tmp/aa-out-dry 2>&1
rc=$?
if [[ $rc -eq 0 ]] && grep -qi "DRY-RUN" /tmp/aa-out-dry \
   && [[ ! -e "$TH/.claude" ]] && [[ ! -e "$TH/.agency-agents-backup" ]]; then
  PASS=$((PASS+1)); echo "PASS --dry-run: pré-visualiza e não toca em nada"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("dry-run"); echo "FAIL --dry-run escreveu algo (rc=$rc)"; head -5 /tmp/aa-out-dry | sed 's/^/    /'
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 18. --list imprime JSON válido (sem rede) ----------
TH=/tmp/aa-h-list; rm -rf "$TH"; mkdir -p "$TH"
if HOME="$TH" bash "$INSTALLER" --list </dev/null 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert len(d["tools"]) >= 13, "tools insuficientes"
assert any(t["id"] == "cursor" and t["projectOnly"] for t in d["tools"]), "cursor projectOnly"
assert d["squads"] and len(d["squads"]["treino"]["slugs"]) == 4, "squads"
assert d["catalog"] is None, "sem catálogo deve ser null"' 2>/tmp/aa-list-err; then
  PASS=$((PASS+1)); echo "PASS --list: JSON válido (13 tools, squads, projectOnly)"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("list-json"); echo "FAIL --list"; cat /tmp/aa-list-err | head -3
fi
rm -rf "$TH"

# ---------- 19. --uninstall remove só a agência (backup + arquivo próprio preservado) ----------
TH=/tmp/aa-h-uninstall; new_home "$TH"
cat > "$TH/plan2.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[{"slug":"code-reviewer","file":"engineering/engineering-code-reviewer.md"},{"slug":"reality-checker","file":"testing/testing-reality-checker.md"}]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan2.json" </dev/null >/dev/null 2>&1
echo "# meu agente próprio, não mexe" > "$TH/.zcode/agents/my-own-agent.md"
HOME="$TH" bash "$INSTALLER" --lang en --uninstall --tool zcode </dev/null >/tmp/aa-out-unin 2>&1
rc=$?
if [[ $rc -eq 0 ]] && [[ ! -e "$TH/.zcode/agents/code-reviewer.md" ]] && [[ -f "$TH/.zcode/agents/my-own-agent.md" ]] \
   && find "$TH/.agency-agents-backup" -type d -name "uninstall-*" | grep -q . ; then
  PASS=$((PASS+1)); echo "PASS --uninstall: removeu 2, preservou arquivo próprio, com backup"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("uninstall"); echo "FAIL --uninstall (rc=$rc)"; head -5 /tmp/aa-out-unin | sed 's/^/    /'
fi
rm -rf "$TH"

# ---------- 20. --dir instala por projeto (Cursor → .cursor/rules/*.mdc) ----------
TH=/tmp/aa-h-dir; new_home "$TH"; mkdir -p "$TH/meu-projeto"
HOME="$TH" bash "$INSTALLER" --lang en --tool cursor --dir "$TH/meu-projeto" --squad treino </dev/null >/tmp/aa-out-dir 2>&1
rc=$?
n=$(find "$TH/meu-projeto/.cursor/rules" -name "*.mdc" 2>/dev/null | wc -l)
if [[ $rc -eq 0 && "$n" == "4" && -f "$TH/meu-projeto/.cursor/rules/api-tester.mdc" ]]; then
  PASS=$((PASS+1)); echo "PASS --dir: 4 .mdc do Cursor dentro do projeto"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("dir-cursor"); echo "FAIL --dir cursor: n=$n rc=$rc"; head -5 /tmp/aa-out-dir | sed 's/^/    /'
fi
rm -rf "$TH"

# ---------- 21. --plan sem valor → busca automática (plano na raiz, rodando de instaladores/) ----------
ROG="/tmp/aa-autodet-$$"; TH=/tmp/aa-h-autodet
rm -rf "$ROG" "$TH"; mkdir -p "$ROG/instaladores"
cp "$INSTALLER" "$DRIVER" "$ROG/instaladores/"
cat > "$ROG/agency-plan.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[{"slug":"code-reviewer","file":"engineering/engineering-code-reviewer.md"},{"slug":"reality-checker","file":"testing/testing-reality-checker.md"}]}
EOF
new_home "$TH"
( cd "$ROG/instaladores" && HOME="$TH" bash ./instalar-linux.sh --plan </dev/null ) >/tmp/aa-out-autodet 2>&1
rc=$?
n=$(ls "$TH/.zcode/agents/" 2>/dev/null | wc -l)
if [[ $rc -eq 0 && "$n" == "2" ]] && grep -qi "automatically\|automaticamente" /tmp/aa-out-autodet; then
  PASS=$((PASS+1)); echo "PASS --plan sem valor: achou o plano um diretório acima e instalou 2"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("plan-autodetect"); echo "FAIL autodetecção: n=$n rc=$rc"; head -5 /tmp/aa-out-autodet | sed 's/^/    /'
fi
rm -rf "$ROG" "$TH"

# ---------- 22. idioma persistido em ~/.agency-agents/config + respeitado na 2ª execução ----------
TH=/tmp/aa-h-langsave; rm -rf "$TH"; mkdir -p "$TH"
HOME="$TH" bash "$INSTALLER" --lang pt --status </dev/null >/dev/null 2>&1
if grep -q "^lang=pt$" "$TH/.agency-agents/config" 2>/dev/null; then
  PASS=$((PASS+1)); echo "PASS --lang pt persistido em ~/.agency-agents/config"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("lang-persist"); echo "FAIL config de idioma não salvo"; fi
# 2ª execução SEM --lang usa o idioma salvo (não cai no locale nem pergunta)
if HOME="$TH" bash "$INSTALLER" --status --json </dev/null 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["lang"] == "pt", "esperado lang=pt"' 2>/dev/null; then
  PASS=$((PASS+1)); echo "PASS idioma salvo é respeitado na 2ª execução (--status --json lang=pt)"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("lang-reuse"); echo "FAIL 2ª execução não usou o idioma salvo"; fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 23. --status --json: JSON puro no stdout, nenhum arquivo escrito ----------
ROG="/tmp/aa-json-$$"; TH=/tmp/aa-h-json
rm -rf "$ROG" "$TH"; mkdir -p "$ROG/instaladores"
cp "$INSTALLER" "$DRIVER" "$ROG/instaladores/"
echo "<html>guia fake</html>" > "$ROG/guia-especialistas-agencia.html"
rm -rf "$TH"; mkdir -p "$TH"   # sem catálogo: catalog=null no JSON
if ( cd "$ROG" && HOME="$TH" bash instaladores/instalar-linux.sh --status --json </dev/null 2>/dev/null ) >/tmp/aa-out-json 2>/dev/null \
   && python3 -c '
import json
d = json.load(open("/tmp/aa-out-json"))
assert d["lang"] == "en" and isinstance(d["tools"], list) and len(d["tools"]) >= 13
assert d["catalog"] is None, "sem catálogo deve ser null"' 2>/tmp/aa-json-err \
   && [[ ! -e "$ROG/guia-status.js" ]]; then
  PASS=$((PASS+1)); echo "PASS --status --json: stdout JSON válido, nada escrito"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("status-json"); echo "FAIL --status --json"; head -3 /tmp/aa-out-json 2>/dev/null; cat /tmp/aa-json-err 2>/dev/null | head -2
fi
rm -rf "$ROG" "$TH"

# ---------- 24. --dry-run --uninstall NÃO remove nada (contrato do dry-run) ----------
TH=/tmp/aa-h-dryunin; new_home "$TH"
cat > "$TH/plan2.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[{"slug":"code-reviewer","file":"engineering/engineering-code-reviewer.md"},{"slug":"reality-checker","file":"testing/testing-reality-checker.md"}]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan2.json" </dev/null >/dev/null 2>&1
HOME="$TH" bash "$INSTALLER" --lang en --dry-run --uninstall --tool zcode </dev/null >/tmp/aa-out-dryunin 2>&1
rc=$?
if [[ $rc -eq 0 ]] && grep -qi "would remove\|removeria" /tmp/aa-out-dryunin \
   && [[ -f "$TH/.zcode/agents/code-reviewer.md" ]] && [[ -f "$TH/.zcode/agents/reality-checker.md" ]] \
   && ! find "$TH/.agency-agents-backup" -type d -name "uninstall-*" 2>/dev/null | grep -q .; then
  PASS=$((PASS+1)); echo "PASS --dry-run --uninstall: pré-visualiza e NÃO remove nada"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("dry-run-uninstall"); echo "FAIL --dry-run --uninstall removeu arquivos (rc=$rc)"; head -5 /tmp/aa-out-dryunin | sed 's/^/    /'
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 25. roster (Aider) via --dir + uninstall honesto do roster ----------
TH=/tmp/aa-h-roster; new_home "$TH"; mkdir -p "$TH/proj"
HOME="$TH" bash "$INSTALLER" --lang en --tool aider --dir "$TH/proj" --squad treino </dev/null >/tmp/aa-out-roster 2>&1
rc=$?
if [[ $rc -eq 0 && -f "$TH/proj/CONVENTIONS.md" ]] && grep -q "Roster updated: Aider" /tmp/aa-out-roster; then
  PASS=$((PASS+1)); echo "PASS roster Aider em --dir: CONVENTIONS.md gerado"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("roster-aider"); echo "FAIL roster aider (rc=$rc)"; head -5 /tmp/aa-out-roster | sed 's/^/    /'
fi
HOME="$TH" bash "$INSTALLER" --lang en --uninstall --tool aider --dir "$TH/proj" </dev/null >/tmp/aa-out-roster-un 2>&1
if [[ -f "$TH/proj/CONVENTIONS.md" ]] && grep -qi "not removed automatically\|não é removido automaticamente" /tmp/aa-out-roster-un; then
  PASS=$((PASS+1)); echo "PASS uninstall de roster: avisa e preserva o arquivo"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("roster-uninstall"); echo "FAIL uninstall de roster deveria avisar e preservar"; head -5 /tmp/aa-out-roster-un
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 26. MÁQUINA LIMPA: instalação com --lang clona e preserva o config ----------
# regressão v2.2.0/2.2.1: save_lang criava ~/.agency-agents (com config) ANTES do clone
# e `git clone` em diretório não-vazio falhava — a primeira instalação real quebrava.
TH=/tmp/aa-h-fresh; rm -rf "$TH"; mkdir -p "$TH"   # HOME sem catálogo, sem nada
HOME="$TH" bash "$INSTALLER" --lang pt --tool zcode --squad treino </dev/null >/tmp/aa-out-fresh 2>&1
rc=$?
n=$(ls "$TH/.zcode/agents/" 2>/dev/null | wc -l)
if [[ $rc -eq 0 && "$n" == "4" ]] && [[ -d "$TH/.agency-agents/.git" ]] \
   && grep -q "^lang=pt$" "$TH/.agency-agents/config" 2>/dev/null \
   && grep -q "Especialistas instalados em ZCode" /tmp/aa-out-fresh; then
  PASS=$((PASS+1)); echo "PASS máquina limpa: clone mesclado com config de idioma, instalação OK"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("fresh-machine"); echo "FAIL máquina limpa (rc=$rc, n=$n)"; head -8 /tmp/aa-out-fresh | sed 's/^/    /'
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 27. REJECTED: squad inválida em modo não-interativo ----------
TH=/tmp/aa-h-sqbad; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --lang en --tool zcode --squad xyz </dev/null >/tmp/aa-out-sqbad 2>&1; rc=$?
if [[ $rc -ne 0 ]] && grep -qi "Invalid squad\|Squad inválida\|Ungültiges Team\|Escouade invalide" /tmp/aa-out-sqbad; then
  PASS=$((PASS+1)); echo "PASS --squad xyz → err_squad, rc!=0"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("squad-invalid"); echo "FAIL squad inválida deveria rejeitar (rc=$rc)"; head -5 /tmp/aa-out-sqbad | sed 's/^/    /'
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 28. REJECTED/warn: --tool desconhecida, mistura válida+inválida, catalog-supported não integrada ----------
TH=/tmp/aa-h-toolbad; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --lang en --tool foo </dev/null >/tmp/aa-out-toolbad 2>&1; rc=$?
[[ $rc -ne 0 ]] && grep -qi "Unknown tool\|desconhecida\|unbekanntes Tool\|outil inconnu" /tmp/aa-out-toolbad \
  && { PASS=$((PASS+1)); echo "PASS --tool foo → tool_unknown, rc!=0"; } \
  || { FAIL=$((FAIL+1)); FAILED_NAMES+=("tool-unknown"); echo "FAIL --tool foo (rc=$rc)"; head -5 /tmp/aa-out-toolbad | sed 's/^/    /'; }
HOME="$TH" bash "$INSTALLER" --lang en --tool zcode,foo --squad treino </dev/null >/tmp/aa-out-mix 2>&1; rc=$?
n=$(ls "$TH/.zcode/agents/" 2>/dev/null | wc -l)
[[ $rc -eq 0 && "$n" == "4" ]] && grep -qi "Unknown tool\|desconhecida" /tmp/aa-out-mix \
  && { PASS=$((PASS+1)); echo "PASS --tool zcode,foo → instala zcode (4) e avisa foo, rc=0"; } \
  || { FAIL=$((FAIL+1)); FAILED_NAMES+=("tool-mixed"); echo "FAIL mistura válida+inválida (rc=$rc, n=$n)"; head -5 /tmp/aa-out-mix | sed 's/^/    /'; }
HOME="$TH" bash "$INSTALLER" --lang en --tool vibe </dev/null >/tmp/aa-out-vibe 2>&1; rc=$?
[[ $rc -eq 0 ]] && grep -qi "not supported\|não suportada\|no soportada" /tmp/aa-out-vibe \
  && { PASS=$((PASS+1)); echo "PASS --tool vibe → unsupported com aviso honesto, rc=0"; } \
  || { FAIL=$((FAIL+1)); FAILED_NAMES+=("tool-vibe"); echo "FAIL vibe (rc=$rc)"; head -5 /tmp/aa-out-vibe | sed 's/^/    /'; }
rm -rf "$TH"; clean_repo_side_effects

# ---------- 29. REJECTED: --dir inexistente / arquivo no lugar de pasta ----------
TH=/tmp/aa-h-dirbad; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --lang en --tool cursor --dir "$TH/não-existe" --squad pre </dev/null >/tmp/aa-out-dirbad 2>&1; rc=$?
[[ $rc -ne 0 ]] && grep -qi "not found\|não encontrado\|no encontrado\|introuvable" /tmp/aa-out-dirbad \
  && { PASS=$((PASS+1)); echo "PASS --dir inexistente → err_dir, rc!=0"; } \
  || { FAIL=$((FAIL+1)); FAILED_NAMES+=("dir-bad"); echo "FAIL --dir inválido (rc=$rc)"; head -5 /tmp/aa-out-dirbad | sed 's/^/    /'; }
echo x > "$TH/um-arquivo.txt"
HOME="$TH" bash "$INSTALLER" --lang en --tool cursor --dir "$TH/um-arquivo.txt" --squad pre </dev/null >/dev/null 2>&1; rc=$?
[[ $rc -ne 0 ]] && { PASS=$((PASS+1)); echo "PASS --dir apontando para ARQUIVO → rc!=0"; } \
  || { FAIL=$((FAIL+1)); FAILED_NAMES+=("dir-file"); echo "FAIL --dir=arquivo aceito (rc=$rc)"; }
rm -rf "$TH"; clean_repo_side_effects

# ---------- 30. REJECTED: planos malformados além dos clássicos ----------
TH=/tmp/aa-h-malformed; new_home "$TH"
try_plan() { # try_plan <nome> <json> <espera rc!=0>
  local name="$1" json="$2"
  printf '%s' "$json" > "$TH/p.json"
  HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/p.json" --status </dev/null >/dev/null 2>&1
  local rc=$?
  [[ $rc -ne 0 ]] && { PASS=$((PASS+1)); echo "PASS plano $name → rejected"; } \
    || { FAIL=$((FAIL+1)); FAILED_NAMES+=("plan-$name"); echo "FAIL plano $name foi ACEITO (rc=0)"; }
}
try_plan "raiz-lista"      '[1,2,3]'
try_plan "ferramentas-str" '{"ferramentas":"zcode","agentes":[]}'
try_plan "agentes-dict"    '{"ferramentas":["zcode"],"agentes":{"slug":"x","file":"a/b.md"}}'
try_plan "file-abs-win"    '{"ferramentas":["claudeCode"],"agentes":[{"slug":"x","file":"C:\\etc\\passwd"}]}'
try_plan "slug-backslash"  '{"ferramentas":["zcode"],"agentes":[{"slug":"a\\b","file":"a/b.md"}]}'
try_plan "slug-vazio"      '{"ferramentas":["zcode"],"agentes":[{"slug":"","file":"a/b.md"}]}'
rm -rf "$TH"; clean_repo_side_effects

# ---------- 31. config de idioma: BOM do PowerShell respeitado; config corrompida cai no fallback ----------
TH=/tmp/aa-h-cfg; rm -rf "$TH"; mkdir -p "$TH/.agency-agents"
printf '\xef\xbb\xbflang=pt\n' > "$TH/.agency-agents/config"   # BOM como o PS 5.1 grava
if HOME="$TH" bash "$INSTALLER" --status --json </dev/null 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["lang"] == "pt", "esperado pt com BOM"' 2>/dev/null; then
  PASS=$((PASS+1)); echo "PASS config com BOM → lang=pt respeitado"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("cfg-bom"); echo "FAIL config com BOM ignorada"
fi
echo "lang=zz" > "$TH/.agency-agents/config"
if HOME="$TH" bash "$INSTALLER" --status --json </dev/null 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["lang"] == "en", "corrompida deve cair no fallback"' 2>/dev/null; then
  PASS=$((PASS+1)); echo "PASS config corrompida (lang=zz) → fallback en"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("cfg-bad"); echo "FAIL config corrompida não caiu no fallback"
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 32. catálogo "clone sem .git" (divisions.json presente) → instalação funciona ----------
TH=/tmp/aa-h-nogit; rm -rf "$TH"; mkdir -p "$TH"
cp -r "$TESTCAT" "$TH/.agency-agents" && rm -rf "$TH/.agency-agents/.git"
HOME="$TH" bash "$INSTALLER" --lang en --tool zcode --squad treino </dev/null >/tmp/aa-out-nogit 2>&1; rc=$?
n=$(ls "$TH/.zcode/agents/" 2>/dev/null | wc -l)
[[ $rc -eq 0 && "$n" == "4" ]] && { PASS=$((PASS+1)); echo "PASS catálogo sem .git (divisions.json) → 4 instalados"; } \
  || { FAIL=$((FAIL+1)); FAILED_NAMES+=("catalog-nogit"); echo "FAIL catálogo sem .git (rc=$rc, n=$n)"; head -5 /tmp/aa-out-nogit | sed 's/^/    /'; }
rm -rf "$TH"; clean_repo_side_effects

# ---------- 33. FIX B2 (RED esperado): roster instalado → painel conta 1 ----------
TH=/tmp/aa-h-roster2; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --lang en --tool windsurf --squad treino </dev/null >/dev/null 2>&1
if HOME="$TH" bash "$INSTALLER" --status --json </dev/null 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
w = [t for t in d["tools"] if t["id"] == "windsurf"][0]
assert w["agentCount"] == 1, f"windsurf agentCount={w[chr(97)+chr(103)+chr(101)+chr(110)+chr(116)+chr(67)+chr(111)+chr(117)+chr(110)+chr(116)]} (esperado 1)"' 2>/dev/null; then
  PASS=$((PASS+1)); echo "PASS roster no painel: windsurf agentCount=1"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("roster-count"); echo "FAIL roster windsurf agentCount!=1 (bug B2 — fix pendente)"
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 34. FIX B3 (RED esperado): --uninstall --plan remove SÓ os slugs do plano ----------
TH=/tmp/aa-h-unplan; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --lang en --tool zcode --squad treino </dev/null >/dev/null 2>&1   # 4 instalados
cat > "$TH/plano-u.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[{"slug":"code-reviewer","file":"engineering/engineering-code-reviewer.md"}]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --uninstall --plan "$TH/plano-u.json" </dev/null >/dev/null 2>&1; rc=$?
restaram=$(ls "$TH/.zcode/agents/" 2>/dev/null | wc -l)
if [[ $rc -eq 0 && "$restaram" == "3" && ! -f "$TH/.zcode/agents/code-reviewer.md" && -f "$TH/.zcode/agents/reality-checker.md" ]]; then
  PASS=$((PASS+1)); echo "PASS uninstall por plano: removeu 1 do plano, preservou os outros 3"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("uninstall-plan"); echo "FAIL uninstall --plan removeu a ferramenta inteira ($restaram restaram) — bug B3"
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 35. FIX B13 (RED esperado): --dry-run NÃO persiste o idioma ----------
TH=/tmp/aa-h-drylang; new_home "$TH"   # catálogo presente, SEM config
HOME="$TH" bash "$INSTALLER" --lang pt --dry-run --tool zcode --squad treino </dev/null >/dev/null 2>&1; rc=$?
if [[ $rc -eq 0 && ! -e "$TH/.agency-agents/config" ]]; then
  PASS=$((PASS+1)); echo "PASS dry-run: config de idioma não escrito"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("dry-lang"); echo "FAIL dry-run persistiu o idioma — bug B13"
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 36. FIX B4 (RED esperado): project_only sem --dir → aviso explícito ----------
TH=/tmp/aa-h-ponote; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --lang pt --tool cursor --squad treino </dev/null >/tmp/aa-out-ponote 2>&1; rc=$?
n=$(find "$TH/.cursor/rules" -name "*.mdc" 2>/dev/null | wc -l)
if [[ $rc -eq 0 && "$n" == "4" ]] && grep -qi "por projeto\|per-project\|por proyecto\|par projet\|pro projekt" /tmp/aa-out-ponote; then
  PASS=$((PASS+1)); echo "PASS cursor sem --dir: instala em HOME mas avisa que é por projeto"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("project-only-note"); echo "FAIL cursor sem --dir silencioso (n=$n) — bug B4"
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 37. FIX B1 (RED esperado): symlink escapando do catálogo → aviso i18n, não EN ----------
TH=/tmp/aa-h-symlink; new_home "$TH"
ln -s /etc/passwd "$TH/.agency-agents/engineering/aa-evil.md" 2>/dev/null
cat > "$TH/p-sym.json" <<'EOF'
{"ferramentas":["claudeCode"],"agentes":[{"slug":"aa-evil","file":"engineering/aa-evil.md"},{"slug":"code-reviewer","file":"engineering/engineering-code-reviewer.md"}]}
EOF
HOME="$TH" bash "$INSTALLER" --lang pt --plan "$TH/p-sym.json" </dev/null >/tmp/aa-out-sym 2>&1; rc=$?
# identity copia o NOME OFICIAL do arquivo (engineering-code-reviewer.md), não o slug
if [[ $rc -eq 0 ]] && grep -qi "caminho inseguro\|inseguro ignorado" /tmp/aa-out-sym \
   && [[ ! -f "$TH/.claude/agents/aa-evil.md" ]] && [[ -f "$TH/.claude/agents/engineering-code-reviewer.md" ]]; then
  PASS=$((PASS+1)); echo "PASS symlink escape → aviso i18n (pt), skip, instala o resto"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("symlink-escape"); echo "FAIL symlink (rc=$rc) — aviso EN hard-coded (bug B1) ou escape"; head -5 /tmp/aa-out-sym | sed 's/^/    /'
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- 38. FIX B16 (condicional): sem opener no PATH → não anuncia "Opening" ----------
if ! command -v xdg-open >/dev/null 2>&1 && ! command -v open >/dev/null 2>&1 && ! command -v osascript >/dev/null 2>&1; then
  TH=/tmp/aa-h-noopen; new_home "$TH"
  HOME="$TH" bash "$INSTALLER" --lang en --status </dev/null >/tmp/aa-out-noopen 2>&1
  grep -qi "Opening the guide" /tmp/aa-out-noopen \
    && { FAIL=$((FAIL+1)); FAILED_NAMES+=("opening-noopener"); echo "FAIL anunciou Opening sem opener — bug B16"; } \
    || { PASS=$((PASS+1)); echo "PASS sem opener: não anuncia Opening"; }
  rm -rf "$TH"; clean_repo_side_effects
else
  echo "SKIP 38 (opener presente neste host — branch testado só em CI sem desktop)"
fi

# ---------- 39. backup idempotente: reinstalar sem modificar NÃO cria backup novo ----------
TH=/tmp/aa-h-bkp0; new_home "$TH"
cat > "$TH/p.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[{"slug":"code-reviewer","file":"engineering/engineering-code-reviewer.md"}]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/p.json" </dev/null >/dev/null 2>&1
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/p.json" </dev/null >/dev/null 2>&1
n_bkp=$(find "$TH/.agency-agents-backup" -type f 2>/dev/null | wc -l)
[[ "$n_bkp" == "0" ]] && { PASS=$((PASS+1)); echo "PASS reinstalação idêntica → 0 backups (skip por conteúdo igual)"; } \
  || { FAIL=$((FAIL+1)); FAILED_NAMES+=("backup-identical"); echo "FAIL reinstalação idêntica criou $n_bkp backup(s)"; }
rm -rf "$TH"; clean_repo_side_effects

# ---------- 40. REJECTED: --uninstall sem --tool/sem plano e sem TTY ----------
TH=/tmp/aa-h-unnoty; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --lang en --uninstall </dev/null >/dev/null 2>&1; rc=$?
[[ $rc -ne 0 ]] && { PASS=$((PASS+1)); echo "PASS --uninstall sem seleção e sem TTY → err, rc!=0"; } \
  || { FAIL=$((FAIL+1)); FAILED_NAMES+=("uninstall-notty"); echo "FAIL --uninstall sem seleção seguiu (rc=0)"; }
rm -rf "$TH"; clean_repo_side_effects

# ---------- 41. guia ausente ao lado do instalador → aviso honesto, rc=0 ----------
ROG="/tmp/aa-noguia-$$"; TH=/tmp/aa-h-noguia
rm -rf "$ROG" "$TH"; mkdir -p "$ROG/instaladores"
cp "$INSTALLER" "$DRIVER" "$ROG/instaladores/"   # SEM guia no diretório pai
new_home "$TH"
( cd "$ROG" && HOME="$TH" bash instaladores/instalar-linux.sh --lang en --status </dev/null ) >/tmp/aa-out-noguia 2>&1; rc=$?
if [[ $rc -eq 0 ]] && grep -qi "not found next to the installer\|não encontrado junto" /tmp/aa-out-noguia; then
  PASS=$((PASS+1)); echo "PASS sem guia: aviso guia_not_found, rc=0"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("no-guide"); echo "FAIL sem guia (rc=$rc)"; head -5 /tmp/aa-out-noguia | sed 's/^/    /'
fi
rm -rf "$ROG" "$TH"; clean_repo_side_effects

# ---------- limpeza ----------
rm -rf "$TESTCAT" /tmp/aa-out-* /tmp/aa-badplan.json /tmp/aa-trav.json /tmp/aa-h-* /tmp/aa-list-err /tmp/aa-json-err 2>/dev/null || true
clean_repo_side_effects

echo
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then echo "FALHARAM: ${FAILED_NAMES[*]}"; exit 1; fi
echo "SUÍTE VERDE"
