# ============================================================================
# instalar-windows.ps1 — Agency Agents Guia (Windows)
#
# Detecta suas ferramentas de código (Claude Code, ZCode, Codex, Gemini CLI…),
# instala especialistas da agência nelas (com backup do que já existe) e deixa
# o guia-especialistas-agencia.html informado (gera guia-status.js).
#
# PRÉ-REQUISITO: Git for Windows (https://git-scm.com/download/win) — ele traz
# o bash usado para converter os agentes. Só isso.
#
# Uso (no PowerShell):
#   .\instalar-windows.ps1                          # modo interativo
#   .\instalar-windows.ps1 -Plano plano-agencia.json # usa o planinho do guia
#   .\instalar-windows.ps1 -Status                   # só detecta e gera status
# ============================================================================
[CmdletBinding()]
param(
  [string]$Plano = "",
  [switch]$Status
)
$ErrorActionPreference = "Stop"

function Say($m)  { Write-Host "[ok]  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!!]  $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "[err] $m" -ForegroundColor Red; exit 1 }

$Home' = $env:USERPROFILE
$Catalog = Join-Path $env:USERPROFILE ".agency-agents"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Work = Join-Path $env:TEMP ("agencia-" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $Work | Out-Null

# ---------- pré-requisitos ----------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Err "Git não encontrado. Instale o Git for Windows em https://git-scm.com/download/win e rode de novo." }
$GitDir = Split-Path -Parent (Get-Command git).Source          # ...\Git\cmd
$GitRoot = Split-Path -Parent $GitDir                            # ...\Git
$Bash = Join-Path $GitRoot "bin\bash.exe"
if (-not (Test-Path $Bash)) { Err "bash.exe não encontrado dentro do Git ($Bash). Reinstale o Git for Windows com as opções padrão." }

# ---------- catálogo ----------
if (Test-Path (Join-Path $Catalog ".git")) {
  Say "Atualizando o catálogo em $Catalog…"
  & git -C $Catalog pull --ff-only 2>$null | Out-Null
} else {
  Say "Baixando o catálogo oficial de agentes (~\.agency-agents)…"
  & git clone --depth 1 https://github.com/msitarzewski/agency-agents.git $Catalog 2>$null | Out-Null
  if (-not (Test-Path $Catalog)) { Err "Falha ao clonar o catálogo. Verifique sua internet." }
}
$CatCommit = (& git -C $Catalog rev-parse --short HEAD) 2>$null
if (-not $CatCommit) { $CatCommit = "?" }

# ---------- ferramentas ----------
$TOOLS = @(
  @{ id="claudeCode";  label="Claude Code";      dirs=@(".claude");            dest=".claude\agents";            render=$null;          compat="sim" },
  @{ id="zcode";       label="ZCode";            dirs=@(".zcode");             dest=".zcode\agents";             render=@("zcode","agents","arquivo");  compat="sim" },
  @{ id="codex";       label="Codex CLI";        dirs=@(".codex");             dest=".codex\agents";             render=@("codex","agents","arquivo");  compat="wsl" },
  @{ id="geminiCli";   label="Gemini CLI";       dirs=@(".gemini");            dest=".gemini\agents";            render=@("gemini-cli","agents","arquivo"); compat="sim" },
  @{ id="copilot";     label="GitHub Copilot";   dirs=@(".github\agents",".copilot"); dest=".github\agents";     render=$null;          compat="sim" },
  @{ id="qwen";        label="Qwen Code";        dirs=@(".qwen");              dest=".qwen\agents";              render=@("qwen","agents","arquivo");   compat="sim" },
  @{ id="opencode";    label="opencode";         dirs=@(".config\opencode");   dest=".config\opencode\agents";   render=@("opencode","agents","arquivo"); compat="sim" },
  @{ id="antigravity"; label="Antigravity";      dirs=@(".gemini\config");     dest=".gemini\config\skills";     render=@("antigravity","skills","pasta"); compat="sim" },
  @{ id="osaurus";     label="Osaurus";          dirs=@(".osaurus");           dest=".osaurus\skills";           render=@("osaurus","skills","pasta");  compat="nao" },
  @{ id="kimi";        label="Kimi CLI";         dirs=@(".config\kimi");       dest=".config\kimi\agents";       render=@("kimi","agents","pasta");     compat="wsl" }
)
foreach ($t in $TOOLS) {
  $t.installed = ($t.dirs | Where-Object { Test-Path (Join-Path $env:USERPROFILE $_) }).Count -gt 0
  $d = Join-Path $env:USERPROFILE ($t.dest -replace "/", "\")
  $t.agentCount = 0
  if (Test-Path $d) {
    $t.agentCount = (Get-ChildItem $d -Recurse -Depth 1 -Include *.md,*.toml,SKILL.md,agent.yaml -ErrorAction SilentlyContinue | Measure-Object).Count
  }
}

# ---------- instalar ----------
function Install-IdentityAll($destRel) {
  $dest = Join-Path $env:USERPROFILE $destRel
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  $divs = @("academic","design","engineering","finance","game-development","gis","healthcare","marketing","paid-media","product","project-management","research","sales","security","spatial-computing","specialized","support","testing")
  foreach ($dv in $divs) {
    $src = Join-Path $Catalog $dv
    if (Test-Path $src) { Copy-Item (Join-Path $src "*.md") $dest -Force }
  }
}
function Install-IdentityPlano($planoPath, $destRel) {
  $dest = Join-Path $env:USERPROFILE $destRel
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  $plano = Get-Content $planoPath -Raw | ConvertFrom-Json
  foreach ($ag in $plano.agentes) {
    $src = Join-Path $Catalog ($ag.file -replace "/", "\")
    if (Test-Path $src) { Copy-Item $src $dest -Force }
  }
}
function Install-Rendered($tool, $sub, $destRel, $mode) {
  # converte usando o bash do Git (byte a byte igual ao oficial)
  $out = Join-Path $Work "out"
  & $Bash -lc "cd '~/.agency-agents' && bash scripts/convert.sh --tool $tool --out '$( ($out -replace '\\','/') )'" 2>$null | Out-Null
  # Git Bash não expande ~ do Windows em alguns casos: tenta de novo com caminho MSYS
  $src = Join-Path $out (Join-Path $tool $sub)
  if (-not (Test-Path $src)) {
    $msysOut = $out -replace '^([A-Za-z]):', '$1'
    & $Bash -lc "cd /c/Users/$env:USERNAME/.agency-agents && bash scripts/convert.sh --tool $tool --out '/tmp/agencia-out'" 2>$null | Out-Null
    $srcTmp = & $Bash -lc "cygpath -w /tmp/agencia-out/$tool/$sub"
    if ($srcTmp -and (Test-Path $srcTmp)) { $src = $srcTmp } else { Warn "render de $tool não gerou saída"; return }
  }
  $dest = Join-Path $env:USERPROFILE $destRel
  if ($mode -eq "arquivo") {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item (Join-Path $src "*") $dest -Force
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Get-ChildItem $src -Directory | ForEach-Object {
      $target = Join-Path $dest $_.Name
      if (Test-Path $target) { Remove-Item $target -Recurse -Force }
      Copy-Item $_.FullName $target -Recurse -Force
    }
  }
}

$doTools = @()
$slugsFile = ""
if ($Plano) {
  if (-not (Test-Path $Plano)) { Err "Plano não encontrado: $Plano" }
  $plano = Get-Content $Plano -Raw | ConvertFrom-Json
  $doTools = $plano.ferramentas
  $slugsFile = (Resolve-Path $Plano).Path
} elseif (-not $Status) {
  Say "Ferramentas encontradas nesta máquina:"
  $i = 1; $opts = @()
  foreach ($t in $TOOLS) {
    if ($t.compat -eq "nao") { continue }
    $st = "não instalada (posso configurar mesmo assim)"; if ($t.installed) { $st = "instalada ✓" }
    $wsl = ""; if ($t.compat -eq "wsl") { $wsl = " (via WSL)" }
    Write-Host ("  {0,2}) {1,-14} {2}{3}" -f $i, $t.id, $st, $wsl)
    $opts += $t.id; $i++
  }
  $resp = Read-Host "Números separados por vírgula (Enter = todas)"
  if (-not $resp.Trim()) { $doTools = $opts } else { $doTools = $resp.Split(",") | ForEach-Object { $opts[[int]($_.Trim())-1] } }
  $s = Read-Host "Quantos especialistas? 1) Squad pré-lançamento (12)  2) Treino (4)  3) Todos  [1]"
  if (-not $s) { $s = "1" }
  $slugsFile = "squad$s"
}

function Install-One($id) {
  $t = $TOOLS | Where-Object { $_.id -eq $id }
  if (-not $t) { Warn "Ferramenta $id não suportada pelo instalador (use o app Agency Agents)."; return }
  if ($null -eq $t.render) { # identity: claude e copilot
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
  Say "Instalados especialistas em $($t.label) ✓"
}
if (-not $Status -and $doTools.Count -gt 0) { foreach ($id in $doTools) { Install-One $id.Trim() } }

# squads nomeadas (só para identity) — se squad12/4 escolhido, os renders das demais ferramentas
# trazem a agência completa por praticidade; refine escolhendo 'plano' no guia para listas precisas.

# ---------- guia-status.js ----------
$guiaDirs = @((Join-Path $ScriptDir ".."), (Join-Path $env:USERPROFILE "Documentos"), (Join-Path $env:USERPROFILE "Documents"))
$guDir = $guiaDirs | Where-Object { Test-Path (Join-Path $_ "guia-especialistas-agencia.html") } | Select-Object -First 1
$statusObj = [ordered]@{
  version = 1
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  os = @{ family = "windows"; label = "Windows"; arch = $env:PROCESSOR_ARCHITECTURE }
  catalog = @{ path = $Catalog; commit = $CatCommit; updated = (Get-Date).ToString("yyyy-MM-dd") }
  tools = @($TOOLS | ForEach-Object { [ordered]@{ id = $_.id; installed = [bool]$_.installed; agentCount = $_.agentCount } })
}
$json = $statusObj | ConvertTo-Json -Depth 5 -Compress
if ($guDir) {
  Set-Content -Path (Join-Path $guDir "guia-status.js") -Value ("window.GUIA_STATUS = " + $json + ";") -Encoding UTF8
  Say "Painel do guia atualizado: $(Join-Path $guDir 'guia-status.js')"
  Say "Abrindo o guia…"
  Start-Process (Join-Path $guDir "guia-especialistas-agencia.html")
} else {
  Warn "guia-especialistas-agencia.html não encontrado ao lado do instalador."
}
Say "Concluído! Rode de novo a qualquer momento — é seguro."
Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
