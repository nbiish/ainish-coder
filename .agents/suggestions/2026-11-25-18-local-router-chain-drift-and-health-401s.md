# local-router chain drift and the z.ai 401 health spam

## What happened

Investigating the degraded context injection on 2026-11-25 (`wsl-94gb`), three local-router
operational findings surfaced that this task did not fix:

1. **Fallback-chain drift.** `scripts/local-router-sync.sh --verify` fails on `wsl-94gb`:
   the served chain differs from the repo canonical (`config/local-router/fallback-models.json`,
   committed 2026-11-22 as "the chain the operator saved"), while the live
   `~/.config/local-router/fallback-models.json` (mtime 2026-11-20) matches the operator's
   2026-11-23 export (`local-router-fallback/v1`). Which chain is CURRENT operator intent is
   genuinely open: the repo claims authority ("the repo copy is authoritative"), but the export
   post-dates the canonical commit.
2. **The router rewrites its own config**, so the sync script's verify mode cannot pass while the
   router runs ("re-run with the router stopped, or start it as: local-router start --config …").
3. **Health-probe 401 spam.** `probeFirstFallbackTargetReachability` logs
   `[health] First fallback target upstream https://api.z.ai/... answered HTTP 401` in a tight
   loop (48+ consecutive lines observed in `.local-router-server.log`): the first eligible chain
   member resolves to a z.ai model whose key is missing or invalid on this host. Also observed:
   `claude-runner.js` running from `D:/Code/local-router` (feature branch
   `feat/portable-config-and-updates`) while the server runs from `D:/Workspace/local-router`
   (`main`) — two checkouts of different vintages on one machine.

## Why it matters

`local-router/fallback-models` is the driver chain head for the context agents on every machine.
Drift means "the same chain" is not the same chain; the rewrite defeats sync verification; and the
401 loop both spams the log and reflects a chain head that cannot serve on this host.

## Settled by

Nothing yet — needs the operator's call:

- Adopt which chain as canonical: the repo copy (then `local-router-sync.sh` install + restart with
  the router stopped) or the 2026-11-23 export (then `local-router-sync.sh --capture` /
  `--from-text` to bring the repo to it).
- Consider a bounded backoff (or one-shot cadence) for `probeFirstFallbackTargetReachability`, and
  quarantining a chain head that answers 401 instead of probing it forever.
- Run only one local-router checkout per machine (point the `claude-runner` relay at the same tree
  the server runs from).
