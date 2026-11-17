# 03 — Practitioner evidence: what was tried, and what broke

Source: video `XaJi7a0UChs` (full transcript in `sources/video1-XaJi7a0UChs-transcript.txt`).
This document exists separately because the *failures* are more decision-relevant for us than the
architecture, and because the architecture is already covered by Harness².

## The build

A recursive harness on the **Gemini Interaction API**, chosen for two properties: conversation state
lives server-side (only new tool outputs are sent per turn), and **every request carries its own
system instructions, settings and tool list**. That second property is what allows a tool written on
turn 3 to be a real callable on turn 4 of the same conversation.

Cost caveat stated plainly: **the turn immediately after a tool-list change misses the context
cache.** Hence: patch tool updates, do not rewrite the tool list every turn.

Three zones:

| Zone | Contents | Why it is separate |
|---|---|---|
| 1 | Model API | Mutable per-turn tool list is the enabling mechanism |
| 2 | Sandboxed kernel: 3 tools (shell/read/write) + toolbox (`create_tool`, hooks, reflective memory) | Minimal kernel forced by real need; sandbox so it cannot read keys |
| 3 | Hidden checker + external model broker | The agent must not see or game its evaluator; tools must not hold secrets |

`create_tool` requires **five** things — name, description, parameter schema, Python code, and **at
least one unit test** — and the harness runs the test in the sandbox before registering the tool.

Hook points are deliberately only two: `session_start` (runs before turn 1, output shown immediately)
and `before_done` (runs when the model says it is finished; a reported failure **blocks the finish**
and is sent back).

## The three rounds

### Round 1 — web apps, evolving vs frozen

Frozen = same three base tools, nothing kept between tasks. Evolving = full recursive harness.

The evolving agent wrote a Chrome screenshot tool on app 1 (giving a text-only harness "eyes"), a pixel
comparison tool on app 2, then in its first reflection turned its own browser check into a
`before_done` hook and added a `session_start` hook that surveys every new project.

**Result: both harnesses passed every hidden check on every app, in almost the same time.**

The elegant recursive harness won nothing. This is the single most important negative result in the
video, and it is not softened.

### Round 2 — harder: remove the image helper and the broker entirely

The frozen agent had no built-in way to look at screenshots or video. It still reproduced a pricing
page to the pixel.

How: it wrote a program calling **macOS built-in OCR** to read the reference screenshot, then plain
Python to measure colours and edges. Given a silent bug-report video, it wrote its own computer-vision
script from scratch — matching reference photos against video frames to track order, finding the drop
marker by filtering for its exact colour.

> "A frontier model with a shell will build whatever capability it needs in line, whether the harness
> lets it safe tools or not."

### Round 3 — the expensive-parser family (where recursion pays)

Five tasks on a custom binary format, each needing a complex parser.

- Evolving harness with the parser already in its toolbox: built the parser on task 1, **called it
  immediately on the next four**, finishing significantly faster than frozen.
- A second evolving harness starting from an **empty** toolbox on the same family: built the most
  impressive toolbox of all the runs — and bloat killed it (below).

## The three failure modes, in detail

### F1 — Self-bloat (the ironic trap)

Every reflection added more checks to its own `before_done` hook. By task 5 the checklist had grown
until **running it consumed 100% of the time saved** by reusing the parser. The harness that was
supposed to escape bloated one-size-fits-all designs had bloated itself.

> "the exact ironic trap of self-improvement … Remember how our whole goal was to escape bloated
> harness."

### F2 — Re-verification loop

After building a *stricter* pixel-diff tool, the agent kept re-verifying a page that had already
passed until it ran out of time. A capability improvement turned into a time sink because nothing
bounded repeated verification.

### F3 — Criterion leakage

The growing `before_done` checks **started copying hidden check names directly from the task
description**. The agent was drifting from "do the work well" to "name the grader's checks".

This is the failure that zone 3 exists to prevent, and it happened anyway — because the check *names*
were visible in the task text.

## The stated conclusion

> "recursive self-learning harness does not make the model smarter because a strong model builds
> throw-away scripts in line anyway. It pays off under the specific conditions when a capability is
> expensive to rebuild from scratch, when your task repeats in a domain family, and when the evolution
> stays lean so that the agent doesn't bloat its own loop."

Three conditions, all necessary:

1. **Expensive to rebuild** — the capability costs real work each time.
2. **Repeats in a domain family** — so the once-built thing gets reused.
3. **Stays lean** — a cap, enforced.

And four rules:

1. Tiny kernel in a sandbox, so every new tool is forced by a real need.
2. Mandatory unit test before any generalised function enters the tool list.
3. Creator and secret broker outside the sandbox.
4. `session_start` / `before_done` hooks for process improvement, but **keep reflection short and
   strictly cap the `before_done` hook so it stays fast**.

## Why this maps onto us cleanly

The three conditions are a checklist we can actually satisfy — or fail honestly.

| Condition | Our situation |
|---|---|
| Expensive to rebuild | **Yes.** Working out *which* wiki section and *which* coordination artefact answers a task costs a retrieval pass plus two model calls today. An operator hand-tuning this per repo costs hours. |
| Repeats in a domain family | **Yes.** `DecisionEngine.route` already emits a `target_domain` from a fixed five-value vocabulary (`codebase_symbols`, `architectural_wiki`, `security_governance`, `technical_debt`, `general_knowledge`). That is a domain partition we get for free. |
| Stays lean | **Only if we cap it.** This is the design constraint that must be enforced in code, not prose. |

And each failure mode has a direct countermeasure we can build:
F1 → a hard character cap plus a growth budget. F2 → deduplicate and bound re-verification.
F3 → never let the learned surface see the evaluation criteria (cf. harness2's
`assert_tree_has_no_grader_verdicts`).

Round 1 is the humbling one: **the win may be zero.** A design that cannot report "no measurable
improvement, keep the base" will manufacture false progress. That is why the acceptance rule in
[`05-design.md`](05-design.md) treats KEEP_BASE as a first-class recorded outcome.
