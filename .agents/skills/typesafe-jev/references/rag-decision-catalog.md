# ainish-rag decision catalog

Every judgment the engine asks Jev, with the code decision that consumes it. Anchors are to the
current tree; when you change a question, change this file in the same commit and re-probe live.

Implementation anchors:

- Rust client, builders, parser: `src/rag/src/decision.rs`
- Python parity: `src/rag/rag.py` (`DecisionEngine`)
- Command surfaces: `src/rag/src/main.rs` (`route`, `rerank`, `decide`, `eval`, `secrets`)
- Retrieval blend: `store.rs` (`search_vector`) → `decision.rs` (`rerank`)

Shared policy: noul bands **≥ 0.70 yes / ≤ 0.30 no / between unsettled**; decisions in code, never
in the question.

## route — `ainish-rag route "<request>"`

Asked together in one request; state is the request text.

| id | type | question | criteria |
| :--- | :--- | :--- | :--- |
| `needs_retrieval` | noul | Does answering this request require retrieving this repository's code, architecture wiki, or coordination context instead of relying on general knowledge? | true — the answer depends on files, symbols, documentation, or task history in this repository; false — the request is self-contained or answerable from general knowledge |
| `domain_target` | choice | Which part of this repository's context would best answer the request? | `codebase_symbols` source/symbols/APIs · `architectural_wiki` architecture/data flow/design · `security_governance` policy/PQC/secrets/audit · `technical_debt` gaps/TODOs/drift · `general_knowledge` language/tooling |
| `context_freshness` | noul | Does the request concern recent changes, the current branch, or today's work rather than long-lived architecture? | true — recent edits, uncommitted work, current branch, today's activity; false — stable architecture or long-lived behaviour |

Code decision:

- `needs_retrieval = retrieval_probability >= 0.5`.
- `target_domain` and `route_confidence` are reported, not acted on blindly.
- `context_freshness` drives source choice: high → `ainish-rag orient --inject` + index; low → wiki
  and stable docs first.
- Fallback: `route_local` keyword/calibration; `source: local-calibrated`.

Output (JSON): `needs_retrieval`, `retrieval_probability`, `target_domain`, `route_confidence`,
`context_freshness`, `source`.

## rerank — `ainish-rag query` / `rerank`

One request, up to 12 candidates. State carries the query and the task; each question carries that
candidate's own excerpt (questions cannot see each other).

| id pattern | type | question | criteria |
| :--- | :--- | :--- | :--- |
| `answers_directly_{i}` | noul | Does this excerpt provide the specific fact, symbol, or implementation the query needs? | true — states the definition/behaviour/symbol asked for; false — topically related or answers a different question |
| `names_query_symbols_{i}` | noul | Does this excerpt contain any symbol, file, or API named in the query? | true — at least one named symbol/API appears; false — none appear |
| `utility_{i}` | score 5 | How useful is this excerpt for answering the query? | unrelated → tangential background → related but incomplete → directly useful evidence → canonical implementation/reference |
| `chunk_role_{i}` | choice | What kind of artefact is this excerpt from? | `implementation`, `documentation`, `test`, `generated` |

Code decision:

```
decision = 0.45*direct + 0.25*symbol_support + 0.30*(utility/4)
penalty  = 0.08 if role == "generated" else 0.03 if role == "test" else 0
combined = max(0, decision - penalty)*0.70 + vector_score*0.30
keep     = combined >= --min-relevance
```

- `direct >= 0.5` sets `decision_relevance`.
- Sorting is by `combined`; `decision_score` is the pre-vector decision value.
- `rationale` records direct band, symbol support, utility, role, and vector score so an agent can
  explain why a chunk was chosen.
- `generated` and `test` are discounted so vendored/generated material cannot crowd out primary
  sources on high vector similarity.
- Fallback: RRF hybrid fusion in `rerank_local` (`source: local-calibrated-rrf`).

Output fields added per hit: `decision_score`, `decision_relevance`, `decision_probability`
(direct noul), `decision_utility`, `decision_role`, `rerank_source`, `rationale`.

## eval — `ainish-rag eval --context … --output …`

| id | type | question | criteria |
| :--- | :--- | :--- | :--- |
| `is_faithful` | noul | Is the output grounded in the provided context, without claims the context does not support? | true — every claim is supported; false — adds claims or specifics the context does not contain |
| `faithfulness_score` | score 5 | How completely does the output stay within the provided context? | contradicts → mostly unsupported → partly grounded → grounded with minor gaps → fully grounded |

Code decision:

```
faithfulness = 0.6*noul + 0.4*(score/4)
is_faithful  = noul >= 0.5 and score/4 >= 0.4
risk         = 1 - faithfulness
```

Fallback: lexical grounding heuristic (`evaluation_source: local-heuristic`).

## decide — arbitrary typed batches

`ainish-rag decide "<state>" --questions '<json>'` sends any noul/choice/score batch using the same
builders and returns:

```json
{
  "state": "...",
  "model": "typesafe/jev-1.14-20261014",
  "source": "openrouter:typesafe/jev-1.14-20261014",
  "answers": [ { "id": "...", "type": "noul", "noul": 0.93, "choice": null, "score": null } ],
  "usage": { "input_tokens": 0, "output_tokens": 0, "cost": 0 }
}
```

Use it for plan assumptions, risk triage, and any judgment that does not warrant a new engine
surface. `--question` is a shortcut for a single noul with generic criteria; prefer `--questions`
with explicit criteria when precision matters.

## Thresholds and weights

| Constant | Value | Where |
| :--- | :--- | :--- |
| noul yes / no bands | 0.70 / 0.30 | `JEV_NOUL_YES` / `JEV_NOUL_NO` |
| rerank blend | decision 70% / vector 30% | `rerank_via_jev` |
| decision mix | 45% direct / 25% symbols / 30% utility | `rerank_via_jev` |
| role penalty | generated 0.08, test 0.03 | `rerank_via_jev` |
| faithfulness mix | 60% noul / 40% score | `evaluate_faithfulness` |
| candidate cap | 12 per request | `rerank_via_jev` |
| request timeout | 8 s (`AINISH_RAG_TIMEOUT`) | `DecisionEngine::new` |

Changing any of these is a behaviour change: probe on cases you did not tune on, update this
catalog, and keep the fallback intact.

## Degradation policy

- No key or unreachable API → `source` names the local fallback; the command still answers.
- API error (400/401/5xx) during rerank → that rerank falls back locally; the command continues.
- API error during `decide --questions` → the command exits with an error (no invented answer).
- Never treat a transport failure as a negative judgment.
