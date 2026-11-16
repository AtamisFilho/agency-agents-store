#!/usr/bin/env python3
"""Testes do guia gerado (estáticos): payload, i18n, XSS, paridade.

As expectativas são DERIVADAS de dados/ (agents.json, squads.json, meta.json,
i18n.json) — nenhum número mágico: quando o catálogo crescer, a suíte continua
verde desde que o build regenere o guia.
"""
import json, re, sys, pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent
HTML = REPO / "guia-especialistas-agencia.html"
fails = []

def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + (f" — {detail}" if detail and not cond else ""))
    if not cond: fails.append(name)

# ---------- expectativas derivadas dos dados ----------
agents = json.loads((REPO / "dados" / "agents.json").read_text(encoding="utf-8"))
squads = json.loads((REPO / "dados" / "squads.json").read_text(encoding="utf-8"))
meta = json.loads((REPO / "dados" / "meta.json").read_text(encoding="utf-8"))
i18n_data = json.loads((REPO / "dados" / "i18n.json").read_text(encoding="utf-8"))
N_AGENTS = len(agents)
N_DIVS = len(meta["divisions"])
N_TOOLS = meta["expectedTools"]
VERSION = meta["version"]
SLUGS = {a["slug"] for a in agents}
WHEN_CUSTOM = len(i18n_data["pt"]["when"]["custom"])

h = HTML.read_text(encoding="utf-8")

# 1. placeholders não vazaram
check("sem placeholders __PAYLOAD__/__UI__", "__PAYLOAD__" not in h and "__UI__" not in h)

# 2. XSS: nenhum </script> literal dentro do payload/UI embutidos
seg_data = h.split("const DATA = ", 1)[1].split(";\nconst UI", 1)[0]
seg_ui = h.split("const UI = ", 1)[1].split(";\nconst VER", 1)[0]
check("payload sem </script> literal (XSS guard)", "</script" not in seg_data.lower())
check("UI sem </script> literal (XSS guard)", "</script" not in seg_ui.lower())

# 3. JSON válido e completo (contagens dinâmicas)
d = json.loads(seg_data)
ui = json.loads(seg_ui)
check(f"{N_AGENTS} agentes no payload (= agents.json)", len(d["agents"]) == N_AGENTS)
check(f"{N_DIVS} divisões (= meta.json)", len(d["divisions"]) == N_DIVS)
check(f"{N_TOOLS} tools (= meta.expectedTools)", len(d["tools"]) == N_TOOLS)
check(f"versão {VERSION} (= meta.json)", d["version"] == VERSION)
check("repo correto", d["ourRepo"] == meta["ourRepo"])

# 4. i18n: 5 idiomas × N agentes × (desc + 4 exemplos) + when
for lang in ["en","pt","es","fr","de"]:
    v = d["i18n"][lang]
    check(f"i18n {lang}: {N_AGENTS} agentes", len(v["agents"]) == N_AGENTS)
    bad = [s for s, x in v["agents"].items() if len(x.get("x", [])) != 4 or not x.get("d")]
    check(f"i18n {lang}: 4 exemplos por agente", not bad, str(bad[:3]))
    check(f"i18n {lang}: when {N_DIVS}+{WHEN_CUSTOM}", len(v["when"]["div"]) == N_DIVS and len(v["when"]["custom"]) == WHEN_CUSTOM)

# 5. paridade de chaves da UI nos 5 idiomas
base = set(ui["en"].keys())
for lang in ui:
    check(f"UI paridade {lang}", set(ui[lang].keys()) == base,
          str(base ^ set(ui.get(lang, {}).keys()))[:120])
# sem chave vazia
for lang in ui:
    empty = [k for k, v in ui[lang].items() if not str(v).strip()]
    check(f"UI {lang} sem strings vazias", not empty, str(empty))

# 6. divLabels e descs de tools nos 5 idiomas
for lang in ["en","pt","es","fr","de"]:
    check(f"divLabels {lang} = {N_DIVS}", len(d["divLabels"][lang]) == N_DIVS)
    missing = [t["id"] for t in d["tools"] if lang not in t["descs"]]
    check(f"tool descs {lang} completas", not missing, str(missing))

# 7. todo agente do payload existe em TODOS os idiomas (cross-check)
for lang in ["en","pt","es","fr","de"]:
    miss = [a["slug"] for a in d["agents"] if a["slug"] not in d["i18n"][lang]["agents"]]
    check(f"cross-check agentes↔i18n {lang}", not miss, str(miss[:3]))

# 8. squads coerentes (tamanhos derivados de squads.json)
for k, v in squads.items():
    check(f"squad {k} = {len(v['agentes'])} (= squads.json)",
          len(d["squads"][k]["slugs"]) == len(v["agentes"]))
    check(f"squad {k} ⊂ catálogo", set(d["squads"][k]["slugs"]) <= SLUGS)

# 9. sem marcadores de conflito de merge no HTML
check("sem marcadores de conflito", "<<<<<<<" not in h and ">>>>>>>" not in h)

# 9b. badge de atualização EXISTE no HTML (regressão: JS usava getElementById("updBadge")
#     sem o elemento existir — o aviso de nova versão nunca aparecia)
check("elemento #updBadge existe", 'id="updBadge"' in h)
check("elemento #btnRecheck existe", 'id="btnRecheck"' in h)

# 10. todos os caminhos de arquivo são relativos e seguros (nada de /abs nem ..)
bad_paths = [a["file"] for a in d["agents"] if a["file"].startswith("/") or ".." in a["file"].split("/")]
check("paths de agentes seguros", not bad_paths, str(bad_paths[:3]))

# 11. comando do wizard roda da RAIZ do repo (regressão: instruía `../instaladores`
#     com o plano um diretório acima — agora o plano é buscado automaticamente)
check("wizard: comando windows na raiz", "instaladores\\\\instalar-windows.ps1 -Plan" in h)
check("wizard: comando posix na raiz", "./instaladores/instalar-linux.sh --plan" in h)

print()
if fails:
    print(f"FALHAS: {len(fails)} → {fails}")
    sys.exit(1)
print("TODOS OS TESTES DO GUIA PASSARAM")
