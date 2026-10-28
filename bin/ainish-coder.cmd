@echo off
rem ============================================================================
rem ainish-coder.cmd - native Windows launcher for the ainish-coder CLI.
rem
rem The CLI itself is POSIX shell, so Windows runs it through the bash that ships
rem with Git for Windows, MSYS2 or Cygwin. No WSL is required.
rem
rem Arguments are forwarded verbatim with %*, which preserves both quoted paths
rem ("C:\Program Files\x") and bare Windows paths (D:\Code\app): the MSYS runtime
rem only treats a backslash as an escape immediately before a double quote.
rem Windows-style path arguments are canonicalised to POSIX form inside the CLI by
rem src/runtime.sh, so they never need manual conversion at the prompt.
rem ============================================================================
setlocal EnableExtensions

set "AINISH_CLI=%~dp0ainish-coder"
if not exist "%AINISH_CLI%" goto :no_cli

set "AINISH_BASH="

rem Preferred: Git for Windows and its siblings, in install-location order.
call :probe "%ProgramFiles%\Git\bin\bash.exe"
call :probe "%ProgramFiles(x86)%\Git\bin\bash.exe"
call :probe "%LocalAppData%\Programs\Git\bin\bash.exe"
call :probe "%ProgramData%\chocolatey\bin\bash.exe"
call :probe "%UserProfile%\scoop\apps\git\current\bin\bash.exe"
call :probe "%SystemDrive%\msys64\usr\bin\bash.exe"
call :probe "%SystemDrive%\cygwin64\bin\bash.exe"
call :probe "%SystemDrive%\cygwin\bin\bash.exe"
if defined AINISH_BASH goto :run

rem Last resort: whatever bash resolves to. The WindowsApps entry is skipped - it
rem is the WSL launcher stub, which cannot run a Windows-path POSIX CLI.
for /f "delims=" %%B in ('where bash 2^>nul') do call :accept "%%B"
if defined AINISH_BASH goto :run

echo Error: no usable bash found. 1>&2
echo. 1>&2
echo   ainish-coder runs its POSIX CLI on Windows through the bash shipped with
echo   Git for Windows, MSYS2 or Cygwin. WSL is optional, not required. 1>&2
echo. 1>&2
echo   Install Git for Windows, then reopen your terminal: 1>&2
echo       winget install --id Git.Git -e 1>&2
echo. 1>&2
echo   Meanwhile, WSL works too:  wsl ainish-coder --rules 1>&2
endlocal & exit /b 127

:probe
rem Accept a candidate when it exists and is a real binary, not a 0-byte alias.
if defined AINISH_BASH exit /b 0
set "_CAND=%~1"
if not exist "%_CAND%" exit /b 0
for %%S in ("%_CAND%") do if "%%~zS"=="0" exit /b 0
set "AINISH_BASH=%_CAND%"
exit /b 0

:accept
if defined AINISH_BASH exit /b 0
set "_CHK=%~1"
if not "%_CHK%"=="%_CHK:WindowsApps=%" exit /b 0
call :probe "%~1"
exit /b 0

:run
"%AINISH_BASH%" "%AINISH_CLI%" %*
set "AINISH_RC=%ERRORLEVEL%"
endlocal & exit /b %AINISH_RC%

:no_cli
echo Error: ainish-coder CLI not found at "%AINISH_CLI%" 1>&2
endlocal & exit /b 1