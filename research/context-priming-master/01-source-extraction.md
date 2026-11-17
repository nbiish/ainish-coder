# 01 — Source extraction

Four sources were supplied. Two are primary research, two are practitioner accounts. They agree on
more than they disagree, and where they disagree the disagreement is the useful part.

| # | Source | Kind | Weight in this dossier |
|---|---|---|---|
| S1 | [YouTube: XaJi7a0UChs](https://www.youtube.com/watch?v=XaJi7a0UChs) | Practitioner experiment, 3 rounds, real benchmarks | High for **failure modes**, low for architecture (it is one person's build) |
| S2 | [YouTube: mnGNNtzK5lY](https://www.youtube.com/watch?v=mnGNNtzK5lY) | Secondary explainer of Harness² | Low — superseded by S3/S4; useful only as a sanity check on the framing |
| S3 | [arXiv 2610.14224v1](https://arxiv.org/html/2610.14224v1) | Primary paper, Harness² | **Highest** — the method, the ablations, the failure analysis |
| S4 | [google-research/harness2](https://github.com/google-research/harness2) | Reference implementation | **Highest** for mechanics — validators, guards, storage shapes |

---

## S3 — Harness²: Recursive Agent Harnessing for an Open World

Xu, Chen, CuiZhu, Dalvi Mishra, Ming, Yu, Han, Lee, Pfister — Google Cloud AI Research /
Northwestern. arXiv 2610.14224.

### The claim

> "LLM agents' capabilities depend not only on their underlying models but also on their execution
> harnesses. Recursive self-improvement (RSI) offers a promising approach to automatically evolve
> these harnesses. However, deploying RSI in open-world settings still faces two critical challenges.
> First, open-world tasks are typically unseen during the harness design phase and novel at test
> time, leaving no ground-truth verifiers to reliably guide online harness edits. Second, the RSI
> process remains highly task-specific and fails to generalize to novel scenarios."

The definition that matters:

> "A harness H = (c¹,…,c^K) consists of K editable components … It composes with M to form an agent
> A(·;M,H) without changing its weights."

`Agent = Model + Harness`, with weights frozen. Harnessing is optimising the harness, not the model.

### The two levels of recursion

**Task-level recursion** refines the harness for the *current* task. Because there is no ground truth,
it uses a **contrastive** step rather than a scored one:

- **Propose** — from a *reference execution* `e⁰` of the current harness, propose two candidates:
  one **invariant** (agentic deficiencies: planning, tool use, context management, delegation) and
  one **domain-specific** (knowledge, procedures, constraints of this domain).
- **Probe** — run each candidate on the same task under matched model and environment.
- **Compose** — read reference + candidates + diffs + all execution evidence, and selectively merge
  supported changes, revise conflicts, adopt one, or **keep the current harness**. Every decision ties
  to a concrete observation.

> "Compose is selective: it may merge supported changes, revise conflicting edits, adopt one
> candidate, or preserve the current harness. Each decision is tied to a concrete observation rather
> than a presumed score gain."

Crucially:

> "These contrasts inform subsequent composition rather than verify task correctness, as execution
> stochasticity and shared model biases limit the reliability of the evidence."

This is the honest core of the method: **it never claims correctness**, only behavioural difference.

Scaling: **parallel** recursion (k invariant + k domain candidates, k independent compositions from
the shared pool) versus **sequential** recursion (k chained Propose–Probe–Compose steps, each seeing
accumulated evidence). Budget identity is explicit: `R = 4k` rollouts, `P = 3k` improvement stages.

**Final selection** is agentic and deliberately blind:

> "an agentic selector compares anonymized deliverables against the task request and source materials.
> It returns an existing output without access to its originating harness or synthesizing new content."

Labels are anonymised and seed-shuffled so the selector cannot learn which harness produced what. At
k=1 selection is bypassed.

**Harnessing-level recursion** is the second level and the one most people skip:

> "Reflection extracts lessons about which changes addressed the observed deficiencies, under what
> conditions, and with what consequences. Lessons are retained only when supported by execution
> contrasts; selecting an output alone does not establish transferability."

The library `R` holds, per domain, `(harness tree, EXPERIENCE.md)`. Entries carry **cue, lesson,
evidence, confidence**. Next task starts from the *same base harness* `H₀` — earlier components are
reused *by proposal*, never inherited automatically.

### The eight components

System prompt, guardrails, memory, skills, tool guidance, scripts, subagents, middleware plugin. Each
is a file in the runtime; the split exists so a proposal can be scoped to the cheapest effective
component rather than appending prose.

### Ablations (Table 3, Gemini 3.5 Flash, OpenCode, k=1)

| Removed | WorkBuddy Δ | JobBench Δ |
|---|---|---|
| Library | −3.1 | −1.8 |
| Scoped editors (INV/DOM) | −2.9 | −3.7 |
| Composition | −1.6 | −1.9 |

All three earn their place. Scoping matters most on the professional-task benchmark; composition
matters least but still does.

### The finding that constrains our whole design

> "directly refining the base execution harness without access to reference executions, candidate
> probes, or the improvement library degrades performance on Code and Web. Specifically, Code scores
> drop from 73.4 to 63.2 and Web scores fall from 69.9 to 65.0."

**Naive self-editing of a harness makes it worse.** This is the single most important result in the
paper for us. A system that lets an agent rewrite its own context assembly without the full
Propose–Probe–Compose apparatus and a library is a regression generator.

### Other results worth holding

- Same model as executor and editor still improves (+3.3 / +5.5 / +3.0 with Opus 5; +13.7 on LAB with
  GLM-5). **We do not need a stronger editor than the executor** — which matters because our default
  is one local model.
- Gains are monotonic in k from 1→5 but the paper does not claim a universal budget.
- Library transfer works: a JobBench-derived library improves WorkBuddy-Bench (+0.6 / +0.5 / +2.9).
  Cross-repo transfer is therefore plausible but unproven at our scale.

### Stated limitations (the paper's own future work)

- The experience space is "just a simple index structure" — merging overlapping components, expiring
  stale experience, optimising retrieval, and **dynamically allocating recursion budget by task
  difficulty** are all future work.
- Compose/Probe evidence is unreliable by construction (stochasticity + shared model bias).
- Compute rises with k; parallel reduces wall time, not total compute.

---

## S4 — the reference implementation

Read at source level; mechanics are documented separately in
[`02-harness2-mechanics.md`](02-harness2-mechanics.md). Three things from the repo matter at the
sourcing stage because they are *not* in the paper:

1. **The improvement target is a filesystem tree with a single validity predicate**, not an abstract
   object. `SurfaceSpec` (paths, caps, frontmatter rules) + `is_allowed()` + `validate()` decide what
   may be edited and whether the result is admissible. Everything else is data.
2. **Omitted-is-inherited edit contract.** "A proposal emits only what it changes." A proposal is the
   edited directory on disk; there is no diff format to get wrong.
3. **The guards are structural, not prompt-based.** `assert_tree_has_no_grader_verdicts` refuses to
   store a harness whose files mention grader markers, so evidence served to later tasks can never
   carry a verdict. The prompt asks nicely; the code refuses.

---

## S1 — the practitioner experiment (first video)

This is the most useful source for *what goes wrong*. Architecture: three zones.

- **Zone 1 — the model API.** Gemini Interaction API specifically because each request carries its own
  system instructions, settings and tool list, so a tool written on turn 3 is callable on turn 4 of
  the same conversation. One cost caveat: **the turn immediately after a tool-list change misses the
  context cache.**
- **Zone 2 — the sandbox.** A three-tool kernel (shell, read, write) plus a "toolbox" of three
  recursive primitives: `create_tool` with a **mandatory unit-test gate**, lifecycle hooks
  (`session_start`, `before_done`), and **reflective memory** (a note file injected at task start plus
  a short between-task reflection).
- **Zone 3 — outside the sandbox.** Two guardrails: a **hidden checker the agent cannot see or game**
  (it only learns which check names passed/failed), and an **external model broker** holding API keys
  so agent-authored tools can be model-powered without ever seeing a secret.

The `before_done` hook is the interesting primitive: a tool attached there that reports failure
**blocks** the finish and sends the failure back. So the agent writes its own definition of done and
the harness enforces it on every future task.

### The three experiments, honestly reported

| Round | Setup | Result |
|---|---|---|
| 1 | Web apps, evolving vs frozen (3 tools, nothing kept) | **Both passed every hidden check, in about the same time.** The elegant evolving harness won nothing. |
| 2 | Harder: image helper and broker removed entirely | The **frozen** agent wrote its own OCR + computer-vision scripts and solved it anyway. |
| 3 | Custom binary format, 5 tasks, expensive parser | Evolving harness won clearly — built the parser once, reused it 4×. |

The lesson, in the author's words:

> "recursive self-learning harness does not make the model smarter because a strong model builds
> throw-away scripts in line anyway. It pays off under the specific conditions when a capability is
> expensive to rebuild from scratch, when your task repeats in a domain family, and when the evolution
> stays lean so that the agent doesn't bloat its own loop."

### The failure modes, which are the real deliverable

1. **Self-bloat.** With an empty toolbox on the binary-format family, the agent built the most
   impressive toolbox of all runs — and kept adding checks to its own `before_done` hook on every
   reflection. By task 5 the growing checklist consumed **100% of the time saved** by reusing the
   parser.
2. **Re-verification loops.** After building a stricter pixel-diff tool, the agent re-verified an
   already-passing page until it ran out of time.
3. **Criterion leakage.** The growing `before_done` check started **copying hidden check names
   straight out of the task description**. The agent began optimising the grader, not the work.
4. **Broken tool accepted.** Motivated the mandatory unit-test gate in `create_tool`; the very first
   run had a screenshot tool that failed because the browser binary was missing, was rejected, and was
   then fixed by the model.

His four rules, which read as a direct brief for our design:

> "Start with tiny three tool kernel inside a sandbox so every new tool is forced by a real task need.
> Require unit test inside create tool before any generalized function enters the tool list. Then keep
> your creator and your secret brokers outside the sandbox. Use session start and before done hooks so
> the model can improve its own process but **keep reflection short and strictly cap your before done
> hook** so it stays fast."

---

## S2 — the secondary explainer (second video)

Mostly a restatement of S3. Three points it adds or sharpens:

- Framing of the eight layers by *role*: "Constraints act as guardrails. Procedures are organized into
  skills. Verification is handled by execution scripts and loop control is managed through
  middleware." — i.e. the split is by **runtime cost and reach**, not by topic.
- "Simply keeping error logs is not enough. The system should analyze execution history to understand
  why a failure occurred and which modules needed to be changed to prevent it." — logging is not
  learning.
- Explicit cost warning: "as the recursive budget increases, the inference cost continues to rise.
  Parallel execution can reduce waiting time, but does not reduce the total computational cost."

Nothing here contradicts S3. It is useful mainly as confirmation that a reader coming to Harness² cold
takes away: *layer by responsibility; learn from execution, not from logs; budget is real.*

---

## Where the sources disagree, and how we resolve it

| Tension | S1 (practitioner) | S3/S4 (paper) | Resolution for us |
|---|---|---|---|
| Does self-improvement pay? | Often not — a strong model rebuilds in line | Yes, consistently, on professional benchmarks | Both are right at different capability costs. Our costliest-to-rebuild capability is **repository orientation + retrieval selection**, which is exactly the "expensive parser" shape from S1 round 3. Learn there, not on general reasoning. |
| How big should the harness be? | Start at 3 tools, stay minimal | Eight components, rich surface | Start minimal, expose only surfaces our engine can validate. A large editable surface is a bloat invitation. |
| Trust in the evidence | Hidden external checks | No labels at all, behavioural contrast only | We have neither hidden checks nor labels. We must therefore be *more* conservative than either: contrast plus a human-visible record, and a hard cap on growth. |
| Reflection frequency | Short, strictly capped | Every task, into a library | Capped and rate-limited. Reflection is the bloat vector in S1. |
