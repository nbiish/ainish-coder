# Task: integrate the wtf task lane, and sweep stale references

- lane: now
- branch: `chore/wtf-integration-and-stale-refs` (worktree `D:\Code\ac-wtf-integrate`)
- status: done
- scope: `.agents/skills/wtf-is-going-on-mcp/SKILL.md`, `.agents/skills/llms.txt`, `README.md`,
  `docs/rag-context-system-plan.md`, `src/rag/tests/test_context_injection.py`,
  `scripts/test-pqc-dist.sh`, `.agents/canonical/`, `.agents/audit/`

## 1. The wtf task lane

Another tool is actively developing `wtf-is-going-on-mcp`; its working-tree change added a federated
task lane. Integrated as written:

- Six `task_*` tools — `task_dispatch`, `task_claim`, `task_report`, `task_status`, `task_run`,
  `runner_probe` — plus the pull-based semantics (the hub queues, an agent **on** the target machine
  claims; nothing is spawned over ssh) and the 15-minute claim lease.
- Runner selection: `auto` prefers Orca, falls back to Herdr; naming one explicitly fails loudly
  rather than silently using the other.
- Remote-machine pairing, and the `7800` default port with no auto-fallback.
- Nine new troubleshooting rows.

Also added the pack to `.agents/skills/llms.txt`, where it was missing despite being a distributed
pack — it was reachable only by browsing the directory.

**Correction made:** the pack undercounted its own tools — header said 24, catalog lists 23. That
off-by-one is pre-existing (the previous version said 18 and listed 17); I corrected it to 23 rather
than carrying the error forward. `env_report`/`env_probe` sharing one table row is the likely origin.

## 2. Stale-reference sweep — what was actually wrong

| Surface | Problem |
|---|---|
| `README.md` skills table | Advertised 3 packs that **do not exist** (`browser-harness`, `camofox-stack`, `skyvern`), omitted 4 that do (`browser-skill`, `browser-use`, the TTS pack, `typesafe-jev`) |
| `README.md` tree | Also listed `osa/` and `pi/` (never existed), and claimed "24 packs" against 20 directories |
| `docs/rag-context-system-plan.md` | Appendix B described the retired `context-orchestration` skill in the present tense |
| `.agents/skills/llms.txt` | Did not list `wtf-is-going-on-mcp` |
| `llms.txt` dangling section refs | The four `<DOCUMENT_MODEL>`/`<SERVERS>`/`<REPO_MEMORY>`/`<OUTPUT>` refs fixed last pass — confirmed none remain |

README's table and tree were **rebuilt from the filesystem**, not hand-corrected. The plan's Appendix B
was marked as a historical note rather than rewritten, because it records *why* Phase 4 was scoped as
new work — editing it would falsify the record.

## 3. A test that was failing on main and had been masked

`test_distinct_reviewer_makes_the_two_roles_request_different_models` asserted that two `chat()` calls
requested different models. That holds **only when provider keys exist**. The native PQC store now
holds **1** key (`LOCALROUTER_TEST_VENDOR_API_KEY`) where it previously resolved **24** through WSL,
so every direct step fails over to the router and both roles legitimately land on the same model.

The rotation itself is correct — `chain_steps("goldfish")` demonstrably returns a different first step
than `chain_steps("elephant")`. The test failed for an **environment** reason while the feature was
fine, and it was already failing on `main`.

Fixed by asserting the chain property the code owns rather than the answered model, which depends on
credentials. Verified the live pipeline still works: all four sections, `distinct_models: false`
reported honestly, no blocking.

## 4. The detector, and why it was proved first

A gate assertion now fails if any surface (`README.md`, `.agents/skills/llms.txt`, `src/help.sh`,
`.agents/llms.txt`, `llms.txt`) names a `.agents/skills/<name>/` that does not exist.

It was **proved against an injected fake pack** before being trusted:

```
current tree stale refs: 0        (expect 0)
after injecting a fake pack: 1    (expect >0)
after restore: 0                  (expect 0)
```

A detector that has only ever passed is indistinguishable from one that cannot fail.

## Verification

- `bash scripts/test-pqc-dist.sh` — **158/158** (2 new).
- `py -m unittest discover -s src/rag/tests` — **164 pass** (the previously-failing test now green for
  the right reason).
- Live `ainish-rag context` returns all four sections with the reduced key store.
- Tool count in the wtf catalog verified programmatically: 23 declared, 23 listed.
- `ainish-rag audit verify` after re-signing.

## Flagged, not changed

- **The PQC store lost 23 keys at 20:05 today** — it now holds only `LOCALROUTER_TEST_VENDOR_API_KEY`.
  That is outside this task and almost certainly the other tool's doing, but it disables every direct
  driver tier (they all fail over to the router) and will disable signing paths that expect specific
  keys. Worth confirming before it surprises someone.
- **The wtf documentation was integrated as written, not verified against the binary** — `wtf` is not
  installed on this machine, so the six new tools, the 7800 default, and the Orca-before-Herdr
  behaviour are the maintainer's claims rather than tested facts here.
