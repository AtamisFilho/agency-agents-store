#!/usr/bin/env bash
# ============================================================================
# run-tests.sh — suíte adversarial do instalador Linux/macOS
# Exercita branches REJECTED: planos maliciosos, idiomas inválidos, TTY
# ausente, ferramentas incompatíveis, HOME com espaço, backup, modo pasta.
# ============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
INSTALLER="$REPO/instaladores/instalar-linux.sh"
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
clean_repo_side_effects() { rm -f "$REPO/guia-status.js"; }

# ---------- catálogo compartilhado (clone único, hardlinks nos testes) ----------
rm -rf "$TESTCAT"
git clone --depth 1 -q https://github.com/msitarzewski/agency-agents.git "$TESTCAT" || { echo "FATAL: clone catálogo"; exit 1; }
clean_repo_side_effects

# ---------- 1. sintaxe ----------
t "bash -n no instalador" ok bash -n "$INSTALLER"
t "py_compile no build.py" ok python3 -m py_compile "$REPO/gerador/build.py"

# ---------- 2. idioma inválido → rejected ----------
TH=/tmp/aa-h-lang; new_home "$TH"
out=$(HOME="$TH" bash "$INSTALLER" --lang xx --status 2>&1) || true
if echo "$out" | grep -qi "invalid language\|idioma inválido\|Ungültige\|Langue invalide"; then PASS=$((PASS+1)); echo "PASS --lang inválido mostra erro"; else FAIL=$((FAIL+1)); FAILED_NAMES+=("--lang msg"); echo "FAIL --lang msg"; echo "$out" | head -3 | sed 's/^/    /'; fi
rm -rf "$TH"

# ---------- 3. plano inexistente → rejected ----------
TH=/tmp/aa-h-plan404; new_home "$TH"
HOME="$TH" bash "$INSTALLER" --plan /tmp/aa-inexistente-$$ --status >/tmp/aa-out-plan404 2>&1
assert_out "--plan inexistente → err" "not found\|não encontrado\|no encontrado\|introuvable\|nicht gefunden" /tmp/aa-out-plan404
rm -rf "$TH"

# ---------- 4. plano JSON inválido → rejected ----------
TH=/tmp/aa-h-badplan; new_home "$TH"
echo "{isto não é json" > /tmp/aa-badplan.json
HOME="$TH" bash "$INSTALLER" --plan /tmp/aa-badplan.json --status >/tmp/aa-out-badplan 2>&1
assert_out "plano JSON inválido → err" "Invalid plan\|inválido\|inválido\|invalide\|Ungültige" /tmp/aa-out-badplan
rm -rf "$TH"

# ---------- 5. plano com path traversal → rejected ----------
TH=/tmp/aa-h-trav; new_home "$TH"
cat > /tmp/aa-trav.json <<'EOF'
{"ferramentas":["claudeCode"],"agentes":[{"slug":"x","file":"../../../../etc/passwd"}]}
EOF
HOME="$TH" bash "$INSTALLER" --plan /tmp/aa-trav.json --status >/tmp/aa-out-trav 2>&1
assert_out "path traversal no plano → recusado" "Invalid plan\|inválido\|Ungültige\|invalide" /tmp/aa-out-trav
[[ -f "$TH/claude/agents/passwd" || -f "$TH/.claude/agents/passwd" ]] && { FAIL=$((FAIL+1)); echo "FAIL traversal ESCAPOU"; } || { PASS=$((PASS+1)); echo "PASS traversal não escapou"; }
rm -rf "$TH"

# ---------- 6. interativo sem TTY → rejected limpo (não trava) ----------
TH=/tmp/aa-h-notty; new_home "$TH"
timeout 10 env HOME="$TH" bash "$INSTALLER" </dev/null >/tmp/aa-out-notty 2>&1
rc=$?
if [[ $rc -ne 0 ]] && grep -qi "terminal\|--plan" /tmp/aa-out-notty; then PASS=$((PASS+1)); echo "PASS sem TTY → erro orientado (rc=$rc)"
elif [[ $rc -eq 124 ]]; then FAIL=$((FAIL+1)); FAILED_NAMES+=("notty-travou"); echo "FAIL sem TTY TRAVOU (timeout)"
else PASS=$((PASS+1)); echo "PASS sem TTY termina sem travar (rc=$rc)"; fi
rm -rf "$TH"

# ---------- 7. instalação real: squad treino em zcode (plano válido) ----------
TH="/tmp/aa h space"; new_home "$TH"   # HOME com ESPAÇO no nome
cat > "$TH/plan.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[{"slug":"code-reviewer","file":"engineering/engineering-code-reviewer.md"},{"slug":"reality-checker","file":"testing/testing-reality-checker.md"}]}
EOF
HOME="$TH" bash "$INSTALLER" --lang pt --plan "$TH/plan.json" >/tmp/aa-out-real 2>&1
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
HOME="$TH" bash "$INSTALLER" --lang pt --plan "$TH/plan.json" >/dev/null 2>&1
n_backup=$(find "$TH/.agency-agents-backup" -name "*.md" 2>/dev/null | wc -l)
[[ "$n_backup" -ge 1 ]] && { PASS=$((PASS+1)); echo "PASS backup criado na 2ª instalação ($n_backup arq.)"; } || { FAIL=$((FAIL+1)); echo "FAIL backup ausente"; }
# conteúdo restaurado (a 2ª instalação sobrescreve com o original)
grep -q "modificado" "$TH/.zcode/agents/code-reviewer.md" && { FAIL=$((FAIL+1)); echo "FAIL sobrescrita não restaurou"; } || { PASS=$((PASS+1)); echo "PASS sobrescrita restaurou o original"; }
rm -rf "$TH"; clean_repo_side_effects

# ---------- 8. identity "all" inclui subpastas de divisões ----------
TH=/tmp/aa-h-all; new_home "$TH"
cat > "$TH/plan-all.json" <<'EOF'
{"ferramentas":["claudeCode"],"agentes":[]}
EOF
# truque: "all" usa o caminho próprio; usamos ferramenta claudeCode + all via env do SLUGS_FILE? não exposto.
# alternativa: validar direto o find que o instalador usa
n_catalog=$(find "$TH/.agency-agents" -type f -name "*.md" \
  \( -path "*/academic/*" -o -path "*/design/*" -o -path "*/engineering/*" -o -path "*/finance/*" \
     -o -path "*/game-development/*" -o -path "*/gis/*" -o -path "*/healthcare/*" -o -path "*/marketing/*" \
     -o -path "*/paid-media/*" -o -path "*/product/*" -o -path "*/project-management/*" -o -path "*/research/*" \
     -o -path "*/sales/*" -o -path "*/security/*" -o -path "*/spatial-computing/*" -o -path "*/specialized/*" \
     -o -path "*/support/*" -o -path "*/testing/*" \) \
  ! -iname "readme*" ! -iname "contributing*" ! -iname "*worklog*" | wc -l)
[[ "$n_catalog" -eq 283 ]] && { PASS=$((PASS+1)); echo "PASS find all = 283 (inclui subpastas godot/unity/unreal/roblox)"; } || { FAIL=$((FAIL+1)); FAILED_NAMES+=("all-283"); echo "FAIL find all = $n_catalog (esperado 283)"; }
rm -rf "$TH"

# ---------- 9. modo pasta (antigravity) → SKILL.md no destino ----------
TH=/tmp/aa-h-agv; new_home "$TH"
cat > "$TH/plan-agv.json" <<'EOF'
{"ferramentas":["antigravity"],"agentes":[]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-agv.json" >/tmp/aa-out-agv 2>&1
# antigravity render → pasta por slug com SKILL.md; usa convert (pode falhar se convert não suportar) — valida contagem > 0 OU aviso honesto
if grep -q "Specialists installed in Antigravity" /tmp/aa-out-agv; then
  n=$(find "$TH/.gemini/config/skills" -name "SKILL.md" 2>/dev/null | wc -l)
  [[ "$n" -ge 1 ]] && { PASS=$((PASS+1)); echo "PASS antigravity modo pasta: $n SKILL.md"; } || { FAIL=$((FAIL+1)); echo "FAIL antigravity: ✓ mas 0 SKILL.md"; }
elif grep -q "render antigravity" /tmp/aa-out-agv || grep -qi "warn" /tmp/aa-out-agv; then
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
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-unsup.json" >/tmp/aa-out-unsup 2>&1
rc=$?
if [[ $rc -eq 0 ]] && grep -qi "not supported" /tmp/aa-out-unsup; then PASS=$((PASS+1)); echo "PASS hermes → aviso unsupported, rc=0"
else FAIL=$((FAIL+1)); echo "FAIL hermes (rc=$rc)"; fi
rm -rf "$TH"

# ---------- 11. ferramenta incompatível com o SO no plano → recusada ----------
TH=/tmp/aa-h-incomp; new_home "$TH"
cat > "$TH/plan-osaurus.json" <<'EOF'
{"ferramentas":["osaurus"],"agentes":[]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-osaurus.json" >/tmp/aa-out-osaurus 2>&1
# osaurus é macOS-only: no linux deve recusar com aviso (após fix) — teste documenta o comportamento esperado
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
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-noslug.json" >/tmp/aa-out-noslug 2>&1
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
cp "$INSTALLER" "$ROG/instaladores/"
echo "<html>guia fake</html>" > "$ROG/guia-especialistas-agencia.html"
chmod 555 "$ROG"
new_home "$TH"
HOME="$TH" bash "$ROG/instaladores/instalar-linux.sh" --lang en --status >/tmp/aa-out-ro 2>&1
rc=$?
chmod 755 "$ROG"   # permite a limpeza
if [[ $rc -eq 0 ]] && grep -q "Done!" /tmp/aa-out-ro && ! grep -q "Guide panel updated" /tmp/aa-out-ro; then
  PASS=$((PASS+1)); echo "PASS escrita do status falha → aviso, resumo impresso, rc=0"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("status-ro"); echo "FAIL status read-only (rc=$rc) — crash ou sucesso falso"; head -8 /tmp/aa-out-ro
fi
rm -rf "$ROG" "$TH"; clean_repo_side_effects

# ---------- 14. agentes vazio = instalar TODOS (semântica única nas duas famílias) ----------
TH=/tmp/aa-h-empty; new_home "$TH"
cat > "$TH/plan-empty.json" <<'EOF'
{"ferramentas":["zcode"],"agentes":[]}
EOF
HOME="$TH" bash "$INSTALLER" --lang en --plan "$TH/plan-empty.json" >/tmp/aa-out-empty 2>&1
rc=$?
n=$(find "$TH/.zcode/agents" -type f -name "*.md" 2>/dev/null | wc -l)
if [[ $rc -eq 0 && "$n" -eq 283 ]]; then
  PASS=$((PASS+1)); echo "PASS agentes vazio = todos (283 no destino)"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("empty=all"); echo "FAIL agentes vazio: $n instalados, rc=$rc (esperado 283)"; head -5 /tmp/aa-out-empty
fi
rm -rf "$TH"; clean_repo_side_effects

# ---------- limpeza ----------
rm -rf "$TESTCAT" /tmp/aa-out-* /tmp/aa-badplan.json /tmp/aa-trav.json /tmp/aa-h-* 2>/dev/null || true
clean_repo_side_effects

echo
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then echo "FALHARAM: ${FAILED_NAMES[*]}"; exit 1; fi
echo "SUÍTE VERDE"
