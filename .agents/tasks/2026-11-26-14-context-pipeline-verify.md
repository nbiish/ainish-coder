# Task: Verify `ainish-coder --context` agents on macOS against the Windows baseline

- lane: now
- branch: `feat/egm-pair-runtimes-and-consolidation-sweep` (PR #19 conflict resolution + this record); router remediation was operator-authorized ops outside the repo
- worktree: `/Users/nbiish/code/ainish-coder-worktrees/feat-egm-pair-runtimes`
- status: done
- plan: `.agents/plans/2026-11-25-17-egm-pair-runtimes-and-consolidation-sweep.md` (PR #19's plan of record, completed by the merge below); this session's decisions were taken interactively with the operator on 2026-11-26 (full guarded router sequence / resolve PR #19 / leave the goldfish model unpinned) and are recorded in `.agents/comms/2026-11-26-team.md`
- scope: external: the local-router checkout named by `~/Library/LaunchAgents/com.localrouter.daemon.plist` (pull + build) and its launchd service `com.localrouter.daemon`; repo: PR #19 branch only — merge commit, `.agents/comms/2026-11-26-team.md`, this record, one memory file, one suggestion. No change to `main`.
- compat: no schema or flag change; the running local-router now serves the behaviour its checkout already contained (#21 harness wiring, #24 glm-5.4 1M specs, #26 self-healing fallback)
- objective: Find why macOS `ainish-coder --context` output was weaker than the Windows host's and fix it.

## Findings (2026-11-26)

- The ainish-coder pipeline was not the fault: fresh `bash bin/ainish-coder --context --json "…"` exited 0 (67s before the fix, 59s after), elephant on `hermes:context-elephant`, goldfish on `hermes:context-goldfish`; all six Hermes profiles and `~/.pi/agent/models.json` matched `config/context-agents/`.
- The running local-router was stale: pid 13820 started 2026-11-25T12:57Z and was never restarted after that day's pulls. `curl 127.0.0.1:11434/api/agents-proxy/status` listed only `claude` and `codex`; `/v1/models` served `zai-glm-5.4` with `context_length` 64000; `grep -l selectForcedLastPassMembers build/*.js` matched nothing. `/api/update-status` reported `currentCommit` 316ebaa because it reads the checkout's HEAD, not the loaded code.
- Fallback chain: members 1–3 were quarantined (two rate-limit, one auth), so `local-router/fallback-models` traffic landed on a flapping `zai-glm-5.4` — the failover seen in `--context` output.
- PR #19 conflicted with `main` in one file only (`.agents/comms/2026-11-25-team.md`, append-vs-append); `src/context/engine.py`, `src/context/tests/test_context_injection.py`, `bin/ainish-coder` and `src/help.sh` auto-merged.

## Verification & Closeout Evidence (2026-11-26)

- Router remediation (operator-authorized, guarded): snapshot to `~/.config/local-router/build-backup-20261126T142950Z` (73 files); `git pull --ff-only` → `6f9d135`; `tsc --outDir <tmp>` exit 0, 0 `error TS`; scratch boot on :11436 with an isolated `$HOME`: `/api/version` 200 after 1s, status keys `["baseUrl","claude","codex","generatedAt","hermes","pi"]`.
- Live restart: `kill 13820` (SIGTERM ignored for 20s, then SIGKILL); launchd supervisor (pid 13816) logged `[supervise] 2026-11-26T14:31:11.986Z router is back`; new server pid 48603, cwd = router checkout.
- Read-back after restart: `/api/update-status` `{"currentVersion":"1.2.1","currentCommit":"6f9d135",…}`; `/api/agents-proxy/status` keys include `hermes` and `pi`; `/v1/models` `zai-glm-5.4` `context_length` 1000000, 153 models; `node bin/agents-doctor.js` exit 0 — "Verdict: harness wiring is coherent", "Hermes provider + ctx present (6/6 ctx profiles)", "pi models.json provider present".
- `bash bin/ainish-context gate`: exit 0, OVERALL GREEN; `.agents/rag/gate-status.json` now `{"status":"GREEN","commit":"a984b3d"}` (was 3d18234).
- PR #19 merge (0a8e343, parents ab11ec6 + a984b3d): `python3 -m py_compile src/context/engine.py` pass; `bash -n bin/ainish-coder src/help.sh` pass; `python3 -m unittest src/context/tests/test_context_injection.py` — `Ran 117 tests … OK`.
- Live smoke from the merged branch on macOS (`AINISH_CONSOLIDATE_ON_CONTEXT=off bash bin/ainish-coder --context --json "…"`): exit 0, 67s, `degraded: false`, elephant `hermes:context-elephant`, goldfish `pi:local-router/fallback-models` (served `mimo-v2.6-pro`), `provenance.route_note` "retrieval skipped by route: answer directly; do not retrieve", all three reviewer steps true; worktree clean afterwards.
- Push read-back: `git ls-remote origin refs/heads/feat/egm-pair-runtimes-and-consolidation-sweep` = `072a9293c3a26f004c42a10916b7f0647ead852e` = local HEAD; `gh pr view 19` → `mergeable: MERGEABLE` (was `CONFLICTING`).

## Not done, deliberately

- PR #19 is not merged: delivery is by PR after human approval.
- The goldfish model is not pinned, by operator choice; reviews stay `PROVISIONAL` (`reviewer_isolation: "fresh-context"`) until `AINISH_RAG_GOLDFISH_MODEL` is set.
- local-router upstream `main` moved to 5e541f6 during the task; the checkout stays at 6f9d135 (v1.2.1).
- Left untouched: stale xiaomi keys in the four `consolidate-*` profile configs and the extra `ollama` provider in `~/.pi/agent/models.json` (operator-owned, not blueprint-managed, harmless); the rollback snapshot above.
- First failure to expect if this is wrong: a `--context` run whose goldfish degrades to `driver` with `fallback_from: "pi"` — that would mean Pi is not reaching the rebuilt router on this host.
