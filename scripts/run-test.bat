@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  PetStore Catalog load test runner (Windows)
REM
REM  Usage:
REM    run-test.bat <level> [loops] [rampup]
REM      <level>  = 30 | 40 | 50 | 70 | all   (required)
REM      [loops]  = loop count            (default 10)
REM      [rampup] = ramp-up seconds       (default 30)
REM
REM  Examples:
REM    run-test.bat 30            Full 30-user run (630 samples, ~0.5 TPS)
REM    run-test.bat 70            Full 70-user run (1470 samples, ~1.2 TPS)
REM    run-test.bat 30 1 5        Quick smoke (1 loop, 5s ramp = 30*3 samples)
REM    run-test.bat all           Run 30, 40, 50, 70 back to back
REM
REM  Level -> users / tpm (throughput in samples/MINUTE = TPS * 60):
REM    30 -> users=30  tpm=30  (~0.5 TPS)
REM    40 -> users=40  tpm=42  (~0.7 TPS)
REM    50 -> users=50  tpm=48  (~0.8 TPS)
REM    70 -> users=70  tpm=72  (~1.2 TPS)
REM ============================================================

set "JMETER_HOME=C:\Users\roy.a.sinaga\application\apache-jmeter-5.6.3\apache-jmeter-5.6.3"

REM --- resolve repo root (parent of this script's folder) ---
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "REPO_ROOT=%CD%"
popd >nul

set "PLAN=%REPO_ROOT%\test-plans\petstore-catalog.jmx"

set "LEVEL=%~1"
set "LOOPS=%~2"
set "RAMPUP=%~3"
if "%LEVEL%"==""  ( echo ERROR: missing level argument. Use 30^|40^|50^|70^|all & exit /b 1 )
if "%LOOPS%"==""  set "LOOPS=10"
if "%RAMPUP%"=="" set "RAMPUP=30"

if not exist "%JMETER_HOME%\bin\jmeter.bat" (
  echo ERROR: JMeter not found at "%JMETER_HOME%". Edit JMETER_HOME in this script.
  exit /b 1
)

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
if "%LVL%"=="30" ( set "USERS=30" & set "TPM=30" ) ^
else if "%LVL%"=="40" ( set "USERS=40" & set "TPM=42" ) ^
else if "%LVL%"=="50" ( set "USERS=50" & set "TPM=48" ) ^
else if "%LVL%"=="70" ( set "USERS=70" & set "TPM=72" ) ^
else ( echo ERROR: unknown level "%LVL%". Use 30^|40^|50^|70^|all & exit /b 1 )

REM timestamp YYYYMMDD-HHMMSS (locale-independent, via PowerShell)
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"`) do set "TS=%%i"
if "%TS%"=="" set "TS=%RANDOM%"
set "OUTDIR=%REPO_ROOT%\results\%LVL%users-%TS%"
mkdir "%OUTDIR%" 2>nul
if not exist "%OUTDIR%" (
  echo ERROR: could not create output directory "%OUTDIR%".
  exit /b 1
)

echo.
echo === Running level %LVL%: users=%USERS% loops=%LOOPS% tpm=%TPM% rampup=%RAMPUP% ===
echo === Output: %OUTDIR% ===

call "%JMETER_HOME%\bin\jmeter.bat" -n -t "%PLAN%" ^
  -Jusers=%USERS% -Jloops=%LOOPS% -Jtpm=%TPM% -Jrampup=%RAMPUP% ^
  -Jjtl="%OUTDIR%\result.jtl" ^
  -l "%OUTDIR%\result.jtl" ^
  -e -o "%OUTDIR%\html" ^
  -j "%OUTDIR%\jmeter.log"

if errorlevel 1 ( echo Level %LVL% FAILED. & exit /b 1 )
echo Level %LVL% done. Report: %OUTDIR%\html\index.html
exit /b 0
