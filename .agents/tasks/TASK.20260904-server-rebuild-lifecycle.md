# TASK.20260904-server-rebuild-lifecycle

- **date:** 2026-09-04
- **agent:** dsh-orchestrator
- **branch:** docs/server-rebuild-lifecycle (worktree `../server-rebuild-lifecycle` from main `cdca32a`)
- **operator directive:** AGENTS.md must expertly and concisely instruct all agents to (1) always tear down old servers and rebuild fresh main content, (2) verify a worktree is not a current agent's work (git + time info) before removal so multi-agent work is never deleted, (3) orchestrate rebuild timing via master COMMS so the operator is always prompted with the most recent build/main.

#### draft: gate → checkin → ownership scan → <SERVERS> section → workflow/audit wiring → llms.txt

## Design (what was codified)

1. **`<SERVERS>` section (universal):**
   - Worktree Ownership Verification — remove only when ALL pass: **Merged** (`git branch --merged main`, zero unmerged commits — unmerged peer work NEVER deleted, only flagged), **Unclaimed** (no open `checkin`/`intent-merge` without `checkout` in `AGENTS/*COMMS.md`; unlocked in `git worktree list`), **Idle** (last commit + last ledger mention > quiet window, default 24h; wtf hub live check when available, git+time fallback with COMMS gap note when down).
   - Rebuild Window Orchestration — quiet window only (main at HEAD, zero in-progress intent-merge, no fresh checkins), `intent-rebuild` ledger entry before teardown, closed after green smoke test; one rebuild at a time; never leave a torn-down state.
   - Teardown → Rebuild — locate by contract port/PID file → kill exactly that process tree (never blanket pkill) → rebuild from fresh `main` → smoke test (green: `log_event` + COMMS receipt; red: restore previous build; docs-only: `no-rebuild-needed`).
2. **Wiring:** frontmatter clause; WORKFLOW gains step 9 Rebuild (Cleanup → 10); cleanup-commands ownership warning; AUDIT item 9; REINFORCEMENT clause.
3. **llms.txt (repo-local):** "Server Lifecycle (repo-local)" — ainish-coder has no server (`no-rebuild-needed`); external services (wtf 7800, local-router 11434/11435, DSH GUI 3080) are never touched by this repo's cycles; targets inherit `<SERVERS>` with ports in their own llms.txt chains.

## Verification performed this session

- Ownership scan (read-only) across registered worktrees: only this task's worktree registered — earlier peer worktrees already torn down; no peer work at risk. Ledger has no unclosed intents except this task's own live entries.
- wtf hub 7800 DOWN → exercised the git+time fallback path the standard prescribes.
- Docs-only change set → `no-rebuild-needed` per the new rule; audit: no secrets, no banned crypto.

#### draft result: merged+unclaimed+idle proof before any teardown; quiet-window rebuilds from fresh main, always COMMS-timed
