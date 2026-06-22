@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  PetStore Catalog load test runner - k6 (Windows)
REM
REM  Usage:
REM    run-test.bat <level> [loops]
REM      <level> = 30 | 40 | 50 | 70 | all   (required)
REM      [loops] = iterations per VU         (default 10)
REM
REM  Examples:
REM    run-test.bat 30          Full 30-VU run (630 samples, ~0.5 TPS)
REM    run-test.bat 70          1470 samples, ~1.2 TPS
REM    run-test.bat all         Run 30, 40, 50, 70 back to back
REM    run-test.bat 30 1        Quick smoke (1 loop = 30*3 samples)
REM
REM  Level -> VUs / PACING seconds (pacing approximates the target TPS):
REM    30 -> USERS=30 PACING=60  (~0.5 TPS)
REM    40 -> USERS=40 PACING=57  (~0.7 TPS)
REM    50 -> USERS=50 PACING=62  (~0.8 TPS)
REM    70 -> USERS=70 PACING=58  (~1.2 TPS)
REM
REM  Requires k6 >= 0.49 on PATH (built-in web dashboard HTML export).
REM  Override the binary with the K6_BIN env var if needed.
REM ============================================================

if "%K6_BIN%"=="" set "K6_BIN=k6"

"%K6_BIN%" version >nul 2>&1
if errorlevel 1 (
  echo ERROR: k6 not found on PATH.
  echo Install it with one of:
  echo     winget install k6 --source winget
  echo     choco install k6
  echo Then re-run, or set K6_BIN to the k6.exe path.
  exit /b 1
)

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "K6_ROOT=%CD%"
popd >nul
set "PLAN=%K6_ROOT%\petstore-catalog.js"

set "LEVEL=%~1"
set "LOOPS=%~2"
if "%LEVEL%"=="" ( echo ERROR: missing level argument. Use 30^|40^|50^|70^|all & exit /b 1 )
if "%LOOPS%"=="" set "LOOPS=10"

if /i "%LEVEL%"=="all" (
  call :run 30 || exit /b 1
  call :run 40 || exit /b 1
  call :run 50 || exit /b 1
  call :run 70 || exit /b 1
  echo All levels complete.
  exit /b 0
)

call :run %LEVEL%
exit /b %ERRORLEVEL%

REM ---------------------------------------------------------
:run
set "LVL=%~1"
if "%LVL%"=="30" ( set "USERS=30" & set "PACING=60" ) ^
else if "%LVL%"=="40" ( set "USERS=40" & set "PACING=57" ) ^
else if "%LVL%"=="50" ( set "USERS=50" & set "PACING=62" ) ^
else if "%LVL%"=="70" ( set "USERS=70" & set "PACING=58" ) ^
else ( echo ERROR: unknown level "%LVL%". Use 30^|40^|50^|70^|all & exit /b 1 )

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"`) do set "TS=%%i"
if "%TS%"=="" set "TS=%RANDOM%"
set "OUTDIR=%K6_ROOT%\results\%LVL%users-%TS%"
mkdir "%OUTDIR%" 2>nul
if not exist "%OUTDIR%" (
  echo ERROR: could not create output directory "%OUTDIR%".
  exit /b 1
)

echo.
echo === Running level %LVL%: USERS=%USERS% LOOPS=%LOOPS% PACING=%PACING%s ===
echo === Output: %OUTDIR% ===

set "K6_WEB_DASHBOARD=true"
set "K6_WEB_DASHBOARD_EXPORT=%OUTDIR%\report.html"

"%K6_BIN%" run "%PLAN%" ^
  -e USERS=%USERS% -e LOOPS=%LOOPS% -e PACING=%PACING% ^
  -e OUT_DIR="%OUTDIR%"

set "RC=%ERRORLEVEL%"
set "K6_WEB_DASHBOARD="
set "K6_WEB_DASHBOARD_EXPORT="
REM k6 exits non-zero when a threshold fails; still produce the report.
if not exist "%OUTDIR%\report.html" ( echo Level %LVL% produced no HTML report. & exit /b 1 )
echo Level %LVL% done. Report: %OUTDIR%\report.html
exit /b 0
