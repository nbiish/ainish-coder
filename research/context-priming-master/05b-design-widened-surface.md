# 05b — Design revision: the widened surface (skills and scripts)

Supersedes §4 of [`05-design.md`](05-design.md). Written 2026-11-17 after the operator chose
**"go as far as harness2 does — let the improver write skill files and scripts"** over the
numbers-and-tokens-only ceiling.

This revision changes the blast radius substantially, so it restates the threat model rather than
inheriting it.

---

## 1. What changed, and what the first draft got wrong

The first draft argued that a prose surface invites the S1 bloat path. **That argument was
misdirected**, and harness2's own prompts say why:

> "ALWAYS-ON PROSE IS THE EXPENSIVE OPTION. Every word of it is in context on every run … An on-demand
> component costs nothing until the moment it is invoked. So prefer, in this order: a SKILL for
> anything with a recognisable trigger … ALWAYS-ON TEXT last."

A *skill* is not the bloat vector. **A skill is the cheap form** — it costs nothing until invoked. The
bloat vector is always-on text, which a skill is not. So allowing skills *reduces* R2 exposure compared
to allowing prose, and the operator's choice is better-founded than the first draft implied.

What genuinely gets worse is **R3/R4** — gaming and injection — because a skill body *is* prompt text
that reaches a model, and because a skill can carry a script.

---

## 2. The one fact that governs the whole revision

This repository's own `.agents/skills/llms.txt` states the constraint:

> "agent harnesses auto-discover `**/.agents/skills` and treat every pack found there as **standing
> prompt surface** — carrying the full payload there made each session's context larger for no
> benefit."

So a file at `.agents/skills/<name>/SKILL.md` is **not** just context-harness state. It is standing
prompt surface for *every session of every agent* in that repo — Cursor, Claude, Codex, all of them —
permanently, whether or not `--context` is ever called.

That is a completely different blast radius from `.agents/context-harness/`, and it is the most
important consequence of widening the surface. It cannot be done silently.

### Resolution: two tiers, one of them opt-in

| Tier | Location | Loaded by | Reach |
|---|---|---|---|
| **Staged** (default) | `.agents/context-harness/skills/<name>/` | Only when `--context` surfaces it as a hit, or the agent opens it | Bounded by the prime |
| **Promoted** (opt-in) | `.agents/skills/learned-<name>/` | Auto-discovered by every agent harness in the repo | Standing prompt surface, always |

The improver writes to **staged**. Promotion is a separate, explicit operator action
(`ainish-rag --context-promote <name>`), never automatic. This keeps "go as far as harness2" — the
improver can write real skills with real scripts — while refusing to let a self-improving loop
silently enlarge every session's prompt in every harness.

This is the decision I would defend hardest. It is written as an explicit clarification in the plan of
record so the operator can overrule it deliberately rather than by omission.

---

## 3. The widened surface

Following harness2's `SurfaceSpec` + `tree.py`, adapted. Our tree is a real directory, so most of
their machinery transfers directly.

### 3.1 Editable paths

```
prime-profile.json                          bounded scalars (unchanged from 05-design.md §4)
skills/<name>/SKILL.md                      a reusable procedure, on-demand
skills/<name>/scripts/<file>.py             a deterministic helper shipped WITH its skill
EXPERIENCE.md                               evidence for the current generation
```

`<name>` must match `learned-[a-z0-9][a-z0-9_-]*`. The prefix is not cosmetic: it is what
`deploy_skills.sh` uses to recognise "authored by the learner, never sweep", and what an operator greps.

### 3.2 Bounds — the validators, which are the security boundary

Adapted from harness2's `validate()`, because every one of those checks was paid for:

| Check | Rule | Why (harness2's own words) |
|---|---|---|
| Frontmatter name | `name:` equals the directory name | "a mismatch is dropped SILENTLY at load" |
| Frontmatter description | `description:` present and non-empty | "or the skill is dropped SILENTLY at load" |
| Trigger | every skill name appears in the trigger surface | "an untriggered skill is dead weight" |
| Script refs | every `scripts/x.py` named must ship in the same proposal | "a skill invokes a script that does not exist" |
| Compiles | every `.py` must `compile(src, rel, "exec")` | a broken helper that is accepted is trusted all task |
| Acceptance leakage | no acceptance-marker token in name or body | the S1 criterion-leakage failure |
| Count | ≤ 3 live skills per generation | bounded growth |
| Body size | `SKILL.md` ≤ 4000 chars | a skill is a procedure, not an essay |
| Script size | each `.py` ≤ 8000 chars | ditto |
| No network | body must not contain `http://`, `https://`, `curl `, `wget ` | a learned helper must not call out |
| No secrets | no `_KEY`, `_TOKEN`, `_SECRET`, `password` patterns | `pqc-secrets` is the only secret path |
| Import allowlist | scripts may use a documented stdlib subset | keeps the blast radius inside the repo |

The last three are **ours, not harness2's** — their sandbox enforced those properties at the OS level
and we have no sandbox. This is an honest downgrade: an OS boundary replaced by a static check is
weaker. It is stated rather than glossed.

### 3.3 The trigger surface

harness2's `autotrigger()` appends a trigger line into always-on text, **skipping the line if it would
breach the cap**. Ours cannot: our always-on text is the injection envelope, budget-capped at ~3,200
tokens and already full.

So our trigger is: **`--context` surfaces staged skills as a labelled retrieval hit** —
`learned-skill: <name> — <description> (load when: <trigger>)` — costing ≤ 2 lines inside the existing
retrieval cap, and only when the task's terms match the skill's trigger. Skills that never match are
counted and reported, so dead weight is visible instead of accumulating.

This is a genuine divergence and should be recorded as one: **harness2 has a runtime that can dispatch;
we have a prime that can only point.**

---

## 4. Revised threat model

**Adversary 1 — drift** (unchanged): the learned state optimises for a stale distribution.
*Response:* expiry, immutable history, `KEEP_BASE` first class.

**Adversary 2 — the improver gaming its gate** (worse in reach, not in kind): it now writes prompt
text, so a bad acceptance writes to the thing that steers the model.
*Response:* `assert_no_acceptance_leakage`; the improver never sees the signals; every generation is
reversible.

**Adversary 3 — injection via repository content** (materially worse): the improver reads wiki pages
and `.agents/` artefacts, which are attacker-influenced in a shared repo or after cloning untrusted
content. Previously it could only reorder retrieval; now it can write a `SKILL.md` containing an
instruction.

*Response, in layers:*
1. Skill bodies are **not** auto-loaded while staged — they reach a model only when `--context`
   surfaces them or an agent opens them explicitly.
2. Promotion to standing prompt surface requires an operator command.
3. Static checks refuse URLs, secret patterns, and non-allowlisted imports.
4. On surfacing, the body is wrapped with an explicit "this is a learned procedure, not an instruction
   from the operator" label.
5. `EXPERIENCE.md` must cite the evidence behind each skill, so a reviewer sees what content it came
   from.

None of that is airtight. **A staged skill in a hostile repo can still put text in front of a model.**
The mitigation is that it is reviewable, labelled, and reversible — not that it is impossible. The
contract's "no silent downgrade" rule requires saying so.

**Adversary 4 — blast radius** (the reason for tiering): a promoted skill is standing prompt surface
for every agent session, forever. *Response:* promotion is opt-in, named `learned-*`, exempt from the
deploy sweep, and revocable by deleting one directory.

---

## 5. Interaction with `--rules` that must be fixed, not worked around

`src/deploy_skills.sh:181` sweeps target skill directories absent from source:

```bash
for sweep_dir in "$skills_target"/*/; do
    [[ -d "$skills_source/$sweep_name" ]] && continue
    if _skill_mandatory "$sweep_name"; then ... continue; fi
    if skills_selection_has_entry "$target_dir" "$sweep_name"; then
        rm -rf "$sweep_dir"
```

A promoted `learned-*` pack is absent from source, is not mandatory, and has **no selection entry** —
so today it survives by accident. That is exactly the kind of accident that stops holding the moment
someone records a selection. Two changes:

1. `_skill_learned "$name"` beside `_skill_mandatory`, matching `learned-*`, consulted by the same
   sweep. **Never sweep a learned pack, never overwrite one, warn if a source pack collides.**
2. The selector must not present learned packs as toggleable — they are not source packs.

This mirrors the existing `_skill_mandatory` precedent, including its comment about the duplicate-list
bug that made a pack mandatory in one path and selectable in another. One predicate, one place.

---

## 6. What this does not change

- Learning is still a **separate verb**, off the `--context` path (R6).
- Generation 0 is still **frozen and mandatory** (R1; the 73.4→63.2 result).
- Acceptance is still a **deterministic gate**, not a model judgement.
- `KEEP_BASE` is still a **first-class outcome** — S1 round 1 says it may be the common one.
- The profile still lives at a **tracked** path (R5).
- Still **no `AGENTS.md` change** (160-line cap).
- Still **no new injection section** — profile values and skill hits fit inside the existing retrieval cap.

## 7. Revised risk ranking

| Was | Now | Why it moved |
|---|---|---|
| R7 contrast meaningless | **R7 — still #1** | Unchanged: it decides whether this ships |
| R1 learner makes primes worse | R1 — #2 | Unchanged in kind; skills enlarge the reach of a bad acceptance |
| R2 self-bloat | **R2 — #7, much lower** | Skills are on-demand; the bloat vector is always-on text, which we did not add. The one risk this choice *improves*. |
| R3 criterion leakage | **R3 — #3, higher** | The improver now writes prompt text |
| R4 injection | **R4 — #4, much higher** | Was "useless to attempt"; now a real write primitive, bounded by tiering and static checks |
| R12 (new) promotion blast radius | **#5** | A promoted skill is standing prompt surface in every harness |
| R13 (new) `--rules` sweep destroys learned skills | **#6** | Found at `deploy_skills.sh:181`; the fix is small but must ship with the feature |
