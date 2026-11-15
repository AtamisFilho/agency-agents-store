#!/usr/bin/env python3
"""Testes do guia gerado (estáticos): payload, i18n, XSS, paridade."""
import json, re, sys, pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent
HTML = REPO / "guia-especialistas-agencia.html"
fails = []

def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + (f" — {detail}" if detail and not cond else ""))
    if not cond: fails.append(name)

h = HTML.read_text(encoding="utf-8")

# 1. placeholders não vazaram
check("sem placeholders __PAYLOAD__/__UI__", "__PAYLOAD__" not in h and "__UI__" not in h)

# 2. XSS: nenhum </script> literal dentro do payload/UI embutidos
seg_data = h.split("const DATA = ", 1)[1].split(";\nconst UI", 1)[0]
seg_ui = h.split("const UI = ", 1)[1].split(";\nconst VER", 1)[0]
check("payload sem </script> literal (XSS guard)", "</script" not in seg_data.lower())
check("UI sem </script> literal (XSS guard)", "</script" not in seg_ui.lower())

# 3. JSON válido e completo
d = json.loads(seg_data)
ui = json.loads(seg_ui)
check("283 agentes no payload", len(d["agents"]) == 283)
check("18 divisões", len(d["divisions"]) == 18)
check("16 tools", len(d["tools"]) == 16)
check("versão 2.1.1", d["version"] == "2.1.1")
check("repo correto", d["ourRepo"] == "AtamisFilho/agency-agents-store")

# 4. i18n: 5 idiomas × 283 × (desc + 4 exemplos) + when
for lang in ["en","pt","es","fr","de"]:
    v = d["i18n"][lang]
    check(f"i18n {lang}: 283 agentes", len(v["agents"]) == 283)
    bad = [s for s, x in v["agents"].items() if len(x.get("x", [])) != 4 or not x.get("d")]
    check(f"i18n {lang}: 4 exemplos por agente", not bad, str(bad[:3]))
    check(f"i18n {lang}: when 18+12", len(v["when"]["div"]) == 18 and len(v["when"]["custom"]) == 12)

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
    check(f"divLabels {lang} = 18", len(d["divLabels"][lang]) == 18)
    missing = [t["id"] for t in d["tools"] if lang not in t["descs"]]
    check(f"tool descs {lang} completas", not missing, str(missing))

# 7. todo agente do payload existe em TODOS os idiomas (cross-check)
for lang in ["en","pt","es","fr","de"]:
    miss = [a["slug"] for a in d["agents"] if a["slug"] not in d["i18n"][lang]["agents"]]
    check(f"cross-check agentes↔i18n {lang}", not miss, str(miss[:3]))

# 8. squads coerentes
check("squad pre-lancamento = 12", len(d["squads"]["pre-lancamento"]["slugs"]) == 12)
check("squad treino = 4", len(d["squads"]["treino"]["slugs"]) == 4)
slugs_set = {a["slug"] for a in d["agents"]}
check("squads ⊂ catálogo", set(d["squads"]["pre-lancamento"]["slugs"]) <= slugs_set and set(d["squads"]["treino"]["slugs"]) <= slugs_set)

# 9. sem marcadores de conflito de merge no HTML
check("sem marcadores de conflito", "<<<<<<<" not in h and ">>>>>>>" not in h)

# 9b. badge de atualização EXISTE no HTML (regressão: JS usava getElementById("updBadge")
#     sem o elemento existir — o aviso de nova versão nunca aparecia)
check("elemento #updBadge existe", 'id="updBadge"' in h)
check("elemento #btnRecheck existe", 'id="btnRecheck"' in h)

# 10. todos os caminhos de arquivo são relativos e seguros (nada de /abs nem ..)
bad_paths = [a["file"] for a in d["agents"] if a["file"].startswith("/") or ".." in a["file"].split("/")]
check("paths de agentes seguros", not bad_paths, str(bad_paths[:3]))

print()
if fails:
    print(f"FALHAS: {len(fails)} → {fails}")
    sys.exit(1)
print("TODOS OS TESTES DO GUIA PASSARAM")
