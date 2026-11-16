@echo off
rem ============================================================================
rem instalar-windows.cmd — Agency Agents Store (Windows)
rem
rem ALTERNATIVA ao abrir o PowerShell manualmente: DUPLO CLIQUE neste arquivo.
rem Ele chama o instalador com -ExecutionPolicy Bypass (não mexe na policy da
rem máquina) e segura a janela no fim para você ler o resultado.
rem
rem Com argumentos (ex.: instalar-windows.cmd -Tool zcode -Squad pre) roda direto,
rem sem pause — serve também para scripts/CI.
rem ============================================================================
setlocal
set "PS=%~dp0instalar-windows.ps1"
if not exist "%PS%" (
  echo [err] instalar-windows.ps1 not found next to this file.
  echo [err] Instale via one-liner do README ou baixe o repositorio completo.
  if "%~1"=="" pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS%" %*
set "RC=%ERRORLEVEL%"
if "%~1"=="" pause
exit /b %RC%
