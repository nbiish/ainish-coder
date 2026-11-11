# Cross-machine federation + graph-only retrieval

- **status:** done
- **scope:** `src/machine_sync.sh`, `scripts/local-router-sync.sh`, `config/local-router/fallback-models.json`,
  `src/rag/rag.py`, `bin/ainish-rag`, `bin/ainish-rag.cmd`, `AGENTS.md`
- **objective:** one command syncs a repo edit from any machine to every peer; the router chain is the
  same on every machine; `--context` never spends embedding API funds.

## What was found

1. **The chain was never landing.** `local-router --config` takes the declarative shape
   (`fallbackModels`); the persisted `routes` file was handed to it instead. It was accepted silently,
   then the router rewrote the persisted file from its own empty state — so Windows served
   `fallback-models: []` while the installer reported success.
2. **Two machines, two schemas.** Mac's persisted file held the persisted shape; Windows' held the same
   shape with an empty chain, rewritten at 18:35 by the router itself. No amount of copying fixes that
   until the boot config is declarative.
3. **Retrieval still had a vector path.** `--context` fell back to embeddings on a graph miss, starting
   an embedding server and downloading a model to answer a question about the newest `.agents` files.
4. **WSL could not initiate anything, and could not have.** No `machines.txt`, no `mac-18gb` SSH alias,
   and a registry line pointing at the Windows box it shares a disk with.

## What changed

- `scripts/local-router-sync.sh`: derives `routes.boot.json` (declarative) from the human-edited file,
  passes it at boot, verifies the **route** rather than the port, refuses to deploy or capture an empty
  chain, and gained `--capture` for "I edited the chain in the UI, make it canonical".
- `config/local-router/fallback-models.json`: captured from the live router (17 models). The repo copy
  was 16 and had drifted.
- `src/rag/rag.py`: graph-only retrieval by default; `AINISH_RAG_VECTOR_FALLBACK=1` opts into vectors.
- `src/machine_sync.sh`: `--auto-commit` (an edit becomes a commit the peer fast-forwards onto), peer
  fast-forward on by default, `_ms_info` defined, checked-out branch ref set explicitly after a fetch.
- `bin/ainish-rag`, `bin/ainish-rag.cmd`: `context`/`secrets` routed to the Python engine; the binary is
  `ainish-rag.native.exe` so `ainish-rag` cannot resolve past the launcher; uv's managed-Python failure
  is handled per platform.

## Verified

- Chain: 17 models on mac and Windows, installed through the declarative boot config; WSL staged.
- Retrieval: `--context --retrieval-only` in seconds, `mode wiki_graph`, `degraded: false`, no spawn.
- Real edit on WSL → `--auto-commit` → commit `7609e64` → present on the Mac.
- `scripts/test-machine-sync.sh` 26/26; `src/rag` tests 179/179.

## Open

- Windows still warns its vector index was built with API embeddings. Irrelevant to graph-first
  retrieval; `ainish-rag index --rebuild` clears it.
- WSL has no `local-router` binary, so it stages the chain and cannot serve it locally.
