2026-11-17-team

---
agent: deepseek-v4.1-flash
task: 2026-11-17-13-federation-discoverability
start: 2026-11-17T18:56:00Z
end: 2026-11-17T19:12:00Z
- input:Operator asked that the federation system be easy for future agents to use and appear in the ainish-coder / ainish-rag --help surfaces.
- output:`ainish-rag --help` now carries a "WORKING ON THIS REPO FROM MORE THAN ONE MACHINE?" block naming `--machine-link … --watch` (one-time setup), `--machine-sync --latest` (which copy is newest), `--machine-sync --branches`, `--machine-watch --status`, and the registry paths. `AGENTS.md` gained one pointer row in *Where everything else lives*. The stale `2026-11-15-09-watch-suggestions` record (task + plan) was corrected from `implementing` to `done (merged e08333a)` because `--context` orientation was advertising a finished task as active. `scripts/test-pqc-dist.sh` gained four assertions so neither surface can silently lose the verbs again.
- verification:`scripts/test-pqc-dist.sh` 306 passed (was 302, all four new assertions green); `scripts/test-machine-watch.sh` 40/0; `scripts/test-machine-sync.sh` 60/0. Measured agent-facing discoverability: `ainish-rag --help | grep -c machine` 0 -> 6; `grep -c machine-sync AGENTS.md` 0 -> 1; `wc -l AGENTS.md` stays 160.
- blockers:None. `AGENTS.md` was already at its hard 160-line gate, so the pointer row had to be paid for: I compressed the destructive-comma