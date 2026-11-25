# Pair transport durability on `wsl-94gb`: `pi` empty blocks and a 300s Hermes timeout

## What happened

On the live smokes of the pinned-runtimes pair (2026-11-25, `wsl-94gb`, real
`local-router/fallback-models` chain), both pinned runtimes failed in production and the pair was
served entirely by the `DriverEngine` fallback — every step recorded, nothing silent:

```
elephant degraded to DriverEngine (hermes:context-elephant: hermes profile 'context-elephant' missing …)
elephant degraded to DriverEngine (hermes:context-elephant: hermes timed out after 300s (profile context-elephant))
comprehension: goldfish degraded to DriverEngine (pi: pi returned no text blocks in 2 attempt(s))
antagonistic:  goldfish degraded to DriverEngine (pi: pi returned no text blocks in 2 attempt(s))
readiness:     goldfish degraded to DriverEngine (pi: pi returned no text blocks in 2 attempt(s))
```

Smoke 1 (pre-provisioning): the elephant's Hermes profile was missing on this host — since fixed
with `--context-setup` (6/6 profiles, read-back verified). Smoke 2 (post-provisioning): the
elephant REACHES its profile but the hermes call exceeds `HERMES_TIMEOUT_DEFAULT` (300s) on this
host's chain latency, so it degrades the same way. `llms.txt` already records an intermittent empty
`pi` response "measured 1 in 3 on this host", retried once; on these smokes the retry was empty in
all three goldfish steps. With the goldfish PINNED to `pi` and the elephant PINNED to Hermes
(operator architecture 2026-11-25), the pair's availability equals those two transports' health —
and on `wsl-94gb` that currently means every prime is a DriverEngine prime.

## Why it matters

EGM wants a fresh reviewer context, and the goldfish-isolation tests pin `--no-session` per step.
If the steps keep falling through to DriverEngine, the operator gets a reviewer that is neither the
pinned runtime nor isolated by process; the envelope reports it, but a prime whose goldfish is
regularly "degraded to DriverEngine" is not the architecture that was asked for.

## Settled by

Nothing yet — needs the operator's call (the pins are deliberate, so widening the ladders is a
policy change):

- Raise the empty-block retry budget for goldfish steps (2 → 3-4) before degrading, and/or switch
  the retry to a fresh `pi` invocation with a nudged prompt.
- Raise the hermes call timeout on high-latency hosts (`AINISH_HERMES_TIMEOUT`), or make the
  elephant's hermes tier fail fast (a shorter per-tier timeout) so a stuck profile does not burn
  300s before the recorded degrade.
- Or widen the ladders behind recorded degrades (`pi → hermes → driver` for goldfish;
  `hermes → pi → driver` is already the elephant's) so the pinned runtime stays primary and the
  fallback is explicit.
- Either way, keep the provenance honest: `goldfish_served_models` / `degrade_note` already carry
  what actually answered.
