# ============================================================================
# instalar.ps1 — Agency Agents Store, instalador de UMA LINHA (Windows)
#
#   irm https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/main/instaladores/instalar.ps1 | iex
#
# Baixa o instalador completo (instalar-windows.ps1 + launcher .cmd), os dados
# de tradução (dados/) e o guia para ~\.agency-agents-store e executa.
# PINAR VERSÃO (CI/ambientes controlados):  & ([scriptblock]::Create((irm <url>))) -Branch v2.3.1
# ou defina $env:AA_BRANCH antes do iex.
# ============================================================================
[CmdletBinding()]
param(
  [string]$Branch = "",
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Rest
)

$ErrorActionPreference = "Stop"
$Store = Join-Path $env:USERPROFILE ".agency-agents-store"
if (-not $Branch) { $Branch = if ($env:AA_BRANCH) { $env:AA_BRANCH } else { "main" } }
$Base = "https://raw.githubusercontent.com/AtamisFilho/agency-agents-store/$Branch"

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
  Invoke-WebRequest -UseBasicParsing "$Base/instaladores/instalar-windows.cmd" -OutFile (Join-Path $Store "instaladores\instalar-windows.cmd")
  Invoke-WebRequest -UseBasicParsing "$Base/dados/i18n-instalador.json"        -OutFile (Join-Path $Store "dados\i18n-instalador.json")
  Invoke-WebRequest -UseBasicParsing "$Base/dados/squads.json"                 -OutFile (Join-Path $Store "dados\squads.json")
  Invoke-WebRequest -UseBasicParsing "$Base/guia-especialistas-agencia.html"   -OutFile (Join-Path $Store "guia-especialistas-agencia.html")
  # desbloqueia Mark-of-the-Web: arquivos baixados ficam bloqueados p/ scripts
  Get-ChildItem $Store -Recurse | Unblock-File -ErrorAction SilentlyContinue
} catch {
  Die "Download failed: $($_.Exception.Message)"
}

# ALTO-2: invocar um ARQUIVO .ps1 é sujeito à ExecutionPolicy — e o default de máquina
# cliente é Restricted (o Unblock-File acima só resolve MOTW sob RemoteSigned).
# Bypass no escopo Process: não exige admin, não muda a máquina, morre com a sessão.
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force } catch {}

& (Join-Path $Store "instaladores\instalar-windows.ps1") @Rest
