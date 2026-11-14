---
plan_format: ainish/plan/v1
slug: driver-chain-direct
date: 2026-11-13
status: done
branch: fix/driver-chain-direct
worktree: /Users/nbiish/code/ainish-coder-chain
task_record: .agents/tasks/2026-11-13-00-driver-chain-direct.md
operator: question-me
---

# Driver chain: local-router, then z.ai, then xiaomi-mimo, then openrouter

## 1. Problem

The operator specified the exact driver fallback order for `ainish-rag`:

1. `localhost:11434` — the `local-router/fallback-models` route
2. `https://api.z.ai/api/coding/paas/v4` — `glm-5.3-flash`
3. `https://token-plan-sgp.xiaomimimo.com/v1` — `mimo-v2.6-pro`
4. `https://openrouter.ai/api/v1/chat/completions` — `deepseek-v4.1-flash-1017`

The current chain does not match it. Steps 2-4 are present but carry `transport: "local-router"`,
so they are *routes through the local router* — names like `zai-glm-5.3-flash` sent to
`127.0.0.1:11434` — not direct calls to z.ai, xiaomimimo, and OpenRouter. The endpoints the operator
named already exist in `DRIVER_REMOTE_BASES` (`zai`, `xiaomi-mimo`, `openrouter`) but appear only
*after* four router steps, interleaved with Nous Portal, Nebius, and ZenMux.

Consequence today: if the local router is up but its own upstream for a given vendor is down, steps
2-4 all fail against the same dead router, and the direct-provider fallbacks that would have worked
are further down the list, behind vendors the operator did not ask for.

## 2. Anchor facts

| Fact | Established by |
|---|---|
| Local router is live, 147 models | `curl 127.0.0.1:11434/v1/models` |
| The four endpoints already exist | `DRIVER_REMOTE_BASES`: `zai`=`https://api.z.ai/api/coding/paas/v4`, `xiaomi-mimo`=`https://token-plan-sgp.xiaomimimo.com/v1`, `openrouter`=`https://openrouter.ai/api/v1` |
| Key names already match the vault | vault holds `LOCALROUTER_ZAI_API_KEY`, `LOCALROUTER_XIAOMI_MIMO_API_KEY`, `LOCALROUTER_OPENROUTER_API_KEY`; `DRIVER_KEY_NAMES` lists all three as candidates |
| The vault is currently LOCKED | `pqc-secrets export --json` prompts for a passphrase; `_pqc_export()` returned 0 entries |
| Step 1 already sends the right model id | `DriverEngine.chat` sends `step["id"]`, and step 1's id is `local-router/fallback-models` |
| `_chat_url` handles both base shapes | joins `/chat/completions` without duplicating `/v1` or Z.AI's `/v4` |

## 3. Design

`DRIVER_CHAIN` becomes exactly the four steps the operator named, in that order, with the last three
as DIRECT transports:

| # | transport | model id sent | endpoint |
|---|---|---|---|
| 1 | `local-router` | `local-router/fallback-models` | `http://127.0.0.1:11434` |
| 2 | `zai` | `glm-5.3-flash` | `https://api.z.ai/api/coding/paas/v4` |
| 3 | `xiaomi-mimo` | `mimo-v2.6-pro` | `https://token-plan-sgp.xiaomimimo.com/v1` |
| 4 | `openrouter` | `deepseek/deepseek-v4.1-flash-1017` | `https://openrouter.ai/api/v1` |

Decisions taken while designing:

- **The extra vendors are dropped, not demoted.** Nous Portal, Nebius, and ZenMux are removed from the
  default chain. The operator named four steps and "otherwise if all else fails" refers to the last
  one; keeping unrequested vendors between step 1 and the operator's fallbacks reintroduces the
  ordering problem this change exists to fix. (Recorded as a suggestion: they remain reachable by
  explicit pin.)
- **Step 1 keeps `expect_any: True`.** `local-router/fallback-models` is a *route*; whatever model it
  selects is by definition the request being honoured, so the identifier check must not fire.
- **Steps 2-4 keep model verification.** Each names a concrete model, so a provider silently
  substituting one is reported as degraded rather than accepted (measured precedent: Z.AI answers
  `glm-4.6` requests with `glm-5.3-flash`).
- **`reasoning: True` stays on the direct deepseek and Z.AI steps**, because the `max_tokens` floor
  must cover reasoning plus answer.
- **Key resolution is unchanged.** `DRIVER_KEY_NAMES` already lists the vault's `LOCALROUTER_*` names,
  so no key wiring is needed — only an unlocked vault.
- **A missing key skips with a reason, never a silent substitution.** Existing behaviour; preserved.

## 4. Tasks

- [ ] `src/rag/rag.py`: rewrite `DRIVER_CHAIN` to the four steps above; rewrite the block comment so
      it states the operator's order and that the last three are direct transports (not routes).
- [ ] `src/rag/rag.py`: prune `DRIVER_TIERS` to the transports the chain can actually use, keeping
      `local-model` as the offline floor.
- [ ] Confirm `secrets` / `inspect_drivers` reporting reflects the new order without change.
- [ ] `src/rag/tests/test_context_injection.py`: pin the chain order and each transport/endpoint pair.
- [ ] `llms.txt`: update the documented chain.
- [ ] `scripts/test-pqc-dist.sh`: assertions for the order and the direct transports.

## 5. Gates

- **The default chain is exactly the operator's four steps, in order.** A test asserts
  `[(transport, id)]` equals the specified list, so an inserted vendor fails CI.
- **Each named endpoint is the one actually called.** Asserted per step, not just that a transport
  exists in `DRIVER_REMOTE_BASES`.
- **A dead step still degrades.** With the vault locked, step 1 answers and steps 2-4 report "no API
  key resolved" — verified live, and *not* counted as a chain failure.

## 6. Verification

- `pytest src/rag/tests` green; `bash scripts/test-pqc-dist.sh` green (baseline first).
- Live: `ainish-rag secrets` shows the four steps in order.
- Live: `ainish-rag --context --task ...` answers from step 1 and reports the chain honestly.
- Live with the vault locked: steps 2-4 report the key reason, proving the skip path works.

## 7. Open

- **The vault is locked on this host**, so steps 2-4 cannot be exercised end-to-end. `_pqc_export()`
  returns 0 entries and `resolve_driver_key` returns None for all three direct transports; the engine
  then skips each with "no API key resolved" (verified live), which is correct. Unlocking the vault is
  the operator's action, not something to fake with an env var.
- **`secrets` reports openrouter "up" while its chat path has no key.** The health probe hits
  `/models`, which OpenRouter serves publicly without auth, so a reachable catalogue reads as a usable
  step. The chat call is the one that matters and it was never exercised by the probe. This predates
  the change and is recorded as a suggestion rather than widened into this task.
