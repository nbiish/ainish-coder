# 02 — harness2 mechanics, read at source level

Everything here was read from a shallow clone of `google-research/harness2` at `main`
(commit dated 2026-11-02, `HEAD` at clone time). File paths are repo-relative so any claim can be
re-checked. This document exists because the *paper* describes intent and the *code* describes what
is actually enforceable — and we are copying the enforceable parts.

Layout of `harness2/core/`:

| File | Lines | Role |
|---|---|---|
| `spec.py` | ~290 | The seam: `BenchSpec`, `BenchPrompts`, `ChannelSpec`, `BenchmarkAdapter` protocol |
| `tree.py` | ~390 | The editable component tree: `SurfaceSpec`, `is_allowed`, `read_tree`, `write_tree`, `validate`, `diff_summary`, `diversity`, `autotrigger` |
| `context.py` | ~560 | The evidence tree handed to an improver session, plus `mission()` and the anti-grader guard |
| `proposer.py` | ~470 | Improver sessions with file access |
| `recursion.py` | ~500 | Parallel and sequential task-level recursion |
| `selection.py` | ~500 | Blind selection + `reflect_adoption` |
| `library.py` | ~250 | Per-domain experience library `R` |
| `ledger.py` | ~150 | Budget identity `R=4k`, `P=3k` |
| `runmark.py` | ~180 | Trial identity: was this rollout finished, by this configuration |
| `prompts.py` | ~1200 | All stage prompts |
| `judge.py` | small | Benchmark scoring, isolated from everything else |

---

## 1. The `BenchSpec` validators that encode hard-won lessons

`spec.py` is worth reading for its `__post_init__` assertions alone. Each one is a bug that was
paid for:

```python
if self.obs_trunc < 10_000:
    raise ValueError(
        f"obs_trunc={self.obs_trunc} is in the range that fabricates defects; "
        f"use >= 10_000 (default 50_000)"
    )
```

Truncating observations below 10k characters **invents failure modes** that then get "fixed" by the
improver. That is a direct warning for us: if we truncate a trajectory or a retrieved section before
handing it to the improver, the improver will propose edits against artefacts of the truncation.
`context.py` restates this to the improver in `mission()`:

> "Every trajectory EVENT is present: the trajectory was not clipped to fit this mission. An
> individual observation may contain an explicit renderer-truncation marker; that marker is ours, not
> behavior by the solver. Do not diagnose it as a solver failure."

```python
for bad in ("benchmark", "evaluation", "grader", "rubric", "score"):
    if bad in low:
        raise ValueError(
            f"BenchPrompts.{field_name} must describe the WORK, not its "
            f"measurement (found {bad!r}). Say what the practitioner needs."
        )
```

Prompt text is **structurally forbidden** from describing its own measurement. Not "please don't" —
a constructor that raises.

```python
if (kind is None) != (model is None):
    raise ValueError("channel and model must be overridden TOGETHER ...")
```

Partial overrides fail silently downstream, so they are refused at construction.

**Take-away for us:** every constraint we care about should be a constructor-time or
validate-time refusal in code, not a sentence in a prompt.

---

## 2. `SurfaceSpec` + `tree.py` — the editable surface

The whole editable surface is data:

```python
@dataclass(frozen=True)
class SurfaceSpec:
    name: str
    always_on: tuple[str, ...]          # files always in context — the expensive ones
    always_on_max: int                  # a HARD CAP, in chars
    always_on_cap_reason: str           # the reason is data, so error text stays true
    skill_dir: str
    skill_name_rule: str
    trigger_hint: str
    autotrigger_file: str
    trigger_line: str
    subagent_requires_mode: bool
    plugin_dir: str | None
    hooks_file: str | None
    hook_events: frozenset[str] = frozenset()
    compile_skill_scripts: bool = False
    reject_empty_always_on: bool = False
    stubs: tuple[tuple[str, str], ...] = ()
```

Notes:

- `always_on_max` is **characters**, not tokens and not files. One number, one meaning, checked in one
  place. There is no second budget to disagree with it.
- `always_on_cap_reason` is stored next to the cap so the validation error explains *why* without a
  second lookup table drifting from the first.
- `is_allowed()` is a **predicate that never raises**: off-surface paths are reported, not fatal.

```python
def normalize_rel(rel: str) -> str:
    r = str(rel).strip().replace("\\", "/")
    if r.startswith("/") or ".." in r.split("/"):
        raise ValueError(f"path escapes the harness: {rel!r}")
```

Path traversal is refused before any join.

**The edit contract is omitted-is-inherited:**

> "Files you do not touch are inherited unchanged. Do not rewrite a file to keep it the same. Delete a
> file to remove that component."

A proposal *is* the edited directory. There is no patch format, no schema to mis-serialise, and a
no-op is expressible (`KEEP_BASE`).

### `validate()` — the gate every proposal must pass

`validate()` collects **every** problem and raises once with them joined by `" | "`, because the
message is fed back verbatim as retry feedback. The checks:

1. **Always-on cap.** `len(body) > cap` is a hard error.
2. **Empty always-on** refused when it is the only always-on file (`reject_empty_always_on`).
3. **Every skill needs `description:`** in frontmatter — "or the skill is dropped SILENTLY at load".
4. **Skill `name:` must match its directory** (on surfaces with `skill_name_rule == "must_match"`) —
   likewise a silent drop.
5. **Every skill must be named in the always-on text** — "an untriggered skill is dead weight".
6. **Subagent frontmatter** needs `mode: subagent` and `description:`.
7. **Every `.py` compiles.** `_py_compiles` runs `compile(src, rel, "exec")`.
8. **Hooks file schema** — events must be in `surface.hook_events`, entries must be lists of objects
   with a `hooks` list, and each hook must be `type: "command"` with a non-empty command, because
   "async/prompt/agent hooks are skipped as 'not supported yet'" — a malformed hooks file "never fires
   rather than erroring".
9. **Every script referenced must exist.** `_check_script_refs` scans skill and always-on bodies for
   `python3 scripts/x.py` style references and errors if the file is not shipped *in the same
   proposal*. Exception: runtime-reserved scripts.

And then `autotrigger()` runs **before** validate, to repair the single most-violated rule
automatically:

```python
def autotrigger(surface, tree, *, always_on_max=None) -> list[str]:
    """Give every skill a trigger line in always-on text; return the names repaired.
    A line that would push the body over the always-on cap is skipped instead."""
```

It extracts the skill's `description:` and appends the surface's `trigger_line` template — **unless
that would breach the cap**, in which case it skips rather than silently overflowing. Repair, then
validate, then refuse.

`diff_summary()` returns `added / removed / modified / always_on_char_delta`. `diversity()` computes
pairwise line-Jaccard across candidate trees "so collapse to one body is visible" — i.e. they measure
whether k candidates are actually different or the model wrote the same thing k times.

**Take-aways for us:** a small, typed surface; one hard cap in one unit; silent-drop failure modes
promoted to hard errors; one validate that reports everything; repair what can be repaired
deterministically before refusing.

---

## 3. `context.py` — evidence as files, prompt as pointer

This is the cleanest idea in the repo and the one we should copy first.

```
context/task.md                  the task as the agent received it
context/rollouts/<label>.md      full trajectory -- no prompt-budget truncation
context/deliverables/<label>/    the artifact, via the judge's own extractor
context/harness/<rel>            the c1..c8 tree being edited
context/library/INDEX.md         earlier tasks in this domain + their full harnesses
context/pool/<label>/            candidate harness + its rollout
MISSION.md                       what to do with all of it
```

> "Evidence is served as files and the prompt is a short pointer, so nothing is truncated to fit a
> prompt."

`mission()` is ~20 lines: the job, the layout listing (only what exists), and the instruction to
read. It explicitly says "Read it — do not answer from this message alone", and "Cite the specific
trajectory moment behind every change; one you cannot trace to a moment is speculation."

`ContextTree.layout` is a property that **only mentions paths that exist** — the evidence listing
cannot lie about what it provided.

The anti-grader guard:

```python
GRADER_VERDICT_MARKERS = (...)
def assert_tree_has_no_grader_verdicts(tree, markers=GRADER_VERDICT_MARKERS) -> None:
    """... such a tree could never afterwards be served as evidence."""
```

Checked on the **filename** and on the **body** (for relevant suffixes), and it raises with the
offset and surrounding context so the fix is obvious. Applied both when a harness is stored in the
library and when library content is assembled into evidence.

**Take-away for us:** put the prime's evidence on disk and pass a pointer. It removes the entire
class of "we truncated the thing it needed and it invented a defect".

---

## 4. `recursion.py` — Propose–Probe–Compose, concretely

Budget: `expected_rollouts(k) = 4k`, `expected_sessions(k) = 3k`. The ledger asserts the identity, so
a run that silently under- or over-spent is a reported failure (`BudgetError`).

Each stage gets **one retry** (`STAGE_ATTEMPTS = 2`) and then falls back to the current harness with
`fell_back=True` and the error recorded — never a silent empty result.

`_accept_tree` is the gate:

```python
def _accept_tree(surface, adapter, new, fallback, label) -> tuple[bool, str]:
    triggered = harness_tree.autotrigger(surface, new)
    changed = harness_tree.diff_summary(surface, fallback, new)
    kept = not (changed["added"] or changed["removed"] or changed["modified"])
    try:
        harness_tree.validate(surface, new, ...)
        adapter.validate_tree(new)
        context.assert_tree_has_no_grader_verdicts(new)
    except ValueError as exc:
        return kept, str(exc)
    return kept, ""
```

Note the ordering: **repair → diff → validate → guard**. And `kept_base` is a first-class outcome,
reported in `ModeResult.kept_base`, not an error.

`ModeResult.ok` is a conjunction, and deliberately strict:

```python
return (bool(self.finals) and not self.errors
        and not any(stage.execution_failed for stage in self.stages))
```

A stage that failed to *execute* poisons the whole result rather than quietly contributing a tree
nobody ran.

**Take-away for us:** a no-op must be a legal, recorded outcome; a failed probe must never be treated
as a null result; and the budget identity should be asserted, not estimated.

---

## 5. `selection.py` — blind choice, then reflection

Anonymisation is seeded and stable:

```python
def assign_ids(labels, *, task_id, k, mode) -> dict[str, str]:
    """anon id -> label, by canonical sort then a seeded shuffle: stable across reruns."""
    seed = int(hashlib.sha1(f"{task_id}|{k}|{mode}".encode()).hexdigest()[:12], 16)
```

`order_graded_first` puts graded items first **in their original relative order; nothing is
discarded** — order is used as a hint, never as a filter.

The selector returns an **existing** deliverable. It cannot synthesise. `_CHOICE` is parsed from a
fenced block, `_WHY` / `_EXP` / `_EDITS` from XML-ish tags, so a malformed reply is detectable rather
than silently empty.

`reflect_adoption` runs **only after adoption succeeded**, rebuilds the evidence tree with the chosen
harness and the candidate pool, copies the base harness in for comparison, and writes `adoption.json`
with the chosen label, the id map, and the reason. Reflection is grounded in a full re-read, not in
memory of the run.

**Take-away for us:** selection must not see provenance; reflection must be a separate session that
re-reads evidence; and the anon map must be recorded so a human can audit what was chosen.

---

## 6. `library.py` — the experience store

```
<root>/<run-tag>/<mode>/<domain>/INDEX.md
<root>/<run-tag>/<mode>/<domain>/harnesses/<task>/harness/<rel>   the full adopted tree
<root>/<run-tag>/<mode>/<domain>/harnesses/<task>/EXPERIENCE.md   why picked + lesson
```

> "Retrieval is by construction: a domain's directory only ever holds same-domain entries. The whole
> tree is carried, never a summary."

Four properties to copy:

1. **`has_experience()` is a gate, not a formality** — an entry is only written when `cue`, `lesson`
   and `evidence` are all non-empty strings. No evidence, no entry. (Paper §2.3: "When evidence is
   insufficient, reflection adds no new experience entry.")
2. **`retain()` keeps only entries preceding the current task in the stream.** The library can never
   contain a future task's harness, which would leak.
3. **`INDEX.md` is rebuilt from disk**, never appended by hand, and lists the cue for each entry so a
   reader can decide what to open.
4. **`forget()` takes explicit task ids** and ignores unknown ones — pruning is a deliberate act.

`EXPERIENCE.md` has a fixed shape: adopted label, run id, component inventory, `## Why this was
chosen`, `## What each edit did`, `## Transferable lesson` with `cue / lesson / evidence /
confidence`.

**Take-away for us:** a lesson without cited evidence is not stored; an entry carries the **whole**
artefact, not a summary; and the index is derived.

---

## 7. `runmark.py` — trial identity

```python
def fingerprint(harness_dir: Path | None) -> str:
    """A stable digest of the harness tree that produced a rollout; `None` means a base
    rollout on the inherited harness and digests to the shared value "base"."""
```

Plus `inputs_fingerprint(task_prompt, files_dir)` hashing "what the agent was asked and what it was
given". The module docstring states the principle:

> "Completion is recorded explicitly by the code that observed the run return; presence of output is
> not enough."

A rollout from a different configuration, or one answering a task that has since been corrected, is
never reused. `_ignored()` excludes `__pycache__`, `.pyc`, `.DS_Store` so byproducts do not change
identity.

**Take-away for us:** any cached prime or cached contrast must be keyed on a fingerprint of the
configuration and the request, and "it produced output" is not evidence that it ran.

---

## 8. `config.py` — secrets and scoping

`scrub_env()` removes a `SCRUB_ENV` frozenset from the environment handed to a subprocess, with
`provider_keys()` naming exactly which credentials a given `provider/model` legitimately needs. The
comment records why each name is in the set.

> "(The SCRUB_ENV names an OpenCode provider reads for its own credentials …)"

**Take-away for us:** our improver sessions must run with an explicit environment allowlist, not
`os.environ` minus a denylist. In this repo that is already the `pqc-secrets` contract.

---

## 9. What harness2 has that we cannot copy

| harness2 | Why not us |
|---|---|
| Benchmark judge (`core/judge.py`) producing scores | We have no labelled tasks. This is the whole reason for the contrastive step. |
| Containerised rollouts (WorkBuddy needs Docker) | Our deployment target is a developer's laptop; no Docker assumed. |
| OpenCode / Codex executors as substrates | We have `DriverEngine` and `pi_agent_call`; a substrate abstraction is over-engineering at our scale. |
| `--k 5` recursion sweeps | Cost. One local model, and the operator pays in wall-clock. |
| Vertex AI model config | We resolve models through `local-router` / `_pi_role_model`, by contract. |

What is left after removing those is small and portable: **a typed surface, a validator, a library of
evidence-backed lessons, an anti-grader guard, and a contrast-based acceptance rule.** That is what
[`05-design.md`](05-design.md) proposes.
