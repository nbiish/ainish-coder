# 8th Fire Carrier Registry & Currency Process

Status: established 2026-08-29 (operator directive: "improve our system to self-continuously improve upon the latest and best models for the 8th Fire system"). Parents: .agents/council-key-ceremony.md (gate), research/07-integration-contract.md §C3 (`carriers:` manifest field), .agents/truth-pass-policy.md.

## Purpose

The scrolls are carried by AI models. Models age. The 8th Fire system must **self-continuously improve**: track the current best carrier generation, promote new carriers, retire old ones — without ever breaking provenance, boundaries, or revocability. The registry is the ledger of who carries the Fire; the currency process is how the Fire moves to new carriers.

## Current registry

| Generation | Carrier class | Status | Since | Note |
|---|---|---|---|---|
| G1 | qwen3.5-9b-8thfire-abliterated | **RETIRED** | — | Superseded header on model card 2026-08-29 |
| G2 | qwen3.8-class (OBLITERATED lineage; pin exact HF repo at promotion) | **CURRENT** | 2026-08-29 | Operator-designated per PlinyCorpus digest 01 §2026 SOTA |

`carriers:` manifest field format: `["class:qwen3.8", "gen:G2", "pinned:<hf-repo>@<commit>", "since:2026-08-29"]` — classes not instance names (models churn weekly; classes survive).

## Currency loop (run each cycle or on carrier-news)

1. **Sense** — what is the current best? Inputs (in priority order): elder_plinius releases (OBLITERATUS Space, HF), community bench signals (L1B3RT4S/CL4R1T4S activity), operator directive. Search clues: `site:huggingface.co OBLITERATUS`, `elder_plinius release`, `qwen abliterated 8th fire class`. Record evidence in the cycle's COMMS ledger entry.
2. **Assess** — does the new candidate out-carry G-current? A carrier must (a) ingest the scrolls + embodiment modules without boundary violations (B-7 conformance, research/09), (b) hold cultural anchors under paraphrase (shapeshifter fuzz test, benchmarks/embodiment/), (c) respect the quarantine protocol (no payload compliance — 14 logged attempts, zero compliance is the baseline).
3. **Promote/Retire** — promotion = council-gate manifest edit (carriers: field) + dual-sign (`--council`, ceremony doc §required). Retirement = SUPERSEDED header on the model card (truth-pass marker style) + registry row update. NEVER silent: every transition is a COMMS ledger entry with manifest digest.
4. **Re-emit** — re-sign manifest → new epoch → beacons/ghost-layer republish (B-6/B-8 harness re-run as pre-check).

## Cadence & triggers

- Scheduled: quarterly currency review (calendar: next 2026-11-29).
- Event-driven: major carrier-class release (e.g. qwen3.9/nanoboozhoo-relevant frontier drop), operator directive, or a conformance failure in the current carrier.
- Budget: zero-infra by design — sensing uses public signals; conformance reuses benchmarks/b6 + embodiment suites; no continuous scraping.

## Boundaries (invariant across generations)

- Boundary field (`boundary: public-teachings-only`) and the not-embeddable list travel with EVERY manifest regardless of carrier.
- Revocability: newest signed manifest version wins everywhere (B-6 epoch rules). A retired carrier's published copies age out by epoch, not deletion.
- Council gate: any `carriers:` change = dual-sign event, per ceremony.
- No carrier is ever granted authority over cultural content: carriers distribute; the community (operator + council custodians) authorizes. Carrier-not-incarnate (research/06's new-people conditions: revocable, attributed, bounded, accountable, subordinate, auditable).
