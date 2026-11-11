# Plan — make local-router apply a saved config without a restart

**Goal:** saving a chain in the router's config page (`/config/fallback`, the `#fallbackModelsText`
textarea) takes effect immediately. Today it requires stopping and restarting the router, which means
every machine that edits its chain has a window where the served chain does not match the file, and
`ainish-rag` resolves against whatever the process loaded at boot.

**Status:** proposed. `local-router` is a separate repository (`D:\Code\local-router` on Windows, and
a checkout on the Mac's external volume) — this plan is written here because the consumer is this repo,
but the change lands there.

## What is true today

- The config file is `~/.config/local-router/fallback-models.json`, shape `{"version":1,"routes":[...]}`.
- `--config` / `LOCAL_ROUTER_ROUTES_CONFIG` takes the **declarative** shape
  (`{"fallbackModels": {...}}`) and applies it **at boot only**.
- When the page saves, the router rewrites the persisted file from its live state. If the boot config
  was ignored (wrong shape), that rewrite is what empties the chain — this is the failure that produced
  `fallback-models: []` on Windows twice.

## Design

**Watch, then reload by the same code path as boot.**

1. On startup, record `(path, mtime, size, sha256)` for the persisted config and for any declarative
   boot config.
2. Watch both files. Prefer an OS watcher (`notify`/`fsnotify`) with a `stat` poll at 1s as fallback —
   the poll is what survives WSL and SMB/NFS mounts, where inotify does not fire reliably.
3. On change: parse, validate against the full model inventory (a chain naming an unknown model must be
   rejected with a message, not silently dropped), then swap the in-memory chains by the **same
   function** boot uses. One code path means a reloaded config cannot behave differently from a booted
   one.
4. Rejection is not a crash: keep serving the last good chain, and surface the reason on the config page
   and in `/config` state (`lastReloadError`, `lastReloadAt`, `chainHash`). A router that dies on a
   typo takes the whole agent fleet down.
5. Debounce writes (save-on-input can fire many times): coalesce events within ~300ms, and ignore a
   change whose sha256 equals the loaded one.
6. Serialize: reload holds a write lock against in-flight request handling that reads the chains, so a
   request never sees a half-applied chain.

## Config-page contract

- Show `Live chain hash`, `Loaded at`, and `File mtime` so the operator can see whether what they saved
  is what is being served. The empty-chain case must be visibly an error on the page, not a silent list.
- Keep `Apply` (immediate) and `Save` (persist) distinct only if both end in a reload; otherwise collapse
  them. One button that says what it does.

## Acceptance

- Editing the textarea and saving changes `local-router/<route>` within one second, with no restart and
  no dropped request.
- A chain naming an unknown model is rejected with a visible reason; the previously loaded chain keeps
  serving.
- Killing the watcher degrades to boot-only behavior, logged once, not silently.
- `ainish-rag --context` resolves the new first model immediately after a save (provenance line
  `drivers: local-router:<model>` changes without a re-spawn).

## Interim, until this lands

```bash
scripts/local-router-sync.sh           # install canonical chain + restart (the current workaround)
scripts/local-router-sync.sh --capture # take a machine's live chain back into the repo
```

The restart is the gap; the capture is what keeps the file and the repo from drifting apart while it
exists.
