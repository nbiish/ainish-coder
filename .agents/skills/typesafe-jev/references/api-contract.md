# TypeSafe Jev — live API contract

Source of truth: OpenRouter's Decisions API, exercised and verified against the live service on
2026-10-30. Re-verify with `scripts/jev_probe.py` when models or fields change.

## Endpoint and authentication

```
POST https://openrouter.ai/api/alpha/decisions
Authorization: Bearer <OPENROUTER KEY>
Content-Type: application/json
HTTP-Referer: https://github.com/nbiish/ainish-coder
X-Title: ainish-rag-decisions
```

The key is resolved in memory only, in this order:

1. environment — `OPENROUTER_API_KEY`, `ROUTER_API_KEY`, `OPENROUTER_EMBED_API_KEY`,
   `LOCALROUTER_OPENROUTER_API_KEY`, `LOCALROUTER_OPENROUTER_EMBED_API_KEY`,
   `AINISHCODER_OPENROUTER_API_KEY`;
2. the PQC store through `pqc-secrets export --json` (the store commonly holds the
   consumer-prefixed `LOCALROUTER_OPENROUTER_API_KEY`);
3. otherwise the calibrated local fallback.

Never write the key to disk, argv, logs, or a task record. `ainish-rag secrets` reports resolution
status without the value.

## Models

| Model id | Status |
| :--- | :--- |
| `typesafe/jev-1.14` | latest decision model; responses report `typesafe/jev-1.14-20261014` |
| `typesafe/jev-1.13` | previous decision model; automatic fallback |
| `typesafe/jev-router` | chat router model, **not** accepted by the Decisions API |

Override with `JEV_DECISION_MODEL`. When OpenRouter answers `Model ... does not exist`, the engine
retries the next known decision model instead of failing the command.

## Request body

```json
{
  "model": "typesafe/jev-1.14",
  "state": "file src/rag/src/provider.rs resolves embedding credentials...",
  "questions": {
    "needs_retrieval": {
      "type": "noul",
      "instructions": "Does answering this require repository context?",
      "criteria": {
        "true": "the answer depends on files or history in this repository",
        "false": "the request is answerable from general knowledge"
      }
    },
    "component": {
      "type": "choice",
      "instructions": "Which component does this state describe?",
      "options": ["provider_resolver", "http_server"],
      "criteria": {
        "provider_resolver": "resolves keys from env or the PQC store",
        "http_server": "binds a port and serves HTTP"
      }
    },
    "utility": {
      "type": "score",
      "instructions": "How directly does this state answer the question?",
      "levels": [1, 2, 3, 4, 5],
      "criteria": [
        "no relevant fact",
        "mentions the topic only",
        "partial evidence",
        "names the exact resolver",
        "a complete, quotable answer"
      ]
    }
  }
}
```

Rules that the service enforces:

- `questions` is an object keyed by id; ids are echoed back and are **not** sent to the model.
- `criteria` is mandatory for `noul`, `choice`, and `score`. A missing `criteria` returns
  `400 invalid_type` and no answers.
- `choice.criteria` is an **object** keyed by option name; `score.criteria` is an **array** with
  one entry per level; `noul.criteria` is an object with `true` and `false`.
- `score.levels` is `[1..n]`; the answer is continuous in `[0, n-1]`.
- Questions are answered independently and in parallel; they cannot see one another or each
  other's answers. Context needed by one question belongs in its `instructions`.

## Response body

```json
{
  "model": "typesafe/jev-1.14-20261014",
  "answers": {
    "needs_retrieval": { "type": "noul", "noul": 0.95 },
    "component": {
      "type": "choice",
      "choice": "provider_resolver",
      "probabilities": { "provider_resolver": 1, "http_server": 0 },
      "confidence": 1
    },
    "utility": {
      "type": "score",
      "score": 3.61,
      "legend": { "0": "no relevant fact", "1": "mentions the topic only" },
      "probabilities": { "0": 0, "1": 0.01, "2": 0.02, "3": 0.33, "4": 0.64 },
      "confidence": 0.67
    }
  },
  "usage": { "input_tokens": 484, "output_tokens": 76, "cost": 0 },
  "id": "gen-dec-...",
  "provider": "TypeSafe"
}
```

- `answers` is the container. Older integrations that read `decisions` or `value`/`probability`
  are parsing a shape this endpoint no longer returns; `decision.rs` and `rag.py` accept both, but
  new code must target `answers`.
- `noul` is a probability, not a boolean. Apply bands in code (≥ 0.70 yes, ≤ 0.30 no, between
  unsettled).
- `confidence` is distribution concentration, not correctness.
- `usage.cost` is returned per call; decisions are inexpensive but not free — batch questions per
  state rather than calling once per question.

## Error semantics

| Status | Meaning | Handling |
| :--- | :--- | :--- |
| `400` with `expected record ... criteria` | contract violation in the request | fix the question builder; do not retry |
| `400` with `Model ... does not exist` | retired or wrong model id | retry the next known decision model |
| `401`/`403` | key invalid or unauthorized | surface the error and keep the local fallback; do not silently downgrade |
| `429` | rate limited | back off and retry once; rerank batches should degrade to local |
| `5xx` | upstream failure | treat as an error, not as an answer |

A transport failure must never be interpreted as `false`, `no`, or "not relevant" in code.

## Minimal curl probe

```bash
# Key stays in the environment; never inline it in a recorded command.
export OPENROUTER_API_KEY="$(pqc-secrets export --json \
  | python -c 'import json,sys;print(json.load(sys.stdin)["secrets"].get("LOCALROUTER_OPENROUTER_API_KEY",""))')"

curl -sS https://openrouter.ai/api/alpha/decisions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"typesafe/jev-1.14","state":"file src/rag/src/store.rs uses lancedb",
       "questions":{"q":{"type":"noul","instructions":"Does this file use a vector database?",
       "criteria":{"true":"it connects to LanceDB","false":"it does not touch a vector store"}}}}'
```

The dependency-free equivalent is `scripts/jev_probe.py`.
