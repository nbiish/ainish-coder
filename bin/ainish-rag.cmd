@echo off
rem ============================================================================
rem ainish-rag.cmd - native Windows launcher for the ainish-rag RAG engine.
rem
rem Backend order: compiled ainish-rag.exe, then the Python engine through uv,
rem then any real python3/python, then the py launcher.
rem
rem Two Windows defects are handled explicitly here:
rem   - `python` and `python3` on PATH are often 0-byte App Execution Aliases
rem     that open the Microsoft Store and exit non-zero. Each candidate is
rem     proven with `-c "import sys"` before it is trusted.
rem   - A batch `if (...)` block expands %ERRORLEVEL% when the block is parsed,
rem     so the usual `cmd & exit /b %ERRORLEVEL%` reports a stale status. Every
rem     branch below exits through a label instead, preserving the real code.
rem ============================================================================
setlocal EnableExtensions

set "SELF_DIR=%~dp0"
set "NATIVE_BIN=%SELF_DIR%ainish-rag.exe"
set "PY_ENGINE=%SELF_DIR%..\src\rag\rag.py"
rem Verbs that exist only in the Python engine. A compiled build can lag by design (the exe is a
rem gitignored artifact), so never hand one of these to the binary.
set "PY_ONLY_SUBCOMMANDS= context "

if not exist "%PY_ENGINE%" goto :no_engine
if exist "%NATIVE_BIN%" goto :native

:py_first
rem --- backend 1: uv on PATH ------------------------------------------------
where uv >nul 2>nul
if not errorlevel 1 goto :uv_path

rem --- backend 2: uv from the hermes install --------------------------------
if not exist "%LOCALAPPDATA%\hermes\bin\uv.exe" goto :py
goto :uv_hermes

rem --- backend 3: a real Python on PATH -------------------------------------
:py
call :works python
if not errorlevel 1 goto :py_python
call :works python3
if not errorlevel 1 goto :py_python3
where py >nul 2>nul
if not errorlevel 1 goto :py_launcher

echo Error: no ainish-rag backend found. 1>&2
echo. 1>&2
echo   Provide bin\ainish-rag.exe, or install uv or Python 3: 1>&2
echo       winget install --id astral-sh.uv -e 1>&2
echo       winget install --id Python.Python.3.12 -e 1>&2
endlocal & exit /b 1

rem --- dispatch -------------------------------------------------------------
:native
rem A compiled build can lag the Python engine (the exe is a gitignored artifact). If the binary does
rem not advertise the requested verb in --help, fall through to Python instead of failing with
rem "unrecognized subcommand". PY_ONLY_SUBCOMMANDS is the escape hatch for verbs added ahead of a rebuild.
rem
rem The scan uses a subroutine rather than a `for` block: this file does not enable delayed expansion,
rem so `!VAR!` inside a block stays literal and every verb would fall through to Python.
set "NATIVE_OK=1"
set "FIRST_ARG="
for %%A in (%*) do call :take_first "%%~A"
if not defined FIRST_ARG goto :run_native
echo %PY_ONLY_SUBCOMMANDS% | findstr /C:" %FIRST_ARG% " >nul && set "NATIVE_OK=0"
if "%NATIVE_OK%"=="1" (
    "%NATIVE_BIN%" --help 2>nul | findstr /R /C:"^  %FIRST_ARG% " >nul
    if errorlevel 1 set "NATIVE_OK=0"
)
:run_native
if "%NATIVE_OK%"=="1" (
    "%NATIVE_BIN%" %*
    set "RC=%ERRORLEVEL%"
    endlocal & exit /b %RC%
)
goto :py_first

:take_first
rem %1 = one token; record it only if it is the first non-option token, then stop.
if defined FIRST_ARG exit /b 0
set "CANDIDATE=%~1"
if "%CANDIDATE:~0,1%"=="-" exit /b 0
set "FIRST_ARG=%CANDIDATE%"
exit /b 0

:uv_path
uv run "%PY_ENGINE%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%

:uv_hermes
"%LOCALAPPDATA%\hermes\bin\uv.exe" run "%PY_ENGINE%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%

:py_python
python "%PY_ENGINE%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%

:py_python3
python3 "%PY_ENGINE%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%

:py_launcher
py -3 "%PY_ENGINE%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%

rem --- helpers --------------------------------------------------------------
:works
rem %1 = interpreter name; exit 0 only when it actually runs Python.
where %~1 >nul 2>nul
if errorlevel 1 exit /b 1
%~1 -c "import sys" >nul 2>nul
if errorlevel 1 exit /b 1
exit /b 0

:no_engine
echo Error: Python engine not found at "%PY_ENGINE%" 1>&2
endlocal & exit /b 1