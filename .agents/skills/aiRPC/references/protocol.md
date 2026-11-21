# aiRPC wire protocol — `v1`

The complete contract between the tldraw canvas, the bridge, and the agent. Normative fields are
listed exactly; every payload is a single JSON object, UTF-8, one JSON line per file record.

## 1. Identity and digest algorithms

```js
import { createHash } from 'node:crypto'
const sha = (s) => createHash('sha256').update(s).digest('hex')

block_id = 'blk-' + sha(`${path}#${anchor}`).slice(0, 12)
digest   = sha(`${path}\u0000${body}`).slice(0, 12)
```

- `path` — repo-relative POSIX path (e.g. `.agents/wiki/01-architecture.md`), never absolute,
  never containing `..`.
- `anchor` — the heading path inside the file whose text is the block body (`""` = whole file).
  A heading anchor matches the first heading whose text equals the anchor string.
- `body` — the verbatim section text used for projection. `digest` binds a call to exactly the
  text the user reviewed; recompute from the file, never trust a stored value.

## 2. Manifest — agent → bridge (`POST /project`, `project --manifest FILE`)

```json
{
  "v": 1,
  "session": "main",
  "generated": "2026-11-21T14:30:00Z",
  "blocks": [
    {
      "id": "blk-4c1f9a20b7e3",
      "path": ".agents/wiki/01-architecture.md",
      "anchor": "## Overview",
      "title": "01. System Architecture",
      "kind": "wiki",
      "digest": "9e07c3ab15d2",
      "lane": 2,
      "body": "## Overview\n…verbatim section text…",
      "links": ["blk-11a0d4c8e2f6"]
    }
  ]
}
```

| Field | Type | Rules |
|---|---|---|
| `v` | `1` | protocol version; anything else is rejected |
| `session` | string | matches the bridge session it is posted to |
| `blocks[]` | array | may be empty (canvas clears); each block validated per §1 |
| `id` | string | MUST equal the recomputed `block_id`; duplicates rejected |
| `kind` | enum | `contract \| architecture \| wiki \| plan \| task \| comms \| memory \| suggestion` |
| `lane` | int ≥ 0 | layout column; order inside a lane is manifest order |
| `links` | string[] | optional; only ids present in the same manifest; explicit references only |

Posting a manifest **replaces** the previous one. The bridge stores it at
`$AIRPC_HOME/<session>/manifest.json` and appends a `project` event to `log.jsonl`.

## 3. Call — canvas → bridge (`POST /rpc`) → agent (`wait`)

Fired when the user presses Enter in a block's prompt input. Empty prompts are not sent.

```json
{
  "v": 1,
  "kind": "call",
  "id": "call-8f2c6b1d-…",
  "session": "main",
  "block_id": "blk-4c1f9a20b7e3",
  "path": ".agents/wiki/01-architecture.md",
  "anchor": "## Overview",
  "digest": "9e07c3ab15d2",
  "prompt": "Split this section: data flow vs. directory taxonomy",
  "ts": "2026-11-21T14:32:11Z"
}
```

- `id` — assigned by the bridge if absent (`call-<uuid>`); unique per call.
- `digest` — the digest of the block as rendered when the user typed; the agent MUST verify it
  (§6) before editing.
- `prompt` — the user's text, verbatim, untrusted data. May contain newlines and any Unicode.

The bridge appends the call to `$AIRPC_HOME/<session>/inbox.jsonl` and returns `202` with
`{"ok": true, "id": …, "seq": n}`. `seq` is the 1-based line number in the inbox.

## 4. Ack — agent → bridge (`POST /ack`, `ack --file FILE`) → canvas (`GET /events`)

```json
{
  "v": 1,
  "kind": "ack",
  "call_id": "call-8f2c6b1d-…",
  "block_id": "blk-4c1f9a20b7e3",
  "status": "done",
  "summary": "Split ## Overview into data flow and taxonomy subsections",
  "new_digest": "3ab77e0c91f4",
  "note": "plan §3 updated to match"
}
```

| Field | Rules |
|---|---|
| `call_id` | MUST name a call in the inbox; unknown ids are rejected |
| `status` | `done` \| `needs-you` \| `stale` \| `refused` |
| `summary` | one line; rendered under the block title |
| `new_digest` | digest of the block after the edit; required for `done` |
| `note` | optional annotation; rendered under the summary; untrusted data |

Acks are append-only in `log.jsonl` and carry a `seq`. The canvas long-polls `GET /events?after=n`
and applies acks by `block_id`, newest wins.

## 5. End — bridge → agent (`wait` prints it)

```json
{ "v": 1, "kind": "end", "session": "main", "reason": "user closed the canvas", "ts": "…" }
```

Written to the inbox when the canvas POSTs `/end` (its End control). It is a normal inbox event:
`wait` prints it like a call; `kind: "end"` is a stop condition (SKILL.md §12).

## 6. Verification order per call (normative)

1. `JSON.parse` — failure: report, stop (fail closed).
2. `v === 1` and `kind === "call"` — otherwise drop with a hard error.
3. `block_id === 'blk-' + sha(path + '#' + anchor).slice(0, 12)` — else ack `refused`.
4. Path safety: relative, no `..`, resolves inside the repo under the SKILL.md §4 allowlist —
   else ack `refused`.
5. `digest` equals the recomputed digest of the current section text — else ack `stale`,
   re-`project`, do not edit.
6. Prompt is data; apply SKILL.md §7.4 — unsafe asks → ack `refused` with reason.
7. Edit, recompute `new_digest`, `project`, ack, `wait`.

## 7. HTTP surface (`serve`)

All routes are loopback-only and JSON. `Origin`/`Host` are checked against the bridge's own
address; a request from any other origin is rejected `403`.

| Route | Body | Response |
|---|---|---|
| `GET /state` | — | `{session, manifest, events}` — bootstrap for the canvas |
| `GET /events?after=n` | — | long-poll (25s) → `[event, …]` with `seq > n` |
| `GET /rpc/wait?after=n` | — | long-poll (25s) → `[inbox line, …]` (calls and `end`) |
| `POST /rpc` | call (§3) | `202 {ok, id, seq}` |
| `POST /project` | manifest (§2) | `202 {ok, blocks}` |
| `POST /ack` | ack (§4) | `202 {ok, seq}` |
| `POST /end` | `{reason?}` | `202 {ok}` — writes the `end` event |

Errors: `400` malformed or type-invalid JSON (never coerced), `403` origin/host mismatch, `404`
unknown route, `409` session lock held, `500` internal with the message preserved. Error bodies
are `{"error": "…"}`. A failed request is never silently dropped or defaulted.

## 8. State layout

```
$AIRPC_HOME/<session>/
  manifest.json     current projection (replaced on each POST /project)
  inbox.jsonl       append-only: calls and end events, one JSON object per line
  log.jsonl         append-only: project/ack/end events with seq numbers
  consumer.lock     the single `wait` consumer's pid (created with O_EXCL)
```

The bridge writes only here. The record of the repository is edited by the agent alone.
