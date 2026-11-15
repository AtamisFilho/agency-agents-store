#!/usr/bin/env python3
"""Gera o guia-especialistas-agencia.html (v2) — self-contained, offline.

Dados: dados/agents.json + pt*.json (traduções) + ex*.json (situações reais).
Saída: guia-especialistas-agencia.html na raiz do repo (e ~/Documentos se existir).
"""
import json, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DADOS = REPO / "dados"
GUIA_VERSION = "2.0.0"
OUR_REPO = "AtamisFilho/agency-agents-store"

agents = json.load(open(DADOS / "agents.json"))
pt = {}
for i in range(3):
    pt.update(json.load(open(DADOS / f"pt{i}.json")))
ex = {}
for i in range(3):
    ex.update(json.load(open(DADOS / f"ex{i}.json")))

INSTALLED_CLAUDE = {
    "engineering/engineering-code-reviewer.md", "engineering/engineering-devops-automator.md",
    "testing/testing-reality-checker.md", "testing/testing-api-tester.md",
    "testing/testing-test-automation-engineer.md", "testing/testing-evidence-collector.md",
    "testing/testing-accessibility-auditor.md", "testing/testing-performance-benchmarker.md",
    "security/security-penetration-tester.md", "security/security-appsec-engineer.md",
    "security/security-threat-detection-engineer.md", "product/product-sprint-prioritizer.md",
}
ZCODE_SLUGS = {"code-reviewer", "reality-checker", "api-tester", "sprint-prioritizer"}

DIV_PT = {
    "academic": "Acadêmico & Narrativa", "design": "Design & UX", "engineering": "Engenharia",
    "finance": "Finanças", "game-development": "Jogos", "gis": "GIS & Mapas",
    "healthcare": "Saúde", "marketing": "Marketing & Conteúdo", "paid-media": "Mídia Paga (Anúncios)",
    "product": "Produto", "project-management": "Gestão de Projetos", "research": "Pesquisa",
    "sales": "Vendas", "security": "Segurança", "spatial-computing": "Computação Espacial (AR/VR)",
    "specialized": "Especialistas Diversos", "support": "Suporte & Operações", "testing": "Testes & QA",
}
DIV_WHEN = {
    "academic": "Quando o projeto envolver mundos fictícios, pesquisa séria ou conteúdo que precisa de embasamento real.",
    "design": "Quando precisar melhorar a aparência, a usabilidade ou a experiência de uso do app.",
    "engineering": "Quando precisar construir, consertar ou melhorar o código e a infraestrutura do projeto.",
    "finance": "Quando precisar entender números, preços, orçamento ou a saúde financeira do negócio.",
    "game-development": "Quando o projeto for um jogo ou tiver elementos de jogo.",
    "gis": "Quando o projeto envolver mapas, dados geográficos ou localização.",
    "healthcare": "Quando o projeto estiver na área da saúde e precisar seguir as regras do setor.",
    "marketing": "Quando precisar atrair, engajar ou fidelizar usuários com conteúdo.",
    "paid-media": "Quando estiver pagando por anúncios e quiser melhorar o retorno de cada real investido.",
    "product": "Quando precisar decidir O QUE construir e em que ordem.",
    "project-management": "Quando precisar organizar tarefas, prazos e o fluxo de trabalho do time.",
    "research": "Quando precisar separar fato de opinião em pesquisas e fontes.",
    "sales": "Quando precisar vender, prospectar clientes ou cuidar da carteira existente.",
    "security": "Antes do lançamento e sempre que envolver dados de usuários — é o seguro de vida do projeto.",
    "spatial-computing": "Quando o projeto envolver realidade aumentada/virtual ou 3D avançado.",
    "specialized": "Papéis especiais para situações específicas — navegue aqui quando tiver um desafio fora do comum.",
    "support": "Quando precisar cuidar do cliente depois do lançamento ou organizar a operação do dia a dia.",
    "testing": "Antes de declarar qualquer coisa “pronta” — é aqui que vive a prova de que funciona.",
}
WHEN_CUSTOM = {
    "code-reviewer": "Depois de qualquer mudança de código importante. Diga: “use o code-reviewer para revisar a mudança X com foco em correção e segurança”.",
    "devops-automator": "Na hora de montar o deploy, o CI/CD e publicar a plataforma (ex.: deploy no Zorin/Docker).",
    "reality-checker": "Antes de acreditar que algo está pronto. Diga: “verifique com provas se X realmente funciona”. Ele não aceita promessa, só evidência.",
    "api-tester": "Para testar as rotas do backend de ponta a ponta (login, partidas, convites, rankings, pagamentos).",
    "test-automation-engineer": "Para criar a suíte de testes automatizados que roda sozinha a cada mudança (Playwright/Cypress).",
    "evidence-collector": "Para transformar “testei e funciona” em relatório com provas reproduzíveis — e marcar honestamente o que não foi testado.",
    "accessibility-auditor": "Antes do lançamento público: garante que o app serve a todo mundo (teclado, leitores de tela, contraste).",
    "performance-benchmarker": "Quando o app estiver lento ou antes do lançamento, para medir e melhorar a velocidade com números.",
    "penetration-tester": "OBRIGATÓRIO antes de abrir ao público: simula ataques reais para achar brechas antes dos criminosos acharem.",
    "application-security-engineer": "Para revisar a segurança do código novo: segredos expostos, permissões, falhas de injeção.",
    "threat-detection-engineer": "Depois do lançamento: configura o monitoramento e os alertas que detectam ataques em produção.",
    "sprint-prioritizer": "No começo de cada ciclo: transforma “tudo é urgente” num plano ordenado com primeiro marco claro.",
}

# Ferramentas-alvo: metadados p/ painel, wizard e compatibilidade por SO.
# compat: l=linux, m=macos, w=windows; "wsl" = funciona no Windows via WSL.
TOOLS = [
    {"id": "claudeCode", "label": "Claude Code", "icon": "🤖", "kebab": "claude-code", "format": "identity",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dirs": [".claude"], "dest": "~/.claude/agents/<slug>.md",
     "desc": "O assistente de código da Anthropic, no terminal."},
    {"id": "zcode", "label": "ZCode", "icon": "🧭", "kebab": "zcode", "format": "zcode-md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dirs": [".zcode"], "dest": "~/.zcode/agents/<slug>.md",
     "desc": "O agente de código GLM/Z.ai (o que você está usando agora)."},
    {"id": "codex", "label": "Codex CLI", "icon": "⚙️", "kebab": "codex", "format": "toml",
     "compat": {"l": "sim", "m": "sim", "w": "wsl"}, "projectOnly": False, "main": True,
     "dirs": [".codex"], "dest": "~/.codex/agents/<slug>.toml",
     "desc": "O agente de código da OpenAI, no terminal."},
    {"id": "geminiCli", "label": "Gemini CLI", "icon": "✨", "kebab": "gemini-cli", "format": "md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dirs": [".gemini"], "dest": "~/.gemini/agents/<slug>.md",
     "desc": "O agente de código do Google, no terminal."},
    {"id": "copilot", "label": "GitHub Copilot", "icon": "🐙", "kebab": "github-copilot", "format": "identity",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dirs": [".github/agents", ".copilot"], "dest": "~/.github/agents/<slug>.md",
     "desc": "Copilot da GitHub (VS Code, JetBrains e CLI) — pasta de agentes."},
    {"id": "qwen", "label": "Qwen Code", "icon": "🌐", "kebab": "qwen", "format": "md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dirs": [".qwen"], "dest": "~/.qwen/agents/<slug>.md",
     "desc": "O agente de código do modelo Qwen (Alibaba)."},
    {"id": "opencode", "label": "opencode", "icon": "🔓", "kebab": "opencode", "format": "opencode-md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dirs": [".config/opencode"], "dest": "~/.config/opencode/agents/<slug>.md",
     "desc": "Agente de código open source multi-modelo."},
    {"id": "cursor", "label": "Cursor", "icon": "🖱️", "kebab": "cursor", "format": "mdc",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": True, "main": True,
     "dirs": [".cursor"], "dest": "<projeto>/.cursor/rules/<slug>.mdc",
     "desc": "Editor com IA — regras/agentes ficam DENTRO de cada projeto."},
    {"id": "antigravity", "label": "Antigravity", "icon": "🛸", "kebab": "antigravity", "format": "skill-md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dirs": [".gemini/config/skills"], "dest": "~/.gemini/config/skills/<slug>/SKILL.md",
     "desc": "O IDE agêntico do Google (Gemini 3)."},
    {"id": "osaurus", "label": "Osaurus", "icon": "🦕", "kebab": "osaurus", "format": "skill-md",
     "compat": {"l": "nao", "m": "sim", "w": "nao"}, "projectOnly": False, "main": True,
     "dirs": [".osaurus"], "dest": "~/.osaurus/skills/agency-<slug>/SKILL.md",
     "desc": "App nativo de IA local — só no macOS."},
    {"id": "kimi", "label": "Kimi CLI", "icon": "🌙", "kebab": "kimi", "format": "kimi-dir",
     "compat": {"l": "sim", "m": "sim", "w": "wsl"}, "projectOnly": False, "main": False,
     "dirs": [".config/kimi"], "dest": "~/.config/kimi/agents/<slug>/",
     "desc": "Agente de código do modelo Kimi (Moonshot)."},
    {"id": "vibe", "label": "Mistral Vibe", "icon": "🌬️", "kebab": "vibe", "format": "vibe-dir",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": False,
     "dirs": [".vibe"], "dest": "~/.vibe/agents/<slug>.toml + prompts",
     "desc": "CLI agêntica da Mistral (avançado)."},
    {"id": "dsh", "label": "DeepSeek Harness", "icon": "🐋", "kebab": "dsh", "format": "skill-md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": False,
     "dirs": [".dsh"], "dest": "~/.dsh/skills/<slug>/SKILL.md",
     "desc": "Harness de skills do DeepSeek (avançado)."},
    {"id": "openclaw", "label": "OpenClaw", "icon": "🦞", "kebab": "openclaw", "format": "openclaw-dir",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": False,
     "dirs": [".openclaw"], "dest": "~/.openclaw/agency-agents/<slug>/",
     "desc": "Runtime de agentes com memória/identidade (avançado)."},
    {"id": "aider", "label": "Aider", "icon": "🩹", "kebab": "aider", "format": "roster",
     "compat": {"l": "sim", "m": "sim", "w": "wsl"}, "projectOnly": True, "main": False,
     "dirs": [".git"], "dest": "<projeto>/CONVENTIONS.md (roster único)",
     "desc": "Programação par com IA no terminal — índice coletivo (avançado)."},
    {"id": "windsurf", "label": "Windsurf", "icon": "🏄", "kebab": "windsurf", "format": "windsurf",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": True, "main": False,
     "dirs": [".windsurf"], "dest": "<projeto>/.windsurfrules (roster único)",
     "desc": "Editor com IA da Codeium — regras por projeto (avançado)."},
]
MAIN_TOOLS = [t for t in TOOLS if t["main"]]

for a in agents:
    a["pt"] = pt[a["slug"]]
    a["ex"] = ex[a["slug"]]
    a["divpt"] = DIV_PT[a["division"]]
    a["when"] = WHEN_CUSTOM.get(a["slug"], DIV_WHEN[a["division"]])
    a["custom_when"] = a["slug"] in WHEN_CUSTOM
    a["inst_claude"] = a["file"] in INSTALLED_CLAUDE
    a["inst_zcode"] = a["slug"] in ZCODE_SLUGS

data = sorted(agents, key=lambda a: (DIV_PT[a["division"]], a["name"].lower()))
divs = []
for d_pt in sorted(DIV_PT.values()):
    rows = [a for a in data if a["divpt"] == d_pt]
    divs.append({"pt": d_pt, "raw": rows[0]["division"], "n": len(rows),
                 "inst": sum(1 for a in rows if a["inst_claude"] or a["inst_zcode"])})

SQUADS = {
    "pre-lancamento": {"label": "Squad pré-lançamento (12)", "slugs": sorted(a["slug"] for a in data if a["inst_claude"])},
    "treino": {"label": "Squad de treino (4)", "slugs": sorted(ZCODE_SLUGS)},
}
# squads.json para os instaladores (slug -> arquivo fonte do catálogo)
sq_out = {k: {"label": v["label"], "agentes": [{"slug": s, "file": next(a["file"] for a in data if a["slug"] == s)} for s in v["slugs"]]} for k, v in SQUADS.items()}
(DADOS / "squads.json").write_text(json.dumps(sq_out, ensure_ascii=False, indent=1), encoding="utf-8")

payload = {"version": GUIA_VERSION, "ourRepo": OUR_REPO, "agents": data, "divisions": divs,
           "tools": TOOLS, "mainTools": [t["id"] for t in MAIN_TOOLS], "squads": SQUADS}

HTML = r"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Guia de Especialistas — Agency Agents</title>
<style>
:root{
  --bg:#f6f7f9; --card:#ffffff; --ink:#1a202c; --muted:#5a6472; --line:#e3e7ee;
  --accent:#4f46e5; --accent2:#0ea5a4; --claude:#d97757; --zcode:#4263eb;
  --ok:#16a34a; --warn:#d97706; --chip:#eef1f6; --shadow:0 1px 3px rgba(16,24,40,.08),0 1px 2px rgba(16,24,40,.04);
}
@media (prefers-color-scheme: dark){ :root{
  --bg:#0f1420; --card:#171e2e; --ink:#e8ecf3; --muted:#9aa4b5; --line:#2a3446;
  --accent:#818cf8; --accent2:#2dd4bf; --chip:#1e2739; --shadow:0 1px 3px rgba(0,0,0,.4);
}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.wrap{max-width:1200px;margin:0 auto;padding:24px 20px 80px}
header h1{font-size:26px;margin:0 0 6px}
header p.sub{color:var(--muted);margin:0 0 18px}
.stats{display:flex;flex-wrap:wrap;gap:10px;margin:0 0 22px}
.stat{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:10px 16px;box-shadow:var(--shadow)}
.stat b{font-size:20px;display:block}
.stat span{color:var(--muted);font-size:12.5px}
.panel{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px 20px;margin:0 0 22px;box-shadow:var(--shadow)}
.panel h2{margin:0 0 10px;font-size:18px}
.panel ol,.panel ul{margin:8px 0 0;padding-left:22px}
.panel li{margin:4px 0}
kbd{background:var(--chip);border:1px solid var(--line);border-radius:5px;padding:1px 6px;font-size:12.5px}
.example{background:var(--chip);border-left:3px solid var(--accent);border-radius:0 8px 8px 0;padding:8px 12px;margin:6px 0;font-size:13.5px}
.badge{display:inline-block;border-radius:999px;padding:3px 10px;font-size:12px;font-weight:600;margin-left:8px;vertical-align:middle}
.badge.new{background:color-mix(in srgb,var(--warn) 18%,transparent);color:var(--warn)}
.badge.ok{background:color-mix(in srgb,var(--ok) 15%,transparent);color:var(--ok)}
/* ---- painel da máquina ---- */
#machine{position:relative}
#mStatus{color:var(--muted);font-size:13.5px;margin:0 0 12px}
.toolgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:10px}
.tool{border:1px solid var(--line);border-radius:12px;padding:12px 14px;display:flex;flex-direction:column;gap:5px;background:var(--card)}
.tool .t-head{display:flex;align-items:center;gap:8px;font-weight:600}
.tool .t-state{font-size:12px;border-radius:999px;padding:2px 9px;align-self:flex-start}
.st-ready{background:color-mix(in srgb,var(--ok) 14%,transparent);color:var(--ok)}
.st-detected{background:color-mix(in srgb,var(--accent2) 14%,transparent);color:var(--accent2)}
.st-absent{background:var(--chip);color:var(--muted)}
.st-incompat{background:var(--chip);color:var(--muted)}
.st-unknown{background:color-mix(in srgb,var(--warn) 14%,transparent);color:var(--warn)}
.tool .t-desc{font-size:12.5px;color:var(--muted)}
.tool .t-dest{font-size:11.5px;color:var(--muted);font-family:ui-monospace,monospace}
.tool button{margin-top:6px;border:1px solid var(--accent);color:var(--accent);background:transparent;border-radius:8px;padding:6px 10px;font-size:12.5px;cursor:pointer}
.tool button:hover{background:var(--accent);color:#fff}
.mActions{display:flex;gap:10px;margin-top:14px;flex-wrap:wrap}
.btn{border:0;border-radius:10px;padding:10px 16px;font-size:14px;cursor:pointer;font-weight:600}
.btn.primary{background:var(--accent);color:#fff}
.btn.ghost{background:transparent;border:1.5px solid var(--line);color:var(--ink)}
.btn.primary:hover{filter:brightness(1.08)}
/* ---- modal ---- */
dialog{border:0;border-radius:16px;background:var(--card);color:var(--ink);max-width:640px;width:92vw;padding:0;box-shadow:0 20px 60px rgba(0,0,0,.35)}
dialog::backdrop{background:rgba(10,14,25,.55);backdrop-filter:blur(2px)}
.mWrap{padding:22px 24px}
.mWrap h3{margin:0 0 4px;font-size:19px}
.mWrap .mSub{color:var(--muted);font-size:13.5px;margin:0 0 16px}
.mStep{display:none}.mStep.on{display:block}
.opt{border:1.5px solid var(--line);border-radius:12px;padding:12px 14px;margin:8px 0;cursor:pointer;display:flex;gap:10px;align-items:flex-start}
.opt:hover{border-color:var(--accent)}
.opt.sel{border-color:var(--accent);background:color-mix(in srgb,var(--accent) 7%,transparent)}
.opt input{margin-top:3px}
.opt .o-t{font-weight:600;font-size:14px}
.opt .o-d{font-size:12.5px;color:var(--muted)}
.mNav{display:flex;justify-content:space-between;gap:10px;margin-top:18px}
.cmdBox{background:var(--chip);border-radius:10px;padding:10px 12px;font:12.5px/1.5 ui-monospace,monospace;word-break:break-all;margin:8px 0;position:relative}
.copyBtn{position:absolute;right:6px;top:6px;border:0;background:var(--accent);color:#fff;border-radius:6px;padding:3px 9px;font-size:11px;cursor:pointer}
.muted{color:var(--muted)} small.ok{color:var(--ok)} small.no{color:var(--warn)}
/* ---- filtros/cards ---- */
.bar{position:sticky;top:0;z-index:10;background:var(--bg);padding:14px 0 10px;border-bottom:1px solid var(--line);margin-bottom:16px}
.searchrow{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
#q{flex:1;min-width:240px;padding:10px 14px;border:1.5px solid var(--line);border-radius:10px;font-size:15px;background:var(--card);color:var(--ink);outline:none}
#q:focus{border-color:var(--accent)}
.count{color:var(--muted);font-size:13px;white-space:nowrap}
label.tog{display:flex;gap:6px;align-items:center;font-size:13.5px;color:var(--muted);cursor:pointer;user-select:none}
.chips{display:flex;flex-wrap:wrap;gap:7px;margin-top:10px}
.chip{border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:999px;padding:5px 12px;font-size:13px;cursor:pointer;transition:.15s}
.chip:hover{border-color:var(--accent)}
.chip.on{background:var(--accent);border-color:var(--accent);color:#fff}
.chip small{opacity:.75}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px;box-shadow:var(--shadow);display:flex;flex-direction:column;gap:8px}
.card h3{margin:0;font-size:15.5px;line-height:1.35}
.card h3 small{color:var(--muted);font-weight:400;font-size:12px;margin-left:6px}
.tags{display:flex;flex-wrap:wrap;gap:6px}
.tag{font-size:11.5px;border-radius:999px;padding:2px 9px;background:var(--chip);color:var(--muted)}
.tag.div{background:color-mix(in srgb,var(--accent) 12%,transparent);color:var(--accent)}
.tag.claude{background:color-mix(in srgb,var(--claude) 15%,transparent);color:var(--claude);font-weight:600}
.tag.zcode{background:color-mix(in srgb,var(--zcode) 15%,transparent);color:var(--zcode);font-weight:600}
.desc{font-size:13.8px;color:var(--ink)}
.when{font-size:13px;color:var(--muted);background:var(--chip);border-radius:9px;padding:8px 10px}
.when b{color:var(--ink);font-weight:600}
.when.hot{border-left:3px solid var(--accent2)}
.exList{margin:0;padding-left:18px;font-size:12.8px;color:var(--muted)}
.exList li{margin:3px 0}
details{font-size:12.8px;color:var(--muted)}
details summary{cursor:pointer;color:var(--accent);font-size:12.5px}
details pre{white-space:pre-wrap;word-break:break-word;margin:6px 0 0;font:12px/1.5 ui-monospace,monospace;color:var(--muted)}
.sep{margin:34px 0 14px;font-size:19px;font-weight:700}
.sep small{color:var(--muted);font-weight:400;font-size:13px;margin-left:8px}
.empty{color:var(--muted);text-align:center;padding:40px 0;font-size:14px}
footer{margin-top:44px;color:var(--muted);font-size:12.5px;text-align:center}
@media print{
  .bar,.noprint{display:none} body{background:#fff} .panel,.card{box-shadow:none;border:1px solid #ddd}
  details{display:none} dialog{display:none!important}
}
</style>
</head>
<body>
<!-- estado da sua máquina, escrito pelo instalador (instaladores/). Se não existir, o guia segue funcionando. -->
<script src="guia-status.js"></script>
<div class="wrap">
<header>
  <h1>🧭 Guia de Especialistas — Agency Agents <span id="updBadge" class="badge new" hidden>Atualização disponível</span></h1>
  <p class="sub">Catálogo de consulta + painel da sua máquina. Funciona offline; a checagem de atualizações usa internet só quando você pede (ou a cada 24h).</p>
  <div class="stats">
    <div class="stat"><b id="stTotal">—</b><span>especialistas no catálogo</span></div>
    <div class="stat"><b id="stInst">—</b><span>instalados nas suas ferramentas</span></div>
    <div class="stat"><b id="stTools">—</b><span>ferramentas prontas para uso</span></div>
    <div class="stat"><b id="stDiv">—</b><span>divisões (áreas de atuação)</span></div>
  </div>
</header>

<div class="panel" id="machine">
  <h2>🖥️ Sua máquina &amp; suas ferramentas</h2>
  <p id="mStatus">Analisando…</p>
  <div class="toolgrid" id="toolGrid"></div>
  <div class="mActions noprint">
    <button class="btn primary" id="btnWizard">➕ Instalar especialistas numa ferramenta</button>
    <button class="btn ghost" id="btnRecheck">🔄 Verificar atualizações agora</button>
  </div>
</div>

<div class="panel">
  <h2>🚀 Como chamar um especialista</h2>
  <ol>
    <li><b>Comigo (ZCode), agora mesmo:</b> basta pedir em linguagem natural. <div class="example">💬 “Use o <b>reality-checker</b> para verificar com provas se o login está funcionando”</div></li>
    <li><b>Nas ferramentas instaladas:</b> os especialistas aparecem como subagentes — mencione o nome dele no pedido (ex.: no Claude Code, em qualquer pasta; no ZCode, abra a sessão na pasta do projeto).</li>
    <li><b>Para “contratar” mais especialistas:</b> use o botão <b>Instalar especialistas</b> acima — o guia pergunta onde e o quê, e gera o comando/planinho pronto.</li>
  </ol>
</div>

<div class="panel">
  <h2>📏 As 5 regras de ouro (do Playbook oficial)</h2>
  <ol>
    <li><b>Descreva o resultado, não os passos.</b> Diga o que “pronto” significa.</li>
    <li><b>Monte equipe, não solista.</b> Um construtor + um crítico (ex.: code-reviewer + reality-checker) valem mais que dois construtores.</li>
    <li><b>Repita até ter evidência.</b> “Compilou” não é “funciona”. Exija prova: teste rodando, log, print.</li>
    <li><b>Alimente com contexto.</b> Aponte arquivos, restrições e critérios de sucesso antes de pedir.</li>
    <li><b>Comece com um, depois escale.</b> Um agente, uma tarefa, um projeto — depois vire time.</li>
  </ol>
</div>

<div class="bar noprint">
  <div class="searchrow">
    <input id="q" type="search" placeholder="🔎 Buscar por nome, função ou situação… (tecle / para focar)" autocomplete="off">
    <label class="tog"><input type="checkbox" id="onlyInst"> só os instalados</label>
    <span class="count" id="count"></span>
  </div>
  <div class="chips" id="chips"></div>
</div>

<div id="teamSep" class="sep">⭐ Sua equipe atual <small>instalados e prontos para trabalhar</small></div>
<div class="grid" id="teamGrid"></div>

<div class="sep">📚 Catálogo completo <small>o banco de talentos — busque, filtre e “contrate” quando precisar</small></div>
<div class="grid" id="grid"></div>
<div class="empty" id="empty" hidden>Nenhum especialista encontrado com esses filtros.</div>

<footer>
  Guia <span id="fVer"></span> · Catálogo <b>msitarzewski/agency-agents</b> (MIT) · Instalador <b>Agency Agents App</b> ·
  Descrições e situações traduzidas para leigos; o original em inglês fica no detalhe de cada card.
</footer>
</div>

<dialog id="wiz">
  <div class="mWrap">
    <div class="mStep on" data-step="1">
      <h3>Onde instalar? (1/3)</h3>
      <p class="mSub">Estas são as ferramentas que seu sistema suporta. Escolha uma ou mais.</p>
      <div id="wizTools"></div>
      <div class="mNav"><span></span><button class="btn primary" id="wNext1">Continuar →</button></div>
    </div>
    <div class="mStep" data-step="2">
      <h3>Quem contratar? (2/3)</h3>
      <p class="mSub">Escolha o tamanho do time. Você pode mudar depois quando quiser.</p>
      <div id="wizSquads"></div>
      <div class="mNav"><button class="btn ghost" id="wBack2">← Voltar</button><button class="btn primary" id="wNext2">Continuar →</button></div>
    </div>
    <div class="mStep" data-step="3">
      <h3>Pronto! (3/3)</h3>
      <p class="mSub">São <b id="wCount">0</b> especialistas para <b id="wToolsLbl"></b>. Dois passos simples:</p>
      <ol>
        <li>Salve o planinho da instalação no seu computador:
          <div class="mNav" style="justify-content:flex-start"><button class="btn primary" id="wDownload">⬇️ Baixar plano-agencia.json</button></div>
        </li>
        <li>Abra o terminal na pasta onde você salvou o guia e rode o instalador com o planinho:
          <div class="cmdBox" id="wCmd"></div>
          <p class="muted" style="font-size:12.5px">O instalador pergunta só o necessário, faz backup do que já existe e, no fim, atualiza o painel desta página automaticamente.</p>
        </li>
      </ol>
      <div class="mNav"><button class="btn ghost" id="wBack3">← Voltar</button><button class="btn primary" id="wClose">Fechar</button></div>
    </div>
  </div>
</dialog>

<script>
const DATA = __PAYLOAD__;
const VER = DATA.version;

/* ---------- estado da máquina ---------- */
let STATUS = null;
try { STATUS = window.GUIA_STATUS || null; } catch(e) { STATUS = null; }
function detectOS(){
  const ua = navigator.userAgent;
  if (/Windows NT/.test(ua)) return "windows";
  if (/Mac OS X/.test(ua)) return "macos";
  if (/Linux/.test(ua) && !/Android/.test(ua)) return "linux";
  if (/Android/.test(ua)) return "android";
  return "desconhecido";
}
const OS = (STATUS && STATUS.os && STATUS.os.family) || detectOS();
const OS_LABEL = {windows:"Windows", macos:"macOS", linux:"Linux", android:"Android", desconhecido:"Sistema não identificado"}[OS];
function compatOf(t){
  if(!STATUS) return "unknown";
  const key = OS.startsWith("linux")?"l":OS==="macos"?"m":"w";
  const c = (t.compat && t.compat[key]) || "nao";
  if (c === "nao") return "incompat";
  if (t.projectOnly) return "project";
  return "ok";
}

const toolGrid = document.getElementById('toolGrid');
const mStatus = document.getElementById('mStatus');
function toolState(t){
  if(!STATUS) return {cls:"st-unknown", txt:"❓ Rodar o instalador para detectar"};
  const inst = STATUS.tools.find(x=>x.id===t.id);
  const compat = compatOf(t);
  if (compat === "incompat") return {cls:"st-incompat", txt:"🌐 Não disponível para "+OS_LABEL};
  if (compat === "project") return {cls:"st-detected", txt:"📁 Instalação por projeto"};
  if (!inst || !inst.installed) return {cls:"st-absent", txt:"⚪ Não instalada (opcional)"};
  if (inst.agentCount > 0) return {cls:"st-ready", txt:"✅ Pronta · "+inst.agentCount+" especialista"+(inst.agentCount>1?"s":"")};
  return {cls:"st-detected", txt:"🟢 Instalada · sem especialistas da agência"};
}
function renderTools(){
  const main = DATA.tools.filter(t=>t.main);
  toolGrid.innerHTML = main.map(t=>{
    const st = toolState(t);
    const compat = compatOf(t);
    const hint = compat==="wsl" ? '<div class="t-dest">No Windows: via WSL</div>' :
                 compat==="project" ? '<div class="t-dest">Fica dentro de cada projeto</div>' :
                 '<div class="t-dest">'+t.dest.replace(/</g,"&lt;")+'</div>';
    return `<div class="tool" data-id="${t.id}">
      <div class="t-head">${t.icon} ${t.label}</div>
      <span class="t-state ${st.cls}">${st.txt}</span>
      <div class="t-desc">${t.desc}</div>${hint}
      <button data-tool="${t.id}">Instalar especialistas aqui</button>
    </div>`;
  }).join("");
}
function renderStats(){
  const stTools = STATUS ? STATUS.tools.filter(t=>t.installed && t.agentCount>0).length : 0;
  const stInst = STATUS ? STATUS.tools.reduce((s,t)=>s+t.agentCount,0) : (DATA.agents.filter(a=>a.inst_claude||a.inst_zcode).length);
  document.getElementById('stTotal').textContent = DATA.agents.length;
  document.getElementById('stInst').textContent = stInst;
  document.getElementById('stTools').textContent = stTools;
  document.getElementById('stDiv').textContent = DATA.divisions.length;
  document.getElementById('fVer').textContent = "v"+VER;
}
if (STATUS){
  mStatus.innerHTML = `🖥️ ${STATUS.os.label || OS_LABEL} detectado pelo instalador` +
    (STATUS.catalog ? ` · 📚 catálogo em <code>${STATUS.catalog.path}</code> atualizado em ${STATUS.catalog.updated}` : "") +
    ` · 🕒 verificado em ${new Date(STATUS.generatedAt).toLocaleString("pt-BR")}`;
} else {
  mStatus.innerHTML = `🖥️ ${OS_LABEL} (detectado pelo navegador) — <b>para enxergar suas ferramentas, rode o instalador</b> (pasta <code>instaladores/</code> do projeto). Ele cria o arquivo <code>guia-status.js</code> ao lado deste guia.`;
}
renderTools(); renderStats();

/* ---------- wizard ---------- */
const wiz = document.getElementById('wiz');
let wizSel = {tools:new Set(), squad:null, slugs:[]};
const wizTools = document.getElementById('wizTools');
function openWizard(forTool){
  wizSel = {tools:new Set(), squad:null, slugs:[]};
  if (forTool) wizSel.tools.add(forTool);
  wizTools.innerHTML = DATA.tools.filter(t=>{
    const c = compatOf(t);
    return c==="ok" || c==="project" || c==="wsl" || c==="unknown";
  }).map(t=>{
    const c = compatOf(t);
    const lbl = c==="project" ? " (por projeto)" : c==="wsl" ? " (via WSL)" : "";
    return `<label class="opt"><input type="checkbox" value="${t.id}" ${wizSel.tools.has(t.id)?"checked":""}>
      <span><span class="o-t">${t.icon} ${t.label}${lbl}</span><br><span class="o-d">${t.desc}</span></span></label>`;
  }).join("");
  wizTools.querySelectorAll("input").forEach(i=>i.addEventListener("change",()=>{
    i.checked ? wizSel.tools.add(i.value) : wizSel.tools.delete(i.value);
  }));
  const sq = DATA.squads;
  wizSquads.innerHTML = `
    <label class="opt"><input type="radio" name="sq" value="pre-lancamento" checked><span><span class="o-t">⭐ ${sq["pre-lancamento"].label}</span><br><span class="o-d">Quem você precisa antes de lançar: revisor, devops, testes, segurança e planejamento.</span></span></label>
    <label class="opt"><input type="radio" name="sq" value="treino"><span><span class="o-t">🎓 ${sq["treino"].label}</span><br><span class="o-d">O time mínimo para aprender o fluxo: revisão, prova, API e planejamento.</span></span></label>
    <label class="opt"><input type="radio" name="sq" value="todas"><span><span class="o-t">🏫 Todos os ${DATA.agents.length} especialistas</span><br><span class="o-d">A agência inteira — útil se sua ferramenta lista os agentes num menu.</span></span></label>
    <label class="opt"><input type="radio" name="sq" value="divisao"><span><span class="o-t">🗂️ Escolher por área</span><br><span class="o-d">Você marca as divisões (Engenharia, Marketing…) e leva todos daquela área.</span></span></label>`;
  const divBox = document.createElement("div");
  divBox.id = "wizDivs"; divBox.style.display = "none";
  divBox.innerHTML = DATA.divisions.map(d=>`<label class="opt"><input type="checkbox" value="${d.raw}"><span><span class="o-t">${d.pt}</span> <span class="o-d">(${d.n} especialistas)</span></span></label>`).join("");
  wizSquads.parentNode.insertBefore(divBox, wizSquads.nextSibling);
  wizSquads.querySelectorAll("input[name=sq]").forEach(i=>i.addEventListener("change",()=>{
    divBox.style.display = i.value==="divisao" ? "block" : "none";
  }));
  showStep(1);
  wiz.showModal();
}
function showStep(n){
  wiz.querySelectorAll(".mStep").forEach(s=>s.classList.toggle("on", s.dataset.step==String(n)));
}
document.getElementById('btnWizard').addEventListener("click",()=>openWizard(null));
toolGrid.addEventListener("click",e=>{
  const b = e.target.closest("button[data-tool]");
  if (b) openWizard(b.dataset.tool);
});
document.getElementById('wNext1').addEventListener("click",()=>{
  if(!wizSel.tools.size){ alert("Escolha pelo menos uma ferramenta 🙂"); return; }
  showStep(2);
});
document.getElementById('wBack2').addEventListener("click",()=>showStep(1));
document.getElementById('wNext2').addEventListener("click",()=>{
  const sq = wizSquads.querySelector("input[name=sq]:checked").value;
  let slugs = [];
  if (sq==="pre-lancamento"||sq==="treino") slugs = DATA.squads[sq].slugs.slice();
  else if (sq==="todas") slugs = DATA.agents.map(a=>a.slug);
  else {
    const sel = [...document.querySelectorAll("#wizDivs input:checked")].map(i=>i.value);
    if(!sel.length){ alert("Marque pelo menos uma área 🙂"); return; }
    slugs = DATA.agents.filter(a=>sel.includes(a.division)).map(a=>a.slug);
  }
  wizSel.squad = sq; wizSel.slugs = slugs;
  document.getElementById('wCount').textContent = slugs.length;
  document.getElementById('wToolsLbl').textContent = [...wizSel.tools].map(id=>DATA.tools.find(t=>t.id===id).label).join(" + ");
  const sys = OS==="linux"?"linux":OS==="macos"?"macos":"windows";
  const cmd = OS==="windows"
    ? "powershell -File ..\\instaladores\\instalar-windows.ps1 -Plano plano-agencia.json"
    : (OS==="macos" ? "bash ../instaladores/instalar-linux.sh --plano plano-agencia.json"
                    : "../instaladores/instalar-linux.sh --plano plano-agencia.json");
  document.getElementById('wCmd').textContent = cmd;
  showStep(3);
});
document.getElementById('wBack3').addEventListener("click",()=>showStep(2));
document.getElementById('wClose').addEventListener("click",()=>wiz.close());
document.getElementById('wDownload').addEventListener("click",()=>{
  const bySlug = DATA.bySlug;
  const plano = {plano:"agencia-guia", versao:1, geradoEm:new Date().toISOString(), sistema:OS,
                 ferramentas:[...wizSel.tools], squad:wizSel.squad,
                 agentes:wizSel.slugs.map(s=>{const a=bySlug[s];return {slug:s, file:a.file};})};
  const blob = new Blob([JSON.stringify(plano,null,1)],{type:"application/json"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob); a.download = "plano-agencia.json"; a.click();
  URL.revokeObjectURL(a.href);
});

/* ---------- atualizações ---------- */
const LS_KEY = "agencia-guia:lastUpdCheck";
async function gh(url){
  const r = await fetch(url, {headers:{Accept:"application/vnd.github+json"}});
  if(!r.ok) throw new Error(r.status);
  return r.json();
}
async function checkUpdates(force){
  const last = +localStorage.getItem(LS_KEY)||0;
  if(!force && Date.now()-last < 24*3600*1000) return;
  localStorage.setItem(LS_KEY, String(Date.now()));
  const badge = document.getElementById('updBadge');
  const found = [];
  try {
    const rel = await gh("https://api.github.com/repos/msitarzewski/agency-agents-app/releases/latest");
    found.push(`App Agency Agents ${rel.tag_name} → github.com/msitarzewski/agency-agents-app/releases`);
  } catch(e){}
  try {
    const rel = await gh(`https://api.github.com/repos/${DATA.ourRepo}/releases/latest`);
    if (rel.tag_name && rel.tag_name !== "v"+VER) {
      found.push(`Este guia ${rel.tag_name} (você tem v${VER}) → instale a versão nova`);
    }
  } catch(e){}
  if (found.length){
    badge.hidden = false; badge.title = found.join("\n");
    badge.onclick = ()=>alert(found.join("\n\n"));
  }
}
document.getElementById('btnRecheck').addEventListener("click",()=>{checkUpdates(true); alert("Verificação concluída! Se algo novo apareceu, o selo amarelo no topo mostra.");});
checkUpdates(false);

/* ---------- catálogo ---------- */
function esc(s){return s.replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}
function card(a, hot){
  const tags = [`<span class="tag div">${esc(a.divpt)}</span>`];
  if(a.inst_claude) tags.push(`<span class="tag claude">● Claude Code</span>`);
  if(a.inst_zcode) tags.push(`<span class="tag zcode">● ZCode</span>`);
  return `<div class="card">
    <h3>${esc(a.name)}<small>${esc(a.slug)}</small></h3>
    <div class="tags">${tags.join('')}</div>
    <div class="desc">${esc(a.pt)}</div>
    <div class="when ${hot?'hot':''}"><b>Quando chamar:</b> ${esc(a.when)}</div>
    <details open="${hot?'':''}"><summary>💡 Situações reais</summary>
      <ul class="exList">${a.ex.map(x=>`<li>${esc(x)}</li>`).join("")}</ul>
    </details>
    <details><summary>original em inglês + arquivo</summary>
      <div>${esc(a.desc)}</div><pre>${esc(a.file)}</pre>
    </details>
  </div>`;
}
const instAgents = DATA.agents.filter(a=>a.inst_claude||a.inst_zcode);
document.getElementById('teamGrid').innerHTML = instAgents.map(a=>card(a,true)).join('');
document.getElementById('grid').innerHTML = DATA.agents.filter(a=>!(a.inst_claude||a.inst_zcode)).map(a=>card(a,false)).join('');

const chipsEl = document.getElementById('chips');
let activeDiv = null;
chipsEl.innerHTML = `<button class="chip on" data-div="">Todas <small>(${DATA.agents.length})</small></button>` +
  DATA.divisions.map(d=>`<button class="chip" data-div="${esc(d.raw)}">${esc(d.pt)} <small>(${d.n}${d.inst?` · ⭐${d.inst}`:''})</small></button>`).join('');
chipsEl.addEventListener('click', e=>{
  const b = e.target.closest('.chip'); if(!b) return;
  activeDiv = b.dataset.div || null;
  chipsEl.querySelectorAll('.chip').forEach(c=>c.classList.toggle('on', c===b));
  apply();
});
const q = document.getElementById('q'), onlyInst = document.getElementById('onlyInst');
const count = document.getElementById('count'), empty = document.getElementById('empty');
function norm(s){return s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'');}
function apply(){
  const term = norm(q.value.trim());
  const all = [...document.querySelectorAll('.card')];
  let shown = 0;
  all.forEach(el=>{
    const slug = el.querySelector('h3 small').textContent;
    const a = DATA.bySlug[slug];
    const hay = norm([a.name,a.slug,a.pt,a.desc,a.divpt,a.when,a.ex.join(" ")].join(" "));
    const ok = (!activeDiv || a.division===activeDiv)
      && (!onlyInst.checked || a.inst_claude || a.inst_zcode)
      && (!term || hay.includes(term));
    el.hidden = !ok; if(ok) shown++;
  });
  count.textContent = `mostrando ${shown} de ${DATA.agents.length}`;
  empty.hidden = shown>0;
  document.getElementById('teamSep').hidden = ![...document.querySelectorAll('#teamGrid .card')].some(c=>!c.hidden);
}
DATA.bySlug = Object.fromEntries(DATA.agents.map(a=>[a.slug,a]));
q.addEventListener('input', apply);
onlyInst.addEventListener('change', apply);
document.addEventListener('keydown', e=>{ if(e.key==='/' && document.activeElement!==q){e.preventDefault();q.focus();} });
apply();
</script>
</body>
</html>
"""

html = HTML.replace("__PAYLOAD__", json.dumps(payload, ensure_ascii=False))
out1 = REPO / "guia-especialistas-agencia.html"
out1.write_text(html, encoding="utf-8")
docs = Path.home() / "Documentos" / "guia-especialistas-agencia.html"
if docs.parent.exists():
    docs.write_text(html, encoding="utf-8")
    print("gerado também:", docs)
print("gerado:", out1, f"({len(html)//1024} KB)")
