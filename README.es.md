# 🧭 Agency Agents Store — Guía de especialistas e instaladores

**Una guía HTML + instaladores que traen 283 especialistas de IA a tus herramientas de programación** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity y más).

Pensado para "vibe coders" que quieren un equipo de especialistas digitales trabajando a su lado — sin tecnicismos, sin complicaciones.

> Basado en el catálogo de código abierto [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) y en la [Agency Agents App](https://github.com/msitarzewski/agency-agents-app). Este proyecto los empaqueta, traduce y simplifica para principiantes.

**🌐 Lee esta guía en:** [English](README.md) · [Português](README.pt-BR.md) · **[Español](README.es.md)** · [Français](README.fr.md) · [Deutsch](README.de.md)

---

## Qué incluye

| Archivo/carpeta | Qué es |
|---|---|
| `guia-especialistas-agencia.html` | **La guía.** Doble clic para abrirla — funciona sin conexión. Búsqueda, filtros, un panel de "tu máquina" y cada especialista explicado en lenguaje sencillo con 4 situaciones de uso reales. Disponible en inglés, portugués, español, francés y alemán. |
| `instaladores/instalar-linux.sh` | Instalador para **Linux y macOS**. |
| `instaladores/instalar-windows.ps1` | Instalador para **Windows** (solo requiere Git for Windows). |
| `gerador/build.py` | Regenera la guía desde `dados/` (para mantenimiento). |
| `dados/` | Catálogo traducido + situaciones reales (JSON). |

## Cómo empezar (5 minutos)

### 1. Consigue la guía
Haz clic en **Code → Download ZIP** (o clona el repositorio) y abre `guia-especialistas-agencia.html` — puedes explorar los 283 especialistas sin instalar nada. Elige tu idioma en el selector de la esquina superior derecha.

### 2. Ejecuta el instalador (una vez)
Detecta qué herramientas tienes (Claude Code, ZCode, Codex…), **te pregunta tu idioma**, te pregunta dónde instalar y cuántos especialistas traer, **hace copia de seguridad** de todo lo que toca, y al final el panel de "tu máquina" de la guía se actualiza solo.

**Linux/macOS:**
```bash
cd instaladores
./instalar-linux.sh
```

**Windows** (PowerShell — prerrequisito: [Git for Windows](https://git-scm.com/download/win)):
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # if prompted
.\instalar-windows.ps1
```

### 3. Instala desde dentro de la guía (opcional)
En la guía, el botón **"➕ Instalar especialistas en una herramienta"** pregunta *dónde* y *quiénes* (equipo de prelanzamiento, equipo de entrenamiento, los 283, o por división) y genera un `agency-plan.json`. Luego ejecuta:

```bash
./instalar-linux.sh --plan agency-plan.json        # Linux/macOS
.\instalar-windows.ps1 -Plan agency-plan.json      # Windows
```

También puedes elegir el idioma sin interacción: `--lang en|pt|es|fr|de` (o `-Lang` en Windows).

## Qué hace (y qué no hace) el instalador

✅ Detecta las herramientas instaladas y tu sistema operativo
✅ Pregunta tu idioma — todo lo respeta, incluidas las descripciones de los especialistas
✅ Descarga/actualiza el catálogo oficial en `~/.agency-agents`
✅ Convierte los agentes con el **convertidor oficial** (salida idéntica byte a byte)
✅ **Hace copia de seguridad** en `~/.agency-agents-backup/` antes de sobrescribir nada
✅ Escribe `guia-status.js` junto a la guía (alimenta el panel de "tu máquina")
❌ **No** instala herramientas que no tienes (solo configura las existentes/compatibles)
❌ **No** envía nada a internet (solo la guía, cuando tú se lo pides, comprueba las novedades de GitHub)

## Actualizaciones automáticas

La guía comprueba (cada 24 horas o cuando haces clic en **🔄 Buscar actualizaciones**) las versiones oficiales del catálogo, la app y este proyecto. Si llega algo nuevo, aparece una insignia arriba.

## Cómo usar los especialistas

Una vez instalados, los especialistas aparecen en tus herramientas:

- **Claude Code / ZCode / Codex / Gemini CLI…** — menciona el nombre en tu prompt: *"usa el code-reviewer para revisar este cambio"*.
- **En ZCode**, abre una sesión en la carpeta del proyecto y revisa **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — instala por *proyecto* (dentro de la carpeta del repositorio).

La propia guía incluye el manual completo: cómo invocarlos, ejemplos y las cinco reglas de oro.

## Herramientas compatibles

| Herramienta | Alcance | Destino |
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
| Cursor / Aider / Windsurf | por proyecto | dentro de la carpeta del repositorio |

Otras integraciones del catálogo (Mistral Vibe, DeepSeek Harness, OpenClaw…) funcionan mediante el convertidor oficial; para esas, es preferible la [Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Idiomas

La guía y ambos instaladores están disponibles en **inglés, portugués, español, francés y alemán** — incluidas todas las descripciones de los especialistas y todas las situaciones de uso reales. Elige el idioma durante la instalación, o cámbialo en cualquier momento dentro de la guía (selector en la esquina superior derecha).

## Licencias y créditos

- Este proyecto: **MIT** (ver `LICENSE`).
- Catálogo y convertidor: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, por Michael Sitarzewski. Este proyecto solo lo empaqueta, traduce y simplifica para principiantes.
- Las descripciones y las situaciones de uso fueron traducidas/adaptadas; el texto original en inglés está disponible en los detalles de cada tarjeta.
