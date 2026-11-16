# 🧭 Agency Agents Store — Guia de Especialistas & Instaladores

[![CI](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml/badge.svg)](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/AtamisFilho/agency-agents-store)](https://github.com/AtamisFilho/agency-agents-store/releases)
[![CHANGELOG](https://img.shields.io/badge/CHANGELOG-v2.3.0-blue)](CHANGELOG.md)

**Um guia em HTML + instaladores que trazem 283 especialistas de IA para as suas ferramentas de código** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity e outras).

Feito para quem programa "de ouvido" (*vibe coder*) e quer uma equipe de especialistas digitais trabalhando junto — sem jargão, sem burocracia.

> Baseado no catálogo open source [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) e no [Agency Agents App](https://github.com/msitarzewski/agency-agents-app). Este projeto empacota, traduz e simplifica tudo para iniciantes.

**🌐 Leia em:** [English](README.md) · **[Português](README.pt-BR.md)** · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md)

---

## Instale com uma linha

**Linux/macOS** (precisa de `git` + `python3`):
```bash
curl -fsSL https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.sh | bash
```

**Windows** (PowerShell — precisa do [Git for Windows](https://git-scm.com/download/win)):
```powershell
irm https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.ps1 | iex
```

A linha única baixa o instalador, as traduções e o guia para `~/.agency-agents-store` e roda tudo de lá. Prefere o repositório completo? **Code → Download ZIP** e siga lendo.

## O que você encontra aqui

| Arquivo/pasta | O que é |
|---|---|
| `guia-especialistas-agencia.html` | **O guia.** Abra com dois cliques — funciona offline. Busca, filtros, painel "sua máquina" e cada especialista explicado em linguagem simples, com 4 situações reais de uso. Disponível em inglês, português, espanhol, francês e alemão. |
| `instaladores/instalar.sh` / `instalar.ps1` | **Bootstraps de uma linha** (os comandos acima). |
| `instaladores/instalar-linux.sh` | Instalador para **Linux e macOS** (wrapper fino — checa pré-requisitos e chama o driver). |
| `instaladores/agency-install.py` | **O núcleo do instalador** (todas as flags, toda a lógica) para Linux/macOS. |
| `instaladores/instalar-windows.ps1` | Instalador para **Windows** (PowerShell nativo, sem Python; usa o mesmo arquivo de traduções). |
| `gerador/build.py` | Regenera o guia a partir de `dados/` (para manutenção). |
| `dados/` | Catálogo traduzido + situações reais + `meta.json` (fonte única de verdade) + `i18n-instalador.json` (mensagens dos instaladores, 5 idiomas). |

## Como começar (5 minutos)

### 1. Baixe o guia
Clique em **Code → Download ZIP** (ou clone o repositório) e abra o `guia-especialistas-agencia.html` — já dá para navegar nos 283 especialistas sem instalar nada. Escolha o idioma no seletor no canto superior.

### 2. Rode o instalador (uma vez)
Ele detecta quais ferramentas você tem (Claude Code, ZCode, Codex…), **pergunta seu idioma** (e guarda no `~/.agency-agents/config`; o locale do sistema já vale como padrão), pergunta onde instalar e quantos especialistas trazer, faz **backup** de tudo que tocar e, no fim, o painel da máquina do guia se atualiza sozinho.

**Linux/macOS** (a partir do repositório):
```bash
./instaladores/instalar-linux.sh
```

**Windows** (PowerShell — pré-requisito: [Git for Windows](https://git-scm.com/download/win)):
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # se pedirem
.\instalar-windows.ps1
```

### 3. Instale por dentro do guia (opcional)
No guia, o botão **"➕ Instalar especialistas numa ferramenta"** pergunta *onde* e *quem* (squad pré-lançamento, squad de treino, todos os 283, ou por área) e gera um `agency-plan.json`. Depois, na pasta onde salvou o plano:

```bash
./instaladores/instalar-linux.sh --plan          # caminho é opcional: ele acha o agency-plan.json
.\instalar-windows.ps1 -PlanAuto                 # igual no Windows (acha o plano automaticamente)
```

O instalador procura o plano automaticamente em `.`, `..`, na pasta do instalador, em `~/Downloads` e `~/Documents` (o nome antigo `plano-agencia.json` também funciona).

## Automação e controle fino (mesmas flags nas duas plataformas)

| Linux/macOS | Windows | O que faz |
|---|---|---|
| `--tool zcode,codex` | `-Tool zcode,codex` | Escolhe ferramentas sem perguntar (ids válidos: `--list`) |
| `--squad pre\|treino\|all` | `-Squad pre\|treino\|all` | Escolhe a squad sem perguntar (CI/scripts) |
| `--plan [ARQUIVO]` | `-Plan ARQUIVO` / `-PlanAuto` | Usa o plano do guia (busca automática: `--plan` sem caminho, ou `-PlanAuto`) |
| `--dry-run` | `-DryRun` | Pré-visualiza tudo que seria tocado — não escreve nada |
| `--list` | `-List` | Catálogo/ferramentas/squads em JSON no stdout (nunca usa rede) |
| `--status` | `-Status` | Só detecta + atualiza o painel do guia (sem rede) |
| `--status --json` | `-Status -Json` | Estado da máquina em JSON no stdout (não escreve nada) |
| `--uninstall` | `-Uninstall` | Remove os especialistas da agência (backup antes; preserva seus arquivos) |
| `--dir <caminho>` | `-Dir <caminho>` | Instala numa pasta de **projeto** — habilita Cursor/Aider/Windsurf |
| `--lang en\|pt\|es\|fr\|de` | `-Lang en\|pt\|es\|fr\|de` | Idioma (persistido para as próximas execuções) |

Exemplos:
```bash
./instaladores/instalar-linux.sh --tool cursor --dir ~/code/meu-app --squad treino   # regras do Cursor num projeto
./instaladores/instalar-linux.sh --uninstall --tool zcode                           # remove (com backup)
./instaladores/instalar-linux.sh --dry-run --tool claudeCode --squad pre            # só olhar
./instaladores/instalar-linux.sh --list | jq '.tools[].id'                          # para scripts
```

## O que o instalador faz (e não faz)

✅ Detecta ferramentas instaladas e o sistema operacional
✅ Pergunta seu idioma uma vez — e lembra (o locale do SO é o padrão)
✅ Baixa/atualiza o catálogo oficial para `~/.agency-agents`
✅ Converte os agentes com o **conversor oficial** (byte a byte igual)
✅ Faz **backup** em `~/.agency-agents-backup/` antes de sobrescrever qualquer coisa
✅ **Verifica com honestidade**: informa quantos dos especialistas pedidos estão mesmo no destino
✅ Gera `guia-status.js` ao lado do guia (é o que alimenta o painel da máquina)
✅ Desinstala limpo (`--uninstall`) — só arquivos da agência, sempre com backup
❌ **Não** instala ferramentas que você não tem (só configura as que existem ou as compatíveis)
❌ **Não** usa rede nos modos `--status`/`--list`/`--json` (instalar usa, para baixar o catálogo)
❌ **Não** manda nada para mais ninguém (só o guia, quando você pede, confere releases no GitHub)

## Atualizações automáticas

O guia confere (a cada 24h ou quando você clicar em **🔄 Verificar atualizações**) os releases oficiais do catálogo, do app e deste projeto. Se algo novo sair, aparece um selo no topo. Os releases deste projeto seguem o [CHANGELOG.md](CHANGELOG.md) — a tag (`vX.Y.Z`) sempre bate com a versão do guia.

## Instalar como app (PWA)

O guia também é um **app instalável e 100% offline** (PWA):

- **GitHub Pages:** abra https://atamisfilho.github.io/agency-agents-store/ e escolha **Instalar app** (ícone na barra de endereço, ou menu do navegador → "Instalar" / "Adicionar à tela inicial").
- **Hospedagem própria:** baixe o `agency-agents-pwa-vX.Y.Z.zip` nos [releases](https://github.com/AtamisFilho/agency-agents-store/releases) e solte os arquivos em qualquer hospedagem estática HTTPS — pronto.

O primeiro acesso guarda tudo; depois funciona sem internet nenhuma, e o service worker mantém o app atualizado no próximo acesso online. (Instalar o PWA coloca o *guia* no seu dispositivo — os especialistas em si continuam indo para as suas ferramentas de código com o instalador acima.)

Arquivos do PWA: `manifest.webmanifest`, `sw.js`, `index.html`, `pwa-icons/` (gerados por `gerador/gen_icons.py`), ZIP do release via `gerador/package_pwa.py`.

## Como usar os especialistas

Depois de instalados, os especialistas aparecem nas suas ferramentas:

- **Claude Code / ZCode / Codex / Gemini CLI…** — cite o nome dele no pedido: *"use o code-reviewer para revisar essa mudança"*.
- **No ZCode**, abra a sessão na pasta do projeto e veja **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — instalam por *projeto* com `--dir <pasta do projeto>` (regras/índice ficam dentro do repositório).

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
| Cursor | por projeto (`--dir`) | `<projeto>/.cursor/rules/<slug>.mdc` |
| Aider | por projeto (`--dir`) | `<projeto>/CONVENTIONS.md` (índice) |
| Windsurf | por projeto (`--dir`) | `<projeto>/.windsurfrules` (índice) |

Demais integrações do catálogo (Mistral Vibe, DeepSeek Harness, OpenClaw…) funcionam via renderizador oficial; para elas, prefira o [Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Idiomas

O guia e os dois instaladores vêm em **inglês, português, espanhol, francês e alemão** — inclusive todas as descrições dos especialistas e as situações reais de uso. Escolha o idioma na instalação (ele é lembrado) ou troque quando quiser no guia (seletor no topo).

## Desenvolvimento

- `python3 gerador/build.py` regenera o guia a partir de `dados/` — o CI falha se o HTML commitado não bater com os dados.
- `python3 tests/test_guide.py` — testes estáticos do guia (payload, paridade i18n, XSS).
- `bash tests/run-tests.sh` — suíte adversarial do instalador (contagens dinâmicas do catálogo, todas as flags).
- O CI roda tudo a cada push/PR (veja [.github/workflows/ci.yml](.github/workflows/ci.yml)).

## Licenças e créditos

- Este projeto: **MIT** (veja `LICENSE`).
- Catálogo e conversor: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, de Michael Sitarzewski. Este projeto apenas empacota, traduz e simplifica para leigos.
- Descrições e situações de uso foram traduzidas/adaptadas; o texto original em inglês fica disponível no detalhe de cada card.
