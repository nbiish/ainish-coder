#!/bin/bash
# MOLECULE: Plan-first gate
#
# AGENTS.md non-negotiable #1 says no branch is cut until a plan exists at
# `.agents/plans/{date}-{slug}.plan.md`, and that work is verified in a worktree and merged
# back rather than left dangling. Prose alone does not enforce that — it is advisory, and an
# agent under time pressure skips it. This module is the deterministic half.
#
# Three surfaces, one rule:
#   plan_check <dir>          operator/CI verb (`ainish-coder --plan-check [dir] [--json]`)
#   plan_check_precommit <dir> pre-commit hook body: refuse a commit with no plan
#   plan_check_install <dir>  install that hook (idempotent, additive)
#
# The override is AINISH_SKIP_PLAN_CHECK=1, and it is LOUD: the refusal message already names
# it, and when used the hook prints the bypass so the ledger records it. A silent bypass would
# be indistinguishable from a plan that was never required.

# _plan_check_plans_dir <repo_root> — where plans of record live.
_plan_check_plans_dir() {
    printf '%s\n' "${1:-.}/.agents/plans"
}

# _plan_check_current_branch <repo_root> — branch name, or empty outside git.
_plan_check_current_branch() {
    git -C "${1:-.}" branch --show-current 2>/dev/null || true
}

# plan_check_status <repo_root> — prints one of:
#   main            : on the default branch (no plan required to *hold* code, but no commits either)
#   plan-ok <file>  : a plan covers this branch and is past `designing`
#   plan-designing <file> : plan exists but is still a draft
#   plan-missing    : no plan names this branch
#   not-a-repo      : not a git worktree
#
# The plan→branch link is the `branch:` frontmatter key written by the plan template, so a
# plan is not guessed by filename similarity — that would match the wrong plan after a rename.
plan_check_status() {
    local repo_root="${1:-.}"
    local plans_dir branch status_line plan_file=""

    if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
        printf 'not-a-repo\n'
        return 0
    fi

    plans_dir="$(_plan_check_plans_dir "$repo_root")"
    branch="$(_plan_check_current_branch "$repo_root")"

    # main, master, or detached HEAD: nothing to gate. The gate exists to stop unplanned
    # feature work, not to block a fast-forward merge or a read-only checkout.
    if [[ -z "$branch" || "$branch" == "main" || "$branch" == "master" ]]; then
        printf 'main\n'
        return 0
    fi

    if [[ -d "$plans_dir" ]]; then
        while IFS= read -r candidate; do
            [[ -n "$candidate" ]] || continue
            if grep -qE "^[[:space:]]*branch:[[:space:]]*[\"']?${branch}[\"']?[[:space:]]*$" "$candidate" 2>/dev/null; then
                plan_file="$candidate"
                break
            fi
        done < <(find "$plans_dir" -maxdepth 1 -name '*.plan.md' -type f 2>/dev/null | sort)
    fi

    if [[ -z "$plan_file" ]]; then
        printf 'plan-missing\n'
        return 0
    fi

    status_line="$(sed -n 's/^[[:space:]]*status:[[:space:]]*\([a-z]*\).*/\1/p' "$plan_file" 2>/dev/null | head -n 1)"
    if [[ "$status_line" == "designing" ]]; then
        printf 'plan-designing %s\n' "$plan_file"
    else
        printf 'plan-ok %s\n' "$plan_file"
    fi
}

# plan_check <repo_root> [--json] — operator-facing verdict. Exit 0 only when the branch is
# main or is covered by a plan past `designing`.
plan_check() {
    local repo_root="${1:-.}" json="${2:-}"
    local out verdict detail
    out="$(plan_check_status "$repo_root")"
    verdict="${out%% *}"
    detail=""
    [[ "$out" == *" "* ]] && detail="${out#* }"

    if [[ "$json" == "--json" ]]; then
        printf '{"format": "ainish-coder/plan-check/v1", "repo": "%s", "branch": "%s", "verdict": "%s", "plan": "%s"}\n' \
            "$(cd "$repo_root" 2>/dev/null && pwd || printf '%s' "$repo_root")" \
            "$(_plan_check_current_branch "$repo_root")" "$verdict" "$detail"
    else
        case "$verdict" in
            main)
                echo -e "${GREEN}✓ On the default branch — no plan required to hold read-only state.${RESET}" ;;
            plan-ok)
                echo -e "${GREEN}✓ Plan of record: $detail${RESET}" ;;
            plan-designing)
                echo -e "${YELLOW}⚠ Plan is still a draft: $detail${RESET}"
                echo -e "  Set ${BRIGHT_WHITE}status: ready${RESET} once the clarifications are resolved." ;;
            plan-missing)
                echo -e "${BRIGHT_RED}✗ No plan of record for branch '$(_plan_check_current_branch "$repo_root")'.${RESET}"
                echo -e "  Write ${BRIGHT_WHITE}.agents/plans/$(date -u +%Y-%m-%d)-{slug}.plan.md${RESET} first;"
                echo -e "  the plan template's ${BRIGHT_WHITE}branch:${RESET} key is what ties it to this branch."
                echo -e "  Reference: ${BRIGHT_WHITE}.agents/templates/plan.md${RESET}" ;;
            not-a-repo)
                echo -e "${YELLOW}ℹ Not a git worktree — plan gate does not apply.${RESET}" ;;
        esac
    fi

    case "$verdict" in
        main|plan-ok|not-a-repo) return 0 ;;
        *) return 1 ;;
    esac
}

# plan_check_precommit <repo_root> — the hook body. Refuses a commit when the branch has no
# plan of record, unless deliberately bypassed.
plan_check_precommit() {
    local repo_root="${1:-.}"
    local out verdict

    if [[ "${AINISH_SKIP_PLAN_CHECK:-}" == "1" ]]; then
        # Loud on purpose: a bypass that leaves no trace is indistinguishable from a plan
        # that was never required, which is exactly the failure this gate exists to prevent.
        echo "[ainish-coder] AINISH_SKIP_PLAN_CHECK=1 — plan gate bypassed for this commit." >&2
        return 0
    fi

    out="$(plan_check_status "$repo_root")"
    verdict="${out%% *}"
    case "$verdict" in
        plan-missing)
            echo "" >&2
            echo "[ainish-coder] Commit refused: no plan of record for this branch." >&2
            echo "  Branch: $(_plan_check_current_branch "$repo_root")" >&2
            echo "  Write .agents/plans/{date}-{slug}.plan.md with a matching 'branch:' key." >&2
            echo "  Template: .agents/templates/plan.md" >&2
            echo "  Bypass (recorded): AINISH_SKIP_PLAN_CHECK=1 git commit ..." >&2
            echo "" >&2
            return 1 ;;
        plan-designing)
            echo "[ainish-coder] Commit refused: the plan is still status:designing." >&2
            echo "  Resolve the clarification ledger, set status:ready, then commit." >&2
            echo "  Bypass (recorded): AINISH_SKIP_PLAN_CHECK=1 git commit ..." >&2
            return 1 ;;
    esac
    return 0
}

# plan_check_install <repo_root> — install (or refresh) the pre-commit gate. Idempotent and
# additive: an existing hook keeps its other logic, and the block is replaced in place, never
# appended twice. Warn-only AGENTS.md guards elsewhere stay untouched — this is a separate block.
plan_check_install() {
    local repo_root="${1:-.}"
    local git_dir hooks_dir hook start end
    git_dir="$(git -C "$repo_root" rev-parse --git-dir 2>/dev/null)" || return 0
    [[ "$git_dir" == /* ]] || git_dir="${repo_root}/${git_dir}"
    hooks_dir="${git_dir}/hooks"
    mkdir -p "$hooks_dir" || return 1
    hook="${hooks_dir}/pre-commit"

    start="# --- AINISH-CODER PLAN GATE START ---"
    end="# --- AINISH-CODER PLAN GATE END ---"
    local block
    block="${start}
# Refuses a commit on a non-default branch with no plan of record in .agents/plans/.
# Bypass deliberately with AINISH_SKIP_PLAN_CHECK=1 (the bypass announces itself).
if [ -x \"\$(command -v ainish-coder 2>/dev/null)\" ]; then
    ainish-coder --plan-gate . >&2 || exit 1
fi
${end}"

    if [[ ! -f "$hook" ]]; then
        printf '#!/bin/sh\n\n%s\n' "$block" > "$hook"
    elif grep -qF "$start" "$hook" 2>/dev/null; then
        PLAN_BLOCK="$block" PLAN_START="$start" PLAN_END="$end" \
            awk '
                $0 == ENVIRON["PLAN_START"] { inblock=1; printf "%s\n", ENVIRON["PLAN_BLOCK"]; next }
                $0 == ENVIRON["PLAN_END"]   { inblock=0; next }
                !inblock
            ' "$hook" > "${hook}.tmp.$$" && mv "${hook}.tmp.$$" "$hook"
    else
        # Prepend after the shebang so the plan gate runs before any other hook logic.
        local first_line tmp
        first_line="$(head -n 1 "$hook" 2>/dev/null || echo '#!/bin/sh')"
        tmp="${hook}.tmp.$$"
        if [[ "$first_line" =~ ^#! ]]; then
            { echo "$first_line"; echo ""; echo "$block"; echo ""; tail -n +2 "$hook"; } > "$tmp"
        else
            { echo "#!/bin/sh"; echo ""; echo "$block"; echo ""; cat "$hook"; } > "$tmp"
        fi
        mv "$tmp" "$hook"
    fi

    chmod 755 "$hook" 2>/dev/null || chmod +x "$hook" 2>/dev/null || true
    return 0
}
