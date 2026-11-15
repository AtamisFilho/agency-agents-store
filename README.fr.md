# 🧭 Agency Agents Store — Guide des spécialistes & installateurs

**Un guide HTML + des installateurs qui amènent 283 spécialistes de l'IA dans vos outils de programmation** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity et plus encore).

Conçu pour les « vibe coders » qui veulent une équipe de spécialistes numériques travaillant à leurs côtés — sans jargon, sans complications.

> Basé sur le catalogue open source [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) et sur l'[Agency Agents App](https://github.com/msitarzewski/agency-agents-app). Ce projet les empaquète, les traduit et les simplifie pour les débutants.

**🌐 Lisez ce guide en :** [English](README.md) · [Português](README.pt-BR.md) · [Español](README.es.md) · **[Français](README.fr.md)** · [Deutsch](README.de.md)

---

## Ce que vous trouverez ici

| Fichier/dossier | Ce que c'est |
|---|---|
| `guia-especialistas-agencia.html` | **Le guide.** Ouvrez-le d'un double clic — il fonctionne hors ligne. Recherche, filtres, panneau « votre machine » et chaque spécialiste expliqué en langage simple, avec 4 situations d'utilisation concrètes. Disponible en anglais, portugais, espagnol, français et allemand. |
| `instaladores/instalar-linux.sh` | Installateur pour **Linux et macOS**. |
| `instaladores/instalar-windows.ps1` | Installateur pour **Windows** (nécessite uniquement Git for Windows). |
| `gerador/build.py` | Régénère le guide à partir de `dados/` (pour la maintenance). |
| `dados/` | Catalogue traduit + situations concrètes (JSON). |

## Bien démarrer (5 minutes)

### 1. Récupérez le guide
Cliquez sur **Code → Download ZIP** (ou clonez le dépôt) et ouvrez `guia-especialistas-agencia.html` — vous pouvez déjà parcourir les 283 spécialistes sans rien installer. Choisissez la langue dans le sélecteur en haut à droite.

### 2. Lancez l'installateur (une fois)
Il détecte les outils que vous avez (Claude Code, ZCode, Codex…), **vous demande votre langue**, vous demande où installer et combien de spécialistes amener, fait une **sauvegarde** de tout ce qu'il touche, et à la fin le panneau « votre machine » du guide se met à jour tout seul.

**Linux/macOS :**
```bash
cd instaladores
./instalar-linux.sh
```

**Windows** (PowerShell — prérequis : [Git for Windows](https://git-scm.com/download/win)) :
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # if prompted
.\instalar-windows.ps1
```

### 3. Installez depuis le guide (facultatif)
Dans le guide, le bouton **« ➕ Installer des spécialistes dans un outil »** demande *où* et *qui* (équipe de pré-lancement, équipe de formation, les 283, ou par division) et génère un `agency-plan.json`. Ensuite, lancez :

```bash
./instalar-linux.sh --plan agency-plan.json        # Linux/macOS
.\instalar-windows.ps1 -Plan agency-plan.json      # Windows
```

Vous pouvez aussi choisir la langue sans questions : `--lang en|pt|es|fr|de` (ou `-Lang` sous Windows).

## Ce que fait l'installateur (et ce qu'il ne fait pas)

✅ Détecte les outils installés et votre système d'exploitation
✅ Demande votre langue — tout suit ensuite cette langue, y compris les descriptions des spécialistes
✅ Télécharge/met à jour le catalogue officiel vers `~/.agency-agents`
✅ Convertit les agents avec le **convertisseur officiel** (résultat identique octet par octet)
✅ Fait une **sauvegarde** dans `~/.agency-agents-backup/` avant d'écraser quoi que ce soit
✅ Écrit `guia-status.js` à côté du guide (c'est lui qui alimente le panneau « votre machine »)
❌ **N'installe pas** les outils que vous n'avez pas (il configure seulement ceux qui existent déjà ou sont compatibles)
❌ **N'envoie rien** sur internet (seul le guide, quand vous le demandez, vérifie les releases GitHub)

## Mises à jour automatiques

Le guide vérifie (toutes les 24 h ou quand vous cliquez sur **🔄 Vérifier les mises à jour**) les releases officielles du catalogue, de l'app et de ce projet. Si quelque chose de nouveau sort, un badge apparaît en haut.

## Utiliser les spécialistes

Une fois installés, les spécialistes apparaissent dans vos outils :

- **Claude Code / ZCode / Codex / Gemini CLI…** — mentionnez le nom dans votre prompt : *« utilise le code-reviewer pour relire cette modification »*.
- **Dans ZCode**, ouvrez une session dans le dossier du projet et regardez **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — installez par *projet* (dans le dossier du dépôt).

Le guide lui-même contient le mode d'emploi complet : comment appeler, des exemples et les cinq règles d'or.

## Outils pris en charge

| Outil | Portée | Destination |
|---|---|---|
| Claude Code | utilisateur | `~/.claude/agents/*.md` |
| ZCode | utilisateur | `~/.zcode/agents/*.md` |
| Codex CLI | utilisateur | `~/.codex/agents/*.toml` (Windows : WSL) |
| Gemini CLI | utilisateur | `~/.gemini/agents/*.md` |
| GitHub Copilot | utilisateur | `~/.github/agents/*.md` |
| Qwen Code | utilisateur | `~/.qwen/agents/*.md` |
| opencode | utilisateur | `~/.config/opencode/agents/*.md` |
| Antigravity | utilisateur | `~/.gemini/config/skills/<slug>/SKILL.md` |
| Osaurus | utilisateur | `~/.osaurus/skills/…` (macOS uniquement) |
| Kimi CLI | utilisateur | `~/.config/kimi/agents/<slug>/` (Windows : WSL) |
| Cursor / Aider / Windsurf | par projet | dans le dossier du dépôt |

Les autres intégrations du catalogue (Mistral Vibe, DeepSeek Harness, OpenClaw…) fonctionnent via le convertisseur officiel ; pour celles-ci, préférez l'[Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Langues

Le guide et les deux installateurs sont livrés en **anglais, portugais, espagnol, français et allemand** — y compris toutes les descriptions des spécialistes et toutes les situations d'utilisation concrètes. Choisissez la langue pendant l'installation ou changez quand vous voulez dans le guide (sélecteur en haut à droite).

## Licences et crédits

- Ce projet : **MIT** (voir `LICENSE`).
- Catalogue et convertisseur : [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, par Michael Sitarzewski. Ce projet se contente de l'empaqueter, de le traduire et de le simplifier pour les débutants.
- Les descriptions et les situations d'utilisation ont été traduites/adaptées ; le texte original en anglais reste disponible dans le détail de chaque fiche.
