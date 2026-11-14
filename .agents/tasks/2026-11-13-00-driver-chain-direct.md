# Driver chain: local-router → z.ai → xiaomi-mimo → openrouter

- **status:** done
- **branch:** `fix/driver-chain-direct`
- **plan:** `.agents/plans/2026-11-13-00-driver-chain-direct.md`
- **worktree:** `/Users/nbiish/code/ainish-coder-chain`
- **operator ask:** "The ainish-rag should be powered by localhost:11434 using the
  local-router/fallback-models 'model'. If that's not available we should use
  `https://api.z.ai/api/coding/paas/v4` (glm-5.3-flash) and then if that fails
  `https://token-plan-sgp.xiaomimimo.com/v1` (xiaomi-mimo-v2.6-pro) and otherwise if all else fails it
  should fall back to `https://openrouter.ai/api/v1/chat/completions` (deepseek-v4.1-flash-1017)."
- **scope:** `src/rag/rag.py` (DRIVER_CHAIN, DRIVER_TIERS, comment), `src/rag/tests/test_context_injection.py`,
  `llms.txt`, `scripts/test-pqc-dist.sh`

## What was found

1. **Steps 2-4 were routes, not direct calls.** Every one of `zai-glm-5.3-flash`,
   `xiaomi-mimo-mimo-v2.6-pro`, and `openrouter-deepseek-v4.1-flash-1017` carried
   `transport: "local-router"` — so the engine sent those ids to `127.0.0.1:11434` and let the router
   pick a vendor, instead of calling the three endpoints the operator named. The real endpoints existed
   in `DRIVER_REMOTE_BASES` but sat *after* four router steps plus Nous Portal, Nebius, and ZenMux.
2. **The failure this caused:** router up + one vendor's upstream down meant steps 2-4 all failed
   against the same dead route, with the operator's actual fallbacks queued behind unrequested
   vendors.
3. **Key wiring was already correct.** `DRIVER_KEY_NAMES` lists `LOCALROUTER_ZAI_API_KEY`,
   `LOCALROUTER_XIAOMI_MIMO_API_KEY`, `LOCALROUTER_OPENROUTER_API_KEY`, which are exactly the names in
   the PQC vault. No key-name change was needed.
4. **The vault is locked on this host**: `pqc-secrets export --json` prompts for a passphrase, so
   `_pqc_export()` returns 0 entries and no direct key resolves. Step 1 (the local router) is
   unaffected because it needs no key.

## What changed

1. **`DRIVER_CHAIN` is now exactly the operator's four steps.** `local-router` sending the literal id
   `local-router/fallback-models` to `http://127.0.0.1:11434`; then `zai` `glm-5.3-flash` to
   `https://api.z.ai/api/coding/paas/v4`; then `xiaomi-mimo` `mimo-v2.6-pro` to
   `https://token-plan-sgp.xiaomimimo.com/v1`; then `openrouter` `deepseek/deepseek-v4.1-flash-1017` to
   `https://openrouter.ai/api/v1`. The 86-line previous chain (four router routes + six direct
   fallbacks across Nous Portal, Nebius, ZenMux, Z.AI, Xiaomi) is gone.
2. **Steps 2-4 became direct transports.** They were router *routes* — those ids sent to
   `127.0.0.1:11434` — so a live router with a dead vendor upstream failed all three against the same
   route while the operator's real fallbacks sat behind vendors nobody asked for.
3. **`DRIVER_TIERS` pruned** to the four transports the chain can use plus the `local-model` floor.
4. **Comment rewritten** to state the order is the operator's and why the steps are direct.
5. Docs: `llms.txt` chain paragraphs (2 sites) rewritten; `scripts/test-pqc-dist.sh` pins the order and,
   critically, the transport↔id pairing.

## Verification

| Gate | Baseline | After |
|---|---|---|
| `pytest src/rag/tests` | 135 | **137** |
| `scripts/test-pqc-dist.sh` | 277 PASS | **285 PASS** |
| `ainish-rag secrets` | old 10-step order | exactly the 4 steps, each with its endpoint |
| live `chat()` | — | step 1 answered `OK` via `local-router/fallback-models` |
| step 1 forced to fail | — | steps 2-4 skip with "no API key resolved", no bogus header |

The live `chat()` is the load-bearing proof: the engine sent `local-router/fallback-models` to
localhost:11434, received `deepseek-v4.1-flash-1017`, and returned the answer with an empty `attempts`
list — step 1 working exactly as specified.

## Not verified, and why

- **Steps 2-4 cannot answer on this host.** The PQC vault is locked (`_pqc_export()` returns 0,
  `resolve_driver_key` returns None for all three), so each skips with "no API key resolved". This is
  correct fail-closed behaviour, not a chain defect. Proving the three direct providers end-to-end
  needs `pqc-secrets unlock`, which is the operator's action.
- **`secrets` showed `openrouter` as `up` with no key** — its `/models` catalogue is public, so the
  probe's reachability check passed while the chat path would 401. Pre-existing and recorded in
  `.agents/suggestions/2026-11-13-probe-conflates-reachability-with-auth.md`.

## Expected first failure if this is wrong

If the pairing regressed (ids right, transports back to `local-router`), the chain would still contain
all four model strings and `secrets` would still list four steps — but a router-side vendor outage would
take out steps 2-4 together. Three assertions pin `transport` against each `id` for exactly this reason,
so that regression fails CI rather than showing up as "all my fallbacks stopped working at once".
