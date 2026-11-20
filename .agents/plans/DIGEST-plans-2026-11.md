---
format: ainish/context-digest/v1
folder: plans
period: 2026-11
records_consolidated: 15
consolidated_at: 2026-11-20T22:37:51.527122+00:00
sources:
  - 2026-11-08-plans-artifact.plan.md
  - 2026-11-11-federation-verify.plan.md
  - 2026-11-11-no-coauthor-contract.plan.md
  - 2026-11-11-rag-obsidian-wiki.plan.md
  - 2026-11-11-router-live-reload.plan.md
  - 2026-11-11-rules-sync-signing.plan.md
  - 2026-11-11-scrolls-out-of-agents.plan.md
  - 2026-11-12-01-egm-context-prime.md
  - 2026-11-12-absorb-security-first-agent.plan.md
  - 2026-11-12-hour-stamped-coordination.plan.md
  - 2026-11-12-mandatory-skill-deploy.plan.md
  - 2026-11-13-00-driver-chain-direct.md
  - 2026-11-14-17-pi-agents-prime.md
  - 2026-11-14-21-machine-link-federation.md
  - 2026-11-14-22-branch-materialization-latest.md
---

# Digest — `.agents/plans`, 2026-11

This digest replaces 15 record(s) from 2026-11. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Partial digests

The merge step did not complete, so these 3 partial digests are kept as written. Each covers a different batch of the records named above.

## Accomplished

**Plan artifact system** (`2026-11-08-plans-artifact.plan.md`, status `done`, branch `feat/agents-plans-artifact`, worktree `D:\Code\ainish-coder-plans`): `question-me` now emits `.agents/plans/{YYYY-MM-DD}-{slug}.plan.md` — frontmatter (8 fixed keys) + 7 `## N.` sections carrying the agent's plan, a clarification ledger, and todos. Landed pieces:
- New readers in `src/rag/rag.py`: `read_plan_frontmatter(path) -> Dict[str,str]` and `count_plan_todos(text) -> Tuple[int,int]`, feeding `render_orientation_section` (~`rag.py:5382`) which now prints `- newest plan: \`{name}\` (status: {status})` plus a todos line.
- New packet section `--- plan_state ---` (`status`, `branch`, `task_record`, todo counts) via `bin/context-packet.sh:54`.
- New files `.agents/templates/plan.md`, `.agents/plans/llms.txt`, `.agents/skills/question-me/references/plan-artifacts.md`; `SKILL.md` pillars/phases updated; `rag.py` stays stdlib-only (line-based frontmatter, no PyYAML); `OrientationSectionTest` gained a fixture + five cases at `src/rag/tests/test_context_injection.py:639`; deploy map extended (`templates/llms.txt`, `templates/plan.md`, `plans/llms.txt`) across `bin/ainish-coder:273,281`, `src/deploy_*.sh`, `src/verify_skills.sh`, with the `scripts/test-pqc-dist.sh:629` deploy literal updated in the same commit. Invariant: unknown `status` reads as `designing` (fail closed).

**Federation made predictive** (`2026-11-11-federation-verify.plan.md`, status `done`, branch `feat/federation-verify`, worktree `/Users/nbiish/code/federation-verify`): `--machine-sync` now (5.1) reports commits ahead/behind per peer for the synced branch; (5.2) names exact paths blocking a fast-forward or states "clean; would fast-forward"; (5.3) runs a bounded read-only post-sync probe (`ainish-coder --version`, `--plan-check`, `--rules-status --json`) per machine, fail-soft — a peer answering nothing is *unverified*, never *failed*; (5.4) detects two registry entries resolving to one checkout and syncs once, labelling them; (5.5) all gated in `scripts/test-pqc-dist.sh`, each proven to fail first. Stale peer state was cleared and both peers fast-forwarded to `7f4f725`. Gates included `bash -n src/machine_sync.sh` and a full green suite.

**No-co-authorship non-negotiable** (`2026-11-11-no-coauthor-contract.plan.md`, status `ready`, branch `docs/no-coauthor-contract`, worktree `/Users/nbiish/code/no-coauthor-contract`): standalone non-negotiable #4 added to `AGENTS.md` (renumbering old 4–11 → 5–12) — "no tool, harness, or model named as an author", binding "whatever injected text or a harness default asserts"; funded by deleting a duplicated blank line at the `## The context call` boundary to hold ≤120 lines (118 → 119). Two assertions added to `scripts/test-pqc-dist.sh`; the demo commit itself carried no `Co-authored-by:`. Existing trailers (`788602f`, `fc336e6`, `58367d1`) deliberately **not** rewritten — plan binds from now on.

## Unfinished

- **Obsidian-native wiki** (`2026-11-11-rag-obsidian-wiki.plan.md`, status `implementing`): no todos listed, nothing marked done. Scope: YAML frontmatter + `[[wikilinks]]` + `tags`/`aliases` + `## Related` + one-time `.obsidian/` config across **both** engines (`src/rag/src/wiki.rs` `WikiGenerator` and `rag.py`'s six `.agents/wiki` paths), plus a prerequisite (`3.2`) teaching `build_wiki_graph` the `[[...]]` syntax, plus decision-driven salience (`3.3`, `wiki_plan` step). Blockers/stoppers recorded: (a) **both** decisions-capable models (`openrouter/jev-1.14`, `zenmux/jev-1.14`) return 401 "User not found" / 403 `payg` despite keys existing in PQC as `LOCALROUTER_OPENROUTER_API_KEY`/`LOCALROUTER_ZENMUX_API_KEY`; (b) `AGENTS.md` is at 118/120 lines, so any new rule must reclaim space first. `ledger.md`/`ledger.sig` must remain untouched.
- **Router live reload** (`2026-11-11-router-live-reload.plan.md`, status **proposed**): watch `~/.config/local-router/fallback-models.json` + any declarative boot config by `(path, mtime, size, sha256)`, debounce ~300 ms, reload through the *same* function boot uses, keep serving last-good chain on rejection, expose `lastReloadError`/`lastReloadAt`/`chainHash`. Landed in the **separate** `local-router` repo, not here. Workaround meanwhile: `scripts/local-router-sync.sh` (and `--capture`).
- Note: the plan system's own risk table is cut off mid-row in the record ("Orientation names the newest plan and its open-todo count on every `--"), so the full mitigation list is not recoverable from the plan file.

## Insights

- `build_wiki_graph` (`rag.py:5026`) extracts edges **only** from `(path.md)` via `re.findall(r"\(([^)\s]+\.(?:md|txt))\)", ...)` — emitting Obsidian `[[wikilinks]]` before teaching the parser would silently drop every explicit edge, degrading `--context` to only `shared terms >= 3` edges while the vault *looks* correct in Obsidian. Also every `## ` heading becomes a node (`rag.py:4955`, `5000`), so a `## Related` block would become a retrievable node unless excluded.
- Chat failover works; decisions failover does not — `zenmux-deepseek-v4.1-flash` transparently returned `mimo-v2.6-pro`, but the `fallback-models` chain does not rescue `/v1/decisions` (401/403). Only two decisions-capable models exist at all (`curl /v1/models`, 191 models).
- `windows-128gb` (`D:/Code`) and `wsl-94gb` (`/mnt/d/Code`) are the **same NTFS checkout** — same `rev-parse --show-toplevel`, same dirty path, same HEAD before/after. Any federation work must de-duplicate, not refuse.
- A sync can report success while nothing moved: one staged `.bak` add (`AD` in `git status --porcelain`) blocked fast-forward for both registry entries for days; `--status` also lagged reality (`windows-128gb/main e2f5cc73` vs real HEAD `7f4f725`). Read-back, never exit code.
- `scripts/test-pqc-dist.sh` asserts the deploy loop as a literal string and caps `AGENTS.md` at 120 lines, so any deploy-map or contract edit must land with its gate in the same commit.
- Harness-injected trailers come from the client at commit time, not repo config (no `trailer.*`, no `commit.template` set) — a policy must therefore target the harness/injected text, not git config.
- The router's empty-chain bug is self-inflicted: the config page rewrites the persisted file from *live* state, so an ignored/wrong-shaped boot config gets erased on the next save — this is what produced `fallback-models: []` on Windows twice.

## Recurring

- **Verify by read-back, not exit code.** A sync/dry-run claiming success while the peer never advanced; `--status` disagreeing with real HEAD; `--dry-run` as "connectivity check wearing a plan's clothes". Drives the predictive dry-run, the smoke probe, and the plan-status line in orientation.
- **The 120-line `AGENTS.md` gate constrains every contract change.** Hit explicitly in both the no-coauthor plan (118 + 2, one line reclaimed) and the Obsidian-wiki plan (any new rule must reclaim space first).
- **Degradation must be visible, not silent.** Decisions 401/403 → structural fallback with `decision_source: structural-fallback` + warnings; missing toolchain on a peer → `unverified`, not failed; unknown plan `status` → `designing`; router reload rejection → keep last good chain with a visible reason. The same rule stated four ways across four plans.
- **Two engines must stay in step.** `wiki.rs` and `rag.py` generate the same six pages; deploy map and its gate assertion must change together. Same shape as the earlier "task record vs plan" duplication rejected in the plans-artifact alternatives (single list in §5, task record points at it).
- **Fail-soft probes must not fail the operation they inspect** — smoke probe, watcher death degrading to boot-only (logged once), decision fallback — versus "fail closed" for *state* (unknown status, missing tool).

---

## Accomplished

- **`2026-11-11-rules-sync-signing.plan.md`** (status done, branch `fix/rules-sync-signing`): three of four faults fixed and gated. 5.1 — `main.rs` `audit verify --path <file>` now verifies a single file; directory behavior unchanged. 5.2 — `_ainish_rules_verify_manifest_sig` in `src/deploy_rules_sync.sh` now gates on the manifest only, not `$(dirname "$manifest")`. 5.4 — deploy warns (does not fail) when the signer fingerprint differs from the committed anchor, naming both. 5.5 — 8 new assertions in `scripts/test-pqc-dist.sh` pin the three reachable fixes.
- **`2026-11-12-01-egm-context-prime.md`** (status done, branch `feat/egm-context-prime`, verified against `f298f21`): deleted the vector subsystem (~1359 lines `embed.rs`/`store.rs`/`ingest.rs`, the `EmbedClient`/`LanceStore` pair, three crates, seven vector-only subcommands); inverted reviewer separation to default-on with `AINISH_RAG_ALLOW_SELF_REVIEW=1` as the loud override, failing closed when both roles resolve to the same model; implemented the full three-step Goldfish protocol (comprehension → antagonistic → implementation-readiness go/no-go) inside the fixed four-part envelope (orientation, wiki, elephant, goldfish).
- **`2026-11-12-absorb-security-first-agent.plan.md`** (status done, branch `fix/absorb-security-first-agent`): added the `Security-first posture` section to `AGENTS.md` (order of operations, least-context-for-subagents, no unattended authority, stop conditions, report requirements); reverted `_skill_mandatory` to `pqc-secrets|ainish-security`; retired and `git rm`'d `security-first-agent` from both `.agents/skills/` and `skills-to-distribute/skills/`; updated help (19→18 packs), indexes, `llms.txt`, `README.md`, and `test-pqc-dist.sh` (was 240/240 green).
- **`2026-11-12-hour-stamped-coordination.plan.md`** (status done, branch `fix/hour-stamped-coordination`): established the `{date}-{HH}-slug.md` (UTC, zero-padded) convention for tasks/plans/memories/suggestions, comms stays one daily `{date}-team.md`, type carried by frontmatter; updated `AGENTS.md` NN1/NN8/Close, `.agents/plans/llms.txt`, template, and both `question-me/SKILL.md` copies; fixed engine discovery so both naming schemes resolve and no glob matches nothing.

## Unfinished

- **Rules-sync-signing 5.3** — confirm non-git targets register in `targets.txt` and the summary names the fleet-sync mechanism. Deferred with 5.6: registration sits *after* the manifest gate, so it is unreachable while the signer/anchor mismatch aborts the deploy.
- **Rules-sync-signing 5.6** — rotate the trust anchor and re-sign the (corrected count) **18** tracked signature files: 14 in `.agents/audit/`, 2 in `.agents/canonical/`, `.agents/wiki/ledger.sig`, and `.scrolls*/manifest.sig*`. They do not share one key today (`.agents/canonical/AGENTS.sig` is from the local `69e7…` key, audit receipts from anchor `d984…`), so both groups must be re-signed in one pass; no bulk re-sign command exists. Deferred to its own task, deliberately not riding along with bug fixes.
- **`2026-11-11-scrolls-out-of-agents.plan.md`** (status started) — largely unfinished. The operator moved `8thfire-carrier-registry.md`, `council-key-ceremony.md`, the `.scrolls*` trees, `research/`, and the scroll-channel skill packs into `seven-fires-prophecy-prompt-research/` on the Windows box, committed to main there; this machine still shows the pre-move tree with those deletions uncommitted. Remaining: add the `wiki_dir(repo_root)` resolver and repoint its six call sites *before* moving; `git mv` the trees; update readers (`src/deploy_scrolls.sh`, `src/scroll_integrity.sh`, `src/skills_selection.sh`, `src/deploy_skills.sh`, `src/verify_skills.sh`, `llms.txt`, `.agents/llms.txt`); assert the no-scroll-under-`.agents` invariant in `scripts/test-pqc-dist.sh`; verify the `--scrolls` channel and `--skills-list`; re-sign the contract and `--machine-sync`. Stopped at step 1 (freeze the lane) pending confirmation that the other agent's distribution change landed.

## Insights

- Signing-key root cause (`rules-sync-signing`): `resolve_or_create_seed` (`src/rag/src/pqc.rs:68`) generates a random seed and writes a gitignored `.agents/audit/signer.mldsa65.priv` when no seed is in `AINISHRAG_MLDSA65_SEED` or the vault — so every machine invents its own identity. No seed exists in the vault, so the original key is unrecoverable; rotation is the only path.
- `audit verify --path <file>` was broken with `Os { code: 20, NotADirectory }` despite help text advertising single-file support.
- On this host the **Python** engine serves `ainish-rag`: `bin/ainish-rag:69` hard-codes `PY_ONLY_SUBCOMMANDS=" context secrets "`, and no native binary (`-darwin`/`-linux`/`.exe`) exists, so the compiled `src/rag` crate is never selected (`hour-stamped-coordination`).
- Filename-sorted "newest" is wrong under grandfathering: `2026-11-12-09-memory.md` sorts before `2026-11-12-memory.txt`, so the grandfather file wins as "newest" exactly on cutover day (`hour-stamped-coordination`).
- `_read_today_task_record` (`rag.py:7257`) was already dead — it looks for `{date}-task.md`, which never existed under the old `{date}-{slug}-task.md` scheme, so it always returned `""` (`hour-stamped-coordination`).
- Dropping the `.plan.md` suffix would blind three discovery sites (`rag.py:5897`, `plan_gate.sh:63`, `context-packet.sh:70`) — hence the both-schemes requirement.
- `--context` is confirmed graph-first: returns `wiki_graph_empty` unless `AINISH_RAG_VECTOR_FALLBACK=1` (`egm-context-prime`).
- A mandatory skill is progressive disclosure — an agent that never triggers it never reads it — so security posture belongs in `AGENTS.md`, not a linked pack (`absorb-security-first-agent`).
- The wiki is wired into `rag.py` as corpus, generation output, signed-ledger home, and graph-cache key — it must be repointed before it is moved, and moved with `git mv` so the signed ledger's provenance survives (`scrolls-out-of-agents`).
- Scroll-channel packs are excluded from `--rules` by name in `skills_selection.sh`; moving them out converts a standing per-enumerator obligation into a structural guarantee (`scrolls-out-of-agents`).

## Recurring

- **The signer/anchor mismatch (`69e7…` vs `d984…`) is a cross-record theme** — it is the deferred root cause in `rules-sync-signing` §7, an anchor fact explaining the pre-existing `--rules` exit 1 in `hour-stamped-coordination`, and the subject of `.agents/suggestions/2026-11-12-rules-signing-anchor-mismatch.txt`. It blocks multiple downstream tasks.
- **Verify-by-read-back and gating in `scripts/test-pqc-dist.sh`** recur across `rules-sync-signing` (8 assertions), `absorb-security-first-agent` (240/240 green plus new negative pins), and `scrolls-out-of-agents` (planned invariant assertions) — every change is expected to add a checkable pin, not just an edit.
- **Name-based/path-based classification hiding a real invariant** recurs: scroll-pack name exclusion (`scrolls-out-of-agents`) and the `.plan.md` glob that would silently match nothing (`hour-stamped-coordination`) are both cases where a discovery/exclusion rule keyed on a name quietly breaks when the name changes.
- **Deferring a root cause must stay loud** — `rules-sync-signing` deliberately splits the fixable bugs from the key rotation and requires the mismatch to be reported with both fingerprints rather than silently accepted, matching the contract's "no silent downgrade" posture.

---

## Accomplished

**Mandatory-skill consolidation** (`2026-11-12-mandatory-skill-deploy.plan.md`, status done, branch `fix/mandatory-skill-deploy`). Collapsed four drifting copies of the "mandatory skills" list into one `_skill_mandatory` predicate in `src/skills_selection.sh`, now naming three packs: `pqc-secrets`, `ainish-security`, `security-first-agent`. `_skill_channel_excluded` dropped its mandatory branch; `_skills_mandatory_names` now enumerates the source tree through the single predicate instead of a hardcoded name. `src/verify_skills.sh` delegates to `_skill_mandatory` and `sync_ainish_skills` now treats a mandatory pack as `on` regardless of the persisted selection (previously `--skills-sync` skipped packs recorded `false` while `--rules` shipped them and `--skills-verify` failed them). Corrected `src/help.sh` to 19 distributable packs (was claiming 20, listing 17, missing `security-first-agent` and `tts-cli`), with mandatory packs marked. Verification baseline `bash scripts/test-pqc-dist.sh` = 229; `AGENTS.md` deliberately left untouched (see Insights).

**Driver chain rewrite** (`2026-11-13-00-driver-chain-direct.md`, status done, branch `fix/driver-chain-direct`). `DRIVER_CHAIN` in `src/rag/rag.py` set to exactly the operator's four steps in order: (1) `local-router` / `local-router/fallback-models` at `127.0.0.1:11434`, (2) `zai` / `glm-5.3-flash`, (3) `xiaomi-mimo` / `mimo-v2.6-pro`, (4) `openrouter` / `deepseek/deepseek-v4.1-flash-1017` — last three as direct transports, not router routes. Unrequested vendors (Nous Portal, Nebius, ZenMux) dropped from the default chain. Step 1 keeps `expect_any: True`; steps 2-4 keep model verification and `reasoning: True`. Key wiring needed no change (vault names already in `DRIVER_KEY_NAMES`).

**pi agents prime** (`2026-11-14-17-pi-agents-prime.md`, status done, branch `feat/pi-agents-prime`). Made `pi` (1.5.2) the runtime for the Elephant and Goldfish reviewer roles via `--print --no-session --mode json` with `--no-tools`, real files attached as `@path` (top-6 hits, repo-relative, `cwd=repo_root`, 256KB cap), plus a bounded inline excerpt floor. Output extraction selects `agent_end` text blocks and ignores `thinking`. Fixed the measured latency defect: reviewer `max_tokens` is now `REVIEW_MAX_TOKENS` (default 2,048) covering reasoning + answer, with the section cap applied to emitted text only; `finish_reason=length` now stops the transport walk rather than retrying identically-doomed steps. (Note: the two implementing-status machine-sync plans below both target work that, per `2026-11-14-22`, had a green baseline `scripts/test-machine-sync.sh` 48 passed / 0 failed.)

## Unfinished

**`--machine-link` federation** (`2026-11-14-21-machine-link-federation.md`, status *implementing*, not done). Durable repo↔repo links (`~/.config/ainish-coder/links.txt`), post-commit/post-merge hook auto-sync (push-only, env-guarded by `AINISH_MACHINE_SYNC_ACTIVE`), `--machine-sync --all`/`--quiet`, new `src/machine_link.sh`. Stopped mid-implementation; the plan lists three blocking defects to fix first — `_ms_remote` executing `ssh ""` for local peers (exit 255), `--dry-run` dying on peers with no tracking ref (due to `set -euo pipefail` + `rev-list` against absent `refs/remotes/mac-18gb/main`), and a doc/code mismatch where `_MS_FF_PEERS=true` but `src/help.sh:141` says "Off by default."

**Branch materialization + `--latest`** (`2026-11-14-22-branch-materialization-latest.md`, status *implementing*, not done). Additive-only `--machine-sync --branches` (materialise local branches where absent, never force-move, report `diverged`), and `--machine-sync --latest [--json]` (`ainish-coder/machine-latest/v1`). Stopped before completion; the plan's open question (clarification 4.1) was resolved toward materialising local branches but the record is cut off mid-sentence, so final scope confirmation is uncertain. Peer-side mutations must use plain `git -C … branch …` over ssh because Windows runs `ainish-coder` at `1bd8865`, predating `--machine-link`.

**Vault-locked verification gap** (`2026-11-13-00` §7 Open). Steps 2-4 of the driver chain could not be exercised end-to-end because the vault is locked on this host (`_pqc_export()` returns 0 entries; `resolve_driver_key` returns None); the engine correctly skips each with "no API key resolved." Live end-to-end proof of the direct transports remains the operator's step (unlock the vault).

## Insights

- **Duplicate invariant lists drift.** The mandatory-skills logic existed in four shapes that had already diverged (`_skills_mandatory_names` printed only `pqc-secrets`). The fix was structural: one predicate, everything else delegating — not syncing copies.
- **`AGENTS.md` was deliberately not edited** in the mandatory-skill plan because editing the contract re-signs `.agents/canonical/*` and appends to `.agents/audit/contract-history.jsonl`, and the working tree carries an uncommitted audit chain two entries ahead of `HEAD`. Committing a competing chain would trade one inconsistency for a worse one; the contract row was deferred to the anchor-rotation work that re-signs everything at once.
- **Router routes vs. direct transports.** Steps 2-4 of the old chain carried `transport: "local-router"`, so a dead router upstream took down all fallbacks at once; direct transports avoid the single point of failure. `_chat_url` already handles both base shapes (no duplicate `/v1` or Z.AI's `/v4`), so the change was purely ordering/transport.
- **Token budget vs. time budget for reasoning models.** The ~42s `--context` latency was mostly reviewer calls dying at `finish_reason=length, max_tokens=672` (~15s × 3 discarded). The time budget had been raised but the token budget never was; a reasoning model spends a small budget on reasoning before emitting content.
- **Independence vs. availability.** Rotating the reviewer off the drafter's transport is correct for EGM independence but, with the vault locked, it rotates goldfish away from the only keyless working transport (`local-router`) — `chain_steps("goldfish")` starts on `zai`.
- **Windows/Mac repos can share no history.** The three `goal-first-trillion` copies (Mac `026b902`/origin root, Windows, origin) share no merge base and only 3 differing paths — hence the additive-only, refuse-on-diverge stance for branch materialization, and plain-git-over-ssh for any peer mutation (Windows CLI is older).
- **`--status` cannot answer cross-machine questions by design** ("no network, no transfer"), which is why `--latest` needs live bounded peer probes rather than cached refs.

## Recurring

- **Persisted state contradicts the source of truth, repeatedly.** Mandatory skills skipped by sync because a stale config said `false`; peer path resolution guessing `<root>/<repo-name>`; `--latest` refs stale by definition. The recurring lesson: cached/persisted state must defer to the live authoritative source, and a check must consult the real predicate, not a parallel cached list.
- **"Green baseline first" before changes.** Both the pi-agents and machine-sync plans insist on establishing the baseline gate (`test-pqc-dist.sh` 229; `test-machine-sync.sh` 48/0) before touching code — a discipline repeated across records.
- **Verify by read-back, not exit code / silent-success avoidance.** The driver plan refuses to count a vault-skip as success; the machine-link plan treats unreachable peers as reported failures; branch materialization reports `diverged` rather than silently skipping. Same fail-closed posture throughout.
- **Never destroy local/peer work.** Force-pushing peer branches, demoting unrequested vendors into the chain, and editing the contract with an uncommitted audit chain are all the same class: rejected because they trade a visible problem for a worse hidden one.
- **Version skew across machines is assumed hostile.** Both 2026-11-14 plans pin peer-side operations to plain git plumbing because the peer may run older tooling.

## Review

Review:

Faithful in substance — all five plans are covered and the specifics (SHAs, file paths, status values, the two same-checkout registry entries, the 401/403 decision-provider state) check out against the sources. A few things to flag:

Unsupported / worth qualifying:
- `2026-11-11-no-coauthor-contract.plan.md` has `status: ready`, not `done`. The draft files it under **Accomplished** and states the rule/assertions "added" and the demo commit clean. That is defensible (all todos `[x]`, gates green) but it is the digest's inference, not the plan's own status — a reader should know the plan record still says `ready`.
- Draft formatting: the draft ends with a second, empty `## Accomplished` heading and a lone `-`. That trailing duplicate/empty section should be dropped so the digest reads as four sections only.

Omissions a future agent would miss:
- plans-artifact's deliberate non-goals are gone: **no `plan-check.sh` linter** (failure modes not yet known), **no migration of historical task records** (would invent decisions), **no `--question-me` CLI verb**. The rejected-alternatives table (extend the task record, keep plans in `docs/`, free-prose with no frontmatter, PyYAML) is only glancingly touched via the "single list in §5" line. These are scope decisions, not just rationale — losing them risks someone re-proposing a rejected path.
- router-live-reload omits the *why* of the `stat` poll fallback — OS watcher preferred but poll survives **WSL and SMB/NFS mounts where inotify does not fire** — which is the whole reason the poll exists. It also drops the acceptance criteria: route change live within **one second, no restart, no dropped request**, and `ainish-rag --context` resolving the new first model immediately (`drivers:` provenance line changes without re-spawn). Those are the checkable "done" conditions.

Minor:
- The plans-artifact plan's own risk table is truncated in the source; the draft correctly notes this. Worth adding that rag-obsidian-wiki §3.3 is *also* truncated mid-line (`plus a \`warnings:\``) so a reader doesn't assume the fallback-warnings behavior is fully specified.

The trailing `local_router.failover` JSON is not part of the sources or the draft; it is correctly not incorporated, and needs no action here.
