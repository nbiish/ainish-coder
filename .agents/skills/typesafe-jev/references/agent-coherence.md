# Agent coherence with calibrated judgments

The failure this pack prevents: several agents, several sources (code index, wiki, memories,
ledger), and no shared way to decide what matters. Jev gives the agents a common, calibrated
vocabulary for "is this relevant", "is this settled", and "does this evidence support the claim",
while code keeps the decisions identical across agents and sessions.

## Context triage before retrieval

1. Run `ainish-rag orient --inject` for the wiki primer, recent memories, and unresolved ledger
   notes. This is the cheap, bounded context every agent should share.
2. Run `ainish-rag route "<request>" --json` and read three signals:
   - `needs_retrieval`: if false, do not burn context on retrieval.
   - `target_domain`: pick the first source deliberately. `codebase_symbols` → `query --code`;
     `architectural_wiki` → wiki pages and `query` without `--code`; `security_governance` →
     `AGENTS.md`, `.agents/skills/`, audit artifacts; `technical_debt` → ledger notes and TODOs.
   - `context_freshness`: high means the answer depends on the current branch or today's work, so
     run `orient` again and check `git status`/`git log` before trusting stable docs.
3. Only then retrieve. The reranker's `decision_role` tells you whether you are reading primary
   implementation, explanatory documentation, tests, or generated material.

## Compose judgments, not decisions

For any non-trivial claim, ask the parts and put the logic in your plan:

| You want to know | Ask (one per item) | Decision you own |
| :--- | :--- | :--- |
| Is this chunk enough? | answers_directly, names_query_symbols, utility | include only when direct is yes and utility ≥ 3 |
| Is my plan grounded? | one noul per assumption, state = the assumption + evidence | if any assumption is `no`, retrieve; if `unsettled`, retrieve before acting |
| Is this summary trustworthy? | `eval --context --output` | claim only if faithful; otherwise cite the gap |
| Is this a security-sensitive change? | noul "does this change touch secrets, keys, audit, or crypto policy?" | escalate to the security skill and the gate |

The band matters: a noul at 0.5 is not a "no", it is "the state did not settle it". The right
response is more evidence or a narrower question, not a coin flip.

## Multi-agent protocol

- **One retrieval owner per boundary.** An orchestrator runs route + retrieval once and injects the
  primer and results into subagents; subagents do not re-retrieve the same surface. This is the
  `ainish-rag orient --inject` contract.
- **Share probabilities, not adjectives.** Report `decision_score`, `decision_probability`,
  `decision_role`, and `source` so a peer can re-evaluate the same evidence.
- **Record durable judgments.** When a judgment changes future work (for example "the wiki page is
  stale; current branch supersedes it"), append a memory entry with the evidence path. Future
  sessions inherit it through the orient primer.
- **Never silently override a judgment.** If code or an agent ignores a `no`, say so and record
  why; the ledger is the audit trail.
- **Escalate, do not guess.** Unsuitable questions (unreadable crops, expert disputes, arithmetic,
  exact lookups) belong in code or a reasoning model, not Jev.

## When to escalate beyond Jev

Jev answers glance-level judgments. Escalate when:

- the judgment needs multi-step reasoning over many files (use a reasoning model with retrieved
  evidence);
- the answer must be exact (dates, sums, identifiers, policy lookups) — do it in code;
- the question keeps landing `unsettled` even after the state is improved — the state, not the
  threshold, is the defect;
- the decision is a policy choice (who may merge, what ships) — that belongs to the operator and
  the contract, never to a probability.

## Anti-patterns seen in agent loops

- Asking one giant question ("what should I do next?") and then narrating the answer as a plan.
- Treating `confidence` as correctness.
- Re-asking the same question with reworded text until the desired probability appears (prompt
  gymnastics); the fix is state or a narrower question.
- Using Jev to rank error logs or generated files without the role penalty, then quoting a
  vendored file as the source of truth.
- Skipping `eval` because the answer "looks right".
- Letting a failed API call become a silent `false` in a filter.
