@echo off
setlocal

set "SELF_DIR=%~dp0"
set "NATIVE_BIN=%SELF_DIR%ainish-rag.exe"
set "PY_ENGINE=%SELF_DIR%..\src\rag\rag.py"

if exist "%NATIVE_BIN%" (
    "%NATIVE_BIN%" %*
    exit /b %ERRORLEVEL%
)

where uv >nul 2>nul
if %ERRORLEVEL% equ 0 (
    uv run "%PY_ENGINE%" %*
    exit /b %ERRORLEVEL%
)

if exist "%LOCALAPPDATA%\hermes\bin\uv.exe" (
    "%LOCALAPPDATA%\hermes\bin\uv.exe" run "%PY_ENGINE%" %*
    exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python "%PY_ENGINE%" %*
    exit /b %ERRORLEVEL%
)

where py >nul 2>nul
if %ERRORLEVEL% equ 0 (
    py "%PY_ENGINE%" %*
    exit /b %ERRORLEVEL%
)

echo Error: Neither ainish-rag.exe nor uv/python/py was found. >&2
exit /b 1
