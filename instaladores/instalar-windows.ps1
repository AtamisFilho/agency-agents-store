# ============================================================================
# instalar-windows.ps1 — Agency Agents Store (Windows)
#
# Detects your coding tools (Claude Code, ZCode, Codex, Gemini CLI...),
# asks your language, installs agency specialists into them (backing up
# anything it touches) and updates the guide's machine panel.
#
# Translations come from the SAME source as the Linux/macOS driver:
#   dados/i18n-instalador.json  (single source of truth — no divergence)
#
# PREREQUISITE: Git for Windows (https://git-scm.com/download/win) — it brings
# the bash used to convert the agents.
#
# Usage (PowerShell):
#   .\instalar-windows.ps1                                # interactive
#   .\instalar-windows.ps1 -Plan agency-plan.json         # guide plan (explicit path)
#   .\instalar-windows.ps1 -PlanAuto                      # find & use agency-plan.json automatically
#   .\instalar-windows.ps1 -Lang pt -Plan agency-plan.json
#   .\instalar-windows.ps1 -Tool zcode,codex -Squad pre   # non-interactive (CI/scripts)
#   .\instalar-windows.ps1 -Tool cursor -Dir C:\my\project -Squad treino
#   .\instalar-windows.ps1 -Status                        # detect + refresh panel (NO network)
#   .\instalar-windows.ps1 -Status -Json                  # status as JSON on stdout (writes nothing)
#   .\instalar-windows.ps1 -List                          # catalog/tools/squads as JSON (no network)
#   .\instalar-windows.ps1 -DryRun -Tool zcode -Squad treino
#   .\instalar-windows.ps1 -Uninstall -Tool zcode         # remove (backs up first)
# ============================================================================
[CmdletBinding()]
param(
  [string]$Plan = "",
  [switch]$PlanAuto,
  [string]$Lang = "",
  [switch]$Status,
  [switch]$Json,
  [switch]$List,
  [switch]$Uninstall,
  [switch]$DryRun,
  [string]$Tool = "",
  [string]$Squad = "",
  [string]$Dir = ""
)
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Catalog   = Join-Path $env:USERPROFILE ".agency-agents"
$BackupDir = Join-Path $env:USERPROFILE ".agency-agents-backup"
$StoreDir  = Join-Path $env:USERPROFILE ".agency-agents-store"
$ConfigFile = Join-Path $Catalog "config"
$GuideName  = "guia-especialistas-agencia.html"
$ValidLangs = @("en","pt","es","fr","de")
$PlanNames  = @("agency-plan.json", "plano-agencia.json")
$Ts = Get-Date -Format "yyyyMMdd-HHmmss"

function Say($m)  {
  if ($Json -or $List) { [Console]::Error.WriteLine("[ok]  $m") }   # stdout é dado estruturado
  else { Write-Host "[ok]  $m" -ForegroundColor Green }
}
function Warn($m) {
  # -Json/-List: stdout é dado estruturado — avisos vão para stderr (igual ao driver Python)
  if ($Json -or $List) { [Console]::Error.WriteLine("[!!]  $m") }
  else { Write-Host "[!!]  $m" -ForegroundColor Yellow }
}
function Die($m)  { Write-Host "[err] $m" -ForegroundColor Red; exit 1 }

# PS 5.1: com $ErrorActionPreference="Stop", o stderr de um comando NATIVO redirecionado
# (2>$null) vira NativeCommandError FATAL — e git/bash sempre escrevem em stderr.
# Todo comando nativo passa por aqui: roda com EAP Continue e devolve stdout + exit code.
function Invoke-Native($sb) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $out = $null; $code = 1
  try { $out = (& $sb) 2>$null; $code = $LASTEXITCODE } catch { $code = 1 } finally { $ErrorActionPreference = $prev }
  return @{ Out = @($out); Code = $code }
}

# ---------- i18n: fonte única compartilhada com o driver Linux/macOS ----------
$I18nFile = @((Join-Path $ScriptDir "..\dados\i18n-instalador.json"), (Join-Path $StoreDir "dados\i18n-instalador.json")) |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $I18nFile) {
  Die "Installer data files (dados/i18n-instalador.json) not found. Run via instalar.ps1 (one-line installer) or from the full repository."
}
$I18N = Get-Content $I18nFile -Raw -Encoding UTF8 | ConvertFrom-Json

# ---------- idioma: -Lang > config salvo > cultura do SO > pergunta > en ----------
function Read-SavedLang {
  if (Test-Path $ConfigFile) {
    foreach ($line in (Get-Content $ConfigFile -Encoding UTF8)) {
      if ($line -match "^lang=(\w+)") { $v = $Matches[1]; if ($ValidLangs -contains $v) { return $v } }
    }
  }
  return $null
}
function Save-Lang($l) {
  try {
    New-Item -ItemType Directory -Force -Path $Catalog | Out-Null
    # UTF-8 SEM BOM — o driver Python lê o mesmo arquivo (Set-Content UTF8 no PS5.1 grava BOM)
    [System.IO.File]::WriteAllText($ConfigFile, "lang=$l`n", (New-Object System.Text.UTF8Encoding($false)))
  } catch {}
}
if ($Lang -and $ValidLangs -notcontains $Lang) {
  Die (($I18N.en.err_lang -f $Lang) + " / " + ($I18N.pt.err_lang -f $Lang))
}
if (-not $Lang) { $Lang = Read-SavedLang }
if (-not $Lang) {
  $c = (Get-Culture).Name.ToLower()
  foreach ($l in @("pt","es","fr","de","en")) { if ($c.StartsWith($l)) { $Lang = $l; break } }
}
if (-not $Lang -and -not $Json -and -not $List -and [Environment]::UserInteractive) {
  Write-Host $I18N.en.pick_lang
  Write-Host "  1) English   2) Português   3) Español   4) Français   5) Deutsch"
  $default = if ($Lang) { $Lang } else { "en" }
  $ln = Read-Host "1-5 [$default]"
  $idx = 0
  if ($ln -and [int]::TryParse($ln.Trim(), [ref]$idx) -and $idx -ge 1 -and $idx -le 5) {
    $Lang = @("en","pt","es","fr","de")[$idx - 1]
  } else {
    $Lang = $default   # input inválido/vazio → padrão detectado (locale), sem crash
  }
}
if (-not $Lang) { $Lang = "en" }
# -Json/-List têm contrato "writes nothing": idioma NÃO é persistido nesses modos (igual ao driver Python)
if (-not ($Json -or $List) -and $Lang -ne (Read-SavedLang)) { Save-Lang $Lang }
$M = $I18N.$Lang
function Msg($key) { $s = $M.$key; if (-not $s) { $s = $I18N.en.$key }; return $s }
function MsgF($key, $vals) { $s = Msg $key; if ($vals) { return ($s -f $vals) }; return $s }

# ---------- pré-requisitos ----------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die (Msg "need_git") }
$GitDir = Split-Path -Parent (Get-Command git).Source
$GitRoot = Split-Path -Parent $GitDir
$Bash = Join-Path $GitRoot "bin\bash.exe"
if (-not (Test-Path $Bash)) { Die "bash.exe not found inside Git ($Bash). Reinstall Git for Windows with default options." }

# ---------- helpers ----------
$BaseDir = $env:USERPROFILE
if ($Dir) {
  if (-not (Test-Path $Dir -PathType Container)) { Die (MsgF "err_dir" @($Dir)) }
  $BaseDir = (Resolve-Path $Dir).Path
  Say (MsgF "dir_note" @($BaseDir))
}

# catálogo: divisões oficiais do divisions.json (+strategy) e regra frontmatter,
# igual ao install.sh upstream — nada de listas hard-coded que apodrecem.
function Get-Divisions {
  $divs = @()
  $dj = Join-Path $Catalog "divisions.json"
  if (Test-Path $dj) {
    $text = Get-Content $dj -Raw
    if ($text -match '(?s)"divisions"\s*:\s*\{(.*)') {
      $divs = [regex]::Matches($Matches[1], '"([a-z0-9-]+)"\s*:\s*\{') | ForEach-Object { $_.Groups[1].Value }
    }
  }
  if (-not $divs -or $divs.Count -eq 0) {
    $divs = Get-ChildItem $Catalog -Directory | Where-Object { @("scripts","integrations","examples",".git",".github","i18n") -notcontains $_.Name } | ForEach-Object { $_.Name }
  }
  if ($divs -notcontains "strategy") { $divs = @($divs) + @("strategy") }
  return $divs
}
function Test-AgentFile($f) {
  (Get-Content $f -TotalCount 1 -ErrorAction SilentlyContinue) -eq "---"
}
function Get-CatalogAgents {
  $out = @()
  foreach ($d in (Get-Divisions)) {
    $dd = Join-Path $Catalog $d
    if (Test-Path $dd) {
      $out += Get-ChildItem $dd -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object { Test-AgentFile $_.FullName }
    }
  }
  return $out
}
function Get-CatalogStems {
  # chaves de match: stems dos arquivos (identity) E slugs oficiais (renderizados
  # nomeiam por slug: code-reviewer.md, <slug>/SKILL.md…) — igual ao driver Python
  $keys = @{}
  foreach ($f in (Get-CatalogAgents)) {
    $keys[$f.BaseName] = $true
    $n = Get-FrontmatterName $f
    if ($n) { $keys[(Get-Slugify $n)] = $true }
  }
  return @($keys.Keys)
}
function Get-Slugify([string]$name) {
  # slugify oficial do catálogo (lib.sh): minúsculas, não-alnum → '-', colapsa
  $s = ($name.ToLower() -replace "[^a-z0-9]", "-") -replace "-{2,}", "-"
  return $s.Trim("-")
}
function Get-FrontmatterName($f) {
  try {
    if ((Get-Content $f.FullName -TotalCount 1) -ne "---") { return $null }
    foreach ($line in (Get-Content $f.FullName -TotalCount 60 | Select-Object -Skip 1)) {
      if ($line -eq "---") { break }
      if ($line -match "^name:\s*(.+?)\s*$") { return $Matches[1].Trim().Trim('"').Trim("'") }
    }
  } catch {}
  return $null
}

# ---------- plano: caminho explícito ou busca automática (-PlanAuto / -Plan "") ----------
$SquadsFile = @((Join-Path $ScriptDir "..\dados\squads.json"), (Join-Path $StoreDir "dados\squads.json")) |
  Where-Object { Test-Path $_ } | Select-Object -First 1

function Find-PlanAuto {
  $dirs = @((Get-Location).Path, (Split-Path -Parent (Get-Location).Path), (Join-Path $ScriptDir ".."),
            (Join-Path $env:USERPROFILE "Downloads"), (Join-Path $env:USERPROFILE "Documents"), (Join-Path $env:USERPROFILE "Documentos"))
  foreach ($d in $dirs) {
    if (Test-Path $d) {
      foreach ($n in $PlanNames) {
        $c = Join-Path $d $n
        if (Test-Path $c) { return $c }
      }
    }
  }
  return $null
}
$plano = $null
if ($PlanAuto -or $Plan -ne "" -or $PSBoundParameters.ContainsKey("Plan")) {
  $p = $Plan
  if ($PlanAuto -or -not $p) {
    $p = Find-PlanAuto
    if (-not $p) { Die (MsgF "err_plan" @("agency-plan.json (searched ., .., Downloads, Documents)")) }
    Say (MsgF "plan_autodetected" @($p))
  }
  if (-not (Test-Path $p)) { Die (MsgF "err_plan" @($p)) }
  try {
    $plano = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $plano.agentes -or $null -eq $plano.ferramentas) { throw "shape" }
    foreach ($ft in $plano.ferramentas) { if ("$ft".Trim() -eq "") { throw "ferramentas" } }
    foreach ($ag in $plano.agentes) {
      $f = $ag.file -replace "/","\"
      if ($f.StartsWith("\") -or $f.Contains("..") -or $f -match "^[A-Za-z]:") { throw "unsafe path: $($ag.file)" }
      if (-not $ag.slug -or $ag.slug -match "[/\\]") { throw "unsafe slug: $($ag.slug)" }
    }
  } catch { Die (MsgF "err_bad_plan" @($p)) }
}

# ---------- catálogo (Status/List/Json NUNCA usam rede) ----------
$HaveCatalog = $false
if (Test-Path (Join-Path $Catalog ".git")) {
  $HaveCatalog = $true
  if (-not ($Status -or $Json -or $List)) {
    Say (MsgF "cat_update" @($Catalog))
    $r = Invoke-Native { & git -C $Catalog pull --ff-only }
    if ($r.Code -ne 0) { Warn "catalog update skipped" }
  }
} elseif (Test-Path (Join-Path $Catalog "divisions.json")) {
  $HaveCatalog = $true
} elseif (-not ($Status -or $Json -or $List)) {
  Say (Msg "cat_clone")
  # clona em irmão temporário e mescla: ~/.agency-agents pode já existir
  # (ex.: config de idioma salvo antes do clone) e git clone exige dir vazio
  $tmp = Join-Path (Split-Path -Parent $Catalog) (".agency-agents.new-" + $PID)
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  $r = Invoke-Native { & git clone --depth 1 https://github.com/msitarzewski/agency-agents.git $tmp }
  if (-not (Test-Path (Join-Path $tmp ".git")) -or $r.Code -ne 0) {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Die (Msg "cat_fail")
  }
  New-Item -ItemType Directory -Force -Path $Catalog | Out-Null
  Get-ChildItem $tmp | ForEach-Object {
    if (-not (Test-Path (Join-Path $Catalog $_.Name))) { Move-Item $_.FullName (Join-Path $Catalog $_.Name) }
  }
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  $HaveCatalog = $true
} else {
  Warn (MsgF "cat_status_missing" @($Catalog))
}
$CatCommit = "?"; $CatDate = "?"
if (Test-Path (Join-Path $Catalog ".git")) {
  $r = Invoke-Native { & git -C $Catalog rev-parse --short HEAD }
  if ($r.Code -eq 0 -and $r.Out -and "$($r.Out[0])".Trim()) { $CatCommit = "$($r.Out[0])".Trim() }
  $r = Invoke-Native { & git -C $Catalog log -1 --format=%cs }   # data real do commit, não a de hoje
  if ($r.Code -eq 0 -and $r.Out -and "$($r.Out[0])".Trim()) { $CatDate = "$($r.Out[0])".Trim() }
}
$Stems = @()
if ($HaveCatalog) { $Stems = Get-CatalogStems }

# ---------- ferramentas ----------
$TOOLS = @(
  @{ id="claudeCode";  label="Claude Code";    kind="identity"; dest=".claude\agents";            compat="sim";  projectOnly=$false; detect=@(".claude") },
  @{ id="zcode";       label="ZCode";          kind="rendered"; dest=".zcode\agents";             compat="sim";  projectOnly=$false; detect=@(".zcode");  kebab="zcode";       sub="agents"; mode="arquivo" },
  @{ id="codex";       label="Codex CLI";      kind="rendered"; dest=".codex\agents";             compat="wsl";  projectOnly=$false; detect=@(".codex");  kebab="codex";       sub="agents"; mode="arquivo" },
  @{ id="geminiCli";   label="Gemini CLI";     kind="rendered"; dest=".gemini\agents";            compat="sim";  projectOnly=$false; detect=@(".gemini"); kebab="gemini-cli";  sub="agents"; mode="arquivo" },
  @{ id="copilot";     label="GitHub Copilot"; kind="identity"; dest=".github\agents";            compat="sim";  projectOnly=$false; detect=@(".github\agents",".copilot") },
  @{ id="qwen";        label="Qwen Code";      kind="rendered"; dest=".qwen\agents";              compat="sim";  projectOnly=$false; detect=@(".qwen");    kebab="qwen";        sub="agents"; mode="arquivo" },
  @{ id="opencode";    label="opencode";       kind="rendered"; dest=".config\opencode\agents";   compat="sim";  projectOnly=$false; detect=@(".config\opencode"); kebab="opencode"; sub="agents"; mode="arquivo" },
  @{ id="antigravity"; label="Antigravity";    kind="rendered"; dest=".gemini\config\skills";     compat="sim";  projectOnly=$false; detect=@(".gemini\config"); kebab="antigravity"; sub="skills"; mode="pasta" },
  @{ id="osaurus";     label="Osaurus";        kind="rendered"; dest=".osaurus\skills";           compat="nao";  projectOnly=$false; detect=@(".osaurus");  kebab="osaurus";     sub="skills"; mode="pasta" },
  @{ id="kimi";        label="Kimi CLI";       kind="rendered"; dest=".config\kimi\agents";       compat="wsl";  projectOnly=$false; detect=@(".config\kimi"); kebab="kimi";      sub="agents"; mode="pasta" },
  @{ id="cursor";      label="Cursor";         kind="rendered"; dest=".cursor\rules";             compat="sim";  projectOnly=$true;  detect=@(".cursor");  kebab="cursor";    sub="rules";  mode="arquivo" },
  @{ id="aider";       label="Aider";          kind="roster";   dest="CONVENTIONS.md";            compat="wsl";  projectOnly=$true;  detect=@(); kebab="aider";     rosterFile="CONVENTIONS.md" },
  @{ id="windsurf";    label="Windsurf";       kind="roster";   dest=".windsurfrules";            compat="sim";  projectOnly=$true;  detect=@(".windsurf"); kebab="windsurf"; rosterFile=".windsurfrules" }
)
function Test-ToolInstalled($t) {
  ($t.detect | Where-Object { Test-Path (Join-Path $env:USERPROFILE $_) }).Count -gt 0
}
foreach ($t in $TOOLS) { $t.installed = Test-ToolInstalled $t }

# contagem honesta: só arquivos que batem com o catálogo da agência
function Get-AgencyCount($t, $base, $stems) {
  if (-not $stems -or $stems.Count -eq 0) { return 0 }
  $d = Join-Path $base ($t.dest -replace "/", "\")
  if (-not (Test-Path $d)) { return 0 }
  if (Test-Path $d -PathType Leaf) { if ($stems -contains ([IO.Path]::GetFileNameWithoutExtension($d))) { return 1 } else { return 0 } }
  $n = 0
  foreach ($f in (Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue)) {
    if (@(".md",".toml",".mdc") -contains $f.Extension -and $stems -contains $f.BaseName) { $n++ }
    elseif (@("SKILL.md","agent.yaml","SOUL.md","prompt.md") -contains $f.Name -and $stems -contains $f.Directory.Name) { $n++ }
  }
  return $n
}

# ---------- --list: JSON puro, nunca rede ----------
if ($List) {
  $squadsObj = $null
  if ($SquadsFile) {
    $sq = Get-Content $SquadsFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $squadsObj = @{}
    foreach ($p in $sq.PSObject.Properties) {
      $squadsObj[$p.Name] = @{ label = $p.Value.label; slugs = @($p.Value.agentes | ForEach-Object { $_.slug }) }
    }
  }
  $catObj = $null
  if ($HaveCatalog) { $catObj = @{ path = $Catalog; agents = (Get-CatalogAgents).Count } }
  $out = [ordered]@{
    version = 1
    catalog = $catObj
    tools = @($TOOLS | ForEach-Object { [ordered]@{ id=$_.id; label=$_.label; compat=$_.compat; projectOnly=$_.projectOnly; dest=($_.dest -replace "\\","/"); installed=[bool]$_.installed } })
    squads = $squadsObj
  }
  $out | ConvertTo-Json -Depth 5 | Write-Output
  exit 0
}

# ---------- helpers de instalação ----------
# caminho MSYS via cygpath do próprio Git (robusto p/ drive != C:, espaços, &)
function To-Msys($winPath) {
  $r = Invoke-Native { & $Bash -c 'cygpath -u "$1"' "cygpath" "$winPath" }
  if ($r.Code -eq 0 -and $r.Out) { return "$($r.Out -join '')".Trim() }
  return $null
}
function To-Win($msysPath) {
  $r = Invoke-Native { & $Bash -c 'cygpath -w "$1"' "cygpath" "$msysPath" }
  if ($r.Code -eq 0 -and $r.Out) { return "$($r.Out -join '')".Trim() }
  return $null
}

function Backup-IfChanged($dst, $src, $toolId) {
  if (-not (Test-Path $dst)) { return }
  $diff = $true
  if ((Test-Path $dst -PathType Container) -and $src -and (Test-Path $src -PathType Container)) {
    $diff = $true  # pastas: sempre salva cópia antes de substituir
  } elseif ($src -and (Test-Path $src -PathType Leaf) -and (Test-Path $dst -PathType Leaf)) {
    try { $diff = (Get-FileHash $dst).Hash -ne (Get-FileHash $src).Hash } catch { $diff = $true }
  }
  if (-not $diff) { return }
  $bdir = Join-Path $BackupDir ("$Ts\" + $toolId)
  New-Item -ItemType Directory -Force -Path $bdir | Out-Null
  $leaf = Split-Path $dst -Leaf
  if (Test-Path $dst -PathType Container) { Copy-Item $dst (Join-Path $bdir $leaf) -Recurse -Force }
  else { Copy-Item $dst (Join-Path $bdir $leaf) -Force }
}

$script:Slugs = $null   # null = todos
$script:PlanAgentes = $null

function Get-SquadSlugs($name) {
  $map = @{ pre = "pre-lancamento"; "pre-lancamento" = "pre-lancamento"; treino = "treino" }
  if ($name -in @("all","todas","todos")) { return $null }
  if (-not $map.ContainsKey($name)) { Die (MsgF "err_squad" @($name)) }
  if (-not $SquadsFile) { Die (Msg "err_no_data") }
  $sq = (Get-Content $SquadsFile -Raw -Encoding UTF8 | ConvertFrom-Json).($map[$name])
  # JSON corrompido/chave ausente NUNCA vira "instala tudo em silêncio" (igual ao driver Python)
  if (-not $sq -or -not $sq.agentes) { Die (Msg "err_no_data") }
  return @($sq.agentes | ForEach-Object { $_.slug })
}

function Install-Identity($t) {
  $dest = Join-Path $BaseDir ($t.dest -replace "/", "\")
  if ($DryRun) { return }
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  if ($null -ne $script:PlanAgentes) {
    $catFull = (Resolve-Path $Catalog).Path
    foreach ($ag in $script:PlanAgentes) {
      $frel = $ag.file -replace "/","\"
      $src = Join-Path $Catalog $frel
      $resolved = (Resolve-Path $src -ErrorAction SilentlyContinue).Path
      if ($resolved -and $resolved.StartsWith($catFull) -and (Test-Path $src -PathType Leaf)) {
        Backup-IfChanged (Join-Path $dest (Split-Path $frel -Leaf)) $src $t.id
        Copy-Item $src $dest -Force
      }
    }
  } else {
    foreach ($f in (Get-CatalogAgents)) {
      Backup-IfChanged (Join-Path $dest $f.Name) $f.FullName $t.id
      Copy-Item $f.FullName $dest -Force
    }
  }
}

function Install-Rendered($t) {
  $dest = Join-Path $BaseDir ($t.dest -replace "/", "\")
  if ($DryRun) { return }
  $outWin = Join-Path $env:TEMP ("agencia-out-" + [guid]::NewGuid().ToString("N").Substring(0,6))
  try {
    $catalogMsys = To-Msys $Catalog
    $outMsys = To-Msys $outWin
    if (-not $catalogMsys -or -not $outMsys) { Warn "cygpath failed (Git for Windows install broken?)"; return }
    $r = Invoke-Native { & $Bash -c 'cd "$1" && bash scripts/convert.sh --tool "$2" --out "$3"' "convert" "$catalogMsys" "$($t.kebab)" "$outMsys" }
    $src = To-Win "$outMsys/$($t.kebab)/$($t.sub)"
    if ($r.Code -ne 0 -or -not $src -or -not (Test-Path $src)) { Warn "render $($t.kebab): $($t.sub) missing"; return }
    if ($t.mode -eq "arquivo") {
      New-Item -ItemType Directory -Force -Path $dest | Out-Null
      Get-ChildItem $src -Recurse -File | ForEach-Object {
        if ($script:Slugs -and $script:Slugs -notcontains $_.BaseName) { return }
        Backup-IfChanged (Join-Path $dest $_.Name) $_.FullName $t.id
        Copy-Item $_.FullName $dest -Force
      }
    } else {
      New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
      Get-ChildItem $src -Directory | ForEach-Object {
        if ($script:Slugs -and $script:Slugs -notcontains $_.Name) { return }
        $target = Join-Path $dest $_.Name
        Backup-IfChanged $target $_.FullName $t.id
        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        Copy-Item $_.FullName $target -Recurse -Force
      }
    }
  } finally {
    Remove-Item $outWin -Recurse -Force -ErrorAction SilentlyContinue   # limpa mesmo em early-return
  }
}

function Install-Roster($t) {
  $dest = Join-Path $BaseDir ($t.dest -replace "/", "\")
  if ($DryRun) { return }
  $outWin = Join-Path $env:TEMP ("agencia-out-" + [guid]::NewGuid().ToString("N").Substring(0,6))
  try {
    $catalogMsys = To-Msys $Catalog
    $outMsys = To-Msys $outWin
    if (-not $catalogMsys -or -not $outMsys) { Warn "cygpath failed (Git for Windows install broken?)"; return }
    $r = Invoke-Native { & $Bash -c 'cd "$1" && bash scripts/convert.sh --tool "$2" --out "$3"' "convert" "$catalogMsys" "$($t.kebab)" "$outMsys" }
    $src = To-Win "$outMsys/$($t.kebab)/$($t.rosterFile)"
    if ($r.Code -ne 0 -or -not $src -or -not (Test-Path $src -PathType Leaf)) { Warn "render $($t.kebab): roster file missing"; return }
    if ($script:Slugs) { Warn (MsgF "roster_note" @($t.label)) }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    Backup-IfChanged $dest $src $t.id
    Copy-Item $src $dest -Force
  } finally {
    Remove-Item $outWin -Recurse -Force -ErrorAction SilentlyContinue   # limpa mesmo em early-return
  }
}

function Install-One($t) {
  if ($t.compat -eq "nao") { Warn (MsgF "unsupported_os" @($t.label, "Windows")); return }
  $dest = Join-Path $BaseDir ($t.dest -replace "/", "\")
  if ($DryRun) {
    $n = if ($script:Slugs) { $script:Slugs.Count } else { (Get-CatalogAgents).Count }
    Say (MsgF "dry_run_action" @($t.label, $n, $dest))
    return
  }
  Say (MsgF "installing" @($t.label))
  if ($t.kind -eq "identity") { Install-Identity $t }
  elseif ($t.kind -eq "roster") { Install-Roster $t }
  else { Install-Rendered $t }
  # verificação honesta: quantos dos pedidos estão mesmo no destino
  if ($t.kind -eq "roster") {
    if (Test-Path $dest -PathType Leaf) { Say (MsgF "roster_ok" @($t.label, $dest)) }
    else { Warn (MsgF "install_fail" @($t.label)) }
    return
  }
  $present = Get-AgencyCount $t $BaseDir $Stems
  if ($present -eq 0) { Warn (MsgF "install_fail" @($t.label)); return }
  $requested = if ($script:Slugs) { $script:Slugs.Count } else { (Get-CatalogAgents).Count }
  if ($present -lt $requested) {
    $have = @{}
    if (Test-Path $dest) { Get-ChildItem $dest -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $have[$_.BaseName] = $true } }
    $wanted = if ($script:Slugs) { $script:Slugs } else { $Stems }
    $missing = @($wanted | Where-Object { -not $have.ContainsKey($_) } | Select-Object -First 5)
    Warn (MsgF "install_partial" @($present, $requested, $t.label, ($missing -join ", ")))
  }
  Say (MsgF "install_ok" @($t.label, $present))
}

function Uninstall-One($t) {
  if ($t.compat -eq "nao") { Warn (MsgF "unsupported_os" @($t.label, "Windows")); return }
  $dest = Join-Path $BaseDir ($t.dest -replace "/", "\")
  if ($DryRun) {
    # dry-run também vale para remoção: NADA é movido, só pré-visualizado
    $n = Get-AgencyCount $t $BaseDir $Stems
    Say (MsgF "dry_run_remove" @($t.label, $n))
    return
  }
  if ($t.kind -eq "roster") {
    if (Test-Path $dest -PathType Leaf) { Warn (MsgF "uninstall_skip" @($t.label, $dest)) }
    else { Warn (MsgF "uninstall_none" @($t.label)) }
    return
  }
  if (-not (Test-Path $dest -PathType Container)) { Warn (MsgF "uninstall_none" @($t.label)); return }
  $bdir = Join-Path $BackupDir ("uninstall-$Ts\" + $t.id)
  New-Item -ItemType Directory -Force -Path $bdir | Out-Null
  $moved = 0
  foreach ($f in (Get-ChildItem $dest -Recurse -File -ErrorAction SilentlyContinue)) {
    if (@(".md",".toml",".mdc") -contains $f.Extension -and $Stems -contains $f.BaseName) {
      New-Item -ItemType Directory -Force -Path (Join-Path $bdir $f.Directory.Name) | Out-Null
      Move-Item $f.FullName (Join-Path $bdir (Join-Path $f.Directory.Name $f.Name)) -Force
      $moved++
    }
  }
  foreach ($d in (Get-ChildItem $dest -Directory -ErrorAction SilentlyContinue)) {
    if ($Stems -contains $d.Name) { Move-Item $d.FullName (Join-Path $bdir $d.Name) -Force; $moved++ }
  }
  if ($moved -gt 0) { Say (MsgF "uninstall_ok" @($moved, $t.label, (Join-Path $BackupDir "uninstall-$Ts"))) }
  else { Warn (MsgF "uninstall_none" @($t.label)) }
}

# ---------- seleção ----------
$doTools = @()
if ($plano) {
  $script:PlanAgentes = @($plano.agentes)
  if ($script:PlanAgentes.Count -eq 0) { $script:PlanAgentes = $null }  # vazio = todos
  $script:Slugs = @($plano.agentes | ForEach-Object { $_.slug })
  if (-not $script:Slugs -or $script:Slugs.Count -eq 0) { $script:Slugs = $null }
  foreach ($tid in $plano.ferramentas) {
    $t = $TOOLS | Where-Object { $_.id -eq "$tid".Trim() }
    if ($t) { $doTools += $t }
    elseif ("$tid".Trim() -in @("vibe","dsh","openclaw","hermes")) { Warn (MsgF "unsupported" @("$tid".Trim())) }
    else { Warn (MsgF "tool_unknown" @("$tid".Trim())) }
  }
} elseif ($Tool) {
  foreach ($tid in ($Tool -split ",")) {
    $tid = $tid.Trim()
    if (-not $tid) { continue }
    $t = $TOOLS | Where-Object { $_.id -eq $tid }
    if ($t) { $doTools += $t }
    elseif ($tid -in @("vibe","dsh","openclaw","hermes")) { Warn (MsgF "unsupported" @($tid)) }
    else { Warn (MsgF "tool_unknown" @($tid)) }
  }
  if (-not $doTools) { Die (MsgF "tool_unknown" @($Tool)) }
  if (-not ($Uninstall -or $Status)) {
    if ($Squad) {
      $slugs = Get-SquadSlugs $Squad
      $script:Slugs = if ($slugs) { ,$slugs } else { $null }
    } elseif ([Environment]::UserInteractive) {
      Write-Host (Msg "pick_squad")
      Write-Host ("  " + (Msg "squad1"))
      Write-Host ("  " + (Msg "squad2"))
      Write-Host ("  " + (Msg "squad3"))
      $s = Read-Host "1-3 [1]"
      if (-not $s) { $s = "1" }
      $key = if ($s -eq "2") { "treino" } elseif ($s -eq "3") { "all" } else { "pre" }
      $slugs = Get-SquadSlugs $key
      $script:Slugs = if ($slugs) { ,$slugs } else { $null }
    } else {
      Die (Msg "err_need_squad")
    }
  }
} elseif (-not ($Status -or $Json)) {
  if (-not [Environment]::UserInteractive) { Die "Interactive mode needs a console. Use: -Plan agency-plan.json, or -Tool/-Squad for scripts." }
  Say (Msg "found")
  $i = 1; $opts = @()
  foreach ($t in $TOOLS) {
    if ($t.compat -eq "nao") { continue }
    $st = Msg "not_installed"; if ($t.installed) { $st = Msg "installed_ok" }
    $wsl = ""; if ($t.compat -eq "wsl") { $wsl = " (via WSL)" }
    Write-Host ("  {0,2}) {1,-14} {2}{3}" -f $i, $t.id, $st, $wsl)
    $opts += $t; $i++
  }
  $resp = Read-Host (Msg "pick_tools")
  if (-not $resp.Trim()) { $doTools = $opts }
  else {
    foreach ($n in $resp.Split(",")) {
      $idx = 0; if ([int]::TryParse($n.Trim(), [ref]$idx)) { if ($idx -ge 1 -and $idx -le $opts.Count) { $doTools += $opts[$idx-1] } }
    }
    if (-not $doTools) { $doTools = $opts }
  }
  if (-not $Uninstall) {
    $s = Read-Host ("{0}  {1}  {2}  {3}  [1]" -f (Msg "pick_squad"), (Msg "squad1"), (Msg "squad2"), (Msg "squad3"))
    if (-not $s) { $s = "1" }
    $key = if ($s -eq "2") { "treino" } elseif ($s -eq "3") { "all" } else { "pre" }
    $slugs = Get-SquadSlugs $key
    $script:Slugs = if ($slugs) { ,$slugs } else { $null }
  }
}

# ---------- execução ----------
if ($DryRun) { Say (Msg "dry_run_banner") }

if ($Uninstall) {
  if (-not $HaveCatalog) { Die (MsgF "cat_status_missing" @($Catalog)) }
  foreach ($t in $doTools) { Uninstall-One $t }
} elseif (-not ($Status -or $Json) -and $doTools.Count -gt 0) {
  foreach ($t in $doTools) { Install-One $t }
}

# ---------- status / painel ----------
$statusObj = [ordered]@{
  version = 1
  lang = $Lang
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  os = @{ family = "windows"; label = "Windows"; arch = $env:PROCESSOR_ARCHITECTURE }
  catalog = $(if ($HaveCatalog) { @{ path = $Catalog; commit = $CatCommit; updated = $CatDate } } else { $null })
  tools = @($TOOLS | ForEach-Object { [ordered]@{ id = $_.id; installed = [bool]$_.installed; agentCount = (Get-AgencyCount $_ $env:USERPROFILE $Stems) } })
}
if ($Json) {
  $statusObj | ConvertTo-Json -Depth 5 -Compress | Write-Output
  exit 0
}
if (-not $DryRun) {
  $guiaDirs = @((Join-Path $ScriptDir ".."), $StoreDir, (Join-Path $env:USERPROFILE "Documentos"), (Join-Path $env:USERPROFILE "Documents"), (Join-Path $env:USERPROFILE "Downloads"))
  $guDir = $guiaDirs | Where-Object { Test-Path (Join-Path $_ $GuideName) } | Select-Object -First 1
  if ($guDir) {
    try {
      # UTF-8 SEM BOM (antes era ASCII — corrompia ✓/acentos do guia-status.js)
      $json = $statusObj | ConvertTo-Json -Depth 5 -Compress
      [System.IO.File]::WriteAllText((Join-Path $guDir "guia-status.js"), "window.GUIA_STATUS = " + $json + ";`n", (New-Object System.Text.UTF8Encoding($false)))
      Say (MsgF "panel_updated" @((Join-Path $guDir "guia-status.js")))
    } catch {
      Warn (Msg "status_fail")   # instalação já feita: não aborta por causa do painel
    }
    if (-not $Status) { Say (Msg "opening"); Start-Process (Join-Path $guDir $GuideName) }
  } else {
    Warn (Msg "guia_not_found")
  }
} else {
  Say (Msg "dry_run_panel")
}

# ---------- resumo ----------
Say (Msg "done")
foreach ($t in $TOOLS) {
  $d = Join-Path $env:USERPROFILE ($t.dest -replace "/", "\")
  $c = 0
  if (Test-Path $d -PathType Leaf) { $c = 1 }
  elseif (Test-Path $d) { $c = (Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".md",".toml",".mdc" -or $_.Name -in "SKILL.md","agent.yaml" } | Measure-Object).Count }
  $det = if ($t.installed) { Msg "detected" } else { Msg "absent" }
  Write-Host ("  {0,-16} {1,-12} {2} {3}" -f $t.label, $det, $c, (Msg "specialists"))
}
Say (Msg "rerun")
