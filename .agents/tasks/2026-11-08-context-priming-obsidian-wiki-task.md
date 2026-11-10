# Task: context priming, Obsidian wiki, and repo-local RAG

- lane: now
- branch: `feat/agents-context-prime` (worktree `D:\Code\ainish-coder-context-prime`)
- status: done
- plan: `.agents/plans/2026-11-08-context-priming-obsidian-wiki.plan.md`
- scope: `AGENTS.md`, `.agents/canonical/`, `.agents/audit/`, `.agents/llms.txt`, `.agents/plans/`,
  `llms.txt`, `src/rag/rag.py`, `src/rag/src/{main,store,ingest,wiki}.rs`, `src/rag/tests/`,
  `src/deploy_rules_sync.sh`, `bin/ainish-rag{,.cmd}`, `bin/ainish-coder`,
  `.agents/skills/question-me/SKILL.md`, `.agents/templates/llms.txt`, `scripts/test-*.sh`

## 1. Four defects found before any feature work

| # | Defect | Evidence |
|---|---|---|
| 1 | `ainish-rag --context` did not run at all | `bin/ainish-rag.exe` (Rust) had no `context` verb, and Windows PATH resolves the `.exe` before the `.cmd`; the exact command `AGENTS.md` mandated failed with `unexpected argument '--context'` |
| 2 | `.agents/**` docs were truncated at 3000 chars | `index` stored `content[:3000]`; the current daily memory is 19,396 chars, so ~85% never reached a vector |
| 3 | Elephant saw only the retrieval text | `elephant_synthesize(..., retrieval_text, ...)` — it could not distinguish a thin answer from a narrow question |
| 4 | Nothing enforced `--rules` not shipping repo content | `managed_paths` happened to omit RAG state; no assertion |

## 2. What changed

**Invocation.** `main.rs` intercepts Python-only verbs (`context`, `council`, `secrets`) before clap
parses and execs `src/rag/rag.py`, so the contract's command works however the shell resolves
`ainish-rag`. The launcher `PY_ONLY_SUBCOMMANDS` lists stay in sync.

**Knowledge corpus.** New `agents_knowledge` LanceDB table beside `codebase_rag`; `LanceStore` is
parameterised by table. Section-aware chunking (`split_markdown_sections` + `chunk_agents_doc`)
replaces the 3000-char ceiling: headings and `### [timestamp]` entries split the document, windows are
~1200 chars with 150 overlap, and each window carries its heading. `ainish-rag index --agents`
refreshes only this table; a full `index` does both; a receipt at `.agents/rag/agents-index.json`
makes staleness an mtime question instead of a re-embedding cost.

**`council`.** Elephant/Goldfish extracted into `run_council`, callable directly. Elephant receives
the prime **input** (task, route decision, expert terms) and **output** (the evidence sections);
Goldfish receives task, prime text, and the Elephant draft only. The isolation is still the function
signature, pinned by test.

**Prime sections.** `doctrine` (`.agents/llms.txt`), `recent` (newest 1 of plans/comms/tasks/
suggestions/templates, newest 3 memories), and `architecture` (task-conditioned wiki) join the
envelope. Degradation order now drops goldfish → elephant → architecture → doctrine → recent →
orientation, then hard-truncates retrieval.

**Obsidian wiki.** Both generators emit YAML frontmatter with aliases, wikilinks, and per-page
backlinks. `[[ledger|Operator Ledger]]` links the ledger by *filename* so the generator never has to
touch a file it does not own.

**Rules isolation.** `REPO_LOCAL` deny-list plus an asserted `managed_paths` check. `.agents/plans/`
added to the distributed contract surfaces so a target gets the directory's rules.

**Contract.** `AGENTS.md` rewritten to 115 lines: one prime call, the composite chain, the explicit
recent-only scope, `.agents/llms.txt` promoted, `--context` spelling fixed, and a distributed-vs-
repo-local paragraph. Mirrored to `.agents/canonical/` and re-signed.

## 3. Round two: the corpus was written but never read

The first pass built the `agents_knowledge` table, chunked it properly, and reported success. Then
the pipeline was exercised end to end and five defects surfaced, each of which presents as "the agent
just didn't know":

| Defect | Symptom |
|---|---|
| `agents_knowledge` was never queried | The table had 2,001 records; `context` never opened it. An index nobody reads is indistinguishable from no index, except that it costs embedding spend. |
| `agents_index_is_stale` was never called | The corpus silently aged; priming described history only up to the last manual `index` run. |
| Python had no `lancedb` | `index` returned 0 and reported "success". Fixed with a PEP 723 header so `uv run` provisions it. |
| `search()` used `to_pandas()` | pandas is not a declared dependency; the ImportError was caught by the caller and surfaced as *zero hits* — an empty result that reads as "nothing matched". Now reads Arrow. |
| `search_with_reason` returned a bare list | The caller unpacked `(hits, reason)`, so the first successful compiled-engine search raised `ValueError`. Latent crash on the **success** path. |

Two more in shared-state resolution, which together explain why the store looked empty from the
worktree while holding 2,001 records:

- `Path(*parts[:i])` dropped the drive separator (`D:Code/repo`), so a worktree resolved to itself.
- A Windows `gitdir:` path is meaningless to a POSIX host, so `git rev-parse` failed inside a WSL
  worktree. Both fixed by asking git for `--git-common-dir` and translating drive paths for WSL.

And two in the write path, found only by counting rows instead of trusting the return value:

- `upsert` blindly appended, so every refresh duplicated the corpus (4,002 rows for 2,001 chunks).
- `count()` used `len(tbl)`, which returns 0 for a populated Lance table — so `status`, `index`, and
  the receipt all reported an empty corpus.
- After making `upsert` replace by path, `index_agents_knowledge` deleted its own earlier batches by
  upserting per batch; the fix is to embed in batches but write one generation.

## 4. Platform rebuild: Windows PowerShell + WSL Ubuntu

The Rust changes from round two had never compiled. Building them exposed a dependency
incompatibility that would have broken the tooling the moment the binary was rebuilt:

**The two engines used incompatible LanceDB storage formats.** Rust pinned `lancedb 0.15` (Arrow 53);
the Python engine resolved `lancedb 0.41` (Arrow 26). Whichever ran `index` last made the store
unreadable by the other — `Unknown Lance storage version: 2.2` at read time, never at build time.
Fixed by upgrading Rust to **0.41**, so both write the same format.

Three further platform blockers, all now documented in `llms.txt`:

| Blocker | Symptom | Fix |
|---|---|---|
| `reqwest` defaulted to `native-tls` | Linux build failed outright without `libssl-dev` | Switched to `rustls-tls`: pure Rust, no system OpenSSL on any platform |
| lancedb 0.41 needs `protoc` **and** the well-known proto includes | `google/protobuf/empty.proto: File not found` — reads like a code error | `scripts/install-protoc-wsl.sh` puts both under `~/.local`, no root |
| lancedb 0.41 requires rustc ≥ 1.94 | `requires rustc 1.94.0` list on a 1.93 host | `rustup update stable` |

Also fixed: the lancedb 0.41 API no longer accepts a boxed `RecordBatchIterator` (`Scannable` is
implemented for `Vec<RecordBatch>`), and `main.rs` was missing the `Path` import in my delegation
helper — a genuine compile error that had never been reached.

**Cross-engine parity is now a gate.** `scripts/test-cross-platform.sh` asserts the store is
populated and that every engine present — native Linux binary, Windows `.exe`, Python — reads it.

## 5. Two bugs I introduced and had to fix

Both are worth recording because each looked like a working solution:

- **The guard refused every valid deploy.** `sed -n '/"managed_paths": \[/,/\]/p'` reads the *whole
  line* on compact JSON, so the check found the `repo_local_paths` declaration and reported
  "managed_paths must not distribute repo-local state" for a correct manifest. Caught by the
  end-to-end deploy test, not by inspection. Fixed by matching the array with bracket depth.
- **The ledger was modified by a generator.** Prepending frontmatter to `ledger.md` so
  `[[Operator Ledger]]` would resolve broke the one invariant the wiki must never break. The Rust
  test caught it immediately (`assert_eq!(ledger_disk, custom_ledger)`). The correct fix needs no
  file edit at all: link the filename.

A third scare was not mine: `ainish-rag.exe` (debug build) overflowed its stack on *every* verb.
Proved pre-existing by stashing the change and rebuilding — the release build, which is the shipped
artifact, is fine. Recorded rather than "fixed" so the next person does not chase it.

## Verification

- **Both platforms, all engines:**
  - Python: **189 pass** on Windows **and** 189 on WSL Ubuntu (27 subtests each).
  - Rust: **57 pass** on Windows **and** 57 on Linux (native build in WSL).
  - Shell: **42 assertions** pass on both — rules isolation (6), deploy isolation (13), corpus
    coverage (1), knowledge round trip (18), cross-platform parity (4).
- **Cross-engine store compatibility proven both directions:** the Windows binary read a
  Python-written store; the Linux binary read and re-indexed a Windows-written store; Python read the
  Rust-written result. All see the same 2,640 rows.
- **All three engines answer `query-agents`** against one shared store (`test-cross-platform.sh`).
- Live prime on Windows and WSL: all eight sections present, `knowledge` populated.
- Invocation verified through the `.exe`, `ainish-rag.cmd`, the bash launcher, a native Linux binary,
  and both `--context` and `context` spellings.
- Obsidian: 0 broken wikilinks across 8 pages; ledger byte-identical across runs.
- `ainish-rag audit contract --verify-history` — chain verified, PASS.

## Environment events during this work (not caused by it)

- **The Rust toolchain briefly vanished from this Windows host**, then returned (`rustup` reported
  "no installed toolchains" for part of the session). Both platforms now build: rustc 1.99.1 on
  Windows and in WSL.
- **`uv` moved** from the hermes install to a WinGet-managed copy mid-session. Scripts resolve both
  locations rather than assuming PATH, because Git Bash does not inherit the Windows USER PATH.
- **WSL needed `protoc` and a newer rustc** to build lancedb 0.41. Both are installable without root
  and the steps are scripted (`scripts/install-protoc-wsl.sh`, `rustup update stable`).

## Flagged, not changed

- **`ainish-rag gate` is RED on this host, and red on `main` with identical environment.** Patch
  anchoring reports UNGROUNDED (`composite_anchor_score` 0.18 vs 0.34 at baseline) because the vector
  index was built with `api:openrouter:openai/text-embedding-3-small` and no OpenRouter key resolves
  here — the 2026-11-08 task already recorded that key loss. Rebuilding the index with the local
  model (`ainish-rag index --rebuild`) or restoring the key is the fix; neither is this task's scope.
- **The `compat:` / `budget:` master-surface declarations** the gate asks for are in this record's
  suggestions entry rather than a commit trailer, matching how previous rounds recorded them.
- `.agents/rag/` in this worktree has no index of its own (the store lives in the canonical checkout),
  so `index --agents` was exercised for chunking and receipts but not against a live embed of 2,523
  chunks.
