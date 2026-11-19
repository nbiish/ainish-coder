2026-11-19-15-context-agent-followups
# Follow-ups the context-agent correctness work surfaced

Not fixed here because each is either a separate subsystem or needs a decision this task did not
have authority over. Each is stated with what would settle it.

## 1. The compiled renderer is stale and demands a deleted model

`src/rag/target/release/ainish-rag wiki` exits 1 with
`EmbeddingGemma GGUF model not found in <hf-cache-root>`. The binary
predates the 2026-11-12 retirement, so the native vault path is unusable on this host even though
`native_renderer()` now discovers it correctly. `--refresh-wiki` therefore falls back to the Python
generator, which now emits vault format and is safe on any unsigned vault, but cannot splice the
signed `ledger.md` (it refuses, correctly).

**Settled by:** rebuilding the Rust crate (`cargo build --release` in `src/rag`) after removing the
embedding-model requirement from the `wiki` verb. Until then, `AINISH_VAULT_RENDERER` can point at a
known-good build.

## 2. The improver's proposals are narrow and repetitive

Three consecutive learner runs proposed variations of `recency_floor` and a small `domain_prior` list,
and several proposed narrowing `max_wiki_pages` before the evidence explained that 0 means all. The
model is doing what the evidence affords — twelve hits and a graph dump — not what the system needs.

**Settled by:** giving the improver the `EXPERIENCE.md` history and the last N rejections in its
evidence, so it can see what has already been tried and refused. That is a real design change and
belongs in its own plan.

## 3. `skip_retrieval` is still reachable for tasks that do need the corpus

A task naming a layer now forces retrieval, but a task that *describes* work without naming a layer
("why is the merge flaky") can still be routed to `skip_retrieval`. That is the router working as
designed, and orientation still carries the rules — but it is the remaining gap in "one command
answers everything".

**Settled by:** measuring how often a skip-routed prime was followed by the agent reading files the
corpus already held. That number is not currently collected.

## 4. `--rules` seeding requires the target to be a git repository

`bin/ainish-coder:316` guards seeding on `-d "${target_dir}/.git"`, so a non-git target still gets no
generation 0. The guard exists because the outcome signal needs commit history, which is true — but
a repo initialized later would then have no frozen baseline either.

**Settled by:** deciding whether a non-git target should get an uncalibrated generation 0, or an
explicit "seed after `git init`" instruction. Both are honest; the current silent skip is the worst
of the three.

## 5. Historical task records name merge shas that do not exist

Four records reference shas absent from history. They are not wrong so much as orphaned: the history
was rebased across machines. This is why corroboration is now reported rather than required.

**Settled by:** nothing this task can do — the commits are gone. Worth knowing before anyone treats a
recorded sha as evidence.
