---
format: ainish/context-digest/v1
folder: memories
period: 2026-11
records_consolidated: 3
consolidated_at: 2026-11-20T22:16:03.187375+00:00
sources:
  - 2026-11-08-memory.txt
  - 2026-11-11-memory.txt
  - 2026-11-12-memory.txt
---

# Digest — `.agents/memories`, 2026-11

This digest replaces 3 record(s) from 2026-11. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Accomplished

**Coordination record split (`2026-11-08-memory.txt`)** — `.agents/tasks/` was carrying two lifetimes (cheap orient-time coordination state: lane, branch, status, scope; and deep once-read design intent). Split so the plan owns reasoning plus checkbox progress and the task owns coordination with a single `plan:` line; neither restates the other, and §5 todos are the only todo list. Rule: a duplicated list drifts the moment either side is edited.

**PQC dist gate work (`2026-11-08-memory.txt`)** — `scripts/test-pqc-dist.sh` measured at 144 passing before, 150 after, with zero new failures. A two-line `/tmp/uvshim/uv` shim (`exec /mnt/c/.../uv.exe "$@"`) let the gate actually run on WSL instead of being skipped. Added an "every `.agents` child index entry exists" assertion, fixed from a `sed` range to an `awk` range plus a non-trivial-entry-count check.

**Skill payload/target split (`2026-11-11-memory.txt`)** — distributor and consumer now use different directories: source `skills-to-distribute/skills/`, target the consumer's `.agents/skills/`, with `AINISH_SKILLS_[SOURCE|TARGET]_REL` in `src/paths.sh` as the only definition. `_PQC_ENGINE_REL` (which meant both "engine in this checkout" and "vendored engine in a target") was split into side-named constants with a legacy fallback.

**Obsidian vault / RAG contract (`2026-11-11-memory.txt`, `2026-11-12-memory.txt`)** — reader changed before writer: `build_wiki_graph` taught to read `[[wikilinks]]` (previously `(path.md)` only), with a skip list for navigation-only headings and stripping of fenced blocks and inline code so `[[syntax]]` in backticks creates no dangling edge. `ainish-rag wiki` now signs only when the existing envelope no longer verifies (it had been re-signing `ledger.sig` with identical ledger sha256). `generate_wiki` now REFUSES when it detects `ainish/wiki`-tagged pages, after the Python path was found replacing a real vault with plain markdown — frontmatter, aliases, tags, all wikilinks gone, reporting success. Vault pages derive the project name from `origin`/canonical root so worktrees stop rewriting titles. Vault generation is done with the native binary `src/rag/target/release/ainish-rag wiki`.

**Mandatory skill packs unified (`2026-11-12-memory.txt`)** — one predicate, `_skill_mandatory` in `src/skills_selection.sh`, now asked by deploy, sync, verify, selector list, both toggle UIs, and the report. The redundant `_skill_channel_excluded` list was removed, `_skills_mandatory_names` was found stale (one name vs the predicate's two), and `--skills-sync` was made to stop honouring a stale recorded `off`.

**Naming scheme and resolver (`2026-11-12-memory.txt`)** — coordination records carry a zero-padded UTC hour (`{date}-{HH}-{slug}.md`; memory adds `-memory`); comms stays one ledger per UTC day as `{date}-team.md`; pre-2026-11-12 names are grandfathered and every reader accepts both. One shared mtime-based resolver in `src/rag/rag.py` (`_coordination_files` plus `_memory_files`/`_task_files`/`_plan_files`/`_comms_files`) mirrored in the Rust crate.

**Contract change (`2026-11-12-memory.txt`)** — `security-first-agent` pack retired; its posture became the "Security-first posture" section of universal AGENTS.md, with the contract line gate raised 120 → 160 by operator decision. Mandatory set is pqc-secrets + ainish-security again; payload is 18 packs. AGENTS.md now points at `.agents/suggestions/{date}-{slug}.txt` for findings that outlive a task.

**Gates proven in both directions (`2026-11-11`, `2026-11-12-memory.txt`)** — `--plan-check` refused without a plan, allowed with a ready one, rejected a wrong branch, left main ungated, and its bypass announced itself rather than passing silently. `wiki --index` clap flag fixed via `action = clap::ArgAction::Set`.

**Vector subsystem deleted (`2026-11-12-memory.txt`)** — `embed.rs`/`store.rs`/`ingest.rs`, the lancedb/arrow crates, `EmbedClient`/`LanceStore`, and the `serve`/`stop`/`index`/`query`/`rerank`/`bench`/`monitor`/`embed-provider`/`service` verbs are gone from both engines; retired verbs still parse, print their replacement, exit 1. `AINISH_RAG_VECTOR_FALLBACK` no longer exists.

## Unfinished

- **Signer / trust-anchor mismatch (`2026-11-12-memory.txt`)** — local ML-DSA-65 signer `69e7233d…` does not match committed anchor `d98405ea…`, so `--rules` exits 1 after deploying and `.agents/canonical/*` lags the working contract until the anchor rotation re-signs. Recorded in `suggestions/2026-11-12-rules-signing-anchor-mismatch.txt`. Stopped on the anchor rotation, which is the operator's to perform.
- **Seven clap bool flags (`2026-11-12-memory.txt`)** — `#[arg(long, default_value_t = true)]` on a clap 4 `bool` yields a flag that can only ever be true (no `--no-x`, `--x false` rejected). Only `wiki --index` was fixed; seven remain in `src/rag/src/main.rs`.
- **Last insight truncated mid-sentence (`2026-11-12-memory.txt`)** — "Compare models with `driver_model_matches`/`_same_model`, never strings: `zai-g…" ends there in the source; the rationale beyond that is not recoverable from these records.

## Insights

- **WSL is the default `bash`, not Git Bash** (`2026-11-08-memory.txt`). `C:\Users\...` and Windows PATH entries do not apply; `uv.exe` resolves only as `/mnt/c/.../uv.exe` and `/bin/sh` needs the suffix. Assume no Git Bash semantics on this host.
- **14 failures need a baseline before attribution** (`2026-11-08-memory.txt`). The same 14 appear at the pre-change commit in a detached worktree: no `uv` on the WSL PATH, no usable signer for those subcommands. The meaningful number is the delta.
- **A gate that asserts a literal breaks on the correct edit** (`2026-11-08-memory.txt`). `test-pqc-dist.sh` pins the deploy loop as an exact string (`for _tpl in llms.txt templates/masters.md ...`); adding files means string and loop move together. Search for the literal before editing the loop.
- **A check over parsed output can pass vacuously** (`2026-11-08`, `2026-11-11-memory.txt` — same lesson twice). `sed -n '/^## Child DOX index/,/^$/p'` stopped at the first blank line immediately after the heading, so the loop never ran. BSD sed also lacks `\|` alternation, so `s/x\(a\|b\)y/` matches nothing on macOS — use `sed -E`. Any parse-then-iterate needs a companion assertion that the parse found something, and a gate must be shown to FAIL when it should before a pass count means anything.
- **`bin/ainish-rag` is the Python engine on this host** (`2026-11-12-memory.txt`). The launcher forces `context`/`secrets` to `rag.py`; no `bin/ainish-rag-{darwin,linux}`/`.exe` exists, so `src/rag/target/release/ainish-rag` never answers a request. Change `rag.py` for behaviour and mirror the crate so a native build does not regress — scoping engine work to Rust alone scopes the wrong file. Corollary: the vault renderer lives only in `src/rag/src/wiki.rs`, which is why the Python path used to destroy vaults.
- **"Newest wins" means newest by mtime** (`2026-11-12-memory.txt`). Under mixed naming `{date}-09-memory.md` sorts before `{date}-memory.txt`, so a name-sorted pick returns the grandfathered file on exactly the cutover days that matter. Do not reintroduce a local glob with `[-1]` or `.last()`.
- **Dropping a filename suffix makes every filter match nothing, which reads as "no plan of record" rather than an error** (`2026-11-12-memory.txt`). `*.plan.md` globs in `plan_gate.sh`, `rag.py`, and `context-packet.sh` would have blocked every new-scheme branch.
- **Distribution verbs must agree** (`2026-11-12-memory.txt`). `--rules` shipped mandatory packs, `--skills-verify` failed them when absent, `--skills-sync` skipped them. A hidden list drifts silently; derive sets by enumerating the source through the predicate.
- **Refreshing the contract via the deploy path has side effects** (`2026-11-12-memory.txt`). It re-signs `.agents/canonical/*` and appends to `.agents/audit/contract-history.jsonl` with the local (non-anchor) signer, adding artifacts the anchor rotation must re-sign. A FAILED `ainish-rag wiki` still rewrites generated pages with stripped frontmatter. Revert `.agents/{canonical,wiki,audit}` after either; `.agents/canonical/AGENTS.md` is `uchg`-locked, so `chflags nouchg` before restoring.
- **`.gitignore` lives in `.agents/comms/`** and must match `*.live.{txt,md}`, not `*-team.live.*` (`2026-11-12-memory.txt`) — other boards use the convention with a different prefix, and the narrow form let `2026-11-12-identity-guard.live.txt` be committed.
- **Vault write/read are one contract** (`2026-11-11-memory.txt`). Emitting `[[wikilinks]]` without teaching the reader would have deleted every explicit edge while the vault looked *better* in Obsidian. Every `## ` heading becomes a retrieval node, so a `## Related` block competes with what it links to.
- **A signed artifact that re-signs unchanged content is not evidence** (`2026-11-11-memory.txt`).
- **Decision transport and chat transport fail independently** (`2026-11-11-memory.txt`). Chat failed over to a backup model while both decision-capable models returned 401/403; probe each path separately.
- **Reviewer independence is a precondition, not a report** (`2026-11-12-memory.txt`). Google's Elephant-Goldfish Model is the design source for `--context`: Elephant holds session context, Goldfish is a fresh reader with no route to it, and EGM stops the review when no fresh reviewer can be created. No distinct model means refusal with `provenance.reviewer_isolation: unavailable`; `--allow-self-review` is the recorded downgrade.
- **A path constant that resolves "the same file" in two contexts is a latent bug** (`2026-11-11-memory.txt`). Name the side (`_SOURCE`/`_TARGET`) and keep a legacy fallback.
- **Retrieval is graph-only** (`2026-11-12-memory.txt`). `graph_retrieve` returned `wiki_graph_empty` absent a fallback env var; the embedding model is retired, not optional, and the fallback no longer exists.

## Recurring

1. **Checks that pass without verifying.** The `sed` range that matched nothing (`2026-11-08`), the BSD `sed` `\|` alternation matching nothing (`2026-11-11`), the hidden `_skills_mandatory_names` list drifting from its predicate (`2026-11-12`), suffix globs matching nothing and reading as "no plan" (`2026-11-12`), and the always-true clap flags (`2026-11-12`). The stated remedy is consistent: prove the gate fails when it should, and assert the parse found something.
2. **One source of truth vs a restated copy.** Task/plan lifetimes (`2026-11-08`), `_skill_channel_excluded` vs `_skill_mandatory` (`2026-11-12`), `_skills_mandatory_names` vs the predicate (`2026-11-12`), `_PQC_ENGINE_REL` standing for two files (`2026-11-11`). Derive, don't duplicate.
3. **Native vs Python engines diverging.** `rag.py` is what answers here while the Rust crate holds behaviour (vault rendering, resolver, `rag.py` changes needing a crate mirror), across both `2026-11-11` and `2026-11-12`.
4. **Environment assumptions that silently change results.** No `uv` on WSL PATH, no usable signer, WSL bash vs Git Bash (`2026-11-08`); the local signer not matching the committed anchor (`2026-11-12`). Both times the failure looked like a code failure and was an environment one.
5. **Reader-before-writer ordering.** Vault links and the signing envelope (`2026-11-11`), mandatory-pack predicate before the surfaces that consume it (`2026-11-12`).

## Review

The digest does not summarize the sources provided. This is the dominant problem and it makes the rest moot, but specifically:

Fatal mismatch. The five sources are dated 2026-11-01, 11-04, 11-05, 11-06, 11-07. Every citation in the digest points at 2026-11-08, 2026-11-11, or 2026-11-12 — files that are not among the sources. Not one claim in the draft is supported by the records I was given. It reads as a digest of a different, later period.

What the sources actually contain, all omitted:
- Master surfaces: `src/rag/master-surfaces.json`, the `master_surfaces` gate carrying `compat:`/`budget:` text, `context_budget_tokens` (0/1200/2000/2600/3600) + `next_action`, `orient --inject` capping at `budget/12/sections` (2026-11-01).
- The `bin/ainish-rag.exe` PID-lock gotcha (2026-11-01).
- context-orchestration skill split, `context-packet.sh --mode goldfish`, `egm-check.sh` fail-closed (2026-11-04).
- SIGTTIN root cause: WSL→`ainish-rag.exe` via `/init` reads inherited stdin, state `T`, kills the timeout watchdog; fix is `stdin=DEVNULL` detachment (2026-11-05).
- `--pqc-install` fresh-install false negative (keygen makes only the keypair; bundle appears at first pack) (2026-11-05).
- rag-as-operator-utility reversal, twice (2026-11-05, 2026-11-07).
- Signer preflight before writes; signature deliberately NOT made optional (2026-11-06).
- Saturated benchmark; nDCG>1.0 (observed 2.131) needs a range assertion; launcher path-vs-name check (2026-11-06).
- WSL exe UTF-8-vs-UTF-16-LE mojibake; `HOME=` is not isolation on Windows (2026-11-06).
- Embedding identity = model not provider: cosine 1.000000 across providers, 0.0066 across sizes; index can't detect a foreign vector; server width guard inert without `dimensions` (2026-11-06).
- Router 200 proves nothing; compare `response.model`; `deepseek-v4.1-flash` reasoning tokens vs empty content (2026-11-07).
- Goldfish isolation as a signature not a comment; stray deleted `elif` appending `GATE:` to `--json`; budget ladder needs a final hard truncation (2026-11-07).
- Elephant/Goldfish split is an unmeasured hypothesis (2026-11-07).
- Fallback order belongs to its consumer; `expect_any` step 1; suffix-based id matching; floor step must survive the filter (2026-11-07).
- Unattributed human edit to AGENTS.md must be kept, not stripped (2026-11-07).
- Hidden-from-prompt vs mandatory: two predicates + one shared list; mandatory pack must MIRROR not merge; bypass the no-overwrite flag at the copy layer (2026-11-07).

Overlapping theme, still uncited: the digest's "Distribution verbs must agree" and "Mandatory skill packs unified" restate the 2026-11-07 lesson (a pack mandatory in one place, optional in another) but attribute it to 11-12 files and drop the source's specific mechanisms (mirror-not-merge, copy-layer flag bypass).

Also: the draft is truncated mid-sentence ("...with the local (non-anchor) signer, adding").

The trailing `local_router.failover` JSON is not part of the sources and bears on nothing here; I treated it as data and ignored it.

Bottom line: this digest cannot replace the five source files — it summarizes records that were never provided and omits everything that was. It needs to be redone against the actual 2026-11-01/04/05/06/07 sources.
