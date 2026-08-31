---
name: tts-cli
description: "On-device Text-to-Speech CLI (`cli-tts`) for agent voice summaries and ad-hoc speech. Use when: an agent needs to speak a concise end-of-chat summary + one hardened-engineer next-step suggestion; generate speech from text/clipboard/file/pipe; pick a built-in voice; set or check the default engine; or manage isolated `uv` environments. Single engine: KittenTTS nano int8 (15M, CPU ONNX) — fastest on this machine (cold ~7.9s, RTF ~0.47), no accelerator required, cross-platform (macOS/Linux/Windows/WSL), English-only, 8 fixed built-in voices (no zero-shot cloning). Trigger on: 'tts', 'tts-cli', 'cli-tts', 'speak', 'voice summary', 'read aloud', 'play audio', or any request to vocalize agent output."
---

# tts-cli — on-device TTS for agent voice summaries

`cli-tts` generates speech **on-device** (no cloud, no API keys) and is the
canonical channel for an agent's end-of-chat voice summary. It runs **one-shot
in an isolated `uv` env** (Python 3.11) that fully unloads from RAM after each
call — no daemon, no warm cache, no model state held between calls.

**Single engine:** `kitten-tts-nano` — KittenTTS 15M int8, CPU ONNX. `auto` is
an alias. No GPU/MPS needed. English-only. Fixed built-in voices (no cloning).

## 1. The one agent command

```bash
cli-tts --prompt "<1-2 sentence concise summary of what was accomplished>. Next step: <ONE concrete, adversarial next-step a hardened engineer would take>."
```

`--prompt` (`-p`) is an alias for `--text`. The "Next step: ..." segment is
**mandatory** — it is appended to `AGENTS-TTS-COMMS.txt` at the repo root (one
entry per call: the ISO-8601 date-time, a newline, then the suggestion text
only — no model/lang/voice metadata) for cross-agent context. Calls with no
"Next step:" segment still speak but write nothing to the transcript.

Keep stdout quiet — the spoken audio IS the channel; do not dump logs.

**If not installed:** when the engine env is missing, `cli-tts` prints one
concise recovery line and exits non-zero —
`❌ tts-cli engine not ready → https://github.com/nbiish/tts-cli`. Follow the
link for setup, then `cli-tts --create-environment kitten-tts`.

## 2. Setup (once per machine)

```bash
# Requires: uv (https://astral.sh/uv) + Python 3.11
git clone https://github.com/nbiish/tts-cli.git && cd tts-cli
./scripts/setup-global.sh          # installs the `cli-tts` shim system-wide
cli-tts --create-environment kitten-tts   # creates the isolated Python 3.11 env
cli-tts --list                    # should show kitten-tts-nano ✅ Available
```

First generation downloads the ~25MB weights from Hugging Face (cached
thereafter). Verify: `cli-tts --text "Hello world" --output /tmp/t.wav`.

## 3. Commands at a glance

| Goal | Command |
| :--- | :--- |
| **Agent summary (canonical)** | `cli-tts --prompt "<summary>. Next step: <suggestion>"` |
| Plain text | `cli-tts --text "..."` or `cli-tts "..."` |
| Clipboard | `cli-tts --clipboard` |
| Pipe | `echo "hi" \| cli-tts` · `cat file.txt \| cli-tts` |
| File | `cli-tts --input-file in.txt` |
| Choose voice | `cli-tts --text "hi" --voice expr-voice-2-f` |
| List voices | `cli-tts --list-voices` |
| List models | `cli-tts --list` |
| Set default | `cli-tts --set-default kitten-tts-nano` |
| Output file | `cli-tts --text "hi" --output out.wav` |
| List envs | `cli-tts --list-environments` |
| Clean env | `cli-tts --cleanup-environment kitten-tts` |

`--model` accepts `auto` (default) or `kitten-tts-nano` — both resolve to the
same engine. Override the default via `TTS_CLI_DEFAULT_MODEL`. `--lang` is
accepted for compatibility but ignored (English-only).

## 4. Voices

8 fixed built-in voices (no zero-shot cloning). `--voice` selects a **name**,
not a path:

```
expr-voice-2-m  expr-voice-2-f
expr-voice-3-m  expr-voice-3-f
expr-voice-4-m  expr-voice-4-f
expr-voice-5-m  expr-voice-5-f   ← default
```

`cli-tts --list-voices` prints them. An **unknown voice name fails closed**
(no silent fallback) — a typo'd voice produces an error, never unexpected audio.

## 5. Behavior & security (read once)

- **One-shot / cold-start every call:** the engine runs in a subprocess that
  exits immediately after writing the WAV. No daemon, no warm cache, no model
  state held in RAM/VRAM between calls. Every invocation pays the cold load
  (~7.9s) — by design, so models never hold memory outside an active call.
- **Input is injection-safe:** all text/voice/speed params travel via stdin
  JSON to the runner script (no `python -c` interpolation) — no CWE-78 surface.
- **Fail-closed validation:** text > 5000 chars is rejected before spawning the
  runner; unknown voice names are rejected (no silent fallback).
- **No secrets:** the engine is local and open (MIT/KittenML). No API keys, no
  `.env`, no network beyond the one-time HF weights download.
- **Durable transcript:** the "Next step: ..." suggestion of every successful
  `cli-tts` call is auto-appended to `AGENTS-TTS-COMMS.txt` (suggestion only,
  token-economical). Track it in git alongside `AGENTS.md`. No secrets there.
- **Skip only if** `cli-tts` is unavailable or the operator disabled audio.

## 6. Cross-platform notes

Identical CLI on every OS. Audio auto-plays via the OS-native player
(macOS `afplay` / Linux `aplay`/`paplay` / Windows). Environments live in
`.model-envs/` (dev) or `~/.tts-cli/model-envs/` (installed). The default-model
config is `~/.tts-cli/default_model`. No accelerator is used or required.

## 7. MCP harness preference

If the `local-tts-mcp` MCP server is enabled in the harness, **prefer it over
the CLI** (same engine, in-process). Use the CLI otherwise.
