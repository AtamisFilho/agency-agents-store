# 🧭 Agency Agents Store — Guía de especialistas e instaladores

[![CI](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml/badge.svg)](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/AtamisFilho/agency-agents-store)](https://github.com/AtamisFilho/agency-agents-store/releases)
[![CHANGELOG](https://img.shields.io/badge/CHANGELOG-v2.3.0-blue)](CHANGELOG.md)

**Una guía HTML + instaladores que traen 283 especialistas de IA a tus herramientas de programación** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity y más).

Pensado para "vibe coders" que quieren un equipo de especialistas digitales trabajando a su lado — sin tecnicismos, sin complicaciones.

> Basado en el catálogo de código abierto [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) y en la [Agency Agents App](https://github.com/msitarzewski/agency-agents-app). Este proyecto los empaqueta, traduce y simplifica para principiantes.

**🌐 Lee esta guía en:** [English](README.md) · [Português](README.pt-BR.md) · **[Español](README.es.md)** · [Français](README.fr.md) · [Deutsch](README.de.md)

---

## Instala con una línea

**Linux/macOS** (necesitas `git` + `python3`):
```bash
curl -fsSL https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.sh | bash
```

**Windows** (PowerShell — necesitas [Git for Windows](https://git-scm.com/download/win)):
```powershell
irm https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.ps1 | iex
```

La línea única descarga el instalador, las traducciones y la guía a `~/.agency-agents-store` y ejecuta todo desde ahí. ¿Prefieres el repositorio completo? **Code → Download ZIP** y sigue leyendo.

## Qué hay aquí

| Archivo/carpeta | Qué es |
|---|---|
| `guia-especialistas-agencia.html` | **La guía.** Doble clic para abrir — funciona sin conexión. Búsqueda, filtros, panel "tu máquina" y cada especialista explicado en lenguaje sencillo, con 4 situaciones reales de uso. Disponible en inglés, portugués, español, francés y alemán. |
| `instaladores/instalar.sh` / `instalar.ps1` | **Bootstraps de una línea** (los comandos de arriba). |
| `instaladores/instalar-linux.sh` | Instalador para **Linux y macOS** (wrapper fino — comprueba prerequisitos y llama al driver). |
| `instaladores/agency-install.py` | **El núcleo del instalador** (todos los flags, toda la lógica) para Linux/macOS. |
| `instaladores/instalar-windows.ps1` | Instalador para **Windows** (PowerShell nativo, sin Python; usa el mismo archivo de traducciones). |
| `gerador/build.py` | Regenera la guía desde `dados/` (mantenimiento). |
| `dados/` | Catálogo traducido + situaciones reales + `meta.json` (fuente única de verdad) + `i18n-instalador.json` (mensajes de los instaladores, 5 idiomas). |

## Cómo empezar (5 minutos)

### 1. Consigue la guía
Haz clic en **Code → Download ZIP** (o clona el repositorio) y abre `guia-especialistas-agencia.html` — ya puedes navegar los 283 especialistas sin instalar nada. Elige el idioma en el selector de arriba a la derecha.

### 2. Ejecuta el instalador (una vez)
Detecta qué herramientas tienes (Claude Code, ZCode, Codex…), **pregunta tu idioma** (y lo guarda en `~/.agency-agents/config`; el locale del sistema ya vale como predeterminado), pregunta dónde instalar y cuántos especialistas traer, hace **backup** de todo lo que toca y, al final, el panel de la máquina de la guía se actualiza solo.

**Linux/macOS** (desde el repositorio):
```bash
./instaladores/instalar-linux.sh
```

**Windows** (PowerShell — prerequisito: [Git for Windows](https://git-scm.com/download/win)):
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # si lo piden
.\instalar-windows.ps1
```

### 3. Instala desde dentro de la guía (opcional)
En la guía, el botón **"➕ Instalar especialistas en una herramienta"** pregunta *dónde* y *a quién* (escuadrón pre-lanzamiento, de entrenamiento, todos los 283, o por área) y genera un `agency-plan.json`. Luego, desde la carpeta donde guardaste el plan:

```bash
./instaladores/instalar-linux.sh --plan          # la ruta es opcional: encuentra el agency-plan.json
.\instalar-windows.ps1 -PlanAuto                 # igual en Windows (encuentra el plan automáticamente)
```

El instalador busca el plan automáticamente en `.`, `..`, la carpeta del instalador, `~/Downloads` y `~/Documents` (el nombre antiguo `plano-agencia.json` también funciona).

## Automatización y control fino (mismos flags en ambas plataformas)

| Linux/macOS | Windows | Qué hace |
|---|---|---|
| `--tool zcode,codex` | `-Tool zcode,codex` | Elige herramientas sin preguntar (ids válidos: `--list`) |
| `--squad pre\|treino\|all` | `-Squad pre\|treino\|all` | Elige el escuadrón sin preguntar (CI/scripts) |
| `--plan [ARCHIVO]` | `-Plan ARCHIVO` / `-PlanAuto` | Usa el plan de la guía (búsqueda automática: `--plan` sin ruta, o `-PlanAuto`) |
| `--dry-run` | `-DryRun` | Previsualiza todo lo que se tocaría — no escribe nada |
| `--list` | `-List` | Catálogo/herramientas/escuadrones en JSON por stdout (nunca usa red) |
| `--status` | `-Status` | Solo detecta + actualiza el panel de la guía (sin red) |
| `--status --json` | `-Status -Json` | Estado de la máquina en JSON por stdout (no escribe nada) |
| `--uninstall` | `-Uninstall` | Elimina los especialistas de la agencia (backup antes; conserva tus archivos) |
| `--dir <ruta>` | `-Dir <ruta>` | Instala en una carpeta de **proyecto** — habilita Cursor/Aider/Windsurf |
| `--lang en\|pt\|es\|fr\|de` | `-Lang en\|pt\|es\|fr\|de` | Idioma (se recuerda para las próximas ejecuciones) |

Ejemplos:
```bash
./instaladores/instalar-linux.sh --tool cursor --dir ~/code/mi-app --squad treino   # reglas de Cursor en un proyecto
./instaladores/instalar-linux.sh --uninstall --tool zcode                           # eliminar (con backup)
./instaladores/instalar-linux.sh --dry-run --tool claudeCode --squad pre            # solo mirar
./instaladores/instalar-linux.sh --list | jq '.tools[].id'                          # para scripts
```

## Qué hace el instalador (y qué no)

✅ Detecta las herramientas instaladas y tu sistema operativo
✅ Pregunta tu idioma una vez — y lo recuerda (el locale del SO es el predeterminado)
✅ Descarga/actualiza el catálogo oficial en `~/.agency-agents`
✅ Convierte los agentes con el **conversor oficial** (idéntico byte a byte)
✅ Hace **backup** en `~/.agency-agents-backup/` antes de sobrescribir nada
✅ **Verifica con honestidad**: informa cuántos de los especialistas pedidos están de verdad en el destino
✅ Escribe `guia-status.js` junto a la guía (alimenta el panel de la máquina)
✅ Desinstala limpio (`--uninstall`) — solo archivos de la agencia, siempre con backup
❌ **No** instala herramientas que no tienes (solo configura las existentes o compatibles)
❌ **No** usa red en los modos `--status`/`--list`/`--json` (instalar sí, para bajar el catálogo)
❌ **No** envía nada a nadie más (solo la guía, cuando lo pides, consulta releases en GitHub)

## Actualizaciones automáticas

La guía comprueba (cada 24h o al pulsar **🔄 Verificar actualizaciones**) los releases oficiales del catálogo, de la app y de este proyecto. Si sale algo nuevo, aparece un sello arriba. Los releases de este proyecto siguen [CHANGELOG.md](CHANGELOG.md) — el tag (`vX.Y.Z`) siempre coincide con la versión de la guía.

## Instalar como app (PWA)

La guía también es una **app instalable y 100% offline** (PWA):

- **GitHub Pages:** abre https://atamisfilho.github.io/agency-agents-store/ y elige **Instalar app** (icono en la barra de direcciones, o menú del navegador → "Instalar" / "Añadir a la pantalla de inicio").
- **Alojamiento propio:** descarga el `agency-agents-pwa-vX.Y.Z.zip` de los [releases](https://github.com/AtamisFilho/agency-agents-store/releases) y suelta los archivos en cualquier alojamiento estático HTTPS — listo.

El primer acceso lo guarda todo; después funciona sin internet, y el service worker lo mantiene actualizado en la próxima visita online. (Instalar la PWA pone la *guía* en tu dispositivo — los especialistas siguen yendo a tus herramientas de código con el instalador de arriba.)

Archivos del PWA: `manifest.webmanifest`, `sw.js`, `index.html`, `pwa-icons/` (generados por `gerador/gen_icons.py`), ZIP del release vía `gerador/package_pwa.py`.

## Cómo usar los especialistas

Una vez instalados, los especialistas aparecen en tus herramientas:

- **Claude Code / ZCode / Codex / Gemini CLI…** — menciona su nombre en el pedido: *"usa el code-reviewer para revisar este cambio"*.
- **En ZCode**, abre la sesión en la carpeta del proyecto y mira **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — se instalan por *proyecto* con `--dir <carpeta del proyecto>` (las reglas/índice viven dentro del repositorio).

La guía en sí tiene el playbook completo: cómo llamarlos, ejemplos y las cinco reglas de oro.

## Herramientas soportadas

| Herramienta | Ámbito | Destino |
|---|---|---|
| Claude Code | usuario | `~/.claude/agents/*.md` |
| ZCode | usuario | `~/.zcode/agents/*.md` |
| Codex CLI | usuario | `~/.codex/agents/*.toml` (Windows: WSL) |
| Gemini CLI | usuario | `~/.gemini/agents/*.md` |
| GitHub Copilot | usuario | `~/.github/agents/*.md` |
| Qwen Code | usuario | `~/.qwen/agents/*.md` |
| opencode | usuario | `~/.config/opencode/agents/*.md` |
| Antigravity | usuario | `~/.gemini/config/skills/<slug>/SKILL.md` |
| Osaurus | usuario | `~/.osaurus/skills/…` (solo macOS) |
| Kimi CLI | usuario | `~/.config/kimi/agents/<slug>/` (Windows: WSL) |
| Cursor | por proyecto (`--dir`) | `<proyecto>/.cursor/rules/<slug>.mdc` |
| Aider | por proyecto (`--dir`) | `<proyecto>/CONVENTIONS.md` (índice) |
| Windsurf | por proyecto (`--dir`) | `<proyecto>/.windsurfrules` (índice) |

Las demás integraciones del catálogo (Mistral Vibe, DeepSeek Harness, OpenClaw…) funcionan vía el renderizador oficial; para ellas prefiere la [Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Idiomas

La guía y ambos instaladores vienen en **inglés, portugués, español, francés y alemán** — incluidas todas las descripciones de los especialistas y las situaciones reales de uso. Elige el idioma en la instalación (se recuerda) o cámbialo cuando quieras en la guía (selector de arriba).

## Desarrollo

- `python3 gerador/build.py` regenera la guía desde `dados/` — el CI falla si el HTML commitado no coincide con los datos.
- `python3 tests/test_guide.py` — tests estáticos de la guía (payload, paridad i18n, XSS).
- `bash tests/run-tests.sh` — suite adversarial del instalador (conteos dinámicos del catálogo, todos los flags).
- El CI corre todo en cada push/PR (ver [.github/workflows/ci.yml](.github/workflows/ci.yml)).

## Licencias y créditos

- Este proyecto: **MIT** (ver `LICENSE`).
- Catálogo y conversor: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, de Michael Sitarzewski. Este proyecto solo lo empaqueta, traduce y simplifica para principiantes.
- Descripciones y situaciones de uso fueron traducidas/adaptadas; el texto original en inglés está en el detalle de cada tarjeta.
