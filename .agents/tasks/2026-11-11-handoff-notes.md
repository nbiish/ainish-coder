# Handoff — federation, router chain, graph-only context

Written 2026-11-11 so the next session starts from facts, not reconstruction.

## What is true now

- **All three machines are on the same commit** and the same router chain: repo `config/local-router/fallback-models.json`
  hash `e0792421`, installed live on the Mac and on Windows, staged on WSL (no `local-router` binary there).
  Chain is 17 models: cline-deepseek-v4-flash-free, zenmux-glm-5.3-free, zai-glm-5.3-flash,
  xiaomi-mimo-v2.6-pro, antigravity-gemini-3.7-flash, cursor-grok-4.7, cursor-deepseek-v41-flash-1017,
  cursor-auto, github-copilot-auto, opencode-zen-glm-5.3-flash, cline-deepseek-chat-paid,
  openrouter-deepseek-v4.1-flash-batch, openrouter-deepseek-v4.1-flash-1017,
  kilo-deepseek-v4.1-flash-1017-paid, zenmux-deepseek-v4.1-flash, commandcode-deepseek-v4.1-flash,
  pioneer-deepseek-v4-pro.
- **Retrieval is graph-only.** `--context` walks a wiki graph + the newest `.agents` artifacts. No
  embedding server is started, no API is spent. `AINISH_RAG_VECTOR_FALLBACK=1` is the only way back.
  Verified: ~3.8s, `mode wiki_graph`, `sufficiency sufficient`, `degraded: false`.
- **`--machine-sync --auto-commit` moves a real edit end to end.** Proven: edit on WSL → commit
  `7609e64` → present on the Mac. Peers fast-forward by default; `--no-ff-peers` opts out.
- **WSL can initiate.** It has `machines.txt` (`wsl-94gb=self`, `mac-18gb=mac-18gb:/Users/nbiish/code`)
  and an `~/.ssh/config` alias to the Mac at `192.168.1.68`. Its `windows-128gb` peer line was removed:
  WSL shares the Windows disk at `/mnt/d/Code`, so that peer was the same files and always failed.
- **`scripts/local-router-sync.sh` is the installer.** `--verify` (read the route back), `--capture`
  (take this machine's live chain into the repo), `--dry-run`. It refuses an empty chain in both
  directions and boots the router with a *derived declarative* config (`routes.boot.json`).

## Why the chain kept going empty (root cause, do not re-learn)

`local-router --config` (or `LOCAL_ROUTER_ROUTES_CONFIG`) takes the **declarative** shape
`{"fallbackModels": {"<route>": {"models": [...]}}}`. The persisted file is `{"version":1,"routes":[...]}`.
Handing it the persisted shape is silently ignored, and the router then **rewrites** the persisted file
from its own (empty) state — so the installer "succeeds" while `fallback-models` serves `[]`.
The installer now derives the declarative file from the persisted one and passes that at boot.

## Launcher facts that cost an afternoon

- `ainish-rag.exe` beat `ainish-rag.cmd` in PATHEXT order, bypassing `PY_ONLY_SUBCOMMANDS`, so `context`
  reached a binary that exits 2. The binary is now `ainish-rag.native.exe`, called only by the `.cmd`.
- Git Bash resolves `ainish-rag` to the **extensionless POSIX wrapper**, not the `.cmd` — patch both.
- uv's managed interpreter under `%APPDATA%\uv` dies on this host with
  `untrusted mount point (os error 448)`. Pass `uv run --no-managed-python` **on Windows only**;
  macOS needs the managed download for the pinned Python.

## Open, in priority order

1. **`--auto-commit` creates divergent lanes.** WSL and the Mac both committed on top of the same parent;
   the sync reported `✓ synced` for both peers while `main` was diverged. Merged by hand as `fe93474`.
   Fix site: `_ms_pull`, after refs land — merge the peer's branch when it is not an ancestor of `HEAD`
   and the tree is clean, `git merge --abort` on conflict. Written up in
   `.agents/suggestions/2026-11-11-federation-gaps.md` (item 6).
2. **local-router has no live reload.** A saved config needs a restart to take effect. Plan:
   `.agents/plans/2026-11-11-router-live-reload.plan.md`.
3. **Scrolls belong outside `.agents/`.** Plan: `.agents/plans/2026-11-11-scrolls-out-of-agents.plan.md`.
   Another agent is already mid-move: the working tree carries deletions of `.agents/skills/**`
   (including `8thfire-scrolls`) with `skills-to-distribute/skills/` appearing. **Do not commit that
   move from here** — it is their lane.
4. **`test-config.txt` was not found** on Windows (`/d/Code`, `%USERPROFILE%`, the router config dir,
   `/d/Code/local-router`), on WSL (`/mnt/d/Code`), or on the Mac. The textarea excerpt pasted in the
   request contains *placeholder* text, not a saved chain. The live Windows chain was dumped instead and
   it is byte-identical to the repo's 17-model chain, so the saved config is already canonical. If that
   file exists somewhere else, point at it and `--capture` will take it.
5. Windows warns its vector index was built with API embeddings. Harmless under graph-first retrieval;
   `ainish-rag index --rebuild` clears it.

## Verification commands

```bash
bash scripts/local-router-sync.sh --verify        # chain non-empty and served
bash scripts/test-machine-sync.sh                 # 26 assertions
uv run python -m unittest discover -s src/rag/tests   # 179 tests
git merge-base --is-ancestor <peer>/main HEAD     # after a sync: same history?
```
