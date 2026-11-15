# ============================================================================
# instalar-windows.ps1 — Agency Agents Store (Windows)
#
# Detects your coding tools (Claude Code, ZCode, Codex, Gemini CLI...),
# asks your language, installs agency specialists into them (backing up
# anything it touches) and updates the guide's machine panel.
#
# PREREQUISITE: Git for Windows (https://git-scm.com/download/win) — it brings
# the bash used to convert the agents.
#
# Usage (PowerShell):
#   .\instalar-windows.ps1                              # interactive
#   .\instalar-windows.ps1 -Plan agency-plan.json       # use the guide's plan
#   .\instalar-windows.ps1 -Lang pt -Plan agency-plan.json
#   .\instalar-windows.ps1 -Status                      # detect + refresh panel
# ============================================================================
[CmdletBinding()]
param(
  [string]$Plan = "",
  [string]$Lang = "",
  [switch]$Status
)
$ErrorActionPreference = "Stop"

function Say($m)  { Write-Host "[ok]  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!!]  $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "[err] $m" -ForegroundColor Red; exit 1 }

# ---------- i18n ----------
$ValidLangs = @("en","pt","es","fr","de")
$I18N = @{
  en = @{
    pick_lang = "Choose your language:"; need_git = "Git not found. Install it first: https://git-scm.com/download/win and run again."
    cat_update = "Updating the catalog in {0}..."; cat_clone = "Downloading the official agent catalog (~\.agency-agents)..."
    cat_fail = "Failed to clone the catalog. Check your internet connection."
    found = "Tools found on this machine:"; installed_ok = "installed ✓"; not_installed = "not installed (I can still configure it)"
    pick_tools = "Comma-separated numbers (Enter = all):"; pick_squad = "How many specialists to install?"
    squad1 = "1) Pre-launch squad (12 — recommended)"; squad2 = "2) Training squad (4)"; squad3 = "3) Everyone (the whole agency)"
    install_ok = "Specialists installed in {0} ✓ ({1} at the destination)"
    install_fail = "NO specialist found in {0} after installation — see warnings above."
    panel_updated = "Guide panel updated: {0}"; guia_not_found = "guia-especialistas-agencia.html not found next to the installer."
    status_fail = "Could not write the guide panel (guia-status.js) — check the folder permissions. Everything else succeeded."
    done = "Done! Real state of this machine:"; detected = "detected"; absent = "absent"; specialists = "agency specialist(s)"
    opening = "Opening the guide..."; rerun = "Tip: run again anytime — it is safe (backs up before overwriting)."
    err_plan = "Plan file not found: {0}"; err_lang = "Invalid language: {0} (use en, pt, es, fr or de)"
    err_bad_plan = "Invalid plan file: {0}"; unsupported = "Tool {0} not supported by this installer (use the Agency Agents App)."
  }
  pt = @{
    pick_lang = "Escolha o seu idioma:"; need_git = "Git não encontrado. Instale antes: https://git-scm.com/download/win e rode de novo."
    cat_update = "Atualizando o catálogo em {0}..."; cat_clone = "Baixando o catálogo oficial de agentes (~\.agency-agents)..."
    cat_fail = "Falha ao clonar o catálogo. Verifique sua internet."
    found = "Ferramentas encontradas nesta máquina:"; installed_ok = "instalada ✓"; not_installed = "não instalada (posso configurar mesmo assim)"
    pick_tools = "Números separados por vírgula (Enter = todas):"; pick_squad = "Quantos especialistas instalar?"
    squad1 = "1) Squad pré-lançamento (12 — recomendada)"; squad2 = "2) Squad de treino (4)"; squad3 = "3) Todos (a agência inteira)"
    install_ok = "Especialistas instalados em {0} ✓ ({1} no destino)"
    install_fail = "NENHUM especialista em {0} após a instalação — veja os avisos acima."
    panel_updated = "Painel do guia atualizado: {0}"; guia_not_found = "guia-especialistas-agencia.html não encontrado junto ao instalador."
    status_fail = "Não consegui escrever o painel do guia (guia-status.js) — verifique as permissões da pasta. Todo o resto funcionou."
    done = "Concluído! Estado real desta máquina:"; detected = "detectada"; absent = "ausente"; specialists = "especialista(s) da agência"
    opening = "Abrindo o guia..."; rerun = "Dica: rode de novo a qualquer momento — é seguro (faz backup antes de sobrescrever)."
    err_plan = "Plano não encontrado: {0}"; err_lang = "Idioma inválido: {0} (use en, pt, es, fr ou de)"
    err_bad_plan = "Arquivo de plano inválido: {0}"; unsupported = "Ferramenta {0} não suportada por este instalador (use o Agency Agents App)."
  }
  es = @{
    pick_lang = "Elige tu idioma:"; need_git = "Git no encontrado. Instálalo antes: https://git-scm.com/download/win y vuelve a ejecutar."
    cat_update = "Actualizando el catálogo en {0}..."; cat_clone = "Descargando el catálogo oficial de agentes (~\.agency-agents)..."
    cat_fail = "Error al clonar el catálogo. Verifica tu conexión."
    found = "Herramientas encontradas en esta máquina:"; installed_ok = "instalada ✓"; not_installed = "no instalada (puedo configurarla igualmente)"
    pick_tools = "Números separados por comas (Enter = todas):"; pick_squad = "¿Cuántos especialistas instalar?"
    squad1 = "1) Escuadrón pre-lanzamiento (12 — recomendado)"; squad2 = "2) Escuadrón de entrenamiento (4)"; squad3 = "3) Todos (toda la agencia)"
    install_ok = "Especialistas instalados en {0} ✓ ({1} en el destino)"
    install_fail = "NINGÚN especialista en {0} tras la instalación — mira los avisos de arriba."
    panel_updated = "Panel de la guía actualizado: {0}"; guia_not_found = "guia-especialistas-agencia.html no encontrado junto al instalador."
    status_fail = "No pude escribir el panel de la guía (guia-status.js) — revisa los permisos de la carpeta. Todo lo demás funcionó."
    done = "¡Hecho! Estado real de esta máquina:"; detected = "detectada"; absent = "ausente"; specialists = "especialista(s) de la agencia"
    opening = "Abriendo la guía..."; rerun = "Consejo: ejecútalo cuando quieras — es seguro (copia de seguridad antes de sobrescribir)."
    err_plan = "Plan no encontrado: {0}"; err_lang = "Idioma inválido: {0} (usa en, pt, es, fr o de)"
    err_bad_plan = "Archivo de plan inválido: {0}"; unsupported = "Herramienta {0} no soportada por este instalador (usa el Agency Agents App)."
  }
  fr = @{
    pick_lang = "Choisissez votre langue :"; need_git = "Git introuvable. Installez-le d'abord : https://git-scm.com/download/win puis relancez."
    cat_update = "Mise à jour du catalogue dans {0}..."; cat_clone = "Téléchargement du catalogue officiel d'agents (~\.agency-agents)..."
    cat_fail = "Échec du clonage du catalogue. Vérifiez votre connexion."
    found = "Outils trouvés sur cette machine :"; installed_ok = "installé ✓"; not_installed = "non installé (je peux le configurer quand même)"
    pick_tools = "Numéros séparés par des virgules (Entrée = tous) :"; pick_squad = "Combien de spécialistes installer ?"
    squad1 = "1) Escouade pré-lancement (12 — recommandée)"; squad2 = "2) Escouade d'entraînement (4)"; squad3 = "3) Tout le monde (toute l'agence)"
    install_ok = "Spécialistes installés dans {0} ✓ ({1} à destination)"
    install_fail = "AUCUN spécialiste dans {0} après l'installation — voir les avertissements ci-dessus."
    panel_updated = "Panneau du guide mis à jour : {0}"; guia_not_found = "guia-especialistas-agencia.html introuvable à côté de l'installateur."
    status_fail = "Impossible d'écrire le panneau du guide (guia-status.js) — vérifiez les permissions du dossier. Tout le reste a réussi."
    done = "Terminé ! État réel de cette machine :"; detected = "détecté"; absent = "absent"; specialists = "spécialiste(s) de l'agence"
    opening = "Ouverture du guide..."; rerun = "Astuce : relancez quand vous voulez — c'est sûr (sauvegarde avant d'écraser)."
    err_plan = "Plan introuvable : {0}"; err_lang = "Langue invalide : {0} (utilisez en, pt, es, fr ou de)"
    err_bad_plan = "Fichier de plan invalide : {0}"; unsupported = "Outil {0} pas encore pris en charge (utilisez l'Agency Agents App)."
  }
  de = @{
    pick_lang = "Wählen Sie Ihre Sprache:"; need_git = "Git nicht gefunden. Bitte zuerst installieren: https://git-scm.com/download/win und erneut ausführen."
    cat_update = "Aktualisiere den Katalog in {0}..."; cat_clone = "Lade den offiziellen Agentenkatalog herunter (~\.agency-agents)..."
    cat_fail = "Klonen des Katalogs fehlgeschlagen. Bitte Internetverbindung prüfen."
    found = "Auf dieser Maschine gefundene Tools:"; installed_ok = "installiert ✓"; not_installed = "nicht installiert (ich kann sie trotzdem einrichten)"
    pick_tools = "Durch Kommas getrennte Nummern (Enter = alle):"; pick_squad = "Wie viele Spezialisten installieren?"
    squad1 = "1) Pre-Launch-Team (12 — empfohlen)"; squad2 = "2) Trainings-Team (4)"; squad3 = "3) Alle (die ganze Agentur)"
    install_ok = "Spezialisten installiert in {0} ✓ ({1} am Zielort)"
    install_fail = "KEIN Spezialist in {0} nach der Installation — siehe Warnungen oben."
    panel_updated = "Guide-Panel aktualisiert: {0}"; guia_not_found = "guia-especialistas-agencia.html neben dem Installer nicht gefunden."
    status_fail = "Konnte das Guide-Panel (guia-status.js) nicht schreiben — bitte Ordnerberechtigungen prüfen. Alles andere war erfolgreich."
    done = "Fertig! Echter Zustand dieser Maschine:"; detected = "erkannt"; absent = "fehlt"; specialists = "Agentur-Spezialist(en)"
    opening = "Öffne den Guide..."; rerun = "Tipp: jederzeit erneut ausführen — sicher (Backup vor dem Überschreiben)."
    err_plan = "Plan nicht gefunden: {0}"; err_lang = "Ungültige Sprache: {0} (verwende en, pt, es, fr oder de)"
    err_bad_plan = "Ungültige Plandatei: {0}"; unsupported = "Tool {0} wird von diesem Installer nicht unterstützt (nutze die Agency Agents App)."
  }
}
if ($Lang -and $ValidLangs -notcontains $Lang) { Err (($I18N["en"]).err_lang -f $Lang) }
if (-not $Lang -and [Environment]::UserInteractive) {
  Write-Host (($I18N["en"]).pick_lang)
  Write-Host "  1) English   2) Português   3) Español   4) Français   5) Deutsch"
  $ln = Read-Host "1-5 [1]"
  if (-not $ln) { $ln = "1" }
  $Lang = @("en","pt","es","fr","de")[[int]$ln - 1]
}
if (-not $Lang) { $Lang = "en" }
$M = $I18N[$Lang]
function Msg($key, $vals) { $s = $M[$key]; if ($vals) { return ($s -f $vals) } return $s }

# ---------- prerequisites ----------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Err $M.need_git }
$GitDir = Split-Path -Parent (Get-Command git).Source
$GitRoot = Split-Path -Parent $GitDir
$Bash = Join-Path $GitRoot "bin\bash.exe"
if (-not (Test-Path $Bash)) { Err "bash.exe not found inside Git ($Bash). Reinstall Git for Windows with default options." }

$Catalog = Join-Path $env:USERPROFILE ".agency-agents"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Work = Join-Path $env:TEMP ("agencia-" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $Work | Out-Null
# caminho do catálogo em formato MSYS (/c/Users/...) para o bash do Git
$CatalogMsys = "/" + ($Catalog.Substring(0,1).ToLower()) + ($Catalog.Substring(2) -replace "\\","/")

# ---------- plan validation ----------
if ($Plan) {
  if (-not (Test-Path $Plan)) { Err (Msg "err_plan" $Plan) }
  try {
    $plano = Get-Content $Plan -Raw | ConvertFrom-Json
    if ($null -eq $plano.agentes -or $null -eq $plano.ferramentas) { throw "shape" }
    foreach ($ft in $plano.ferramentas) { if ("$ft".Trim() -eq "") { throw "ferramentas" } }
    foreach ($ag in $plano.agentes) {
      $f = $ag.file -replace "/","\"
      if ($f.StartsWith("\") -or $f.Contains("..") -or $f -match "^[A-Za-z]:") { throw "unsafe path: $($ag.file)" }
      if (-not $ag.slug -or $ag.slug -match "[/\\]") { throw "unsafe slug: $($ag.slug)" }
    }
  } catch { Err (Msg "err_bad_plan" $Plan) }
}

# ---------- catalog ----------
if (Test-Path (Join-Path $Catalog ".git")) {
  Say (Msg "cat_update" $Catalog)
  & git -C $Catalog pull --ff-only 2>$null | Out-Null
} else {
  Say $M.cat_clone
  & git clone --depth 1 https://github.com/msitarzewski/agency-agents.git $Catalog 2>$null | Out-Null
  if (-not (Test-Path $Catalog)) { Err $M.cat_fail }
}
$CatCommit = (& git -C $Catalog rev-parse --short HEAD) 2>$null
if (-not $CatCommit) { $CatCommit = "?" }

# ---------- tools ----------
$TOOLS = @(
  @{ id="claudeCode";  label="Claude Code";    dirs=@(".claude");            dest=".claude\agents";            render=$null; compat="sim" },
  @{ id="zcode";       label="ZCode";          dirs=@(".zcode");             dest=".zcode\agents";             render=@("zcode","agents","arquivo");  compat="sim" },
  @{ id="codex";       label="Codex CLI";      dirs=@(".codex");             dest=".codex\agents";             render=@("codex","agents","arquivo");  compat="wsl" },
  @{ id="geminiCli";   label="Gemini CLI";     dirs=@(".gemini");            dest=".gemini\agents";            render=@("gemini-cli","agents","arquivo"); compat="sim" },
  @{ id="copilot";     label="GitHub Copilot"; dirs=@(".github\agents",".copilot"); dest=".github\agents";     render=$null; compat="sim" },
  @{ id="qwen";        label="Qwen Code";      dirs=@(".qwen");              dest=".qwen\agents";              render=@("qwen","agents","arquivo");   compat="sim" },
  @{ id="opencode";    label="opencode";       dirs=@(".config\opencode");   dest=".config\opencode\agents";   render=@("opencode","agents","arquivo"); compat="sim" },
  @{ id="antigravity"; label="Antigravity";    dirs=@(".gemini\config");     dest=".gemini\config\skills";     render=@("antigravity","skills","pasta"); compat="sim" },
  @{ id="osaurus";     label="Osaurus";        dirs=@(".osaurus");           dest=".osaurus\skills";           render=@("osaurus","skills","pasta");  compat="nao" },
  @{ id="kimi";        label="Kimi CLI";       dirs=@(".config\kimi");       dest=".config\kimi\agents";       render=@("kimi","agents","pasta");     compat="wsl" }
)
foreach ($t in $TOOLS) {
  $t.installed = ($t.dirs | Where-Object { Test-Path (Join-Path $env:USERPROFILE $_) }).Count -gt 0
  $d = Join-Path $env:USERPROFILE ($t.dest -replace "/", "\")
  $t.agentCount = 0
  if (Test-Path $d) {
    $t.agentCount = (Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".md",".toml" -or $_.Name -in "SKILL.md","agent.yaml" } | Measure-Object).Count
  }
}

# ---------- install helpers ----------
function Backup-IfChanged($dst, $src) {
  # backup honesto: só quando existe e o conteúdo vai mudar de verdade
  if (-not (Test-Path $dst)) { return }
  $diff = $true
  if ((Test-Path $dst -PathType Container) -and (Test-Path $src -PathType Container)) {
    $diff = $true  # pastas: sempre salva cópia antes de substituir
  } else {
    try { $diff = (Get-FileHash $dst).Hash -ne (Get-FileHash $src).Hash } catch { $diff = $true }
  }
  if (-not $diff) { return }
  $bdir = Join-Path $env:USERPROFILE (".agency-agents-backup\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
  New-Item -ItemType Directory -Force -Path $bdir | Out-Null
  $leaf = Split-Path $dst -Leaf
  if (Test-Path $dst -PathType Container) { Copy-Item $dst (Join-Path $bdir "$leaf.bak") -Recurse -Force }
  else { Copy-Item $dst (Join-Path $bdir "$leaf.bak") -Force }
}
function Install-IdentityAll($destRel) {
  $dest = Join-Path $env:USERPROFILE $destRel
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  $divs = @("academic","design","engineering","finance","game-development","gis","healthcare","marketing","paid-media","product","project-management","research","sales","security","spatial-computing","specialized","support","testing")
  foreach ($dv in $divs) {
    $src = Join-Path $Catalog $dv
    if (Test-Path $src) {
      Get-ChildItem $src -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "^(?i)(readme|contributing|worklog)" } |
        ForEach-Object { Backup-IfChanged (Join-Path $dest $_.Name) $_.FullName; Copy-Item $_.FullName $dest -Force }
    }
  }
}
function Install-IdentityPlano($planoPath, $destRel) {
  $dest = Join-Path $env:USERPROFILE $destRel
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  $plano = Get-Content $planoPath -Raw | ConvertFrom-Json
  if (@($plano.agentes).Count -eq 0) { Install-IdentityAll $destRel; return }  # vazio = todos
  $catFull = (Resolve-Path $Catalog).Path
  foreach ($ag in $plano.agentes) {
    $frel = $ag.file -replace "/","\"
    $src = Join-Path $Catalog $frel
    # proteção: o arquivo tem que ficar DENTRO do catálogo
    $resolved = (Resolve-Path $src -ErrorAction SilentlyContinue).Path
    if ($resolved -and $resolved.StartsWith($catFull) -and (Test-Path $src)) { Backup-IfChanged (Join-Path $dest (Split-Path $frel -Leaf)) $src; Copy-Item $src $dest -Force }
  }
}
function Install-Rendered($tool, $sub, $destRel, $mode) {
  $outMsys = "/tmp/agencia-out-" + [guid]::NewGuid().ToString("N").Substring(0,6)
  & $Bash -lc "cd '$CatalogMsys' && bash scripts/convert.sh --tool $tool --out $outMsys" 2>$null | Out-Null
  # converte o caminho MSYS de volta para Windows
  $winOut = (& $Bash -lc "cygpath -w $outMsys/$tool/$sub" 2>$null)
  if (-not $winOut -or -not (Test-Path $winOut)) { Warn "render $tool/$sub failed"; return }
  $src = $winOut
  $dest = Join-Path $env:USERPROFILE $destRel
  # filtro pelo plano: copia só os slugs pedidos (all/vazio = tudo; falha = nada, por segurança)
  $slugs = $null
  if ($slugsFile -and $slugsFile -ne "all" -and (Test-Path $slugsFile)) {
    try {
      $pf = Get-Content $slugsFile -Raw | ConvertFrom-Json
      $slugs = @($pf.agentes | ForEach-Object { $_.slug })
      if ($slugs.Count -eq 0) { $slugs = $null }
    } catch { $slugs = @("__PLAN_FILTER_ERROR__"); Warn "plan filter error: installing nothing for safety" }
  }
  if ($mode -eq "arquivo") {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem $src -File | ForEach-Object {
      if ($slugs -and $slugs -notcontains $_.BaseName) { return }
      Backup-IfChanged (Join-Path $dest $_.Name) $_.FullName
      Copy-Item $_.FullName $dest -Force
    }
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Get-ChildItem $src -Directory | ForEach-Object {
      if ($slugs -and $slugs -notcontains $_.Name) { return }
      $target = Join-Path $dest $_.Name
      Backup-IfChanged $target $_.FullName
      if (Test-Path $target) { Remove-Item $target -Recurse -Force }
      Copy-Item $_.FullName $target -Recurse -Force
    }
  }
}

# ---------- interactive plan ----------
$doTools = @()
$slugsFile = ""
if ($Plan) { $doTools = $plano.ferramentas; $slugsFile = (Resolve-Path $Plan).Path }
elseif (-not $Status) {
  if (-not [Environment]::UserInteractive) { Err "Interactive mode needs a console. Use: -Plan agency-plan.json" }
  Say $M.found
  $i = 1; $opts = @()
  foreach ($t in $TOOLS) {
    if ($t.compat -eq "nao") { continue }
    $st = $M.not_installed; if ($t.installed) { $st = $M.installed_ok }
    $wsl = ""; if ($t.compat -eq "wsl") { $wsl = " (via WSL)" }
    Write-Host ("  {0,2}) {1,-14} {2}{3}" -f $i, $t.id, $st, $wsl)
    $opts += $t.id; $i++
  }
  $resp = Read-Host $M.pick_tools
  if (-not $resp.Trim()) { $doTools = $opts }
  else {
    $doTools = @()
    foreach ($n in $resp.Split(",")) {
      $idx = 0; if ([int]::TryParse($n.Trim(), [ref]$idx)) { if ($idx -ge 1 -and $idx -le $opts.Count) { $doTools += $opts[$idx-1] } }
    }
    if (-not $doTools) { $doTools = $opts }
  }
  $s = Read-Host ("{0}  {1}  {2}  {3}  [1]" -f $M.pick_squad, $M.squad1, $M.squad2, $M.squad3)
  if (-not $s) { $s = "1" }
  if ($s -eq "3") { $slugsFile = "all" }
  elseif ($s -eq "2") { $slugsFile = "squad4" }
  else { $slugsFile = "squad12" }
}

function Install-One($id) {
  $t = $TOOLS | Where-Object { $_.id -eq $id }
  if (-not $t) { Warn (Msg "unsupported" $id); return }
  if ($null -eq $t.render) {
    if ($slugsFile -is [string] -and $slugsFile -match "^squad\d$") {
      $sqJson = Join-Path $ScriptDir "..\dados\squads.json"
      $key = if ($slugsFile -eq "squad12") { "pre-lancamento" } else { "treino" }
      $tmp = Join-Path $Work "plano.json"
      $sq = (Get-Content $sqJson -Raw | ConvertFrom-Json).$key
      @{ agentes = $sq.agentes } | ConvertTo-Json -Depth 5 | Set-Content $tmp -Encoding UTF8
      Install-IdentityPlano $tmp $t.dest
    }
    elseif ($slugsFile) { Install-IdentityPlano $slugsFile $t.dest }
    else { Install-IdentityAll $t.dest }
  } else {
    Install-Rendered $t.render[0] $t.render[1] $t.dest $t.render[2]
  }
  $d = Join-Path $env:USERPROFILE ($t.dest -replace "/", "\")
  $n = 0
  if (Test-Path $d) { $n = (Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".md",".toml" -or $_.Name -in "SKILL.md","agent.yaml" } | Measure-Object).Count }
  if ($n -eq 0) { Warn ($M.install_fail -f $t.label) } else { Say ($M.install_ok -f $t.label, $n) }
}
if (-not $Status -and $doTools.Count -gt 0) { foreach ($id in $doTools) { Install-One ("$id".Trim()) } }

# ---------- guia-status.js ----------
$guiaDirs = @((Join-Path $ScriptDir ".."), (Join-Path $env:USERPROFILE "Documentos"), (Join-Path $env:USERPROFILE "Documents"))
$guDir = $guiaDirs | Where-Object { Test-Path (Join-Path $_ "guia-especialistas-agencia.html") } | Select-Object -First 1
$statusObj = [ordered]@{
  version = 1
  lang = $Lang
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  os = @{ family = "windows"; label = "Windows"; arch = $env:PROCESSOR_ARCHITECTURE }
  catalog = @{ path = $Catalog; commit = $CatCommit; updated = (Get-Date).ToString("yyyy-MM-dd") }
  tools = @($TOOLS | ForEach-Object { [ordered]@{ id = $_.id; installed = [bool]$_.installed; agentCount = $_.agentCount } })
}
$json = $statusObj | ConvertTo-Json -Depth 5 -Compress
if ($guDir) {
  try {
    Set-Content -Path (Join-Path $guDir "guia-status.js") -Value ("window.GUIA_STATUS = " + $json + ";") -Encoding ASCII -ErrorAction Stop
    Say (Msg "panel_updated" (Join-Path $guDir "guia-status.js"))
  } catch {
    Warn $M.status_fail   # instalação já feita: não aborta por causa do painel
  }
  if (-not $Status) { Say $M.opening; Start-Process (Join-Path $guDir "guia-especialistas-agencia.html") }
} else {
  Warn $M.guia_not_found
}
Say $M.rerun
Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
