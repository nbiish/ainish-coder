@echo off
rem ============================================================================
rem ainish-context.cmd - native Windows launcher for the ainish-coder context engine.
rem
rem The agent-facing command is `ainish-coder --context "<task>"`. This launcher is the engine entry
rem point for context-seed / context-status / context-learn / context-rollback / context-promote /
rem context-skill / wiki / gate / audit / orient / route / decide.
rem
rem The engine is Python only (src\context\engine.py). The compiled Rust engine was deleted along
rem with the embedding subsystem it served, so there is no native binary to prefer and no
rem stale-build fallback to reason about.
rem
rem Two Windows defects are handled explicitly here:
rem   - `python` and `python3` on PATH are often 0-byte App Execution Aliases that open the Microsoft
rem     Store and exit non-zero. Each candidate is proven with `-c "import sys"` before it is trusted.
rem   - A batch `if (...)` block expands %ERRORLEVEL% when the block is parsed, so the usual
rem     `cmd & exit /b %ERRORLEVEL%` reports a stale status. Every branch exits through a label.
rem ============================================================================
setlocal EnableExtensions
rem uv ships a managed interpreter under %APPDATA%\uv; where that path sits on a mount Windows marks
rem untrusted, every uv run dies with "untrusted mount point (os error 448)". Force a system
rem interpreter so the Python engine still starts.
set "UV_NO_MANAGED_PYTHON=1"

set "SELF_DIR=%~dp0"
set "PY_ENGINE=%SELF_DIR%..\src\context\engine.py"

if not exist "%PY_ENGINE%" goto :no_engine

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

echo Error: no context-engine backend found. 1>&2
echo. 1>&2
echo   The engine is Python; install uv or Python 3: 1>&2
echo       winget install --id astral-sh.uv -e 1>&2
echo       winget install --id Python.Python.3.12 -e 1>&2
endlocal & exit /b 1

:uv_path
uv run --no-managed-python "%PY_ENGINE%" %*
if errorlevel 1 goto :py
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%

:uv_hermes
"%LOCALAPPDATA%\hermes\bin\uv.exe" run --no-managed-python "%PY_ENGINE%" %*
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
echo Error: context engine not found at "%PY_ENGINE%" 1>&2
endlocal & exit /b 1
