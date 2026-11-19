Ownership
## Ownership

- `canonical/` owns the source contract deployed as root `AGENTS.md`.
- `skills/` holds the small curated set of packs THIS repo's agents read. The packs this tool
  *distributes* live in [`skills-to-distribute/skills/`](../skills-to-distribute/skills/) — a
  separate tree on purpose: agent harnesses auto-discover `**/.agents/skills`, so anything kept
  here is standing prompt surface for every agent working in this repository.
- `wiki/` owns generated architecture and operator notes; `ledger.md` is append-only.
- `comms/`, `tasks/`, `suggestions/`, and `memories/` own coordination and durable knowledge. Comms/tasks are system-of-record; memory is context only.
- `plans/` owns the per-task plan of record: the problem, anchor facts, design, clarification ledger, and derived todos an agent follows while implementing. Distinct from `docs/` (forward-looking proposals) and from `tasks/` (coordination state).
- `audit/` owns receipts, signatures, manifests, and privacy evidence. Do not hand-edit signed artifacts.
- `rag/` owns local retrieval/index state and drift telemetry.