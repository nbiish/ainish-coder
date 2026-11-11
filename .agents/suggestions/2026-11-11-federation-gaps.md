# Suggestions — federation and context gaps

Ordered by cost of leaving them.

1. **The router chain is the one config that silently diverges.** Everything else in this repo is
   versioned; the chain lives in `~/.config/local-router` and is rewritten by the running router. The
   class fix is done (declarative boot config + `--capture`), but the habit is not: after any UI edit,
   `--capture` then commit. Consider making `--machine-sync` refuse when the repo chain and the live
   chain differ, so divergence is loud instead of discovered later.
2. **A guest that shares its host's disk must not peer with its host.** WSL's registry listed
   `windows-128gb`, which is the same files at `/mnt/d/Code`: a guaranteed failure that teaches the
   operator to ignore the peer list. Removed here; worth a check for the general case
   (any `host:` peer whose realpath equals ours).
3. **`--context` still prints the embed-provider banner** before a graph-only run. The banner is true
   for the process, but it reads as "we spent embedding money" on a call that spent none. Suppress it
   when the graph answered.
4. **AGENTS.md had no instruction for a thin block.** It covered `degraded:` but not
   `wiki_graph_empty`/`insufficient`, and never named which `.agents` folders are authoritative. Both
   added, in the four lines the 120-line gate allowed; the gate itself is now the binding constraint on
   documenting this tool, and it is worth a deliberate decision rather than a silent trim each time.
5. **Windows' embedding index is stale by construction** (built with API embeddings, host now resolves
   a local model). Harmless under graph-first retrieval, but it is a warning every run until rebuilt.
