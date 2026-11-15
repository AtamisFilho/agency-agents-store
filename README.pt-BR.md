# 🧭 Agency Agents Store — Guia de Especialistas & Instaladores

**Um guia em HTML + instaladores que trazem 283 especialistas de IA para as suas ferramentas de código** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity e outras).

Feito para quem programa "de ouvido" (*vibe coder*) e quer uma equipe de especialistas digitais trabalhando junto — sem jargão, sem burocracia.

> Baseado no catálogo open source [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) e no [Agency Agents App](https://github.com/msitarzewski/agency-agents-app). Este projeto empacota, traduz e simplifica tudo para iniciantes.

**🌐 Leia em:** [English](README.md) · **[Português](README.pt-BR.md)** · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md)

---

## O que você encontra aqui

| Arquivo/pasta | O que é |
|---|---|
| `guia-especialistas-agencia.html` | **O guia.** Abra com dois cliques — funciona offline. Busca, filtros, painel "sua máquina" e cada especialista explicado em linguagem simples, com 4 situações reais de uso. Disponível em inglês, português, espanhol, francês e alemão. |
| `instaladores/instalar-linux.sh` | Instalador para **Linux e macOS**. |
| `instaladores/instalar-windows.ps1` | Instalador para **Windows** (pede só o Git for Windows). |
| `gerador/build.py` | Regenera o guia a partir de `dados/` (para manutenção). |
| `dados/` | Catálogo traduzido + situações reais (JSON). |

## Como começar (5 minutos)

### 1. Baixe o guia
Clique em **Code → Download ZIP** (ou clone o repositório) e abra o `guia-especialistas-agencia.html` — já dá para navegar nos 283 especialistas sem instalar nada. Escolha o idioma no seletor no canto superior.

### 2. Rode o instalador (uma vez)
Ele detecta quais ferramentas você tem (Claude Code, ZCode, Codex…), **pergunta seu idioma**, pergunta onde instalar e quantos especialistas trazer, faz **backup** de tudo que tocar e, no fim, o painel da máquina do guia se atualiza sozinho.

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
No guia, o botão **"➕ Instalar especialistas numa ferramenta"** pergunta *onde* e *quem* (squad pré-lançamento, squad de treino, todos os 283, ou por área) e gera um `agency-plan.json`. Depois rode:

```bash
./instalar-linux.sh --plan agency-plan.json        # Linux/macOS
.\instalar-windows.ps1 -Plan agency-plan.json      # Windows
```

Você também pode escolher o idioma sem perguntas: `--lang en|pt|es|fr|de` (ou `-Lang` no Windows).

## O que o instalador faz (e não faz)

✅ Detecta ferramentas instaladas e o sistema operacional
✅ Pergunta seu idioma — tudo segue ele, inclusive as descrições dos especialistas
✅ Baixa/atualiza o catálogo oficial para `~/.agency-agents`
✅ Converte os agentes com o **conversor oficial** (byte a byte igual)
✅ Faz **backup** em `~/.agency-agents-backup/` antes de sobrescrever qualquer coisa
✅ Gera `guia-status.js` ao lado do guia (é o que alimenta o painel da máquina)
❌ **Não** instala ferramentas que você não tem (só configura as que existem ou as compatíveis)
❌ **Não** manda nada para a internet (só o guia, quando você pede, confere releases no GitHub)

## Atualizações automáticas

O guia confere (a cada 24h ou quando você clicar em **🔄 Verificar atualizações**) os releases oficiais do catálogo, do app e deste projeto. Se algo novo sair, aparece um selo no topo.

## Como usar os especialistas

Depois de instalados, os especialistas aparecem nas suas ferramentas:

- **Claude Code / ZCode / Codex / Gemini CLI…** — cite o nome dele no pedido: *"use o code-reviewer para revisar essa mudança"*.
- **No ZCode**, abra a sessão na pasta do projeto e veja **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — instalam por *projeto* (dentro da pasta do repositório).

O guia em si tem o playbook completo: como chamar, exemplos e as cinco regras de ouro.

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

## Idiomas

O guia e os dois instaladores vêm em **inglês, português, espanhol, francês e alemão** — inclusive todas as descrições dos especialistas e as situações reais de uso. Escolha o idioma na instalação ou troque quando quiser no guia (seletor no topo).

## Licenças e créditos

- Este projeto: **MIT** (veja `LICENSE`).
- Catálogo e conversor: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, de Michael Sitarzewski. Este projeto apenas empacota, traduz e simplifica para leigos.
- Descrições e situações de uso foram traduzidas/adaptadas; o texto original em inglês fica disponível no detalhe de cada card.
