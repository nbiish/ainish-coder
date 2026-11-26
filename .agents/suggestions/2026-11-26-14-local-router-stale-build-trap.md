# Suggestion: local-router on macOS serves a stale build after every pull

- date: 2026-11-26
- status: open
- found during: context pipeline verification (`.agents/tasks/2026-11-26-14-context-pipeline-verify.md`)

The macOS router service runs `build/index.js` from an external checkout whose path the launchd
plist `com.localrouter.daemon` names (`supervise --run`). On 2026-11-25 the checkout was pulled
five times (last at 17:38Z, to 316ebaa) and `build/` was rebuilt once at 13:01Z, but the server
process (pid 13820) had started at 12:57Z and was never restarted. For about a day the live router
therefore lacked #21 (Hermes/pi harness wiring), #24 (glm-5.4 1M context) and #26 (self-healing
fallback), while `GET /api/update-status` reported `currentCommit` 316ebaa — it reads the checkout's
HEAD, not the loaded code.

Two traps compound it:

1. `git pull` + `npm run build` are not enough; the server must be restarted, and nothing in the
   pull/build path says so.
2. The old server ignored SIGTERM for 20 s and needed SIGKILL.

Suggested resolution (local-router repo): make `/api/update-status` compare the running build's
identity (a build stamp emitted by `tsc`, or the mtime/hash of `build/index.js` at boot) with the
checkout, and report `restartRequired` when they differ; document pull → build → restart as one
procedure in the README; handle SIGTERM promptly. Until then the macOS procedure is:
`npm run build`, then `kill <server pid>` and let the supervisor re-spawn it (~15–20 s).
