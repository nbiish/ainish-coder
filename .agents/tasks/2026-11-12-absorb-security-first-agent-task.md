# Absorb `security-first-agent` into `AGENTS.md`, retire the pack

- **status:** done
- **branch:** fix/absorb-security-first-agent
- **plan:** `.agents/plans/2026-11-12-absorb-security-first-agent.plan.md`
- **operator ask:** fold the security-first-agent skill into `AGENTS.md` so agents cannot skip it,
  then remove the pack from `.agents/skills`, `skills-to-distribute`, and the `--rules` logic.
  Follow-up: `AGENTS.md` must also prompt `.agents/suggestions/{date}-{slug}.txt`.

## What was found

1. The 2026-11-12 mandatory-deploy made the pack ship everywhere, but a skill is progressive
   disclosure — an agent that never triggers it never reads it. The posture belongs in the one file
   every session reads whole.
2. The contract carried a hard 120-line gate asserted twice in `scripts/test-pqc-dist.sh`;
   absorbing the posture took `AGENTS.md` from 119 to 158 lines. The operator raised the gate to
   160 explicitly (the contract is the only surface consumer agents receive).

## What changed

1. **`AGENTS.md`** — new `Security-first posture` section (order of operations, least context for
   subagents, no unattended authority, stop conditions, report requirements); "the files win over
   the summary" in the context call; Non-negotiable 8 and *Close* prompt
   `.agents/suggestions/{date}-{slug}.txt`.
2. **`src/skills_selection.sh`** — `_skill_mandatory` back to `pqc-secrets|ainish-security` (still
   the single list); retirement rationale in the comment.
3. **`src/deploy_skills.sh`**, **`src/help.sh`** — mandatory-rail comment corrected; help deploys
   18 packs, two mandatory.
4. **Both skills indexes** (`skills-to-distribute/skills/llms.txt`, `.agents/skills/llms.txt`) —
   pack bullet and index row removed, files kept identical.
5. **`llms.txt`**, **`README.md`** — curated-subset lists drop the pack; PRD documents the
   retirement (posture lives in the contract; no payload entry to dangle, no trigger to skip);
   README table row removed.
6. **Packs deleted** from both trees via `git rm`.
7. **`scripts/test-pqc-dist.sh`** — mandatory-set loops cover two packs; new pins: the retired pack
   is not mandatory, help no longer inventories it, the payload index no longer references it,
   `AGENTS.md` carries the posture and the suggestions prompt; PRD asserts `Two packs are
   mandatory`; contract-critical loop covers three packs; line gate 120 → 160 with the amendment
   documented at both assertion sites.

History (`.agents/{tasks,comms,plans}` records naming the pack) untouched — append-only.

## Verification

- `bash scripts/test-pqc-dist.sh`: PASS 239/239, exit 0. Count reconciled against HEAD's 240: the
  retired pack carried three per-pack checks (readable locally, distributable, byte-for-byte), so
  4 → 3 packs is −3, while the new pins and renames net +2 — 239 executed, none lost. `bash -n`
  clean on all four touched scripts.
- Hermetic `--rules` probe (fresh `HOME`, headless): deploys exactly `ainish-security` +
  `pqc-secrets`; `security-first-agent` appears nowhere in the deployed tree;
  `--skills-list --json`: `mandatory: [ainish-security, pqc-secrets]`, `on: []`, `off:` 16 packs.
- `--skills-verify` on a target stripped of `ainish-security`: exit 1,
  `✗ MISSING MANDATORY: ainish-security`.
- `--skills-sync` with `{pqc-secrets: false, ainish-security: false, question-me: false}` recorded:
  both mandatory packs still deployed, `question-me` stayed off, exit 0.
- Known pre-existing, surfaced not caused: the deploy-time signature gate fails on this machine
  identically for `main` and the worktree — the engine's local seed does not match the committed
  trust anchor (signer `69e7233d…`, anchor `d98405ea…`); `--rules` exits 1 after deploying correct
  content. Recorded to `.agents/suggestions/2026-11-12-rules-signing-anchor-mismatch.txt`.

## Left open

- Trust-anchor/seed rotation is an operator decision — see the suggestions file above.
