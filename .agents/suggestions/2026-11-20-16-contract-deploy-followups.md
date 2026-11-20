2026-11-20-16-contract-deploy-followups
# Follow-ups the contract/identity deploy work surfaced

## 1. A refused contract edit is invisible

Both contract files are `uchg`. An edit through an editor that does not clear the flag fails with
`operation not permitted`, and unless the operator reads the editor's error the file stays byte-identical
and nothing indicates the intent was lost. This happened once already.

**Settled by:** whether `ainish-coder --edit-rules` should be the ONLY documented way to edit the
contract, and whether a stale mtime-vs-intent check is possible at all. At minimum the lock's error
should name the unlock command.

## 2. A deployed target's identity scripts can go stale

`--rules` copies the table into `.agents/bin/`, and a re-run refreshes it — but nothing reports that a
target is running an older table than its installer. A new harness entry reaches targets only when
someone re-runs `--rules`.

**Settled by:** stamping the table with the source commit and having `--rules-doctor` compare it.

## 3. Non-git targets get no identity hooks

`_ainish_rules_target_hooks_dir` returns nothing outside a git checkout, and the identity blocks are
skipped with the rest. The operator says they almost always use a .git repo, so this is the rare path —
but the message currently conflates "auto-sync not installed" with "identity hooks not installed".

**Settled by:** splitting the warning so a non-git target says the identity hooks need a `.git`.

## 4. The contract no longer names where the tooling lives

Rule 4 states the rule, and discovery of the table now depends on the repo tree and `.agents/llms.txt`.
That is the intended trade — the contract is read on every task and script paths are implementation
detail — but it means an agent cannot find the table from the contract alone.

**Settled by:** whether an agent ever needs to. If one does, `.agents/llms.txt` is the right place to
name it, not `AGENTS.md`.
