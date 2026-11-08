# Task: mandatory `pqc-secrets` distribution + the remaining driver-provider fallbacks

- lane: now
- branch: `feat/pqc-mandatory-and-provider-chain` (worktree `D:\Code\ac-pqc-mandatory`)
- status: done
- scope: `src/skills_selection.sh`, `src/deploy_skills.sh`, `src/file_operations.sh`,
  `src/verify_skills.sh`, `src/pqc_dist.sh`, `bin/ainish-coder`, `AGENTS.md`, `llms.txt`,
  `src/rag/rag.py`, `src/rag/tests/test_context_injection.py`, `scripts/test-pqc-dist.sh`,
  `.agents/canonical/`, `.agents/audit/contract-history.*`

## Why

Two operator requests:

1. `pqc-secrets` must distribute automatically with the rules bundle, like the other mandatory
   content — and must **not** appear in the skill selector. An agent in any target repo resolves
   secrets through it, so treating it as an optional pack meant a repo could legitimately end up
   without the engine its contract depends on.
2. Extend the `ainish-rag` driver chain to the remaining providers. Local-router tooling is being
   reworked by the operator, so the work had to stay inside `ainish-rag` and touch nothing in that
   checkout.

## What changed — mandatory PQC distribution

The design keeps two ideas separate, because conflating them is what produced the bug:

- **Not selectable** (`_skill_channel_excluded`) — a prompt-surface decision.
- **Always deployed** (`_skill_mandatory`) — a runtime dependency.

| Surface | Behaviour |
|---|---|
| Selector (raw keypress + numbered fallback) | `pqc-secrets` never listed (18 optional packs shown) |
| `--skills-list` | Reported under a separate `Always deployed (mandatory, not selectable)` block; JSON gains `mandatory` and `counts.mandatory` |
| `--skills <repo> --off pqc-secrets` | Refused with "mandatory pack(s) cannot be toggled" and exit 1, rather than saving an `off` that deployment ignores |
| `deploy_skills` | Deployed unconditionally: no selection lookup, no selector row, not pinned into the config |
| `--no-overwrite` (`AINISH_NO_OVERWRITE`) | Still refreshes it — a mandatory pack is a **mirror** (target dir removed first), not a merge, so a file deleted upstream cannot survive |
| Stale-sweep | Never removes a mandatory pack; reports a warning if the source copy is missing |
| `--skills-verify` | An absent mandatory pack is a hard failure with its own message and exit 1 |
| `--pqc-sync-targets` | A stale `off` entry from an older release is ignored and the target is synced; it is reported as `staleSelection`, not `deselected` |
| `--pqc-status` | Prints `pack: pqc-secrets (mandatory …)`; a stale `off` is counted separately |
| `deploy_path_contents` | New optional third arg `force` so the mandatory path can bypass the global no-overwrite flag without a second copy routine |

The reason for the mirror-vs-merge distinction: `deploy_path_contents` reads `AINISH_NO_OVERWRITE`
from the environment, so an outer exemption alone was not enough — the first implementation
still skipped every existing file (caught by test 5 below).

## What changed — driver chain across the remaining providers

`DRIVER_CHAIN` now carries ten steps: the operator's four router steps first, then direct-provider
fallbacks ordered by measured latency, then the local floor.

| # | Transport | Model id | Measured |
|---|---|---|---|
| 1 | local-router | `local-router/fallback-models` | 3.5 s (`mimo-v2.6-pro`) |
| 2 | local-router | `zai-glm-5.3-flash` | 2.5 s |
| 3 | local-router | `xiaomi-mimo-mimo-v2.6-pro` | 2.6 s |
| 4 | local-router | `openrouter-deepseek-v4.1-flash-1017` | 0.9 s |
| 5 | nous-portal | `deepseek/deepseek-v4.1-flash-1017` | 2.0 s |
| 6 | nebius | `deepseek-ai/DeepSeek-V4.1-Flash` | 1.0 s |
| 7 | openrouter | `deepseek/deepseek-v4.1-flash-1017` | 0.9 s |
| 8 | zenmux | `deepseek/deepseek-v4.1-flash` | 1.3 s |
| 9 | zai | `glm-5.3-flash` | 2.5 s |
| 10 | xiaomi-mimo | `mimo-v2.6-pro` | 2.6 s |

Key resolution covers the operator's `LOCALROUTER_*` names, bare names, and consumer prefixes, so a
host holding only one provider key still gets a working driver. Every base URL is overridable.

## Defects found and fixed

1. **`/v1/v1/` double-join killed all six direct providers.** `_post_chat` appended a fixed
   `/v1/chat/completions` to bases that already end in `/v1` (and to Z.AI's
   `/api/coding/paas/v4`). Every direct step 404'd. This was first misread as "these providers do
   not publish `/v1/models`" — the probe had the same bug, so both symptoms agreed with the wrong
   diagnosis. `_chat_url` now joins on the suffix the base does not already supply, and the probe
   derives its catalogue path from the same function.
2. **The probe reported healthy providers as down.** Reachability is now "the host answered HTTP at
   all"; only 401/403 counts as failure (an auth problem, reported as such). Several providers
   legitimately 404 a catalogue while serving chat.
3. **Z.AI silently substitutes models.** Requesting `glm-4.6` returned `glm-5.3-flash` with HTTP
   200. The identity check reports this as degraded rather than accepting it — recorded in the chain
   comments as the concrete reason the check exists.
4. **`--skills --off pqc-secrets` said "unknown or undeployable".** Correct refusal, wrong message:
   it sent the operator hunting for a typo. Now names the pack as mandatory.

## Verification

- Selector: 18 optional packs offered, `pqc-secrets` absent from both the raw-keypress enumeration
  and the numbered UI.
- Sandbox deploy with every optional pack off: `✓ Deployed (mandatory): .agents/skills/pqc-secrets`,
  engine present on disk, exit 0.
- Stale `off` in the config: pack deployed anyway.
- `AINISH_NO_OVERWRITE=true` with a planted stale marker: marker gone, pack refreshed.
- `--skills-verify` with the pack removed: `✗ MISSING MANDATORY`, exit 1.
- `skills_selection_enabled_count` returns 1 (not 0) when only mandatory packs are on, so
  `--rules` no longer claims "no packs deployed".
- End-to-end `--rules --headless` into a clean git repo: pqc-secrets deployed with no prompt,
  `--skills-list` shows it as mandatory, `--skills-list --json` carries `"mandatory": ["pqc-secrets"]`.
- Driver chain: all ten steps probed live and every one answered `DRIVER_OK` with
  `model_verified: true`; forced failover past a dead router reached `nous-portal`, and with Nous
  also unreachable reached `nebius`, recording each earlier rejection.
- `py -m unittest discover -s src/rag/tests` — **136 pass** (8 new: URL join, tier coverage, chain
  ordering).
- `bash scripts/test-pqc-dist.sh` — **108/108** (6 obsolete "pqc-secrets is optional" assertions
  rewritten to the mandatory contract, 9 new assertions added).
- `ainish-rag audit verify` — 16/16 after re-signing the contract.

## Not done, and why

- **Rust engine parity.** `bin/ainish-rag.exe` still has no `context` verb; the launchers fall
  through to Python for verbs it does not advertise.
- **local-router untouched by request.** The operator is reworking that checkout. Its
  `fallback-models` chain is deliberately not modified, and this work reads nothing from it beyond
  the loopback API. `docs/driver-models.md` in that repo now describes an order that has moved on;
  it should be refreshed when the operator's rework settles.
- **Latency.** With the router down, failover costs one round trip per dead step (~9 s to reach
  Nous). Acceptable as a degraded path, not as a normal one; `--retrieval-only` remains the cap.
