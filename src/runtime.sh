#!/bin/bash
# runtime.sh — cross-platform runtime bridge shared by every ainish entry point.
#
# Linux, macOS and WSL hand the CLI a POSIX shell with POSIX paths and a working
# `python3`. Native Windows (Git Bash / MSYS2 / Cygwin) also hands it a POSIX
# shell, but three environment facts differ, and every difference is bridged
# here rather than being sprinkled through the deploy modules:
#
#   1. Path form .... `D:\Code\app` and `D:/Code/app` are valid Windows paths that
#                     are NOT recognised as absolute by the POSIX helpers in
#                     paths.sh. ainish_posix_path() canonicalises them.
#   2. Interpreter .. Windows ships an App Execution Alias stub for `python3` and
#                     `python` (a 0-byte reparse point that opens the Microsoft
#                     Store and exits non-zero). `command -v python3` finds it,
#                     so every JSON/selection/hash helper silently failed.
#                     ainish_python() resolves an interpreter by EXECUTING it.
#   3. Shell compat . A tiny `python3` function shim keeps every existing call
#                     site working verbatim instead of rewriting them all.
#
# Everything is inert off Windows: ainish_is_windows() is false, so no behaviour
# changes on Linux, macOS or WSL.

# ainish_is_windows — true under Git Bash / MSYS2 / Cygwin.
ainish_is_windows() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
    esac
    return 1
}

# ainish_is_wsl — true inside the Windows Subsystem for Linux.
ainish_is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# ainish_posix_path <path> — POSIX form of a path that may be Windows-style.
# Non-path arguments (flags, skill names) pass through untouched, so callers can
# map it over a whole argv without classification work.
ainish_posix_path() {
    local path="${1:-}"
    [[ -n "$path" ]] || { printf '%s' ""; return 0; }

    # Flags never carry an inline Windows path; leave them byte-identical.
    case "$path" in
        -*) printf '%s' "$path"; return 0 ;;
    esac

    case "$path" in
        [A-Za-z]:[\\/]*|\\\\*|[A-Za-z]:)
            # Absolute Windows path: delegate to cygpath when the shell has it.
            if command -v cygpath >/dev/null 2>&1; then
                local converted
                if converted="$(cygpath -u -- "$path" 2>/dev/null)" && [[ -n "$converted" ]]; then
                    printf '%s' "$converted"
                    return 0
                fi
            fi

            # Fallback: rewrite the drive prefix and normalise separators, so
            # `D:\a\b` and `D:/a/b` work without cygpath being installed.
            local drive rest
            drive="$(printf '%s' "${path:0:1}" | tr '[:upper:]' '[:lower:]')"
            rest="${path:2}"
            rest="${rest//\\//}"
            printf '/%s%s' "$drive" "$rest"
            ;;
        *\\*)
            # Windows relative path (`.\app`, `app\sub`): separators only.
            printf '%s' "${path//\\//}"
            ;;
        *)
            printf '%s' "$path"
            ;;
    esac
}

# _ainish_python_works <executable> — proof, not claims: the candidate must
# actually start and run a Python 3 statement. This is what rejects the Windows
# Store stub, which resolves but exits non-zero.
_ainish_python_works() {
    local exe="${1:-}"
    [[ -n "$exe" && -x "$exe" ]] || return 1
    "$exe" -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' \
        >/dev/null 2>&1
}

# ainish_python — print the absolute path of a working Python 3 interpreter.
# Resolution is ordered by trust: explicit override, PATH, the Windows `py`
# launcher (which reports the real interpreter behind the alias), then versioned
# installs that were never added to PATH. Result is cached in AINISH_PYTHON.
ainish_python() {
    if [[ -n "${AINISH_PYTHON:-}" ]] && _ainish_python_works "$AINISH_PYTHON"; then
        printf '%s' "$AINISH_PYTHON"
        return 0
    fi

    local candidate resolved

    # 1. Whatever PATH offers first, if it is genuinely executable.
    for candidate in python3 python; do
        resolved="$(command -v "$candidate" 2>/dev/null || true)"
        if _ainish_python_works "$resolved"; then
            AINISH_PYTHON="$resolved"
            printf '%s' "$AINISH_PYTHON"
            return 0
        fi
    done

    # 2. The Windows `py` launcher knows where the real interpreter is even when
    #    `python`/`python3` on PATH are the Store stubs.
    if command -v py >/dev/null 2>&1; then
        resolved="$(py -3 -c 'import sys; print(sys.executable)' 2>/dev/null | tr -d '\r' || true)"
        resolved="$(ainish_posix_path "$resolved")"
        if _ainish_python_works "$resolved"; then
            AINISH_PYTHON="$resolved"
            printf '%s' "$AINISH_PYTHON"
            return 0
        fi
    fi

    # 3. Versioned installs with no PATH entry at all (common on Windows).
    local pattern root
    for pattern in \
        "${LOCALAPPDATA:+$(ainish_posix_path "$LOCALAPPDATA")/Programs/Python/Python3*/python.exe}" \
        "/c/Python3*/python.exe" \
        "${PROGRAMFILES:+$(ainish_posix_path "$PROGRAMFILES")/Python3*/python.exe}" \
        "${HOME:-}/.local/bin/python3" \
        "/usr/bin/python3" \
        "/opt/homebrew/bin/python3" \
        "/usr/local/bin/python3"; do
        [[ -n "$pattern" ]] || continue
        while IFS= read -r resolved; do
            [[ -n "$resolved" ]] || continue
            if _ainish_python_works "$resolved"; then
                AINISH_PYTHON="$resolved"
                printf '%s' "$AINISH_PYTHON"
                return 0
            fi
        done < <(compgen -G "$pattern" 2>/dev/null | sort -rV)
    done

    return 1
}

# ainish_install_python_shim — on Windows only, shadow a broken `python3` with a
# function that forwards to the resolved interpreter. Every existing call site
# (`python3 -c ...`) keeps working unmodified; on Linux/macOS/WSL this does
# nothing at all.
ainish_install_python_shim() {
    ainish_is_windows || return 0

    local resolved
    resolved="$(ainish_python 2>/dev/null || true)"
    [[ -n "$resolved" ]] || return 0
    export AINISH_PYTHON="$resolved"

    local current
    current="$(command -v python3 2>/dev/null || true)"
    if ! _ainish_python_works "$current"; then
        python3() { "$AINISH_PYTHON" "$@"; }
        export -f python3 2>/dev/null || true
    fi
    return 0
}
