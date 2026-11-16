# ============================================================================
# instalar.ps1 — Agency Agents Store, instalador de UMA LINHA (Windows)
#
#   irm https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.ps1 | iex
#
# Baixa o instalador completo (instalar-windows.ps1), os dados de tradução
# (dados/) e o guia para ~\.agency-agents-store e executa o instalador.
# ============================================================================
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Rest
)

$ErrorActionPreference = "Stop"
$Store = Join-Path $env:USERPROFILE ".agency-agents-store"
$Base = "https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main"

function Say($m)  { Write-Host "[ok]  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!!]  $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[err] $m" -ForegroundColor Red; exit 1 }

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Die "Git not found. Install Git for Windows first: https://git-scm.com/download/win"
}

New-Item -ItemType Directory -Force -Path (Join-Path $Store "instaladores") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Store "dados") | Out-Null

Say "Downloading the installer + guide to ~\.agency-agents-store ..."
try {
  Invoke-WebRequest -UseBasicParsing "$Base/instaladores/instalar-windows.ps1" -OutFile (Join-Path $Store "instaladores\instalar-windows.ps1")
  Invoke-WebRequest -UseBasicParsing "$Base/dados/i18n-instalador.json"        -OutFile (Join-Path $Store "dados\i18n-instalador.json")
  Invoke-WebRequest -UseBasicParsing "$Base/dados/squads.json"                 -OutFile (Join-Path $Store "dados\squads.json")
  Invoke-WebRequest -UseBasicParsing "$Base/guia-especialistas-agencia.html"   -OutFile (Join-Path $Store "guia-especialistas-agencia.html")
} catch {
  Die "Download failed: $($_.Exception.Message)"
}

& (Join-Path $Store "instaladores\instalar-windows.ps1") @Rest
