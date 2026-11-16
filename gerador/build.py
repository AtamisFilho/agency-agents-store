#!/usr/bin/env python3
"""Gera o guia-especialistas-agencia.html — self-contained, offline, 5 idiomas.

Dados: dados/agents.json + pt*.json + ex*.json (PT fonte) + tr/{en,es,fr,de}/*.json + when.json.
Fonte única de metadados (versão, divisões, tags, contagens): dados/meta.json —
nada de listas/contagens hard-coded aqui; o build valida declarativamente.
Saída: guia-especialistas-agencia.html na raiz do repo (e ~/Documentos se existir).
"""
import json, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DADOS = REPO / "dados"
meta = json.load(open(DADOS / "meta.json", encoding="utf-8"))
GUIA_VERSION = meta["version"]
OUR_REPO = meta["ourRepo"]

agents = json.load(open(DADOS / "agents.json", encoding="utf-8"))
squads_data = json.load(open(DADOS / "squads.json", encoding="utf-8"))
i18n = json.load(open(DADOS / "i18n.json", encoding="utf-8"))  # {en,pt,es,fr,de} -> {agents:{slug:{d,x[4]}}, when:{div,custom}}
when_pt = i18n["pt"]["when"]

INSTALLED_CLAUDE = set(meta["tags"]["claudeFiles"])
ZCODE_SLUGS = set(meta["tags"]["zcodeSlugs"])

# ---------- validação declarativa (falha cedo se dados e meta divergirem) ----------
_agent_divisions = {a["division"] for a in agents}
_meta_divisions = set(meta["divisions"])
assert _agent_divisions == _meta_divisions, (
    f"meta.json desalinhado com agents.json — divisões só em um lado: "
    f"{_meta_divisions ^ _agent_divisions}. Atualize dados/meta.json (e traduções) quando o catálogo mudar.")
_agent_slugs = {a["slug"] for a in agents}
_agent_files = {a["file"] for a in agents}
for _sq, _sd in squads_data.items():
    _sq_slugs = {x["slug"] for x in _sd["agentes"]}
    assert _sq_slugs <= _agent_slugs, f"squad {_sq} tem slugs fora do catálogo: {_sq_slugs - _agent_slugs}"
assert INSTALLED_CLAUDE <= _agent_files, f"tags.claudeFiles fora do catálogo: {INSTALLED_CLAUDE - _agent_files}"
assert ZCODE_SLUGS <= _agent_slugs, f"tags.zcodeSlugs fora do catálogo: {ZCODE_SLUGS - _agent_slugs}"

DIV_PT = {
    "academic": "Acadêmico & Narrativa", "design": "Design & UX", "engineering": "Engenharia",
    "finance": "Finanças", "game-development": "Jogos", "gis": "GIS & Mapas",
    "healthcare": "Saúde", "marketing": "Marketing & Conteúdo", "paid-media": "Mídia Paga (Anúncios)",
    "product": "Produto", "project-management": "Gestão de Projetos", "research": "Pesquisa",
    "sales": "Vendas", "security": "Segurança", "spatial-computing": "Computação Espacial (AR/VR)",
    "specialized": "Especialistas Diversos", "support": "Suporte & Operações", "testing": "Testes & QA",
}

TOOLS = [
    {"id": "claudeCode", "label": "Claude Code", "icon": "🤖", "kebab": "claude-code", "format": "identity",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dest": "~/.claude/agents/<slug>.md",
     "desc": "The Anthropic coding agent, in your terminal.",
     "descs": {"en": "The Anthropic coding agent, in your terminal.",
               "pt": "O assistente de código da Anthropic, no terminal.",
               "es": "El asistente de código de Anthropic, en la terminal.",
               "fr": "L'agent de code d'Anthropic, dans le terminal.",
               "de": "Der Coding-Agent von Anthropic, im Terminal."}},
    {"id": "zcode", "label": "ZCode", "icon": "🧭", "kebab": "zcode", "format": "zcode-md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dest": "~/.zcode/agents/<slug>.md",
     "desc": "The GLM/Z.ai coding agent (the one you are using now).",
     "descs": {"en": "The GLM/Z.ai coding agent (the one you are using now).",
               "pt": "O agente de código GLM/Z.ai (o que você está usando agora).",
               "es": "El agente de código GLM/Z.ai (el que estás usando ahora).",
               "fr": "L'agent de code GLM/Z.ai (celui que vous utilisez).",
               "de": "Der GLM/Z.ai-Coding-Agent (der, den Sie gerade nutzen)."}},
    {"id": "codex", "label": "Codex CLI", "icon": "⚙️", "kebab": "codex", "format": "toml",
     "compat": {"l": "sim", "m": "sim", "w": "wsl"}, "projectOnly": False, "main": True,
     "dest": "~/.codex/agents/<slug>.toml",
     "desc": "The OpenAI coding agent, in your terminal.",
     "descs": {"en": "The OpenAI coding agent, in your terminal.",
               "pt": "O agente de código da OpenAI, no terminal.",
               "es": "El agente de código de OpenAI, en la terminal.",
               "fr": "L'agent de code d'OpenAI, dans le terminal.",
               "de": "Der OpenAI-Coding-Agent, im Terminal."}},
    {"id": "geminiCli", "label": "Gemini CLI", "icon": "✨", "kebab": "gemini-cli", "format": "md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dest": "~/.gemini/agents/<slug>.md",
     "desc": "Google's coding agent, in your terminal.",
     "descs": {"en": "Google's coding agent, in your terminal.",
               "pt": "O agente de código do Google, no terminal.",
               "es": "El agente de código de Google, en la terminal.",
               "fr": "L'agent de code de Google, dans le terminal.",
               "de": "Googles Coding-Agent, im Terminal."}},
    {"id": "copilot", "label": "GitHub Copilot", "icon": "🐙", "kebab": "github-copilot", "format": "identity",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dest": "~/.github/agents/<slug>.md",
     "desc": "GitHub Copilot (VS Code, JetBrains and CLI) — agents folder.",
     "descs": {"en": "GitHub Copilot (VS Code, JetBrains and CLI) — agents folder.",
               "pt": "Copilot da GitHub (VS Code, JetBrains e CLI) — pasta de agentes.",
               "es": "Copilot de GitHub (VS Code, JetBrains y CLI) — carpeta de agentes.",
               "fr": "Copilot de GitHub (VS Code, JetBrains et CLI) — dossier d'agents.",
               "de": "GitHub Copilot (VS Code, JetBrains und CLI) — Agents-Ordner."}},
    {"id": "qwen", "label": "Qwen Code", "icon": "🌐", "kebab": "qwen", "format": "md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dest": "~/.qwen/agents/<slug>.md",
     "desc": "The Qwen (Alibaba) coding agent.",
     "descs": {"en": "The Qwen (Alibaba) coding agent.",
               "pt": "O agente de código do modelo Qwen (Alibaba).",
               "es": "El agente de código del modelo Qwen (Alibaba).",
               "fr": "L'agent de code du modèle Qwen (Alibaba).",
               "de": "Der Coding-Agent des Modells Qwen (Alibaba)."}},
    {"id": "opencode", "label": "opencode", "icon": "🔓", "kebab": "opencode", "format": "opencode-md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dest": "~/.config/opencode/agents/<slug>.md",
     "desc": "Open source multi-model coding agent.",
     "descs": {"en": "Open source multi-model coding agent.",
               "pt": "Agente de código open source multi-modelo.",
               "es": "Agente de código abierto multi-modelo.",
               "fr": "Agent de code open source multi-modèles.",
               "de": "Open-Source-Coding-Agent mit mehreren Modellen."}},
    {"id": "cursor", "label": "Cursor", "icon": "🖱️", "kebab": "cursor", "format": "mdc",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": True, "main": True,
     "dest": "<project>/.cursor/rules/<slug>.mdc",
     "desc": "AI editor — rules/agents live INSIDE each project.",
     "descs": {"en": "AI editor — rules/agents live INSIDE each project.",
               "pt": "Editor com IA — regras/agentes ficam DENTRO de cada projeto.",
               "es": "Editor con IA — reglas/agentes viven DENTRO de cada proyecto.",
               "fr": "Éditeur IA — règles/agents vivent DANS chaque projet.",
               "de": "KI-Editor — Regeln/Agenten liegen IN jedem Projekt."}},
    {"id": "antigravity", "label": "Antigravity", "icon": "🛸", "kebab": "antigravity", "format": "skill-md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": True,
     "dest": "~/.gemini/config/skills/<slug>/SKILL.md",
     "desc": "Google's agentic IDE (Gemini 3).",
     "descs": {"en": "Google's agentic IDE (Gemini 3).",
               "pt": "O IDE agêntico do Google (Gemini 3).",
               "es": "El IDE agéntico de Google (Gemini 3).",
               "fr": "L'IDE agentique de Google (Gemini 3).",
               "de": "Googles agentische IDE (Gemini 3)."}},
    {"id": "osaurus", "label": "Osaurus", "icon": "🦕", "kebab": "osaurus", "format": "skill-md",
     "compat": {"l": "nao", "m": "sim", "w": "nao"}, "projectOnly": False, "main": True,
     "dest": "~/.osaurus/skills/agency-<slug>/SKILL.md",
     "desc": "Native local AI app — macOS only.",
     "descs": {"en": "Native local AI app — macOS only.",
               "pt": "App nativo de IA local — só no macOS.",
               "es": "App nativa de IA local — solo en macOS.",
               "fr": "App native d'IA locale — macOS uniquement.",
               "de": "Native lokale KI-App — nur macOS."}},
    {"id": "kimi", "label": "Kimi CLI", "icon": "🌙", "kebab": "kimi", "format": "kimi-dir",
     "compat": {"l": "sim", "m": "sim", "w": "wsl"}, "projectOnly": False, "main": False,
     "dest": "~/.config/kimi/agents/<slug>/",
     "desc": "The Kimi (Moonshot) coding agent.",
     "descs": {"en": "The Kimi (Moonshot) coding agent.",
               "pt": "Agente de código do modelo Kimi (Moonshot).",
               "es": "El agente de código del modelo Kimi (Moonshot).",
               "fr": "L'agent de code du modèle Kimi (Moonshot).",
               "de": "Der Coding-Agent des Modells Kimi (Moonshot)."}},
    {"id": "vibe", "label": "Mistral Vibe", "icon": "🌬️", "kebab": "vibe", "format": "vibe-dir",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": False,
     "dest": "~/.vibe/agents/<slug>.toml + prompts",
     "desc": "Mistral's agentic CLI (advanced).",
     "descs": {"en": "Mistral's agentic CLI (advanced).",
               "pt": "CLI agêntica da Mistral (avançado).",
               "es": "CLI agéntica de Mistral (avanzado).",
               "fr": "CLI agentique de Mistral (avancé).",
               "de": "Mistrals agentische CLI (fortgeschritten)."}},
    {"id": "dsh", "label": "DeepSeek Harness", "icon": "🐋", "kebab": "dsh", "format": "skill-md",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": False,
     "dest": "~/.dsh/skills/<slug>/SKILL.md",
     "desc": "DeepSeek skills harness (advanced).",
     "descs": {"en": "DeepSeek skills harness (advanced).",
               "pt": "Harness de skills do DeepSeek (avançado).",
               "es": "Harness de skills de DeepSeek (avanzado).",
               "fr": "Harness de skills DeepSeek (avancé).",
               "de": "DeepSeek-Skills-Harness (fortgeschritten)."}},
    {"id": "openclaw", "label": "OpenClaw", "icon": "🦞", "kebab": "openclaw", "format": "openclaw-dir",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": False, "main": False,
     "dest": "~/.openclaw/agency-agents/<slug>/",
     "desc": "Agent runtime with memory/identity (advanced).",
     "descs": {"en": "Agent runtime with memory/identity (advanced).",
               "pt": "Runtime de agentes com memória/identidade (avançado).",
               "es": "Runtime de agentes con memoria/identidad (avanzado).",
               "fr": "Runtime d'agents avec mémoire/identité (avancé).",
               "de": "Agent-Runtime mit Speicher/Identität (fortgeschritten)."}},
    {"id": "aider", "label": "Aider", "icon": "🩹", "kebab": "aider", "format": "roster",
     "compat": {"l": "sim", "m": "sim", "w": "wsl"}, "projectOnly": True, "main": False,
     "dest": "<project>/CONVENTIONS.md (single roster)",
     "desc": "AI pair programming in the terminal — shared index (advanced).",
     "descs": {"en": "AI pair programming in the terminal — shared index (advanced).",
               "pt": "Programação par com IA no terminal — índice coletivo (avançado).",
               "es": "Programación en pareja con IA en la terminal — índice colectivo (avanzado).",
               "fr": "Programmation en binôme avec l'IA au terminal — index collectif (avancé).",
               "de": "KI-Paarprogrammierung im Terminal — gemeinsamer Index (fortgeschritten)."}},
    {"id": "windsurf", "label": "Windsurf", "icon": "🏄", "kebab": "windsurf", "format": "windsurf",
     "compat": {"l": "sim", "m": "sim", "w": "sim"}, "projectOnly": True, "main": False,
     "dest": "<project>/.windsurfrules (single roster)",
     "desc": "Codeium's AI editor — per-project rules (advanced).",
     "descs": {"en": "Codeium's AI editor — per-project rules (advanced).",
               "pt": "Editor com IA da Codeium — regras por projeto (avançado).",
               "es": "Editor con IA de Codeium — reglas por proyecto (avanzado).",
               "fr": "Éditeur IA de Codeium — règles par projet (avancé).",
               "de": "Codeiums KI-Editor — Regeln pro Projekt (fortgeschritten)."}},
]

DIV_I18N = {
    "en": {"academic": "Academic & Narrative", "design": "Design & UX", "engineering": "Engineering",
           "finance": "Finance", "game-development": "Games", "gis": "GIS & Maps", "healthcare": "Healthcare",
           "marketing": "Marketing & Content", "paid-media": "Paid Media (Ads)", "product": "Product",
           "project-management": "Project Management", "research": "Research", "sales": "Sales",
           "security": "Security", "spatial-computing": "Spatial Computing (AR/VR)", "specialized": "Specialists",
           "support": "Support & Operations", "testing": "Testing & QA"},
    "pt": DIV_PT,
    "es": {"academic": "Académico y Narrativa", "design": "Diseño y UX", "engineering": "Ingeniería",
           "finance": "Finanzas", "game-development": "Juegos", "gis": "SIG y Mapas", "healthcare": "Salud",
           "marketing": "Marketing y Contenido", "paid-media": "Medios Pagos (Anuncios)", "product": "Producto",
           "project-management": "Gestión de Proyectos", "research": "Investigación", "sales": "Ventas",
           "security": "Seguridad", "spatial-computing": "Computación Espacial (AR/VR)", "specialized": "Especialistas",
           "support": "Soporte y Operaciones", "testing": "Pruebas y QA"},
    "fr": {"academic": "Académique & Narratif", "design": "Design & UX", "engineering": "Ingénierie",
           "finance": "Finance", "game-development": "Jeux", "gis": "SIG & Cartes", "healthcare": "Santé",
           "marketing": "Marketing & Contenu", "paid-media": "Média Payant (Pub)", "product": "Produit",
           "project-management": "Gestion de Projet", "research": "Recherche", "sales": "Ventes",
           "security": "Sécurité", "spatial-computing": "Informatique Spatiale (AR/VR)", "specialized": "Spécialistes",
           "support": "Support & Opérations", "testing": "Tests & QA"},
    "de": {"academic": "Akademisch & Narrativ", "design": "Design & UX", "engineering": "Engineering",
           "finance": "Finanzen", "game-development": "Spiele", "gis": "GIS & Karten", "healthcare": "Gesundheit",
           "marketing": "Marketing & Inhalte", "paid-media": "Paid Media (Werbung)", "product": "Produkt",
           "project-management": "Projektmanagement", "research": "Forschung", "sales": "Vertrieb",
           "security": "Sicherheit", "spatial-computing": "Spatial Computing (AR/VR)", "specialized": "Spezialisten",
           "support": "Support & Betrieb", "testing": "Tests & QA"},
}

UI_I18N = {
"en": {
 "title": "🧭 Specialist Guide — Agency Agents",
 "sub": "Your consultation catalog: who each specialist is, what they do and when to call them. Works offline — the update check only uses internet when you ask (or every 24h).",
 "statTotal": "specialists in the catalog", "statInst": "installed in your tools",
 "statTools": "tools ready to use", "statDiv": "divisions (fields of work)",
 "machineTitle": "🖥️ Your machine & your tools",
 "machineNo": "🖥️ {os} (detected by the browser) — <b>to see your tools, run the installer</b> (the project's <code>instaladores/</code> folder). It creates the <code>guia-status.js</code> file next to this guide.",
 "mOs": "🖥️ {os} detected by the installer", "mCat": " · 📚 catalog at <code>{path}</code> updated on {date}", "mCheck": " · 🕒 checked on {when}",
 "stReady": "✅ Ready · {n} specialist(s)", "stDetected": "🟢 Installed · no store specialists yet",
 "stAbsent": "⚪ Not installed (optional)", "stIncompat": "🌐 Not available for {os}",
 "stUnknown": "❓ Run the installer to detect", "wslNote": "On Windows: via WSL",
 "btnInstall": "➕ Install specialists into a tool", "btnRecheck": "🔄 Check for updates now",
 "updBadge": "Update available",
 "howTitle": "🚀 How to call a specialist",
 "how1": "<b>With me (ZCode), right now:</b> just ask in plain language.",
 "howEx": "💬 “Use the <b>reality-checker</b> to verify with proof that login is working”",
 "how2": "<b>In the installed tools:</b> specialists appear as subagents — mention the name in your request (e.g. in Claude Code, in any folder; in ZCode, open the session in the project folder).",
 "how3": "<b>To “hire” more specialists:</b> use the <b>Install specialists</b> button above — the guide asks where and who, and generates the ready command/plan.",
 "goldenTitle": "📏 The 5 golden rules (from the official Playbook)",
 "g1": "<b>Describe the outcome, not the steps.</b> Say what “done” means.",
 "g2": "<b>Build a team, not a soloist.</b> A builder + a critic (e.g. code-reviewer + reality-checker) beat two builders.",
 "g3": "<b>Loop until there's evidence.</b> “It compiles” is not “it works”. Demand proof: a passing test, a log, a screenshot.",
 "g4": "<b>Feed it context.</b> Point at files, constraints and success criteria before asking.",
 "g5": "<b>Start with one, then scale.</b> One agent, one task, one project — then grow into a team.",
 "searchPh": "🔎 Search by name, role or situation… (press / to focus)",
 "onlyInst": "only installed ones", "showingTpl": "showing {a} of {b}",
 "teamSep": "⭐ Your current team", "teamSepSub": "installed and ready to work",
 "catSep": "📚 Full catalog", "catSepSub": "the talent pool — search, filter and “hire” when needed",
 "empty": "No specialist found with these filters.",
 "whenLabel": "<b>When to call:</b>", "situations": "💡 Real situations", "origEn": "original English text + file",
 "w1t": "Where to install? (1/3)", "w1sub": "These are the tools your system supports. Pick one or more.",
 "w2t": "Who to hire? (2/3)", "w2sub": "Choose the team size. You can change it later, anytime.",
 "sqPre": "⭐ Pre-launch squad (12)", "sqPreD": "Who you need before launch: reviewer, devops, testing, security and planning.",
 "sqTrain": "🎓 Training squad (4)", "sqTrainD": "The minimal team to learn the flow: review, proof, API and planning.",
 "sqAll": "🏫 All {n} specialists", "sqAllD": "The whole agency — useful if your tool lists agents in a menu.",
 "sqDiv": "🗂️ Choose by division", "sqDivD": "You check the divisions (Engineering, Marketing…) and take everyone from that area.",
 "w3t": "Done! (3/3)", "w3sub": "That's <b>{n}</b> specialists for <b>{tools}</b>. Two simple steps:",
 "wStep1": "Save the installation plan to your computer:",
 "wDownload": "⬇️ Download agency-plan.json",
 "wStep2": "Open a terminal in the folder where you saved this guide and run the installer with the plan:",
 "wNote": "The installer asks only what's needed, backs up what already exists and, at the end, updates this page's panel automatically.",
 "btnBack": "← Back", "btnNext": "Continue →", "btnClose": "Close",
 "errNeedTool": "Pick at least one tool 🙂", "errNeedDiv": "Check at least one division 🙂",
 "footer": "Guide <span id=\"fVer\"></span> · Catalog <b>msitarzewski/agency-agents</b> (MIT) · Installer <b>Agency Agents App</b> · Plain-language descriptions and situations; the original English is in each card's details.",
 "osWindows": "Windows", "osMacos": "macOS", "osLinux": "Linux", "osAndroid": "Android", "osUnknown": "Unknown system",
 "langLabel": "Language", "printHint": "🖨️ Print / save as PDF",
},
"pt": {
 "title": "🧭 Guia de Especialistas — Agency Agents",
 "sub": "Seu catálogo de consulta: quem é cada especialista, o que faz e quando chamá-lo. Funciona offline — a checagem de atualizações usa internet só quando você pede (ou a cada 24h).",
 "statTotal": "especialistas no catálogo", "statInst": "instalados nas suas ferramentas",
 "statTools": "ferramentas prontas para uso", "statDiv": "divisões (áreas de atuação)",
 "machineTitle": "🖥️ Sua máquina & suas ferramentas",
 "machineNo": "🖥️ {os} (detectado pelo navegador) — <b>para enxergar suas ferramentas, rode o instalador</b> (pasta <code>instaladores/</code> do projeto). Ele cria o arquivo <code>guia-status.js</code> ao lado deste guia.",
 "mOs": "🖥️ {os} detectado pelo instalador", "mCat": " · 📚 catálogo em <code>{path}</code> atualizado em {date}", "mCheck": " · 🕒 verificado em {when}",
 "stReady": "✅ Pronta · {n} especialista(s)", "stDetected": "🟢 Instalada · sem especialistas da agência",
 "stAbsent": "⚪ Não instalada (opcional)", "stIncompat": "🌐 Não disponível para {os}",
 "stUnknown": "❓ Rodar o instalador para detectar", "wslNote": "No Windows: via WSL",
 "btnInstall": "➕ Instalar especialistas numa ferramenta", "btnRecheck": "🔄 Verificar atualizações agora",
 "updBadge": "Atualização disponível",
 "howTitle": "🚀 Como chamar um especialista",
 "how1": "<b>Comigo (ZCode), agora mesmo:</b> basta pedir em linguagem natural.",
 "howEx": "💬 “Use o <b>reality-checker</b> para verificar com provas se o login está funcionando”",
 "how2": "<b>Nas ferramentas instaladas:</b> os especialistas aparecem como subagentes — mencione o nome dele no pedido (ex.: no Claude Code, em qualquer pasta; no ZCode, abra a sessão na pasta do projeto).",
 "how3": "<b>Para “contratar” mais especialistas:</b> use o botão <b>Instalar especialistas</b> acima — o guia pergunta onde e o quê, e gera o comando/planinho pronto.",
 "goldenTitle": "📏 As 5 regras de ouro (do Playbook oficial)",
 "g1": "<b>Descreva o resultado, não os passos.</b> Diga o que “pronto” significa.",
 "g2": "<b>Monte equipe, não solista.</b> Um construtor + um crítico (ex.: code-reviewer + reality-checker) valem mais que dois construtores.",
 "g3": "<b>Repita até ter evidência.</b> “Compilou” não é “funciona”. Exija prova: teste rodando, log, print.",
 "g4": "<b>Alimente com contexto.</b> Aponte arquivos, restrições e critérios de sucesso antes de pedir.",
 "g5": "<b>Comece com um, depois escale.</b> Um agente, uma tarefa, um projeto — depois vire time.",
 "searchPh": "🔎 Buscar por nome, função ou situação… (tecle / para focar)",
 "onlyInst": "só os instalados", "showingTpl": "mostrando {a} de {b}",
 "teamSep": "⭐ Sua equipe atual", "teamSepSub": "instalados e prontos para trabalhar",
 "catSep": "📚 Catálogo completo", "catSepSub": "o banco de talentos — busque, filtre e “contrate” quando precisar",
 "empty": "Nenhum especialista encontrado com esses filtros.",
 "whenLabel": "<b>Quando chamar:</b>", "situations": "💡 Situações reais", "origEn": "original em inglês + arquivo",
 "w1t": "Onde instalar? (1/3)", "w1sub": "Estas são as ferramentas que seu sistema suporta. Escolha uma ou mais.",
 "w2t": "Quem contratar? (2/3)", "w2sub": "Escolha o tamanho do time. Você pode mudar depois quando quiser.",
 "sqPre": "⭐ Squad pré-lançamento (12)", "sqPreD": "Quem você precisa antes de lançar: revisor, devops, testes, segurança e planejamento.",
 "sqTrain": "🎓 Squad de treino (4)", "sqTrainD": "O time mínimo para aprender o fluxo: revisão, prova, API e planejamento.",
 "sqAll": "🏫 Todos os {n} especialistas", "sqAllD": "A agência inteira — útil se sua ferramenta lista os agentes num menu.",
 "sqDiv": "🗂️ Escolher por área", "sqDivD": "Você marca as divisões (Engenharia, Marketing…) e leva todos daquela área.",
 "w3t": "Pronto! (3/3)", "w3sub": "São <b>{n}</b> especialistas para <b>{tools}</b>. Dois passos simples:",
 "wStep1": "Salve o planinho da instalação no seu computador:",
 "wDownload": "⬇️ Baixar agency-plan.json",
 "wStep2": "Abra o terminal na pasta onde você salvou o guia e rode o instalador com o planinho:",
 "wNote": "O instalador pergunta só o necessário, faz backup do que já existe e, no fim, atualiza o painel desta página automaticamente.",
 "btnBack": "← Voltar", "btnNext": "Continuar →", "btnClose": "Fechar",
 "errNeedTool": "Escolha pelo menos uma ferramenta 🙂", "errNeedDiv": "Marque pelo menos uma área 🙂",
 "footer": "Guia <span id=\"fVer\"></span> · Catálogo <b>msitarzewski/agency-agents</b> (MIT) · Instalador <b>Agency Agents App</b> · Descrições e situações traduzidas para leigos; o original em inglês fica no detalhe de cada card.",
 "osWindows": "Windows", "osMacos": "macOS", "osLinux": "Linux", "osAndroid": "Android", "osUnknown": "Sistema não identificado",
 "langLabel": "Idioma", "printHint": "🖨️ Imprimir / salvar em PDF",
},
"es": {
 "title": "🧭 Guía de Especialistas — Agency Agents",
 "sub": "Tu catálogo de consulta: quién es cada especialista, qué hace y cuándo llamarlo. Funciona sin conexión — la verificación de actualizaciones solo usa internet cuando pides (o cada 24h).",
 "statTotal": "especialistas en el catálogo", "statInst": "instalados en tus herramientas",
 "statTools": "herramientas listas para usar", "statDiv": "divisiones (áreas de actuación)",
 "machineTitle": "🖥️ Tu máquina y tus herramientas",
 "machineNo": "🖥️ {os} (detectado por el navegador) — <b>para ver tus herramientas, ejecuta el instalador</b> (carpeta <code>instaladores/</code> del proyecto). Crea el archivo <code>guia-status.js</code> junto a esta guía.",
 "mOs": "🖥️ {os} detectado por el instalador", "mCat": " · 📚 catálogo en <code>{path}</code> actualizado el {date}", "mCheck": " · 🕒 verificado el {when}",
 "stReady": "✅ Lista · {n} especialista(s)", "stDetected": "🟢 Instalada · sin especialistas de la agencia",
 "stAbsent": "⚪ No instalada (opcional)", "stIncompat": "🌐 No disponible para {os}",
 "stUnknown": "❓ Ejecuta el instalador para detectar", "wslNote": "En Windows: vía WSL",
 "btnInstall": "➕ Instalar especialistas en una herramienta", "btnRecheck": "🔄 Verificar actualizaciones ahora",
 "updBadge": "Actualización disponible",
 "howTitle": "🚀 Cómo llamar a un especialista",
 "how1": "<b>Conmigo (ZCode), ahora mismo:</b> solo pídelo en lenguaje natural.",
 "howEx": "💬 «Usa el <b>reality-checker</b> para verificar con pruebas que el login funciona»",
 "how2": "<b>En las herramientas instaladas:</b> los especialistas aparecen como subagentes — menciona su nombre en el pedido (ej. en Claude Code, en cualquier carpeta; en ZCode, abre la sesión en la carpeta del proyecto).",
 "how3": "<b>Para «contratar» más especialistas:</b> usa el botón <b>Instalar especialistas</b> de arriba — la guía pregunta dónde y quién, y genera el comando/plan listo.",
 "goldenTitle": "📏 Las 5 reglas de oro (del Playbook oficial)",
 "g1": "<b>Describe el resultado, no los pasos.</b> Di qué significa “listo”.",
 "g2": "<b>Arma equipo, no solista.</b> Un constructor + un crítico (ej. code-reviewer + reality-checker) valen más que dos constructores.",
 "g3": "<b>Repite hasta tener evidencia.</b> “Compiló” no es “funciona”. Exige prueba: test corriendo, log, captura.",
 "g4": "<b>Aliméntalo con contexto.</b> Señala archivos, restricciones y criterios de éxito antes de pedir.",
 "g5": "<b>Empieza con uno, luego escala.</b> Un agente, una tarea, un proyecto — después hazte equipo.",
 "searchPh": "🔎 Buscar por nombre, función o situación… (pulsa / para enfocar)",
 "onlyInst": "solo los instalados", "showingTpl": "mostrando {a} de {b}",
 "teamSep": "⭐ Tu equipo actual", "teamSepSub": "instalados y listos para trabajar",
 "catSep": "📚 Catálogo completo", "catSepSub": "el banco de talentos — busca, filtra y «contrata» cuando necesites",
 "empty": "Ningún especialista encontrado con estos filtros.",
 "whenLabel": "<b>Cuándo llamar:</b>", "situations": "💡 Situaciones reales", "origEn": "texto original en inglés + archivo",
 "w1t": "¿Dónde instalar? (1/3)", "w1sub": "Estas son las herramientas que tu sistema soporta. Elige una o más.",
 "w2t": "¿A quién contratar? (2/3)", "w2sub": "Elige el tamaño del equipo. Puedes cambiarlo después cuando quieras.",
 "sqPre": "⭐ Escuadrón pre-lanzamiento (12)", "sqPreD": "Lo que necesitas antes de lanzar: revisor, devops, pruebas, seguridad y planificación.",
 "sqTrain": "🎓 Escuadrón de entrenamiento (4)", "sqTrainD": "El equipo mínimo para aprender el flujo: revisión, prueba, API y planificación.",
 "sqAll": "🏫 Todos los {n} especialistas", "sqAllD": "Toda la agencia — útil si tu herramienta lista los agentes en un menú.",
 "sqDiv": "🗂️ Elegir por área", "sqDivD": "Marcas las divisiones (Ingeniería, Marketing…) y llevas a todos de esa área.",
 "w3t": "¡Listo! (3/3)", "w3sub": "Son <b>{n}</b> especialistas para <b>{tools}</b>. Dos pasos simples:",
 "wStep1": "Guarda el plan de instalación en tu computadora:",
 "wDownload": "⬇️ Descargar agency-plan.json",
 "wStep2": "Abre la terminal en la carpeta donde guardaste la guía y ejecuta el instalador con el plan:",
 "wNote": "El instalador pregunta solo lo necesario, hace backup de lo que ya existe y, al final, actualiza el panel de esta página automáticamente.",
 "btnBack": "← Volver", "btnNext": "Continuar →", "btnClose": "Cerrar",
 "errNeedTool": "Elige al menos una herramienta 🙂", "errNeedDiv": "Marca al menos un área 🙂",
 "footer": "Guía <span id=\"fVer\"></span> · Catálogo <b>msitarzewski/agency-agents</b> (MIT) · Instalador <b>Agency Agents App</b> · Descripciones y situaciones traducidas para principiantes; el original en inglés está en el detalle de cada tarjeta.",
 "osWindows": "Windows", "osMacos": "macOS", "osLinux": "Linux", "osAndroid": "Android", "osUnknown": "Sistema no identificado",
 "langLabel": "Idioma", "printHint": "🖨️ Imprimir / guardar en PDF",
},
"fr": {
 "title": "🧭 Guide des Spécialistes — Agency Agents",
 "sub": "Votre catalogue de consultation : qui est chaque spécialiste, ce qu'il fait et quand l'appeler. Fonctionne hors ligne — la vérification des mises à jour n'utilise internet que sur demande (ou toutes les 24h).",
 "statTotal": "spécialistes au catalogue", "statInst": "installés dans vos outils",
 "statTools": "outils prêts à l'emploi", "statDiv": "divisions (domaines d'action)",
 "machineTitle": "🖥️ Votre machine et vos outils",
 "machineNo": "🖥️ {os} (détecté par le navigateur) — <b>pour voir vos outils, lancez l'installateur</b> (dossier <code>instaladores/</code> du projet). Il crée le fichier <code>guia-status.js</code> à côté de ce guide.",
 "mOs": "🖥️ {os} détecté par l'installateur", "mCat": " · 📚 catalogue dans <code>{path}</code> mis à jour le {date}", "mCheck": " · 🕒 vérifié le {when}",
 "stReady": "✅ Prêt · {n} spécialiste(s)", "stDetected": "🟢 Installé · aucun spécialiste de l'agence",
 "stAbsent": "⚪ Non installé (facultatif)", "stIncompat": "🌐 Non disponible pour {os}",
 "stUnknown": "❓ Lancez l'installateur pour détecter", "wslNote": "Sous Windows : via WSL",
 "btnInstall": "➕ Installer des spécialistes dans un outil", "btnRecheck": "🔄 Vérifier les mises à jour",
 "updBadge": "Mise à jour disponible",
 "howTitle": "🚀 Comment appeler un spécialiste",
 "how1": "<b>Avec moi (ZCode), tout de suite :</b> demandez simplement en langage naturel.",
 "howEx": "💬 « Utilise le <b>reality-checker</b> pour vérifier avec preuve que le login fonctionne »",
 "how2": "<b>Dans les outils installés :</b> les spécialistes apparaissent comme sous-agents — mentionnez leur nom dans la demande (ex. dans Claude Code, dans n'importe quel dossier ; dans ZCode, ouvrez la session dans le dossier du projet).",
 "how3": "<b>Pour « recruter » plus de spécialistes :</b> utilisez le bouton <b>Installer des spécialistes</b> ci-dessus — le guide demande où et qui, et génère la commande/le plan prêts.",
 "goldenTitle": "📏 Les 5 règles d'or (du Playbook officiel)",
 "g1": "<b>Décrivez le résultat, pas les étapes.</b> Dites ce que signifie « terminé ».",
 "g2": "<b>Constituez une équipe, pas un soliste.</b> Un constructeur + un critique (ex. code-reviewer + reality-checker) valent mieux que deux constructeurs.",
 "g3": "<b>Bouclez jusqu'à preuve.</b> « Ça compile » n'est pas « ça marche ». Exigez une preuve : test qui passe, log, capture.",
 "g4": "<b>Nourrissez le contexte.</b> Pointez les fichiers, contraintes et critères de succès avant de demander.",
 "g5": "<b>Commencez par un, puis évoluez.</b> Un agent, une tâche, un projet — puis devenez une équipe.",
 "searchPh": "🔎 Rechercher par nom, rôle ou situation… (tapez / pour focus)",
 "onlyInst": "seulement les installés", "showingTpl": "affichage {a} sur {b}",
 "teamSep": "⭐ Votre équipe actuelle", "teamSepSub": "installés et prêts à travailler",
 "catSep": "📚 Catalogue complet", "catSepSub": "le vivier de talents — cherchez, filtrez et « recrutez » au besoin",
 "empty": "Aucun spécialiste trouvé avec ces filtres.",
 "whenLabel": "<b>Quand l'appeler :</b>", "situations": "💡 Situations réelles", "origEn": "texte original en anglais + fichier",
 "w1t": "Où installer ? (1/3)", "w1sub": "Voici les outils que votre système prend en charge. Choisissez-en un ou plusieurs.",
 "w2t": "Qui recruter ? (2/3)", "w2sub": "Choisissez la taille de l'équipe. Vous pourrez changer plus tard.",
 "sqPre": "⭐ Escouade pré-lancement (12)", "sqPreD": "Ce qu'il vous faut avant de lancer : relecteur, devops, tests, sécurité et planification.",
 "sqTrain": "🎓 Escouade d'entraînement (4)", "sqTrainD": "L'équipe minimale pour apprendre le flux : revue, preuve, API et planification.",
 "sqAll": "🏫 Tous les {n} spécialistes", "sqAllD": "Toute l'agence — utile si votre outil liste les agents dans un menu.",
 "sqDiv": "🗂️ Choisir par division", "sqDivD": "Cochez les divisions (Ingénierie, Marketing…) et prenez tous ceux du domaine.",
 "w3t": "C'est prêt ! (3/3)", "w3sub": "Soit <b>{n}</b> spécialistes pour <b>{tools}</b>. Deux étapes simples :",
 "wStep1": "Enregistrez le plan d'installation sur votre ordinateur :",
 "wDownload": "⬇️ Télécharger agency-plan.json",
 "wStep2": "Ouvrez un terminal dans le dossier où vous avez enregistré ce guide et lancez l'installateur avec le plan :",
 "wNote": "L'installateur ne demande que le nécessaire, sauvegarde ce qui existe et, à la fin, met à jour automatiquement le panneau de cette page.",
 "btnBack": "← Retour", "btnNext": "Continuer →", "btnClose": "Fermer",
 "errNeedTool": "Choisissez au moins un outil 🙂", "errNeedDiv": "Cochez au moins une division 🙂",
 "footer": "Guide <span id=\"fVer\"></span> · Catalogue <b>msitarzewski/agency-agents</b> (MIT) · Installateur <b>Agency Agents App</b> · Descriptions et situations traduites pour débutants ; l'original anglais est dans le détail de chaque carte.",
 "osWindows": "Windows", "osMacos": "macOS", "osLinux": "Linux", "osAndroid": "Android", "osUnknown": "Système non identifié",
 "langLabel": "Langue", "printHint": "🖨️ Imprimer / enregistrer en PDF",
},
"de": {
 "title": "🧭 Spezialisten-Guide — Agency Agents",
 "sub": "Ihr Nachschlagewerk: wer jeder Spezialist ist, was er tut und wann man ihn ruft. Funktioniert offline — die Update-Prüfung nutzt nur auf Wunsch Internet (oder alle 24h).",
 "statTotal": "Spezialisten im Katalog", "statInst": "in Ihren Tools installiert",
 "statTools": "Tools einsatzbereit", "statDiv": "Abteilungen (Einsatzgebiete)",
 "machineTitle": "🖥️ Ihr Rechner & Ihre Tools",
 "machineNo": "🖥️ {os} (vom Browser erkannt) — <b>um Ihre Tools zu sehen, führen Sie den Installer aus</b> (Ordner <code>instaladores/</code> des Projekts). Er erstellt die Datei <code>guia-status.js</code> neben diesem Guide.",
 "mOs": "🖥️ {os} vom Installer erkannt", "mCat": " · 📚 Katalog in <code>{path}</code>, aktualisiert am {date}", "mCheck": " · 🕒 geprüft am {when}",
 "stReady": "✅ Bereit · {n} Spezialist(en)", "stDetected": "🟢 Installiert · noch keine Agentur-Spezialisten",
 "stAbsent": "⚪ Nicht installiert (optional)", "stIncompat": "🌐 Nicht verfügbar für {os}",
 "stUnknown": "❓ Installer ausführen zum Erkennen", "wslNote": "Unter Windows: über WSL",
 "btnInstall": "➕ Spezialisten in einem Tool installieren", "btnRecheck": "🔄 Jetzt nach Updates suchen",
 "updBadge": "Update verfügbar",
 "howTitle": "🚀 So rufen Sie einen Spezialisten",
 "how1": "<b>Mit mir (ZCode), sofort:</b> fragen Sie einfach in natürlicher Sprache.",
 "howEx": "💬 „Benutze den <b>reality-checker</b>, um mit Beweisen zu prüfen, ob der Login funktioniert“",
 "how2": "<b>In den installierten Tools:</b> Spezialisten erscheinen als Subagenten — nennen Sie den Namen in Ihrer Anfrage (z. B. in Claude Code in jedem Ordner; in ZCode Sitzung im Projektordner öffnen).",
 "how3": "<b>Um weitere Spezialisten zu „eingstellen“:</b> nutzen Sie die Schaltfläche <b>Spezialisten installieren</b> oben — der Guide fragt wohin und wen, und erzeugt den fertigen Befehl/Plan.",
 "goldenTitle": "📏 Die 5 goldenen Regeln (aus dem offiziellen Playbook)",
 "g1": "<b>Beschreiben Sie das Ergebnis, nicht die Schritte.</b> Sagen Sie, was „fertig“ bedeutet.",
 "g2": "<b>Bauen Sie ein Team, keinen Solisten.</b> Ein Builder + ein Kritiker (z. B. code-reviewer + reality-checker) schlagen zwei Builder.",
 "g3": "<b>Schleifen Sie bis zum Beweis.</b> „Es kompiliert“ ist nicht „es funktioniert“. Fordern Sie Beweise: laufender Test, Log, Screenshot.",
 "g4": "<b>Füttern Sie mit Kontext.</b> Zeigen Sie auf Dateien, Einschränkungen und Erfolgskriterien, bevor Sie fragen.",
 "g5": "<b>Starten Sie mit einem, dann skalieren.</b> Ein Agent, eine Aufgabe, ein Projekt — dann wird's ein Team.",
 "searchPh": "🔎 Nach Name, Funktion oder Situation suchen… (/, zum Fokussieren)",
 "onlyInst": "nur installierte", "showingTpl": "zeige {a} von {b}",
 "teamSep": "⭐ Ihr aktuelles Team", "teamSepSub": "installiert und einsatzbereit",
 "catSep": "📚 Gesamtkatalog", "catSepSub": "der Talentpool — suchen, filtern und bei Bedarf „einstellen“",
 "empty": "Kein Spezialist mit diesen Filtern gefunden.",
 "whenLabel": "<b>Wann aufrufen:</b>", "situations": "💡 Echte Situationen", "origEn": "Originaltext Englisch + Datei",
 "w1t": "Wohin installieren? (1/3)", "w1sub": "Dies sind die Tools, die Ihr System unterstützt. Wählen Sie eines oder mehrere.",
 "w2t": "Wen einstellen? (2/3)", "w2sub": "Wählen Sie die Teamgröße. Sie können es später jederzeit ändern.",
 "sqPre": "⭐ Pre-Launch-Team (12)", "sqPreD": "Was Sie vor dem Launch brauchen: Reviewer, DevOps, Tests, Sicherheit und Planung.",
 "sqTrain": "🎓 Trainings-Team (4)", "sqTrainD": "Das Minimallteam für den Einstieg: Review, Beweis, API und Planung.",
 "sqAll": "🏫 Alle {n} Spezialisten", "sqAllD": "Die ganze Agentur — nützlich, wenn Ihr Tool die Agenten in einem Menü listet.",
 "sqDiv": "🗂️ Nach Abteilung wählen", "sqDivD": "Markieren Sie Abteilungen (Engineering, Marketing…) und nehmen Sie alle aus diesem Bereich.",
 "w3t": "Fertig! (3/3)", "w3sub": "Das sind <b>{n}</b> Spezialisten für <b>{tools}</b>. Zwei einfache Schritte:",
 "wStep1": "Speichern Sie den Installationsplan auf Ihrem Rechner:",
 "wDownload": "⬇️ agency-plan.json herunterladen",
 "wStep2": "Öffnen Sie ein Terminal im Ordner, in dem Sie diesen Guide gespeichert haben, und führen Sie den Installer mit dem Plan aus:",
 "wNote": "Der Installer fragt nur das Nötige, sichert Bestehendes und aktualisiert am Ende automatisch das Panel dieser Seite.",
 "btnBack": "← Zurück", "btnNext": "Weiter →", "btnClose": "Schließen",
 "errNeedTool": "Wählen Sie mindestens ein Tool 🙂", "errNeedDiv": "Markieren Sie mindestens eine Abteilung 🙂",
 "footer": "Guide <span id=\"fVer\"></span> · Katalog <b>msitarzewski/agency-agents</b> (MIT) · Installer <b>Agency Agents App</b> · Beschreibungen und Situationen übersetzt für Einsteiger; das englische Original in den Details jeder Karte.",
 "osWindows": "Windows", "osMacos": "macOS", "osLinux": "Linux", "osAndroid": "Android", "osUnknown": "System nicht erkannt",
 "langLabel": "Sprache", "printHint": "🖨️ Drucken / als PDF speichern",
},
}

# paridade de chaves entre idiomas (falha cedo se eu esquecer algo)
BASE = set(UI_I18N["en"].keys())
for lang, d in UI_I18N.items():
    assert set(d.keys()) == BASE, f"UI_I18N[{lang}] desalinhado: {BASE ^ set(d.keys())}"
for lang, d in DIV_I18N.items():
    assert set(d.keys()) == set(DIV_I18N["en"].keys()), f"DIV_I18N[{lang}] desalinhado"
for t in TOOLS:
    assert set(t["descs"].keys()) == {"en","pt","es","fr","de"}, f"tool {t['id']} descs incompletas"

payload = {
    "version": GUIA_VERSION, "ourRepo": OUR_REPO,
    "langs": ["en","pt","es","fr","de"],
    "agents": [{"slug": a["slug"], "name": a["name"], "division": a["division"],
                "inst_claude": a["file"] in INSTALLED_CLAUDE, "inst_zcode": a["slug"] in ZCODE_SLUGS}
               for a in agents],
    "i18n": i18n,
    "divisions": [], "tools": [], "squads": {},
}
data_by_div = {}
for a in agents:
    data_by_div.setdefault(a["division"], 0)
    data_by_div[a["division"]] += 1
for raw in sorted(DIV_I18N["en"].keys()):
    n = data_by_div.get(raw, 0)
    inst = sum(1 for a in agents if a["division"] == raw and (a["file"] in INSTALLED_CLAUDE or a["slug"] in ZCODE_SLUGS))
    payload["divisions"].append({"raw": raw, "n": n, "inst": inst})
payload["tools"] = [{k: t[k] for k in ("id","label","icon","compat","projectOnly","main","dest","descs")} for t in TOOLS]
assert len(payload["tools"]) == meta["expectedTools"], (
    f"TOOLS no build.py ({len(payload['tools'])}) != meta.expectedTools ({meta['expectedTools']}) "
    "— atualize dados/meta.json ao adicionar/remover ferramenta")
# squads vêm de dados/squads.json (mesma fonte que os instaladores usam)
payload["squads"] = {k: {"slugs": sorted(x["slug"] for x in v["agentes"])} for k, v in squads_data.items()}

HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Specialist Guide — Agency Agents</title>
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
header p.sub{color:var(--muted);margin:0 0 12px}
.langbar{display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin:0 0 18px}
.langbtn{border:1px solid var(--line);background:var(--card);color:var(--muted);border-radius:8px;padding:4px 10px;font-size:12.5px;cursor:pointer}
.langbtn.on{background:var(--accent);border-color:var(--accent);color:#fff;font-weight:600}
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
.badge{display:inline-block;border-radius:999px;padding:3px 10px;font-size:12px;font-weight:600;margin-left:8px;vertical-align:middle;cursor:pointer}
.badge.new{background:color-mix(in srgb,var(--warn) 18%,transparent);color:var(--warn)}
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
.badge{display:inline-flex;align-items:center;border:0;border-radius:999px;padding:8px 14px;font-size:13px;font-weight:700;cursor:pointer;background:#f5a623;color:#1a1a1a;animation:pulse 1.6s infinite}
@keyframes pulse{0%,100%{transform:scale(1)}50%{transform:scale(1.05)}}
.btn.primary{background:var(--accent);color:#fff}
.btn.ghost{background:transparent;border:1.5px solid var(--line);color:var(--ink)}
.btn.primary:hover{filter:brightness(1.08)}
dialog{border:0;border-radius:16px;background:var(--card);color:var(--ink);max-width:640px;width:92vw;padding:0;box-shadow:0 20px 60px rgba(0,0,0,.35)}
dialog::backdrop{background:rgba(10,14,25,.55);backdrop-filter:blur(2px)}
.mWrap{padding:22px 24px}
.mWrap h3{margin:0 0 4px;font-size:19px}
.mWrap .mSub{color:var(--muted);font-size:13.5px;margin:0 0 16px}
.mStep{display:none}.mStep.on{display:block}
.opt{border:1.5px solid var(--line);border-radius:12px;padding:12px 14px;margin:8px 0;cursor:pointer;display:flex;gap:10px;align-items:flex-start}
.opt:hover{border-color:var(--accent)}
.opt .o-t{font-weight:600;font-size:14px}
.opt .o-d{font-size:12.5px;color:var(--muted)}
.mNav{display:flex;justify-content:space-between;gap:10px;margin-top:18px}
.cmdBox{background:var(--chip);border-radius:10px;padding:10px 12px;font:12.5px/1.5 ui-monospace,monospace;word-break:break-all;margin:8px 0}
.muted{color:var(--muted)}
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
  .bar,.langbar,.noprint{display:none} body{background:#fff} .panel,.card{box-shadow:none;border:1px solid #ddd}
  details{display:none} dialog{display:none!important}
}
</style>
</head>
<body>
<!-- estado da sua máquina, escrito pelo instalador (instaladores/). Se não existir, o guia segue funcionando. -->
<script src="guia-status.js"></script>
<div class="wrap">
<header>
  <h1 id="hTitle"></h1>
  <p class="sub" id="hSub"></p>
  <div class="langbar noprint" id="langbar"></div>
  <div class="stats">
    <div class="stat"><b id="stTotal">—</b><span id="stTotalL"></span></div>
    <div class="stat"><b id="stInst">—</b><span id="stInstL"></span></div>
    <div class="stat"><b id="stTools">—</b><span id="stToolsL"></span></div>
    <div class="stat"><b id="stDiv">—</b><span id="stDivL"></span></div>
  </div>
</header>

<div class="panel" id="machine">
  <h2 id="machineTitle"></h2>
  <p id="mStatus"></p>
  <div class="toolgrid" id="toolGrid"></div>
  <div class="mActions noprint">
    <button class="btn primary" id="btnWizard"></button>
    <button class="btn ghost" id="btnRecheck"></button>
    <button class="badge" id="updBadge" hidden></button>
  </div>
</div>

<div class="panel" id="howPanel">
  <h2 id="howTitle"></h2>
  <ol>
    <li id="how1"></li>
    <div class="example" id="howEx"></div>
    <li id="how2"></li>
    <li id="how3"></li>
  </ol>
</div>

<div class="panel" id="goldenPanel">
  <h2 id="goldenTitle"></h2>
  <ol>
    <li id="g1"></li><li id="g2"></li><li id="g3"></li><li id="g4"></li><li id="g5"></li>
  </ol>
</div>

<div class="bar noprint">
  <div class="searchrow">
    <input id="q" type="search" autocomplete="off">
    <label class="tog"><input type="checkbox" id="onlyInst"><span id="onlyInstL"></span></label>
    <span class="count" id="count"></span>
  </div>
  <div class="chips" id="chips"></div>
</div>

<div id="teamSep" class="sep"></div>
<div class="grid" id="teamGrid"></div>

<div id="catSep" class="sep"></div>
<div class="grid" id="grid"></div>
<div class="empty" id="empty" hidden></div>

<footer id="footer"></footer>
</div>

<dialog id="wiz">
  <div class="mWrap">
    <div class="mStep on" data-step="1">
      <h3 id="w1t"></h3>
      <p class="mSub" id="w1sub"></p>
      <div id="wizTools"></div>
      <div class="mNav"><span></span><button class="btn primary" id="wNext1"></button></div>
    </div>
    <div class="mStep" data-step="2">
      <h3 id="w2t"></h3>
      <p class="mSub" id="w2sub"></p>
      <div id="wizSquads"></div>
      <div class="mNav"><button class="btn ghost" id="wBack2"></button><button class="btn primary" id="wNext2"></button></div>
    </div>
    <div class="mStep" data-step="3">
      <h3 id="w3t"></h3>
      <p class="mSub" id="w3sub"></p>
      <ol>
        <li><span id="wStep1"></span>
          <div class="mNav" style="justify-content:flex-start"><button class="btn primary" id="wDownload"></button></div>
        </li>
        <li><span id="wStep2"></span>
          <div class="cmdBox" id="wCmd"></div>
          <p class="muted" style="font-size:12.5px" id="wNote"></p>
        </li>
      </ol>
      <div class="mNav"><button class="btn ghost" id="wBack3"></button><button class="btn primary" id="wClose"></button></div>
    </div>
  </div>
</dialog>

<script>
const DATA = __PAYLOAD__;
const UI = __UI__;
const VER = DATA.version;
const LANGS = DATA.langs;
const LS_LANG = "agencia-guia:lang";
const LS_KEY = "agencia-guia:lastUpdCheck";

let STATUS = null;
try { STATUS = window.GUIA_STATUS || null; } catch(e) { STATUS = null; }
function detectOS(){
  const ua = navigator.userAgent;
  if (/Windows NT/.test(ua)) return "windows";
  if (/Mac OS X/.test(ua)) return "macos";
  if (/Linux/.test(ua) && !/Android/.test(ua)) return "linux";
  if (/Android/.test(ua)) return "android";
  return "unknown";
}
function normLang(l){
  if (!l) return null;
  l = String(l).toLowerCase();
  if (l.startsWith("pt")) return "pt";
  if (l.startsWith("es")) return "es";
  if (l.startsWith("fr")) return "fr";
  if (l.startsWith("de")) return "de";
  if (l.startsWith("en")) return "en";
  return null;
}
let LANG = null;
try { LANG = normLang(localStorage.getItem(LS_LANG)); } catch(e) {}
if (!LANG && STATUS && STATUS.lang) LANG = normLang(STATUS.lang);
if (!LANG) LANG = normLang(navigator.language) || "en";
if (!LANGS.includes(LANG)) LANG = "en";

function T(key){ return (UI[LANG] && UI[LANG][key]) || UI.en[key] || key; }
function tpl(key, vars){
  let s = T(key);
  for (const k in vars) s = s.split("{"+k+"}").join(vars[k]);
  return s;
}
function esc(s){ return String(s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c])); }
function escAttr(s){ return esc(s); }

function compatKey(os){
  return os.startsWith("linux") ? "l" : os === "macos" ? "m" : "w";
}
function osName(os){ return T("os"+os.charAt(0).toUpperCase()+os.slice(1)); }
const OS = (STATUS && STATUS.os && STATUS.os.family) || detectOS();
function toolCompat(t){
  if (!STATUS) return "unknown";
  const c = (t.compat && t.compat[compatKey(OS)]) || "nao";
  if (c === "nao") return "incompat";
  if (t.projectOnly) return "project";
  return "ok";
}

/* ---------- renders (re-executáveis ao trocar idioma) ---------- */
function renderChrome(){
  document.documentElement.lang = LANG;
  document.title = T("title");
  document.getElementById("hTitle").textContent = T("title");
  document.getElementById("hSub").textContent = T("sub");
  document.getElementById("stTotalL").textContent = T("statTotal");
  document.getElementById("stInstL").textContent = T("statInst");
  document.getElementById("stToolsL").textContent = T("statTools");
  document.getElementById("stDivL").textContent = T("statDiv");
  document.getElementById("machineTitle").textContent = T("machineTitle");
  document.getElementById("btnWizard").textContent = T("btnInstall");
  document.getElementById("btnRecheck").textContent = T("btnRecheck");
  document.getElementById("howTitle").textContent = T("howTitle");
  document.getElementById("how1").innerHTML = T("how1");
  document.getElementById("howEx").innerHTML = T("howEx");
  document.getElementById("how2").innerHTML = T("how2");
  document.getElementById("how3").innerHTML = T("how3");
  document.getElementById("goldenTitle").textContent = T("goldenTitle");
  ["g1","g2","g3","g4","g5"].forEach((k,i)=>{ document.getElementById(k).innerHTML = T(k); });
  document.getElementById("q").placeholder = T("searchPh");
  document.getElementById("onlyInstL").textContent = T("onlyInst");
  document.getElementById("empty").textContent = T("empty");
  document.getElementById("footer").innerHTML = tpl("footer", {ver: VER});
  // seletor de idioma
  const bar = document.getElementById("langbar");
  bar.innerHTML = `<span class="muted" style="font-size:12px">${esc(T("langLabel"))}:</span>` +
    LANGS.map(l=>`<button class="langbtn ${l===LANG?"on":""}" data-lang="${escAttr(l)}">${esc(({en:"English",pt:"Português",es:"Español",fr:"Français",de:"Deutsch"})[l])}</button>`).join("");
}
function renderMachine(){
  const mStatus = document.getElementById("mStatus");
  if (STATUS){
    mStatus.innerHTML = tpl("mOs", {os: esc(osName(OS))}) +
      (STATUS.catalog ? tpl("mCat", {path: esc(STATUS.catalog.path), date: esc(STATUS.catalog.updated)}) : "") +
      tpl("mCheck", {when: esc(new Date(STATUS.generatedAt).toLocaleDateString(LANG))});
  } else {
    mStatus.innerHTML = tpl("machineNo", {os: esc(osName(OS))});
  }
  const grid = document.getElementById("toolGrid");
  grid.innerHTML = DATA.tools.filter(t=>t.main).map(t=>{
    const inst = STATUS ? STATUS.tools.find(x=>x.id===t.id) : null;
    const compat = toolCompat(t);
    let st, cls;
    if (!STATUS){ st = T("stUnknown"); cls = "st-unknown"; }
    else if (compat === "incompat"){ st = tpl("stIncompat", {os: esc(osName(OS))}); cls = "st-incompat"; }
    else if (compat === "project"){ st = T("stDetected"); cls = "st-detected"; }
    else if (!inst || !inst.installed){ st = T("stAbsent"); cls = "st-absent"; }
    else if (inst.agentCount > 0){ st = tpl("stReady", {n: inst.agentCount}); cls = "st-ready"; }
    else { st = T("stDetected"); cls = "st-detected"; }
    const hint = compat === "wsl" ? `<div class="t-dest">${esc(T("wslNote"))}</div>` :
                 compat === "project" ? `<div class="t-dest">${esc(t.dest)}</div>` :
                 `<div class="t-dest">${esc(t.dest)}</div>`;
    const desc = (t.descs && t.descs[LANG]) || t.descs.en;
    return `<div class="tool" data-id="${escAttr(t.id)}">
      <div class="t-head">${esc(t.icon)} ${esc(t.label)}</div>
      <span class="t-state ${cls}">${st}</span>
      <div class="t-desc">${esc(desc)}</div>${hint}
      <button data-tool="${escAttr(t.id)}">${esc(T("btnInstall").replace("➕ ","").replace("+ ",""))}</button>
    </div>`;
  }).join("");
}
function renderSeps(){
  const teamCards = document.querySelectorAll("#teamGrid .card");
  const anyTeam = [...teamCards].some(c=>!c.hidden);
  const ts = document.getElementById("teamSep");
  ts.innerHTML = `${T("teamSep")} <small>${esc(T("teamSepSub"))}</small>`;
  ts.hidden = !anyTeam;
  document.getElementById("catSep").innerHTML = `${T("catSep")} <small>${esc(T("catSepSub"))}</small>`;
}
function cardHTML(a, hot){
  const it = DATA.i18n[LANG].agents[a.slug];
  const divLabel = DATA.divLabels[LANG][a.division];
  const when = (a.custom_when && DATA.i18n[LANG].when.custom[a.slug]) || DATA.i18n[LANG].when.div[a.division];
  const tags = [`<span class="tag div">${esc(divLabel)}</span>`];
  if (a.inst_claude) tags.push(`<span class="tag claude">● Claude Code</span>`);
  if (a.inst_zcode) tags.push(`<span class="tag zcode">● ZCode</span>`);
  const orig = (LANG === "en") ? "" :
    `<details><summary>${esc(T("origEn"))}</summary><div>${esc(a.desc_en)}</div><pre>${esc(a.file)}</pre></details>`;
  return `<div class="card">
    <h3>${esc(a.name)}<small>${esc(a.slug)}</small></h3>
    <div class="tags">${tags.join("")}</div>
    <div class="desc">${esc(it.d)}</div>
    <div class="when ${hot?"hot":""}">${T("whenLabel")} ${esc(when)}</div>
    <details open="${hot?"open":""}"><summary>${esc(T("situations"))}</summary>
      <ul class="exList">${it.x.map(x=>`<li>${esc(x)}</li>`).join("")}</ul>
    </details>
    ${orig}
  </div>`;
}
function renderCards(){
  const inst = DATA.agents.filter(a=>a.inst_claude||a.inst_zcode);
  const rest = DATA.agents.filter(a=>!(a.inst_claude||a.inst_zcode));
  document.getElementById("teamGrid").innerHTML = inst.map(a=>cardHTML(a,true)).join("");
  document.getElementById("grid").innerHTML = rest.map(a=>cardHTML(a,false)).join("");
  const chips = document.getElementById("chips");
  chips.innerHTML = `<button class="chip on" data-div="">${esc(DATA.divLabelAll)} <small>(${DATA.agents.length})</small></button>` +
    DATA.divisions.map(d=>`<button class="chip" data-div="${escAttr(d.raw)}">${esc(DATA.divLabels[LANG][d.raw])} <small>(${d.n}${d.inst?` · ⭐${d.inst}`:""})</small></button>`).join("");
}
function renderStats(){
  const stTools = STATUS ? STATUS.tools.filter(t=>t.installed && t.agentCount>0).length : 0;
  const stInst = STATUS ? STATUS.tools.reduce((s,t)=>s+t.agentCount,0) : DATA.agents.filter(a=>a.inst_claude||a.inst_zcode).length;
  document.getElementById("stTotal").textContent = DATA.agents.length;
  document.getElementById("stInst").textContent = stInst;
  document.getElementById("stTools").textContent = stTools;
  document.getElementById("stDiv").textContent = DATA.divisions.length;
}
function renderAll(){
  renderChrome(); renderMachine(); renderCards(); renderStats(); renderSeps(); apply();
}

/* ---------- busca/filtros ---------- */
const q = document.getElementById("q"), onlyInst = document.getElementById("onlyInst");
const countEl = document.getElementById("count"), emptyEl = document.getElementById("empty");
let activeDiv = null;
function norm(s){ return String(s).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,""); }
function apply(){
  const term = norm(q.value.trim());
  let shown = 0;
  for (const el of document.querySelectorAll(".card")){
    const slug = el.querySelector("h3 small").textContent;
    const a = DATA.bySlug[slug];
    const it = DATA.i18n[LANG].agents[slug];
    const hay = norm([a.name, slug, it.d, a.desc_en, it.x.join(" ")].join(" "));
    const ok = (!activeDiv || a.division === activeDiv)
      && (!onlyInst.checked || a.inst_claude || a.inst_zcode)
      && (!term || hay.includes(term));
    el.hidden = !ok; if (ok) shown++;
  }
  countEl.textContent = tpl("showingTpl", {a: shown, b: DATA.agents.length});
  emptyEl.hidden = shown > 0;
  renderSeps();
}

/* ---------- wizard ---------- */
const wiz = document.getElementById("wiz");
let wizSel = {tools:new Set(), squad:null, slugs:[]};
function renderWizardTools(){
  document.getElementById("w1t").textContent = T("w1t");
  document.getElementById("w1sub").textContent = T("w1sub");
  document.getElementById("w2t").textContent = T("w2t");
  document.getElementById("w2sub").textContent = T("w2sub");
  document.getElementById("w3t").textContent = T("w3t");
  document.getElementById("wStep1").textContent = T("wStep1");
  document.getElementById("wDownload").textContent = T("wDownload");
  document.getElementById("wStep2").textContent = T("wStep2");
  document.getElementById("wNote").textContent = T("wNote");
  document.getElementById("wBack2").textContent = T("btnBack");
  document.getElementById("wBack3").textContent = T("btnBack");
  document.getElementById("wNext1").textContent = T("btnNext");
  document.getElementById("wNext2").textContent = T("btnNext");
  document.getElementById("wClose").textContent = T("btnClose");
  const wizTools = document.getElementById("wizTools");
  wizTools.innerHTML = DATA.tools.filter(t=>{
    const c = toolCompat(t);
    return c === "ok" || c === "project" || c === "wsl" || c === "unknown";
  }).map(t=>{
    const c = toolCompat(t);
    const lbl = c === "project" ? " ("+T("stDetected").replace(/[^\w\sáéíóúà-ÿ():·-]/g,"").trim()+")" : c === "wsl" ? " ("+T("wslNote")+")" : "";
    return `<label class="opt"><input type="checkbox" value="${escAttr(t.id)}" ${wizSel.tools.has(t.id)?"checked":""}>
      <span><span class="o-t">${esc(t.icon)} ${esc(t.label)}${esc(lbl)}</span><br><span class="o-d">${esc((t.descs&&t.descs[LANG])||t.descs.en)}</span></span></label>`;
  }).join("");
  wizTools.querySelectorAll("input").forEach(i=>i.addEventListener("change",()=>{
    i.checked ? wizSel.tools.add(i.value) : wizSel.tools.delete(i.value);
  }));
  const wizSquads = document.getElementById("wizSquads");
  const nAll = DATA.agents.length;
  wizSquads.innerHTML = `
    <label class="opt"><input type="radio" name="sq" value="pre-lancamento" checked><span><span class="o-t">${esc(T("sqPre"))}</span><br><span class="o-d">${esc(T("sqPreD"))}</span></span></label>
    <label class="opt"><input type="radio" name="sq" value="treino"><span><span class="o-t">${esc(T("sqTrain"))}</span><br><span class="o-d">${esc(T("sqTrainD"))}</span></span></label>
    <label class="opt"><input type="radio" name="sq" value="todas"><span><span class="o-t">${esc(tpl("sqAll",{n:nAll}))}</span><br><span class="o-d">${esc(T("sqAllD"))}</span></span></label>
    <label class="opt"><input type="radio" name="sq" value="divisao"><span><span class="o-t">${esc(T("sqDiv"))}</span><br><span class="o-d">${esc(T("sqDivD"))}</span></span></label>`;
  let divBox = document.getElementById("wizDivs");
  if (divBox) divBox.remove();
  divBox = document.createElement("div");
  divBox.id = "wizDivs"; divBox.style.display = "none";
  divBox.innerHTML = DATA.divisions.map(d=>`<label class="opt"><input type="checkbox" value="${escAttr(d.raw)}"><span><span class="o-t">${esc(DATA.divLabels[LANG][d.raw])}</span> <span class="o-d">(${d.n})</span></span></label>`).join("");
  wizSquads.parentNode.insertBefore(divBox, wizSquads.nextSibling);
  wizSquads.querySelectorAll("input[name=sq]").forEach(i=>i.addEventListener("change",()=>{
    divBox.style.display = i.value === "divisao" ? "block" : "none";
  }));
}
function showStep(n){
  wiz.querySelectorAll(".mStep").forEach(s=>s.classList.toggle("on", s.dataset.step == String(n)));
}
function openWizard(forTool){
  wizSel = {tools:new Set(), squad:null, slugs:[]};
  if (forTool) wizSel.tools.add(forTool);
  renderWizardTools();
  showStep(1);
  wiz.showModal();
}
document.getElementById("btnWizard").addEventListener("click", ()=>openWizard(null));
document.getElementById("toolGrid").addEventListener("click", e=>{
  const b = e.target.closest("button[data-tool]");
  if (b) openWizard(b.dataset.tool);
});
document.getElementById("wNext1").addEventListener("click", ()=>{
  if (!wizSel.tools.size){ alert(T("errNeedTool")); return; }
  showStep(2);
});
document.getElementById("wBack2").addEventListener("click", ()=>showStep(1));
document.getElementById("wNext2").addEventListener("click", ()=>{
  const sq = document.querySelector('#wizSquads input[name="sq"]:checked').value;
  let slugs = [];
  if (sq === "pre-lancamento" || sq === "treino") slugs = DATA.squads[sq].slugs.slice();
  else if (sq === "todas") slugs = DATA.agents.map(a=>a.slug);
  else {
    const sel = [...document.querySelectorAll("#wizDivs input:checked")].map(i=>i.value);
    if (!sel.length){ alert(T("errNeedDiv")); return; }
    slugs = DATA.agents.filter(a=>sel.includes(a.division)).map(a=>a.slug);
  }
  wizSel.squad = sq; wizSel.slugs = slugs;
  const toolsLbl = [...wizSel.tools].map(id=>(DATA.tools.find(t=>t.id===id)||{}).label).join(" + ");
  document.getElementById("w3sub").innerHTML = tpl("w3sub", {n: slugs.length, tools: esc(toolsLbl)});
  const cmd = OS === "windows"
    ? "powershell -ExecutionPolicy Bypass -File instaladores\\instalar-windows.ps1 -Plan agency-plan.json"
    : "./instaladores/instalar-linux.sh --plan agency-plan.json";
  document.getElementById("wCmd").textContent = cmd;
  showStep(3);
});
document.getElementById("wBack3").addEventListener("click", ()=>showStep(2));
document.getElementById("wClose").addEventListener("click", ()=>wiz.close());
document.getElementById("wDownload").addEventListener("click", ()=>{
  const plano = {plano: "agency-guia", versao: 2, geradoEm: new Date().toISOString(), sistema: OS,
                 idioma: LANG, ferramentas: [...wizSel.tools], squad: wizSel.squad,
                 agentes: wizSel.slugs.map(s=>{const a = DATA.bySlug[s]; return {slug: s, file: a.file};})};
  const blob = new Blob([JSON.stringify(plano, null, 1)], {type: "application/json"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob); a.download = "agency-plan.json"; a.click();
  URL.revokeObjectURL(a.href);
});

/* ---------- idioma ---------- */
document.getElementById("langbar").addEventListener("click", e=>{
  const b = e.target.closest(".langbtn");
  if (!b) return;
  LANG = b.dataset.lang;
  try { localStorage.setItem(LS_LANG, LANG); } catch(err) {}
  renderAll();
});

/* ---------- atualizações ---------- */
async function gh(url){
  const r = await fetch(url, {headers:{Accept:"application/vnd.github+json"}});
  if (!r.ok) throw new Error(r.status);
  return r.json();
}
async function checkUpdates(force){
  let last = 0;
  try { last = +localStorage.getItem(LS_KEY) || 0; } catch(e) {}
  if (!force && Date.now() - last < 24*3600*1000) return;
  try { localStorage.setItem(LS_KEY, String(Date.now())); } catch(e) {}
  const found = [];
  try {
    const rel = await gh("https://api.github.com/repos/msitarzewski/agency-agents-app/releases/latest");
    found.push("Agency Agents App " + rel.tag_name + " → github.com/msitarzewski/agency-agents-app/releases");
  } catch(e){}
  try {
    const rel = await gh("https://api.github.com/repos/" + DATA.ourRepo + "/releases/latest");
    if (rel.tag_name && rel.tag_name !== "v" + VER) found.push("Guide " + rel.tag_name + " (you have v" + VER + ")");
  } catch(e){}
  const badge = document.getElementById("updBadge");
  if (found.length){
    badge.textContent = T("updBadge");
    badge.hidden = false; badge.title = found.join("\n");
    badge.onclick = ()=>alert(found.join("\n\n"));
  } else badge.hidden = true;
}
document.getElementById("btnRecheck").addEventListener("click", ()=>checkUpdates(true));
checkUpdates(false);

/* ---------- boot ---------- */
document.getElementById("chips").addEventListener("click", e=>{
  const b = e.target.closest(".chip"); if (!b) return;
  activeDiv = b.dataset.div || null;
  document.querySelectorAll("#chips .chip").forEach(c=>c.classList.toggle("on", c===b));
  apply();
});
q.addEventListener("input", apply);
onlyInst.addEventListener("change", apply);
document.addEventListener("keydown", e=>{ if (e.key === "/" && document.activeElement !== q){ e.preventDefault(); q.focus(); } });
DATA.bySlug = Object.fromEntries(DATA.agents.map(a=>[a.slug, a]));
renderAll();
apply();
</script>
</body>
</html>
"""

# rótulos derivados
payload["divLabels"] = {lang: DIV_I18N[lang] for lang in DIV_I18N}
payload["divLabelAll"] = {"en": "All", "pt": "Todas", "es": "Todas", "fr": "Toutes", "de": "Alle"}
# textos auxiliares por agente
for a in payload["agents"]:
    a["desc_en"] = next(x["desc"] for x in agents if x["slug"] == a["slug"])
    a["file"] = next(x["file"] for x in agents if x["slug"] == a["slug"])
    a["custom_when"] = a["slug"] in when_pt["custom"]

payload_json = json.dumps(payload, ensure_ascii=False).replace("</", "<\\/")  # XSS-safe: nenhum </script> literal
ui_json = json.dumps(UI_I18N, ensure_ascii=False).replace("</", "<\\/")
html = HTML.replace("__PAYLOAD__", payload_json).replace("__UI__", ui_json)
out1 = REPO / "guia-especialistas-agencia.html"
out1.write_text(html, encoding="utf-8")
docs = Path.home() / "Documentos" / "guia-especialistas-agencia.html"
if docs.parent.exists():
    docs.write_text(html, encoding="utf-8")
    print("gerado também:", docs)
print("gerado:", out1, f"({len(html)//1024} KB, v{GUIA_VERSION}, 5 idiomas)")
