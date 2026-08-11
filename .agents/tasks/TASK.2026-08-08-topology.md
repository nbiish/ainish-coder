# TASK.2026-08-08-topology — Branch topology reconciliation

Worktree: ../ainish-topology
Branch: chore/branch-topology-reconcile
Base: main @ 1b3f995
Date: 2026-08-08

## CoD

Audit three branches. dev merge-base main = dev tip.
All 25 dev commits reachable from main. 0 missing.
dev redundant. develop fresher (origin/dev sync).
main 15 ahead origin/main (release merge pending push).

####

## Decision

dev deletable. Verified: merge-base main dev = e69bed0 (dev tip).
develop and main both supersede it.
Push outstanding: ask user (remote decision, not local).
Execute dev delete only after push lands (safety ordering).
