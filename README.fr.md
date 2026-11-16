# 🧭 Agency Agents Store — Guide des spécialistes & installateurs

[![CI](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml/badge.svg)](https://github.com/AtamisFilho/agency-agents-store/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/AtamisFilho/agency-agents-store)](https://github.com/AtamisFilho/agency-agents-store/releases)
[![CHANGELOG](https://img.shields.io/badge/CHANGELOG-v2.3.0-blue)](CHANGELOG.md)

**Un guide HTML + des installateurs qui amènent 283 spécialistes de l'IA dans vos outils de programmation** (Claude Code, ZCode, Codex, Gemini CLI, GitHub Copilot, Cursor, Antigravity et plus encore).

Conçu pour les « vibe coders » qui veulent une équipe de spécialistes numériques travaillant à leurs côtés — sans jargon, sans complications.

> Basé sur le catalogue open source [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (MIT) et sur l'[Agency Agents App](https://github.com/msitarzewski/agency-agents-app). Ce projet les empaquète, les traduit et les simplifie pour les débutants.

**🌐 Lisez ce guide en :** [English](README.md) · [Português](README.pt-BR.md) · [Español](README.es.md) · **[Français](README.fr.md)** · [Deutsch](README.de.md)

---

## Installez en une ligne

**Linux/macOS** (prérequis : `git` + `python3`) :
```bash
curl -fsSL https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.sh | bash
```

**Windows** (PowerShell — prérequis : [Git for Windows](https://git-scm.com/download/win)) :
```powershell
irm https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.ps1 | iex
```

La ligne unique télécharge l'installateur, les traductions et le guide dans `~/.agency-agents-store` et exécute tout depuis là. Vous préférez le dépôt complet ? **Code → Download ZIP** et continuez la lecture.

## Ce que contient ce dépôt

| Fichier/dossier | C'est quoi |
|---|---|
| `guia-especialistas-agencia.html` | **Le guide.** Double-clic pour ouvrir — fonctionne hors ligne. Recherche, filtres, panneau « votre machine » et chaque spécialiste expliqué simplement, avec 4 situations réelles d'utilisation. Disponible en anglais, portugais, espagnol, français et allemand. |
| `instaladores/instalar.sh` / `instalar.ps1` | **Bootstraps en une ligne** (les commandes ci-dessus). |
| `instaladores/instalar-linux.sh` | Installateur pour **Linux et macOS** (wrapper léger — vérifie les prérequis puis appelle le moteur). |
| `instaladores/agency-install.py` | **Le cœur de l'installateur** (tous les drapeaux, toute la logique) pour Linux/macOS. |
| `instaladores/instalar-windows.ps1` | Installateur pour **Windows** (PowerShell natif, sans Python ; partage le même fichier de traductions). |
| `gerador/build.py` | Régénère le guide depuis `dados/` (maintenance). |
| `dados/` | Catalogue traduit + situations réelles + `meta.json` (source unique de vérité) + `i18n-instalador.json` (messages des installateurs, 5 langues). |

## Comment commencer (5 minutes)

### 1. Récupérez le guide
Cliquez sur **Code → Download ZIP** (ou clonez le dépôt) et ouvrez `guia-especialistas-agencia.html` — vous pouvez déjà parcourir les 283 spécialistes sans rien installer. Choisissez la langue dans le sélecteur en haut à droite.

### 2. Lancez l'installateur (une fois)
Il détecte vos outils (Claude Code, ZCode, Codex…), **demande votre langue** (et la garde dans `~/.agency-agents/config` ; la locale du système sert de premier défaut), demande où installer et combien de spécialistes recruter, **sauvegarde** tout ce qu'il touche et, à la fin, le panneau « votre machine » du guide se met à jour tout seul.

**Linux/macOS** (depuis le dépôt) :
```bash
./instaladores/instalar-linux.sh
```

**Windows** (PowerShell — prérequis : [Git for Windows](https://git-scm.com/download/win)) :
```powershell
cd instaladores
Set-ExecutionPolicy -Scope Process Bypass   # si demandé
.\instalar-windows.ps1
```

### 3. Installez depuis le guide (facultatif)
Dans le guide, le bouton **« ➕ Installer des spécialistes dans un outil »** demande *où* et *qui* (escouade pré-lancement, escouade d'entraînement, les 283, ou par division) et génère un `agency-plan.json`. Ensuite, depuis le dossier où vous avez enregistré le plan :

```bash
./instaladores/instalar-linux.sh --plan          # le chemin est facultatif : il trouve agency-plan.json
.\instalar-windows.ps1 -PlanAuto                 # pareil sous Windows (trouve le plan automatiquement)
```

L'installateur cherche le plan automatiquement dans `.`, `..`, le dossier de l'installateur, `~/Downloads` et `~/Documents` (l'ancien nom `plano-agencia.json` fonctionne aussi).

## Automatisation et contrôle fin (mêmes drapeaux sur les deux plateformes)

| Linux/macOS | Windows | Ce que ça fait |
|---|---|---|
| `--tool zcode,codex` | `-Tool zcode,codex` | Choix des outils sans question (ids valides : `--list`) |
| `--squad pre\|treino\|all` | `-Squad pre\|treino\|all` | Choix de l'escouade sans question (CI/scripts) |
| `--plan [FICHIER]` | `-Plan FICHIER` / `-PlanAuto` | Utilise le plan du guide (recherche auto : `--plan` sans chemin, ou `-PlanAuto`) |
| `--dry-run` | `-DryRun` | Prévisualise tout ce qui serait touché — n'écrit rien |
| `--list` | `-List` | Catalogue/outils/escouades en JSON sur stdout (jamais de réseau) |
| `--status` | `-Status` | Détection seule + Rafraîchit le panneau du guide (sans réseau) |
| `--status --json` | `-Status -Json` | État de la machine en JSON sur stdout (n'écrit rien) |
| `--uninstall` | `-Uninstall` | Retire les spécialistes de l'agence (sauvegarde avant ; garde vos fichiers) |
| `--dir <chemin>` | `-Dir <chemin>` | Installe dans un dossier de **projet** — active Cursor/Aider/Windsurf |
| `--lang en\|pt\|es\|fr\|de` | `-Lang en\|pt\|es\|fr\|de` | Langue (mémorisée pour les prochaines fois) |

Exemples :
```bash
./instaladores/instalar-linux.sh --tool cursor --dir ~/code/mon-app --squad treino   # règles Cursor dans un projet
./instaladores/instalar-linux.sh --uninstall --tool zcode                           # retirer (avec sauvegarde)
./instaladores/instalar-linux.sh --dry-run --tool claudeCode --squad pre            # juste regarder
./instaladores/instalar-linux.sh --list | jq '.tools[].id'                          # pour scripts
```

## Ce que fait l'installateur (et ce qu'il ne fait pas)

✅ Détecte les outils installés et votre système d'exploitation
✅ Demande votre langue une fois — et s'en souvient (la locale de l'OS est le défaut)
✅ Télécharge/met à jour le catalogue officiel dans `~/.agency-agents`
✅ Convertit les agents avec le **convertisseur officiel** (sortie identique octet par octet)
✅ **Sauvegarde** dans `~/.agency-agents-backup/` avant d'écraser quoi que ce soit
✅ **Vérifie honnêtement** : indique combien des spécialistes demandés sont réellement présents
✅ Écrit `guia-status.js` à côté du guide (il alimente le panneau « votre machine »)
✅ Se désinstalle proprement (`--uninstall`) — seuls les fichiers de l'agence, toujours avec sauvegarde
❌ **N'**installe **pas** d'outils que vous n'avez pas (ne configure que l'existant/compatible)
❌ **N'**utilise **pas** le réseau en modes `--status`/`--list`/`--json` (installer oui, pour récupérer le catalogue)
❌ **N'**envoie **rien** nulle part ailleurs (seul le guide, à votre demande, consulte les releases GitHub)

## Mises à jour automatiques

Le guide vérifie (toutes les 24h ou au clic sur **🔄 Vérifier les mises à jour**) les releases officielles du catalogue, de l'app et de ce projet. Si du neuf sort, un badge apparaît en haut. Les releases de ce projet suivent [CHANGELOG.md](CHANGELOG.md) — le tag (`vX.Y.Z`) correspond toujours à la version du guide.

## Installer comme app (PWA)

Le guide est aussi une **app installable et 100 % hors ligne** (PWA) :

- **GitHub Pages :** ouvrez https://atamisfilho.github.io/agency-agents-store/ et choisissez **Installer l'app** (icône dans la barre d'adresse, ou menu du navigateur → « Installer » / « Ajouter à l'écran d'accueil »).
- **Hébergement perso :** récupérez `agency-agents-pwa-vX.Y.Z.zip` dans les [releases](https://github.com/AtamisFilho/agency-agents-store/releases) et déposez les fichiers sur n'importe quel hébergement statique HTTPS — c'est tout.

Le premier chargement met tout en cache ; ensuite ça marche sans internet, et le service worker maintient l'app à jour à la visite en ligne suivante. (Installer la PWA place le *guide* sur votre appareil — les spécialistes, eux, continuent d'aller dans vos outils de code via l'installateur ci-dessus.)

Fichiers du PWA : `manifest.webmanifest`, `sw.js`, `index.html`, `pwa-icons/` (générés par `gerador/gen_icons.py`), ZIP du release via `gerador/package_pwa.py`.

## Utiliser les spécialistes

Une fois installés, les spécialistes apparaissent dans vos outils :

- **Claude Code / ZCode / Codex / Gemini CLI…** — mentionnez leur nom dans la demande : *« utilise le reality-checker pour vérifier le login »*.
- **Dans ZCode**, ouvrez la session dans le dossier du projet et regardez **Settings → Subagents**.
- **Cursor / Aider / Windsurf** — installation par *projet* avec `--dir <dossier du projet>` (règles/index vivent dans le dépôt).

Le guide lui-même contient le playbook complet : comment les appeler, des exemples et les cinq règles d'or.

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
| Cursor | par projet (`--dir`) | `<projet>/.cursor/rules/<slug>.mdc` |
| Aider | par projet (`--dir`) | `<projet>/CONVENTIONS.md` (index) |
| Windsurf | par projet (`--dir`) | `<projet>/.windsurfrules` (index) |

Les autres intégrations du catalogue (Mistral Vibe, DeepSeek Harness, OpenClaw…) passent par le convertisseur officiel ; pour elles, préférez l'[Agency Agents App](https://github.com/msitarzewski/agency-agents-app/releases).

## Langues

Le guide et les deux installateurs existent en **anglais, portugais, espagnol, français et allemand** — y compris toutes les descriptions des spécialistes et les situations réelles d'utilisation. Choisissez la langue à l'installation (elle est mémorisée) ou changez quand vous voulez dans le guide (sélecteur en haut).

## Développement

- `python3 gerador/build.py` régénère le guide depuis `dados/` — la CI échoue si le HTML commité ne correspond pas aux données.
- `python3 tests/test_guide.py` — tests statiques du guide (payload, parité i18n, XSS).
- `bash tests/run-tests.sh` — suite adversariaire de l'installateur (comptages dynamiques du catalogue, tous les drapeaux).
- La CI exécute tout à chaque push/PR (voir [.github/workflows/ci.yml](.github/workflows/ci.yml)).

## Licences et crédits

- Ce projet : **MIT** (voir `LICENSE`).
- Catalogue et convertisseur : [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — MIT, par Michael Sitarzewski. Ce projet ne fait que l'empaqueter, le traduire et le simplifier pour les débutants.
- Descriptions et situations d'utilisation traduites/adaptées ; le texte original anglais est dans le détail de chaque carte.
