# local-router `fallback-models`: defects to fix

Written 2026-11-14 by the ainish-coder agent, for the agent fixing local-router.
Repo: `local-router` (v0.34.0, checked out under the external-code volume on this host; the tree is
the same repo the running binary was built from). Everything below is measured or
read from that tree at the cited line.

## Why this matters to the caller

`ainish-rag --context` runs its two EGM reviewer roles as `pi` agents against
`model: "local-router/fallback-models"` on `http://127.0.0.1:11434`. A failure in that route is
indistinguishable, from the caller's side, from the model having nothing to say — which is the worst
possible failure shape for a context tool, because it silently produces a prime with a missing role.

---

## D1 (blocking) — a route step that answers HTTP 200 with a 0-block assistant message can be
accepted as success under streaming, and the client sees an empty turn

**Observed.** `pi --print --mode json --model local-router/fallback-models "Say OK"` returned
`message_end` with `content: []`, `usage.output: 1`, `stopReason: "stop"` — i.e. the router answered
successfully and the caller received nothing. Captured 14 of 15 times during one window on
2026-11-14, then 0 of 12 in a later window, which is what makes it a chain-order problem rather than
a code bug in any single step.

**Where the guard exists already.** `classifyResponseContent` (`src/index.ts:6791`) correctly
classifies a 200 body with no content and no tool calls as `instant_error`, and
`isContentFailoverTrigger` (`:6838`) turns that into a failover. Its own doc comment cites the same
bug class from 2026-11-09. So the intent is right.

**The gaps.**

1. **The classifier is only consulted for non-streaming JSON.**
   `src/index.ts:7531`: `if (!isStreamRequest && isJsonResponse) { … classify … }`.
   A streaming request (`stream: true`) never runs `classifyResponseContent`. The streaming branch
   (`:6795-6801`) only looks for an `"error"` substring; a stream whose only delta is
   `finish_reason: "stop"` with no content passes as `streaming`. `pi` uses non-streaming today, so
   this is latent — but any streaming client gets the 2026-11-09 bug back.

2. **A `choices: []` response is treated as generated.** `:6809`:
   `if (!Array.isArray(parsed?.choices) || parsed.choices.length === 0) return 'generated';`
   An empty choices array is not an answer. It should be `instant_error`. This is the branch that most
   likely let the observed 0-block response through when the upstream returned a malformed body.

**Fix:** treat `choices.length === 0` as `instant_error`, and run the same classifier on the
accumulated stream body before committing to a streaming success (buffer the first chunk set, or
classify on `[DONE]`). Rejecting an empty turn must cost one failover, not a delivered blank.

---

## D2 (blocking) — `fallback-models` leads with a free, rate-limited tier, so the first step is the
least reliable one

**Observed config** (`~/.config/local-router/fallback-models.json`): the `fallback-models` chain is
16 steps and begins:

```
1.  openrouter-ernie-5.5-flash-preview-free
2.  kilo-baidu-ernie-5.5-flash-preview-free-paid
3.  xiaomi-mimo-mimo-v2.6-pro
4.  antigravity-gemini-3.7-flash
5.  zai-glm-5.3-flash
...
11. cline-deepseek-deepseek-v4-pro-paid
15. commandcode-glm-5.3-flash
16. zenmux-deepseek-v4.1-flash
```

Step 1 is a **free preview** endpoint. Free tiers are the most likely to rate-limit, queue, or return
degenerate 200s — which is exactly the condition that produces D1's empty turn. Meanwhile
`zai-glm-5.3-flash` (a paid, stable model the operator separately named as their preferred
direct fallback) sits at step 5.

**Why it matters here:** every `ainish-rag --context` call pays step 1's latency and inherits its
failure modes. Measured answer times on this route ranged **0.9s to 10.3s** for the same one-word
prompt, tracking which step answered.

**Fix (operator decision, listed not assumed):** reorder so a paid, stable model leads and free tiers
are last-resort. Suggested order given what this repo already has keys for:
`zai-glm-5.3-flash` → `xiaomi-mimo-mimo-v2.6-pro` → `cursor-deepseek-v41-flash-1017` →
`openrouter-deepseek-v4.1-flash-1017-batch`, then the free previews. This is a config change
(`fallback-models.json`), not code.

---

## D3 (high) — a route reports only the model that answered, with no per-step latency in the
non-streaming response

**Observed.** The success path returns the upstream's body with `model` rewritten to the presented
name. There is no header, body field, or timing summary saying *which step answered* or *how long the
chain took before answering*. `attemptLog` and `trajectory` are built and populated
(`:8360`, `:8475+`) but are reachable only through the local-router log/UI, not the response.

**Why it matters here:** the caller must report which model actually served a review, because a
"reviewed by the router" claim is unverifiable otherwise. `ainish-rag` now scrapes
`responseModel` out of `pi`'s event stream to recover this, which works but is a workaround for
information the router could simply state.

**Fix:** add response headers, e.g. `x-local-router-route: fallback-models`,
`x-local-router-step: 5`, `x-local-router-model: glm-5.3-flash`,
`x-local-router-attempts: 5`, `x-local-router-ms: 1840`. Cheap, non-breaking, and it makes the
chain's behaviour observable to every client without reading logs.

---

## D4 (medium) — `no_reasoning_models` returns 400, which a caller reads as "my request was wrong"

**Observed.** `:8398`: when a caller asks for a thinking level and no step in the chain supports
reasoning, the route answers **HTTP 400** with
`"has no reasoning-capable targets to honour the requested thinking level"`.

That is a server-side capability gap, not a malformed request. A 400 causes clients to stop
retrying and to report a caller bug; `pi` surfaced it as a hard error. `409` or `503` would let a
client distinguish "this route cannot do that" from "you sent nonsense".

**Fix:** use a status the caller can branch on, and include the reasoning-capable subset of the chain
in the body so a client can pick one.

---

## D5 (low) — two local-router processes can be resident at once

**Observed.** `ps` showed PIDs 39101 (started 12:10PM) and 71235 (started Thu 07PM) both running
`build/index.js`. Only 71235 holds `127.0.0.1:11434`, so 39101 is a zombie listener that failed to
bind and stayed resident. It costs ~80MB and does nothing.

**Fix:** on `EADDRINUSE`, exit rather than continuing in a degraded no-listen state; and have the
launcher reap a previous instance.

---

## What ainish-coder changed on its side (so you do not have to solve it there)

- `pi` is invoked with `--no-session --no-tools --mode json --thinking low`, and the JSON stream is
  parsed to keep `text` blocks and discard `thinking` blocks.
- An empty turn is **retried once** client-side and reported via `attempts_made`, so a transient
  blank does not silently drop a role.
- The per-call ceiling is 90s, and a timeout is reported rather than hanging the command.
- `served_model` is scraped from `responseModel` so the prime can state which model reviewed.

Those are workarounds for D1/D3. Fixing them router-side would let the client simplify.

## How to verify a fix from the caller's side

```bash
# 1. Empty-content failover (D1): should never return an empty answer. Run until it fails upstream.
for i in $(seq 20); do
  curl -s -m 60 http://127.0.0.1:11434/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"local-router/fallback-models","messages":[{"role":"user","content":"Say OK"}],"max_tokens":64}' \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); c=(d.get("choices") or [{}])[0].get("message",{}).get("content") or ""; print(d.get("model"), "EMPTY" if not c.strip() else "ok")'
done

# 2. Step observability (D3): headers should name the step that answered.
curl -s -D- -o /dev/null -m 60 http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"local-router/fallback-models","messages":[{"role":"user","content":"hi"}],"max_tokens":16}' \
  | grep -i '^x-local-router-'

# 3. Chain order (D2): confirm a paid stable model leads.
python3 -c 'import json,pathlib; d=json.loads((pathlib.Path.home()/".config/local-router/fallback-models.json").read_text()); print([r for r in d["routes"] if r["id"]=="fallback-models"][0]["models"][:4])'
```
