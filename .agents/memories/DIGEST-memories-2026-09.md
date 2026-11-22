---
format: ainish/context-digest/v1
folder: memories
period: 2026-09
records_consolidated: 1
consolidated_at: 2026-11-20T22:10:20.147586+00:00
sources:
  - 2026-09-23-memory.txt
---

# Digest — `.agents/memories`, 2026-09

This digest replaces 1 record(s) from 2026-09. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Accomplished

- **Memory-scheme cutover (17:58, operator directive).** `2026-09-23-memory.txt` records that memory is now dated `{date}-memory.txt` files, replacing the old `MEMORY.md` digest plus `exports/` snapshots; suggestions moved to `{date}-suggestions.txt`. Format law: plain markdown only, agent/system/dependency agnostic. Format law is stated as `AGENTS.md <REPO_MEMORY>`.
- **Doctrine retired, not replaced.** The `repo-memory-graph-intelligence` dual-substrate skill, its 4-bridge protocol, and the three-server memory MCP standard (dated 2026-09-08/10) are marked `[RESOLVED]` and superseded by the dated memory files; the skill pack was removed. The record is explicit that the earlier work is gone, not carried forward.
- **Portable SHA-256 chain is in place.** `src/agents_protection.sh: _calc_sha256` falls back in order `sha256sum -> shasum -a 256 -> openssl dgst -sha256 -> python3 -> python -> powershell.exe -> cksum`, which the record says keeps cross-platform hashing unbroken.
- **Git hooks made portable.** `scripts/setup-hooks.sh` uses `while IFS= read` loops rather than `xargs -r`, which is illegal under macOS BSD `xargs` and was failing hooks.
- **Darwin file-locking order fixed.** `src/agents_protection.sh: lock_agents_contract / unlock_agents_contract`: `chmod 444` *before* `chflags uchg`, and `chflags nouchg` *before* `chmod 644`.
- **Local Router interception widened.** `bin/local-router.js` `serveSubcommands` now includes `start` and `run`, so the shim intercepts the Unsloth CLI as well as the plain serve path; Unsloth's native backend listens on 8888.

## Unfinished

- **`ainish-coder --rules <dir> --headless` exits 2 after successful deployments.** Observed uniformly across all 13 fleet targets plus a fresh `/tmp` probe, while `--help` exits 0. Root cause untraced (no cause recorded). Interim guidance in the record: treat the exit code as unreliable and verify the deployed copies instead (`bin/ainish-coder`).

## Insights

- **Exit status is not evidence.** A command exiting 2 after a verified-good deployment means the contract's "verify by reading back, never by exit code" rule has a concrete instance here; the record's workaround is to inspect the deployed artifacts.
- **Darwin is not GNU.** Two separate failures trace to BSD tooling differing from GNU: `xargs -r` being illegal, and `chmod` returning EPERM once the `uchg` flag is set. The second is an ordering constraint, not a missing flag — the immutable bit must come off before mode changes and on after them.
- **Backend port 8888 is contested.** Unsloth's native CLI serves on 8888, so any Local Router shim covering that port must route the `start` and `run` subcommands, not just `serve`. Subcommand coverage is the functional requirement, not port binding alone.
- **Superseded memory infrastructure was removed outright** (GitNexus doctrine, `memorix`/`reference_memory`/`engram` MCP plane, the dual-substrate skill pack) rather than kept as legacy paths — relevant if anything still references them.

## Recurring

- **Darwin portability** appears twice in a single day (`scripts/setup-hooks.sh` and `src/agents_protection.sh`): the same class of defect — Unix flags and syscall behaviour assumed to be GNU. Treat macOS/BSD divergence as the default suspicion for any shell-level failure on this host.
- The **exit-code-unreliable** lesson appears once in this period (the `ainish-coder --headless` bug) and should be assumed to recur elsewhere until the root cause is traced; the record itself notes the cause is still open.
- No other repetition is visible: with one record in the period, everything above not marked `[RESOLVED]` is a single observation, not an established pattern.

*Note: the trailing `local_router.failover` event in the request payload is external log data unrelated to the 2026-09 source record; it is not part of this digest.*

## Review

**Format:** one issue — the draft appends a trailing note about `local_router.failover` after the four sections. The instructions say four sections and nothing else; fold it in or drop it.

**Omission:** `2026-09-23-memory.txt` opens with `# Pairs with ../comms/2026-09-23-team.txt`. The digest drops the pairing entirely; a reader who wants the same-day comms record has no pointer. Also the source's format-law line reads `AGENTS.md <REPO_MEMORY>` — the draft renders it as "`AGENTS.md <REPO_MEMORY>`" but never says the placeholder means the repo's own memory-format section, which is the actionable part.

**Slight overreach:** the 17:59 entry says the Local Router "must include `start` and `run` in serveSubcommands" — a normative requirement. The draft says serveSubcommands "now includes `start` and `run`", asserting a completed change the record does not claim. Downgrade to "must include" or note it as unresolved.

**Unsupported import:** "the contract's 'verify by reading back, never by exit code' rule" is from `AGENTS.md`, not from this memory record. The record itself only says treat the exit code as unreliable and verify deployed copies. Citing the contract as if the record said it is a quiet source substitution — attribute it to `AGENTS.md` explicitly or leave it out.

**Section misuse:** the second Recurring bullet (exit-code-unreliable) is a single occurrence; the draft admits this, which makes it belong under Unfinished/Insights rather than Recurring. The closing caveat ("everything above not marked `[RESOLVED]` is a single observation") is correct and worth keeping.

**Everything else is faithful:** the SHA-256 fallback order, the BSD `xargs -r` failure, the chmod/uchg ordering in `lock_agents_contract`/`unlock_agents_contract`, the 13-target + `/tmp` exit-2 reproduction with `--help` at 0 and root cause untraced, and the outright retirement of the dual-substrate skill, GitNexus doctrine and memorix/reference_memory/engram plane all match the record verbatim.
