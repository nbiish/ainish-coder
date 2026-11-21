#!/usr/bin/env node
// aiRPC bridge v1 — zero-dependency transport between the tldraw canvas and one waiting agent.
// Requires Node >= 22 (Promise.withResolvers).
//
//   node bridge.mjs serve   [--port 7331] [--session main]
//   node bridge.mjs project --manifest manifest.json [--session main] [--url URL]
//   node bridge.mjs wait    [--session main] [--by ISO] [--url URL]
//   node bridge.mjs ack     --file ack.json [--session main] [--url URL]
//
// Exit codes: 0 = one event printed on stdout (wait), 2 = --by deadline expired (wait),
// 1 = hard error. State: $AIRPC_HOME/<session>/{manifest.json,inbox.jsonl,log.jsonl,consumer.lock}.
// Security: binds 127.0.0.1 only, checks Host/Origin, writes only under $AIRPC_HOME.
import { createServer } from 'node:http'
import { appendFileSync, closeSync, existsSync, mkdirSync, openSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { homedir } from 'node:os'
import { createHash, randomUUID } from 'node:crypto'

const HOME = process.env.AIRPC_HOME || join(homedir(), '.airpc')
const DEFAULT_URL = 'http://127.0.0.1:7331'
const VERSION = 1
const LONGPOLL_MS = 25_000

// ---------- args / primitives ----------

function parseArgs(argv) {
  const out = { _: [] }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (!a.startsWith('--')) { out._.push(a); continue }
    const k = a.slice(2)
    const v = argv[i + 1]
    if (v !== undefined && !v.startsWith('--')) { out[k] = v; i++ } else out[k] = true
  }
  return out
}

function die(msg) {
  process.stderr.write(`airpc: ${msg}\n`)
  process.exit(1)
}

function hashHex(s) {
  return createHash('sha256').update(s).digest('hex')
}

export function blockId(path, anchor) {
  return `blk-${hashHex(`${path}#${anchor}`).slice(0, 12)}`
}
export function bodyDigest(path, body) {
  return hashHex(`${path}\u0000${body}`).slice(0, 12)
}

function sessionDir(session) {
  return join(HOME, session)
}
function ensureSession(session) {
  mkdirSync(sessionDir(session), { recursive: true })
  return sessionDir(session)
}
function readJsonl(file) {
  if (!existsSync(file)) return []
  return readFileSync(file, 'utf8').split('\n').filter(Boolean).map((line, i) => {
    try { return JSON.parse(line) } catch { die(`malformed JSON at ${file}:${i + 1} (fail closed)`) }
  })
}
function appendJsonl(file, obj) {
  appendFileSync(file, JSON.stringify(obj) + '\n')
}
function now() { return new Date().toISOString() }

// ---------- payload validation (fail closed) ----------

function isSafeRelPath(p) {
  return typeof p === 'string' && p.length > 0 && !p.startsWith('/') && !p.split('/').includes('..')
}
function validateBlock(b) {
  if (!b || typeof b !== 'object') return 'block: not an object'
  for (const k of ['id', 'path', 'anchor', 'title', 'kind', 'digest', 'body']) {
    if (typeof b[k] !== 'string') return `block: ${k} must be a string`
  }
  if (!isSafeRelPath(b.path)) return 'block: unsafe path'
  if (b.id !== blockId(b.path, b.anchor)) return 'block: id mismatch'
  if (b.digest !== bodyDigest(b.path, b.body)) return 'block: digest mismatch'
  if (!Number.isInteger(b.lane) || b.lane < 0) return 'block: lane must be a non-negative integer'
  if (b.links !== undefined && !Array.isArray(b.links)) return 'block: links must be an array'
  return null
}
function validateManifest(m, session) {
  if (!m || typeof m !== 'object') return 'manifest: not an object'
  if (m.v !== VERSION) return 'manifest: unsupported version'
  if (m.session !== session) return 'manifest: session mismatch'
  if (!Array.isArray(m.blocks)) return 'manifest: blocks must be an array'
  const ids = new Set()
  for (const b of m.blocks) {
    const err = validateBlock(b)
    if (err) return err
    if (ids.has(b.id)) return 'manifest: duplicate block id'
    ids.add(b.id)
  }
  for (const b of m.blocks) {
    for (const l of b.links ?? []) if (!ids.has(l)) return 'manifest: link to unknown block'
  }
  return null
}
function validateCall(c, session) {
  if (!c || typeof c !== 'object') return 'call: not an object'
  if (c.v !== VERSION || c.kind !== 'call') return 'call: unsupported version or kind'
  if (c.session !== undefined && c.session !== session) return 'call: session mismatch'
  for (const k of ['block_id', 'path', 'anchor', 'digest', 'prompt']) {
    if (typeof c[k] !== 'string') return `call: ${k} must be a string`
  }
  if (c.prompt.length === 0) return 'call: empty prompt'
  if (!isSafeRelPath(c.path)) return 'call: unsafe path'
  if (c.block_id !== blockId(c.path, c.anchor)) return 'call: block_id mismatch'
  return null
}
function validateAck(a, session, inbox) {
  if (!a || typeof a !== 'object') return 'ack: not an object'
  if (a.v !== VERSION || a.kind !== 'ack') return 'ack: unsupported version or kind'
  for (const k of ['call_id', 'block_id', 'status', 'summary']) {
    if (typeof a[k] !== 'string') return `ack: ${k} must be a string`
  }
  if (!['done', 'needs-you', 'stale', 'refused'].includes(a.status)) return 'ack: bad status'
  if (a.status === 'done' && typeof a.new_digest !== 'string') return 'ack: done requires new_digest'
  if (a.note !== undefined && typeof a.note !== 'string') return 'ack: note must be a string'
  if (!inbox.some((e) => e.kind === 'call' && e.id === a.call_id)) return 'ack: unknown call_id'
  return null
}

// ---------- long-poll hub ----------

function hub() {
  const waiters = new Set()
  return {
    wake() { for (const w of waiters) w() },
    wait(ms) {
      const { promise, resolve } = Promise.withResolvers()
      const done = () => { clearTimeout(t); waiters.delete(done); resolve() }
      const t = setTimeout(done, ms)
      waiters.add(done)
      return promise
    },
  }
}

// ---------- serve ----------

async function serve(args) {
  const port = Number(args.port ?? 7331)
  const session = String(args.session ?? 'main')
  const dir = ensureSession(session)
  const inboxHub = hub()
  const eventHub = hub()

  const readInbox = () => readJsonl(join(dir, 'inbox.jsonl'))
  const readLog = () => readJsonl(join(dir, 'log.jsonl'))

  const server = createServer(async (req, res) => {
    const host = req.headers.host ?? ''
    const origin = req.headers.origin
    const self = `127.0.0.1:${port}`
    const selfAlt = `localhost:${port}`
    if (host !== self && host !== selfAlt) {
      res.writeHead(403, { 'content-type': 'application/json' })
      return res.end(JSON.stringify({ error: 'host not allowed' }))
    }
    if (origin !== undefined && origin !== `http://${self}` && origin !== `http://${selfAlt}`) {
      res.writeHead(403, { 'content-type': 'application/json' })
      return res.end(JSON.stringify({ error: 'origin not allowed' }))
    }
    const url = new URL(req.url, `http://${self}`)
    const json = (code, obj) => {
      res.writeHead(code, { 'content-type': 'application/json', 'cache-control': 'no-store' })
      res.end(JSON.stringify(obj))
    }
    const body = () => new Promise((resolveBody) => {
      let data = ''
      req.on('data', (c) => { data += c })
      req.on('end', () => resolveBody(data))
    })

    try {
      if (req.method === 'GET' && url.pathname === '/state') {
        return json(200, {
          session,
          manifest: existsSync(join(dir, 'manifest.json'))
            ? JSON.parse(readFileSync(join(dir, 'manifest.json'), 'utf8')) : null,
          events: readLog(),
        })
      }
      if (req.method === 'GET' && (url.pathname === '/events' || url.pathname === '/rpc/wait')) {
        const after = Number(url.searchParams.get('after') ?? 0)
        const isEvents = url.pathname === '/events'
        const read = isEvents ? readLog : readInbox
        const deadline = Date.now() + LONGPOLL_MS
        for (;;) {
          let rows = read().map((r, i) => ({ ...r, seq: i + 1 })).filter((r) => r.seq > after)
          if (!isEvents) {
            // protocol: wait surfaces unacked calls; acked ones are settled
            const acked = new Set(readLog().filter((e) => e.kind === 'ack').map((e) => e.call_id))
            rows = rows.filter((r) => r.kind !== 'call' || !acked.has(r.id))
          }
          if (rows.length) return json(200, rows)
          if (Date.now() >= deadline) return json(200, [])
          await (isEvents ? eventHub : inboxHub).wait(Math.min(2000, deadline - Date.now()))
        }
      }
      if (req.method === 'POST' && url.pathname === '/rpc') {
        let call
        try { call = JSON.parse(await body()) } catch { return json(400, { error: 'malformed JSON' }) }
        call.v ??= VERSION
        call.kind ??= 'call'
        call.session = session
        call.id ??= `call-${randomUUID()}`
        call.ts ??= now()
        const err = validateCall(call, session)
        if (err) return json(400, { error: err })
        const seq = readInbox().length + 1
        appendJsonl(join(dir, 'inbox.jsonl'), call)
        inboxHub.wake()
        return json(202, { ok: true, id: call.id, seq })
      }
      if (req.method === 'POST' && url.pathname === '/project') {
        let manifest
        try { manifest = JSON.parse(await body()) } catch { return json(400, { error: 'malformed JSON' }) }
        const err = validateManifest(manifest, session)
        if (err) return json(400, { error: err })
        writeFileSync(join(dir, 'manifest.json'), JSON.stringify(manifest, null, 2))
        appendJsonl(join(dir, 'log.jsonl'), { v: VERSION, kind: 'project', ts: now(), blocks: manifest.blocks.length })
        eventHub.wake()
        return json(202, { ok: true, blocks: manifest.blocks.length })
      }
      if (req.method === 'POST' && url.pathname === '/ack') {
        let ack
        try { ack = JSON.parse(await body()) } catch { return json(400, { error: 'malformed JSON' }) }
        const err = validateAck(ack, session, readInbox())
        if (err) return json(400, { error: err })
        appendJsonl(join(dir, 'log.jsonl'), ack)
        eventHub.wake()
        return json(202, { ok: true, seq: readLog().length })
      }
      if (req.method === 'POST' && url.pathname === '/end') {
        let reason = 'unspecified'
        try { reason = JSON.parse(await body()).reason ?? reason } catch { /* bare /end is fine */ }
        const ev = { v: VERSION, kind: 'end', session, reason, ts: now() }
        appendJsonl(join(dir, 'inbox.jsonl'), ev)
        appendJsonl(join(dir, 'log.jsonl'), ev)
        inboxHub.wake(); eventHub.wake()
        return json(202, { ok: true })
      }
      return json(404, { error: 'unknown route' })
    } catch (e) {
      return json(500, { error: String(e?.message ?? e) })
    }
  })
  server.listen(port, '127.0.0.1', () => {
    process.stdout.write(`airpc: serving session "${session}" on http://127.0.0.1:${port}\n`)
  })
}

// ---------- CLI clients (project / ack / wait) ----------

async function post(url, pathName, payload) {
  const res = await fetch(new URL(pathName, url), {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  })
  const out = await res.json().catch(() => ({}))
  if (!res.ok) die(`${pathName} failed: HTTP ${res.status} ${out.error ?? ''}`)
  return out
}

async function project(args) {
  const session = String(args.session ?? 'main')
  const url = String(args.url ?? DEFAULT_URL)
  if (!args.manifest) die('project: --manifest FILE is required')
  const manifest = JSON.parse(readFileSync(String(args.manifest), 'utf8'))
  manifest.session = session
  const out = await post(url, '/project', manifest)
  process.stdout.write(JSON.stringify(out) + '\n')
}

async function ack(args) {
  const session = String(args.session ?? 'main')
  const url = String(args.url ?? DEFAULT_URL)
  if (!args.file) die('ack: --file FILE is required')
  const a = JSON.parse(readFileSync(String(args.file), 'utf8'))
  const out = await post(url, '/ack', a)
  process.stdout.write(JSON.stringify(out) + '\n')
}

async function waitCmd(args) {
  const session = String(args.session ?? 'main')
  const url = String(args.url ?? DEFAULT_URL)
  const deadlineMs = args.by ? Date.parse(String(args.by)) : Infinity
  if (Number.isNaN(deadlineMs)) die('wait: --by is not a valid ISO time')

  // single consumer: claim consumer.lock for this session (in $AIRPC_HOME, not the repo)
  const dir = ensureSession(session)
  const lock = join(dir, 'consumer.lock')
  try {
    const fd = openSync(lock, 'wx')
    writeFileSync(fd, String(process.pid))
    closeSync(fd)
  } catch {
    die(`session "${session}" already has a wait consumer (consumer.lock)`)
  }
  const release = () => { try { rmSync(lock) } catch { /* already gone */ } }
  process.on('exit', release)
  process.on('SIGINT', () => process.exit(1))
  process.on('SIGTERM', () => process.exit(1))

  let after = 0
  for (;;) {
    const remaining = deadlineMs - Date.now()
    if (remaining <= 0) {
      process.stderr.write(`airpc: --by deadline expired with no response for session "${session}"\n`)
      release()
      process.exit(2)
    }
    const pathName = `/rpc/wait?after=${after}`
    let rows = []
    try {
      const res = await fetch(new URL(pathName, url), { signal: AbortSignal.timeout(Math.min(LONGPOLL_MS + 5000, Math.max(1, remaining))) })
      rows = await res.json()
    } catch (e) {
      if (Date.now() >= deadlineMs) {
        process.stderr.write(`airpc: --by deadline expired with no response for session "${session}"\n`)
        release()
        process.exit(2)
      }
      if (remaining > 5000) {
        const { promise, resolve } = Promise.withResolvers()
        setTimeout(resolve, 1000)
        await promise
        continue
      }
      die(`wait: bridge unreachable at ${url}: ${e?.message ?? e}`)
    }
    for (const row of rows) {
      after = Math.max(after, row.seq ?? after)
      if (row.kind === 'call' || row.kind === 'end') {
        process.stdout.write(JSON.stringify(row) + '\n')
        release()
        return
      }
    }
  }
}

// ---------- entry ----------
import { pathToFileURL } from 'node:url'

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [, , command, ...rest] = process.argv
  const args = parseArgs(rest)
  if (command === 'serve') await serve(args)
  else if (command === 'project') await project(args)
  else if (command === 'ack') await ack(args)
  else if (command === 'wait') await waitCmd(args)
  else die('usage: bridge.mjs serve|project|wait|ack [--session ID] [--url URL] [--port N] [--manifest F] [--file F] [--by ISO]')
}
