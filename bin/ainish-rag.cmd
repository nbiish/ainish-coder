@echo off
rem ============================================================================
rem ainish-rag.cmd - DEPRECATED shim. Use `ainish-coder --context "<task>"` or `ainish-context <verb>`.
rem
rem RAG was never the right name: it described an embedding-and-vector system deleted on 2026-11-12,
rem and keeping the name taught every agent reading this repo that a retrieval model runs here. This
rem shim forwards so an older deployed rules copy keeps working, and says so once on stderr.
rem ============================================================================
setlocal EnableExtensions
set "SELF_DIR=%~dp0"
echo ainish-rag: DEPRECATED — use "ainish-coder --context ""<task>""" (agent-facing) or "ainish-context <verb>" 1>&2
call "%SELF_DIR%ainish-context.cmd" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
