# 🧭 Guia de Especialistas — Agency Agents

**Um guia em HTML + instaladores para trazer 283 especialistas de IA para as suas ferramentas de código** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity e outras).

Feito para quem programa "de ouvido" (*vibe coder*) e quer uma equipe de especialistas digitais trabalhando junto — sem jargão, sem burocracia.

> Baseado no catálogo open source [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) e no instalador [Agency Agents App](https://github.com/msitarzewski/agency-agents-app). O catálogo e os instaladores deste projeto são adaptados e traduzidos para leigos em PT-BR.

---

## O que você encontra aqui

| Arquivo/pasta | O que é |
|---|---|
| `guia-especialistas-agencia.html` | **O guia.** Abra com dois cliques — funciona offline. Tem busca, filtros, painel da sua máquina e explica cada especialista em português simples, com 4 situações reais de uso. |
| `instaladores/instalar-linux.sh` | Instalador para **Linux e macOS**. |
| `instaladores/instalar-windows.ps1` | Instalador para **Windows** (pede só o Git for Windows). |
| `gerador/build.py` | Gera o guia a partir dos dados em `dados/` (para manutenção). |
| `dados/` | Catálogo traduzido + situações reais (JSONs). |

## Como começar (5 minutos)

### 1. Baixe o guia
Clique em **Code → Download ZIP** (ou clone o repositório) e abra o `guia-especialistas-agencia.html` — já dá para navegar nos 283 especialistas sem instalar nada.

### 2. Rode o instalador (uma vez)
Ele detecta quais ferramentas você tem (Claude Code, ZCode, Codex…), pergunta onde instalar e quantos especialistas trazer, faz **backup** do que já existe e, no fim, o guia mostra o painel da sua máquina atualizado.

**Linux/macOS:**
```bash
cd instaladores
./instalar-linux.sh
```

**Windows** (PowerShell — pré-requisito: [Git for Windows](https://git-scm.com/download/win)):
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # se pedirem
.\instalar-windows.ps1
```

### 3. Instale por dentro do guia (opcional)
No guia, o botão **“➕ Instalar especialistas numa ferramenta”** pergunta *onde* e *quem* (squad pré-lançamento, squad de treino, todos, ou por área) e gera um `plano-agencia.json`. Rode:

```bash
./instalar-linux.sh --plano plano-agencia.json        # Linux/macOS
.\instalar-windows.ps1 -Plano plano-agencia.json      # Windows
```

## O que o instalador faz (e não faz)

✅ Detecta ferramentas instaladas e o sistema operacional
✅ Baixa/atualiza o catálogo oficial para `~/.agency-agents`
✅ Converte os agentes com o **conversor oficial** (byte a byte igual)
✅ Faz **backup** em `~/.agency-agents-backup/` antes de sobrescrever qualquer coisa
✅ Gera `guia-status.js` ao lado do guia (é o que alimenta o painel da máquina)
❌ **Não** instala ferramentas que você não tem (só configura as que existem ou as compatíveis)
❌ **Não** manda nada para a internet (só o guia, quando você pede, confere releases no GitHub)

## Atualizações automáticas

O guia confere (a cada 24h ou quando você clicar em **🔄 Verificar atualizações**) os releases oficiais do catálogo/app e deste projeto. Se algo novo sair, aparece um selo no topo.

## Como usar os especialistas

Depois de instalados, os especialistas aparecem nas suas ferramentas:

- **Claude Code / ZCode / Codex / Gemini CLI…** — cite o nome dele no pedido: *“use o code-reviewer para revisar essa mudança”*.
- **No ZCode**, abra a sessão na pasta do projeto e veja **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — instalam por *projeto* (dentro da pasta do repositório).

Guia completo de comandos, exemplos e regras de ouro está **dentro do próprio HTML**.

## Ferramentas suportadas

| Ferramenta | Escopo | Destino |
|---|---|---|
| Claude Code | usuário | `~/.claude/agents/*.md` |
| ZCode | usuário | `~/.zcode/agents/*.md` |
| Codex CLI | usuário | `~/.codex/agents/*.toml` (Windows: WSL) |
| Gemini CLI | usuário | `~/.gemini/agents/*.md` |
| GitHub Copilot | usuário | `~/.github/agents/*.md` |
| Qwen Code | usuário | `~/.qwen/agents/*.md` |
| opencode | usuário | `~/.config/opencode/agents/*.md` |
| Antigravity | usuário | `~/.gemini/config/skills/<slug>/SKILL.md` |
| Osaurus | usuário | `~/.osaurus/skills/…` (só macOS) |
| Kimi CLI | usuário | `~/.config/kimi/agents/<slug>/` (Windows: WSL) |
| Cursor / Aider / Windsurf | por projeto | dentro da pasta do repositório |

Demais integrações do catálogo (Mistral Vibe, DeepSeek Harness, OpenClaw…) funcionam via renderizador oficial; para elas, prefira o [Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Licenças e créditos

- Este projeto: **MIT** (veja `LICENSE`).
- Catálogo e conversor: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, de Michael Sitarzewski. Este projeto apenas empacota, traduz e simplifica para leigos.
- Descrições e situações de uso foram traduzidas/adaptadas para PT-BR; o texto original em inglês fica disponível no detalhe de cada card do guia.
