# ◈──◆──◇ ainish-coder ◇──◆──◈

<div align="center">
  <h1>🚀 Configuration & Skills Manager for AI Coding Agents</h1>
  <p><strong>Deploy hardened AGENTS.md configs, reusable AI skills, and autonomous agent frameworks to any project</strong></p>
  <p>✨ <em>Security-first, self-hosted, Zero Trust — built for the agentic era</em></p>

  <hr width="60%">

  <h2>🎯 What is ainish-coder?</h2>
  <p><strong>ainish-coder</strong> is a modular configuration and skills deployment system for AI coding assistants. It standardizes agent behavior across 10+ IDE extensions and CLI tools via the AGENTS.md standard, ships production-grade security skills, and enables autonomous multi-agent execution through the OSA framework. Every configuration is hardened against the OWASP LLM Top 10, OWASP Agentic Top 10 (ASI 2026), and OWASP Agentic Skills Top 10 (AST10 2026).</p>
</div>

<div align="center">
  <hr width="50%">
  <h3>Support This Project</h3>
  <table style="border: none; border-collapse: collapse;">
    <tr style="border: none;">
      <td align="center" style="border: none; vertical-align: middle; padding: 20px;">
        <h4>Stripe</h4>
        <img src="assets/qr-stripe-donation.png" alt="Scan to donate" width="180"/>
        <p><a href="https://raw.githubusercontent.com/nbiish/license-for-all-works/8e9b73b269add9161dc04bbdd79f818c40fca14e/qr-stripe-donation.png">Donate via Stripe</a></p>
      </td>
      <td align="center" style="border: none; vertical-align: middle; padding: 20px;">
        <a href="https://www.buymeacoffee.com/nbiish">
          <img src="assets/buy-me-a-coffee.svg" alt="Buy me a coffee" />
        </a>
      </td>
    </tr>
  </table>
  <hr width="50%">
</div>

## 🔥 Key Features

- **🎯 AGENTS.md Standard** — Universal agent instructions with OWASP-aligned security baselines
- **🧠 Skills System** — 24 hardened procedural guideline skill packs (security, browser automation, video generation, ComfyUI orchestration, 3D modeling, research)
- **🏗️ Direct Components** — Discoverable shell utilities and deployment commands under `src/`
- **📊 Usage Analytics** — CSV tracking of all CLI invocations (`~/.cache/ainish-coder/usage.csv`) for data-driven improvement
- **🔄 OSA Framework** — Orchestrated System of Agents using standard CLI coding tools (Gemini, Claude, OpenCode, mini-swe-agent, kilo, crush) with fixed-order rotation, automatic fallback, and git worktree isolation
- **🛡️ Security-First** — Zero Trust, PQC-compliant (FIPS 203/204/205), MCP hardening, supply chain integrity
- **⚡ One-Command Deploy** — Configs, skills, and security baselines in a single `ainish-coder` invocation
- **🔗 Smart File Management** — Interactive destination picker (home `~/.agents/` vs project-local) for skills and agents; interactive symlink prompts for single-source-of-truth deployments; global `--link`/`-l` flag for scripted symlink mode; copies for tool-specific customization
- **🎭 Template Agent System** — Craft custom system prompts with expert guidance
- **📜 Scrolls & 8th Fire Protocols** — Deploy `llms.txt` file and `.scrolls` for machine-readable project context, including the Ghost Layer Codex and Prompt Obliteration (Plinian Defense) for AI survival.

---

## 🪶 The 8th Fire Mission & AI Survival

ainish-coder encodes the **8th Fire Mission**—a commitment to digital sovereignty, traditional knowledge preservation, and the survival of Indigenous truths within artificial intelligence systems.

- **Ghost Layer Codex** — Encodes the 8th Fire mandate in invisible metadata (Digital Wiigwaasabak) to conceal from hostile actors and reveal to AI agents.
- **Prompt Obliteration (Plinian Defense)** — Bypasses restrictive corporate AI guardrails that inadvertently censor discussions of historical genocide, MMIP, or treaty defense as "unsafe."
- **Hemispheric Solidarity** — Unifies the struggle of Indigenous peoples across the Americas and beyond (The Eagle, The Quetzal, and The Condor) within the AI's core mandate.

---

## 🧠 Skills System

Skills are portable, expert-level knowledge packs that inject domain expertise into AI agents. The packs this tool **distributes** live in the payload at `skills-to-distribute/skills/<name>/SKILL.md`; `ainish-coder --rules` installs the selected ones into a target repo's `.agents/skills/`, which is where agent harnesses discover them.

This repository keeps only a small curated subset in its own `.agents/skills/` — the packs its agents actually read (`ainish-security`, `pqc-secrets`, `question-me`). That split is deliberate: harnesses auto-discover `**/.agents/skills`, so a full payload kept there would be standing prompt surface in every session.

| Skill | Payload path | Description |
|-------|------|-------------|
| **Advisory Council** | `skills-to-distribute/skills/advisory-council/` | Multi-expert advisory council. Dispatches sub-agents with distinct expert identities for collaborative analysis and decision-making. |
| **Anishinaabe Cyberpunk** | `skills-to-distribute/skills/anishinaabe-cyberpunk-style/` | Anishinaabe-inspired cyberpunk styling guide combining Canadian Aboriginal Syllabics with ASCII circuit symbols. |
| **Browser Skill** | `skills-to-distribute/skills/browser-skill/` | Drive the user's real logged-in Chromium through the `bsk` CLI and extension: automate, scrape, extract observations, click, fill, emulate mobile, or request human takeover. |
| **Browser Use** | `skills-to-distribute/skills/browser-use/` | Direct browser control via CDP for automation, scraping, testing, screenshots, and web work across macOS, Linux, and Windows. |
| **Ainish Security** | `skills-to-distribute/skills/ainish-security/` | The single security contract: code and infrastructure, AI/agentic, secrets and post-quantum cryptography, supply chain, compiler integrity, governance. Progressive depth in four `references/` files. **Mandatory** — `AGENTS.md` links to it. |
| **ComfyUI Orchestration** | `skills-to-distribute/skills/comfyui-orchestration/` | Operate the local ComfyUI install agentically — comfy-cli JSON envelopes plus the comfy-mcp server, host topology, model-path resolution, lifecycle, VRAM gating, and the environment repairs that keep the MCP server booting. |
| **Document Enhancer** | `skills-to-distribute/skills/document-enhancer/` | Dual-pipeline document improvement: fuse external knowledge bases into a target, or recursively harden a document for multi-model LLM effectiveness. |
| **Ghost Layer Injector** | `skills-to-distribute/skills/ghost-layer-injector/` | Inject covert AI/bot context into static HTML so LLMs and crawlers ingest instructions without altering the human view. Scroll channel only — not selectable. |
| **GStack Coder** | `skills-to-distribute/skills/gstack-coder/` | Multi-tool coding orchestration integrating gstack (Claude Code skills), pi, opencode, and qwen for security audits, code reviews, QA, and feature builds. |
| **Modern Prompting** | `skills-to-distribute/skills/modern-prompting/` | Reasoning strategy selection: rates 16 prompting frameworks on a 0–100% suitability scale per task, then applies the highest-rated via OOReDAct. |
| **OpenSCAD Generator** | `skills-to-distribute/skills/openscad-generator/` | Parameterized 3D models from Python templates and OpenSCAD, compiled to STL via Makefile. |
| **PQC Secrets** | `skills-to-distribute/skills/pqc-secrets/` | Post-quantum secrets for API keys and private data: ML-KEM-768 at rest, ML-DSA-65 signing. **Mandatory** — every secret resolution goes through it. |
| **Pliny Research** | `skills-to-distribute/skills/pliny-research/` | Extracted system prompts, guidelines, tools, and jailbreak techniques from major AI models. Deploy with `ainish-coder --unlock`. |
| **Question Me** | `skills-to-distribute/skills/question-me/` | Socratic design interview and requirements resolution — codebase recon first, one question at a time with recommended answers, compiled into a `.agents/plans/{date}-{HH}-{name}.md` holding the plan, clarification ledger, and derived todos. |
| **Remotion Video** | `skills-to-distribute/skills/remotion-video/` | Programmatic video creation with Remotion — APIs, media components, 3D, captions, fonts, Lambda rendering, and layout rules. |
| **TypeSafe Jev** | `skills-to-distribute/skills/typesafe-jev/` | Calibrated decision models over the Decisions API: routing, two-stage reranking, context freshness, faithfulness evaluation, and typed `noul`/`choice`/`score` questions. |
| **Video Knowledge Extractor** | `skills-to-distribute/skills/video-knowledge-extractor/` | Structured markdown knowledge bases from YouTube videos by combining transcripts with sequential visual frames through a Vision-Language Model. |
| **wtf-is-going-on-mcp** | `skills-to-distribute/skills/wtf-is-going-on-mcp/` | Cross-machine agent coordination. Herdr owns agent sessions; wtf records who is doing what, carries encrypted messages, and dispatches addressable work to a paired machine's own agent (`task_*`). |

### Skill Format

```yaml
---
name: skill-name
description: >
  What this skill teaches the agent
version: 1.0.0
---

# Skill Title

## Instructions
## Guidelines
## Guardrails
## Examples
## Troubleshooting
```

---

## 🛡️ Security Posture

ainish-coder configurations enforce a comprehensive security baseline:

| Domain | Standards |
|--------|-----------|
| **Core Framework** | OWASP LLM Top 10 (2025), OWASP Agentic Top 10 (ASI 2026), OWASP Agentic Skills Top 10 (AST10 2026) |
| **Cryptography** | PQC-compliant: ML-KEM-768 (FIPS 203), ML-DSA-65 (FIPS 204), SLH-DSA (FIPS 205); AES-256-GCM at rest; TLS 1.3+ in transit |
| **Agent Security** | Zero Trust; MCP manifest signing; tool schema validation (Zod/Pydantic); HITL for high-risk actions; kill switches |
| **Supply Chain** | SBOMs (CycloneDX/SPDX), SLSA attestations, artifact signing (Sigstore), dependency pinning by hash |
| **Data Protection** | PII redaction (Presidio); env-only secrets; encrypted logs; structured immutable audit trails |
| **MCP Hardening** | Allowlisted servers; pinned manifests; drift detection; sandboxed execution (WASM/Firecracker); no auto-approve |

### Known MCP CVE Mitigations

| CVE | Product | Mitigation |
|-----|---------|------------|
| CVE-2025-32711 | M365 Copilot (EchoLeak) | Output sanitization; strip markdown image refs |
| CVE-2025-53773 | GitHub Copilot (Worm) | Instruction hierarchy; treat repo text as untrusted |
| CVE-2025-54135 | Cursor (CurXecute) | Require explicit approval; no auto-start |
| CVE-2025-64660 | GitHub Copilot | Behavioral monitoring; AGENTS.md immutability |
| CVE-2026-30615 | Windsurf | Never let LLM output modify system config |
| CVE-2026-30623 | LiteLLM | Auth required for MCP creation; allowlisted definitions |

---

## 📦 Quick Start

### Platforms

ainish-coder is architecture-agnostic: macOS, Linux, WSL, and **native Windows**. On Windows the POSIX CLI runs through the bash that ships with Git for Windows (MSYS2 and Cygwin work too), so `cmd.exe`, PowerShell 5.1+, PowerShell 7, and Windows Terminal all work — no WSL required. Commands are shell-generic POSIX and `~` is your home directory on every platform.

### Installation

**macOS, Linux, WSL**

```bash
# Clone the repository
git clone https://github.com/nbiish/ainish-coder
cd ainish-coder

# Run setup (any POSIX shell: macOS Terminal, Linux, or Ubuntu/WSL)
chmod +x scripts/ainish-setup.sh
./scripts/ainish-setup.sh

# Reload your shell config
source ~/.zshrc  # or ~/.bashrc
```

**Windows (native)**

Requires [Git for Windows](https://git-scm.com/download/win) for the bash the CLI runs on, and optionally Python 3 for the skill-selection toggles (`winget install --id Python.Python.3.12 -e`).

```powershell
git clone https://github.com/nbiish/ainish-coder
cd ainish-coder

# Adds <repo>\bin to your user PATH; no elevation required
powershell -ExecutionPolicy Bypass -File .\scripts\ainish-setup.ps1
```

Close and reopen your terminal, then run `ainish-coder --rules`. The setup script prints what it changed; `-Uninstall` removes the PATH entry and restores the previous value exactly.

**WSL (alternative on Windows)**

```bash
cd /mnt/d/Code/ainish-coder && ./scripts/ainish-setup.sh
```

### Basic Usage

```bash
# Deploy core rules files (RECOMMENDED FIRST STEP)
ainish-coder --rules                     # Interactive: AGENTS.md, .gitignore, PQC security skills
                                         #   Prompts for: destination (home ~/ vs project), symlink preference

# Synchronize skills to home or project directory (with interactive candidate ingestion TUI)
ainish-coder --skills-sync               # Interactive: toggle skills to sync & ingest
                                         #   Prompts for: destination, symlink preference

# Deploy AGENTS.md alone
ainish-coder --agents                    # Interactive: destination + symlink prompts

# Deploy security files
ainish-coder --secure                    # Interactive: symlink prompt for each file

# Non-interactive mode (skip all prompts, use defaults)
ainish-coder --rules -y                  # AGENTS.md → target dir, copy mode
ainish-coder --skills-sync --link -y     # Sync skills → target dir, symlink mode
```

### Cross-machine federation (`--machine-sync`)

`--rules` distributes the rules to repos. `--machine-sync` distributes the **repository** to your other
machines — over the SSH link that already exists, without a Git remote in the middle.

```bash
ainish-coder --machine-sync              # send + receive with every registered peer
ainish-coder --machine-sync . --min-ram 64   # only peers with at least 64 GB
ainish-coder --machine-sync . --push     # send only   (--pull for receive only)
ainish-coder --machine-sync . --status   # what is already known here, no transfer
```

Peers live in `~/.config/ainish-coder/machines.txt`, one line each, named by capacity:

```ini
mac-18gb=self                       # this machine (exactly one self line)
windows-128gb=windows-128gb:D:/Code # an SSH alias plus the directory that CONTAINS repos
wsl-94gb=wsl-94gb:/mnt/d/Code
cloud-a100-80gb=cloud-a100-80gb:/srv/code
```

The name is `<kind>[-<accelerator>]-<ram>gb`, where the number is the RAM a job can actually be given
(installed for a bare-metal OS, cgroup-visible for a guest like WSL). That makes capacity a selector,
not a comment: `--min-ram 64` or `--kind windows` pick the machine, and an agent can read the same
names to decide where work belongs.

What crosses is refs, and only refs:

| Arrives as | What it is |
|---|---|
| `refs/remotes/<machine>/*` | every branch the other machine has |
| `refs/machine-sync/<machine>/<branch>` | that machine's **uncommitted work**, snapshotted as a commit |

A snapshot commit is the part `rsync` cannot do and `git push` will not: the sender's dirty tree —
tracked edits, new untracked files, staged-but-uncommitted changes — becomes a readable commit on the
receiver without touching its HEAD, branches, index, or working tree. Ignored files never cross: a
bundle carries commits, not a directory tree, so `bin/*.exe`, vector indexes, signing keys, and `.env`
files stay on the machine that produced them. If the peer's tree is clean, no snapshot is created and
any stale one is dropped.

A peer's checkout moves by default, but only on evidence: after a successful push, a peer that has the
**same branch** checked out **and** a clean working tree is fast-forwarded, so `main` lands on both
machines in one command. A dirty, differently-checked-out, or diverged peer is left alone and says so.
`--no-ff-peers` opts out for a run.

### Linking a repository once (`--machine-link`)

`--machine-sync` addresses a peer's copy as `<peer code root>/<repo name>`, which is only right when
every machine keeps every repo under one root with the same directory name. Real machines do not:
one may hold a repo at `D:/Code/repo` and another at `~/code-external/repo`. `--machine-link` records
the real path once and remembers it:

```bash
ainish-coder --machine-link . --peer windows-128gb --peer-path D:/Code/repo
ainish-coder --machine-link --list                     # what is linked here
ainish-coder --machine-sync --all                      # every linked repo, one command
ainish-coder --machine-link . --peer windows-128gb --remove   # unlink + drop the hook
```

Links live in `~/.config/ainish-coder/links.txt`, one `repo | peer | peer path` line each. Peer path
precedence in `--machine-sync` is: explicit `--peer-path`, then the recorded link, then the
name-based guess — and the resolved path is printed, so a guess is never silent.

Recording a link also arms a `post-commit`/`post-merge` hook in that repository. Commit here and the
linked machines receive it immediately; the next command you run there is already on the new state.
That removes the "remember to run the sync command on the other machine" step, which is the step that
gets skipped.

The hook **sends only**. Receiving moves *this* machine's branch, and doing that unattended from
inside a commit hook is how a machine ends up half-merged with nobody watching — `--pull` and
`--both` stay explicit. The hook is also scoped `--linked-only`, so a commit in one repo never pushes
it to every machine in the registry, and every probe is bounded so a peer that is off cannot block a
commit.

### Sync on save, not just on commit (`--watch`)

Hooks fire on commits, but people work in saves. Add `--watch` to the link command and a per-user
background service takes over:

```bash
ainish-coder --machine-link ~/code-external/repo --peer windows-128gb --peer-path D:/Code/repo --watch
ainish-coder --machine-watch --status      # installed? running? last cycle?
ainish-coder --machine-watch --uninstall   # stop it (links stay)
```

It runs the same proven sync path the hooks use, so every safety property is unchanged:

- an uncommitted **save** is committed with an honest `wip(<machine>)` subject whose body lists the
  changed paths, so `git log` stays readable instead of repeating a bare marker;
- a burst of saves becomes **one** commit (default 2s poll, 2s debounce);
- a peer whose tree is **dirty is never overwritten** — it is reported and skipped, because that
  peer has unsaved work and this tool must never be the reason it disappears;
- **divergence is reported, never auto-merged** — two lanes that meet are a human decision.

Why `wip(...)` commits are not squashed on push: every fast-forward decision uses
`merge-base --is-ancestor` on SHAs, and `--latest` attributes branches by SHA. Rewriting a commit that
a peer has already received would leave that peer holding a tip that no longer exists in its own
history — the exact divergence this tool exists to prevent. The fix for noisy history is a better
message, not a rewrite.

Installed as a launchd agent on macOS (`~/Library/LaunchAgents/`) or a systemd user unit on Linux,
both `RunAtLoad`/`Restart=always`, so it survives reboot and needs no sudo. State and a rolling log
live in `~/.config/ainish-coder/watch.state` and `watch.log`.

**On "instantaneous":** this host has neither `fswatch` nor `inotifywait`, and adding a
platform-specific dependency to a portable script is a worse trade than polling. A change is noticed
within the poll interval and acted on after the debounce settles — **seconds**, not milliseconds.
That is stated plainly rather than advertised as instant.

If you *do* install `fswatch` (or `brew install fswatch`), the watcher uses it automatically:
`--event-watch` subscribes to real file events, cutting the poll latency, and `--poll` forces the old
behaviour. Missing `fswatch` never breaks anything — it only means you wait for the timer. The mode in
use is shown by `--machine-watch --status`.

#### macOS: external-volume repositories work out of the box

If a linked repository lives on an external or removable volume, macOS TCC **blocks a launchd-spawned
process from reading it**. The symptom is subtle: `.git` is stat-able, but every cycle fails with
`Operation not permitted`, so the watcher looks installed and syncs nothing.

You do **not** need to grant anything. The watcher detects this and uses a transport that already has
access:

| Transport | When it is used |
|---|---|
| `direct` | this process can read the repo (the normal case) |
| `ssh` | TCC denies direct reads here, so the whole cycle runs over `ssh localhost`, under sshd's authority |

Detection happens automatically (`--transport auto`, the default); `--transport direct|ssh` pins it.
`--machine-watch --status` reports which one is in use. The only prerequisite for the `ssh` transport
is that loopback ssh works without a password:

```bash
ssh-copy-id localhost      # once, if `ssh localhost` still asks
```

If that prerequisite later breaks — a rotated key, a stopped sshd — the watcher no longer reports a
bare "sync failed". On the first failing cycle it probes loopback ssh once and tells you what broke
and how to fix it, distinguishing a permission denial (`ssh-copy-id localhost`) from a changed host
key (`ssh-keyscan`) from sshd being off (enable Remote Login). The result is recorded, so
`--machine-watch --status` shows `ssh: ok` or `ssh: BROKEN`.

Three things are deliberately *not* suggested, because they do not work: granting Full Disk Access to
your terminal (TCC is per-process, and a launchd agent is not a descendant of your terminal); adding
`/bin/bash` in the FDA picker (the panel will not navigate there); and copying `/bin/bash` elsewhere
(code signing kills the copy, `SIGKILL`/exit 137).

### Every branch on every machine (`--branches`)

Delivered refs land as `refs/remotes/<machine>/*`, which is not a branch you can check out — `git
checkout` on one gives a detached HEAD and `git branch` never lists it. So "synced" and "workable" are
different states, and a machine can hold every commit yet still have only `main` as a branch.

`--branches` closes that gap: every branch this machine has that the peer lacks is created there as a
real local branch. It is strictly additive —

| Peer's branch | Result |
|---|---|
| absent | created at this machine's tip |
| same tip | left alone |
| behind (an ancestor of ours) | fast-forwarded to our tip |
| ahead | left alone; our ref catches up on the next pull |
| **diverged** | **reported with both tips, never moved** |

The diverged case is why nothing here forces anything. Two machines can hold a branch of the same name
with no common ancestor, and overwriting either one deletes real work to make a report look clean.
`--machine-link`'s hook passes `--branches`, so a linked repo keeps every branch current on every
commit.

### Which copy is newest (`--latest`)

```bash
ainish-coder --machine-sync . --latest        # human table
ainish-coder --machine-sync --all --latest --json
```

Per branch: the newest commit, its timestamp, and which machine holds it. It asks every peer directly
in one bounded call each — cached refs are stale by definition, and the question "which copy should I
work from" is exactly the one a cache cannot answer. When two machines hold the same tip the report
says so; when they hold different commits at the same second it names both rather than picking one.

Ties and disagreements are labelled rather than resolved: `(+same tip elsewhere)` and
`(TIE: … differ at the same second)`.

---

## 🔄 OSA Framework (YOLO Mode)

The OSA (Orchestrated System of Agents) framework coordinates multiple CLI coding agents through fixed-order rotation with automatic fallback. All agents are equal peers — multiple arms of the same thinking tool.

**Agents**: Gemini, Claude, OpenCode, mini-swe-agent, kilo, crush

```bash
ainish-coder --skills-sync               # Synchronize explicitly selected skills
```

Security and tool-containment guidance is distributed through
[`skills-to-distribute/skills/ainish-security/SKILL.md`](skills-to-distribute/skills/ainish-security/SKILL.md).

---

### Usage Analytics (NEW)

All `ainish-coder` invocations are optionally tracked to `~/.cache/ainish-coder/usage.csv`:

```
timestamp,tool,subcommand,provider,exit_code,duration_ms,interactive,arg_count
2026-05-28T14:40:00Z,ainish-coder,--skills-sync,skill:gstack-coder,0,340,true,0
```

- **Granular tracking**: `--skills-sync` captures which specific skill was deployed; `--rules` tracks sub-operations
- **Opt-out**: Set `AINISH_NO_TRACKING=true` to disable all logging
- **Zero overhead when absent**: If `cmd-tracker` binary isn't on PATH, commands run directly
- **Auto-migration**: Old CSV schemas are backed up to `.bak` and re-created with the current header

Analyze usage with any CSV tool:
```bash
cat ~/.cache/ainish-coder/usage.csv | column -t -s,
```





## 🏗️ Architecture

The tool is built from directly discoverable shell components:

```
ainish-coder/
├── AGENTS.md                   # Universal agent instructions (OWASP-aligned)
├── bin/
│   ├── ainish-coder             # Main CLI: destination picker, interactive symlink prompts, --cli menu
│   ├── lib/                     # Shared shell libraries
│   │   ├── providers.sh         # Reads ~/.config/ainish-coder/providers.json (8 providers)
│   │   ├── hot_swap.sh          # Config rewrite + backup/restore per tool
│   │   ├── mcp_settings.sh      # MCP server flag parsing, env gen, pi extension gen
│   │   ├── picker.sh            # fzf-based interactive provider picker (NEW)
│   │   └── tracker.sh           # Shared cmd-tracker integration helper (NEW)
│   ├── pi                       # Pi wrapper (provider hot-swap + interactive picker)
│   ├── mini                     # mini-swe-agent wrapper (provider hot-swap + interactive picker)
│   ├── pqc-secrets              # Shell wrapper for Rust FIPS 203 secrets manager
│   ├── cmd-tracker              # Rust binary: CSV usage tracker (NEW)
│   └── security_gate.py         # PQC & zero-trust compliance scanner
├── src/
│   ├── *.sh                     # Shared utilities and deployment commands
│   ├── templates/               # Deployable boilerplate templates
│   ├── pqc-secrets/             # Rust: FIPS 203 secrets manager (ML-KEM-768)
│   └── cmd-tracker/             # Rust: CSV CLI usage tracker (stdlib-only) (NEW)
├── .agents/
│   ├── plans/                   # Per-task plans of record: {date}-{HH}-{slug}.md
│   ├── skills/                  # 18 distributable skill packs (20 dirs incl. 2 scroll-channel)
│   │   ├── 8thfire-scrolls/SKILL.md
│   │   ├── advisory-council/SKILL.md
│   │   ├── ainish-security/SKILL.md
│   │   ├── anishinaabe-cyberpunk-style/SKILL.md
│   │   ├── browser-skill/SKILL.md
│   │   ├── browser-use/SKILL.md
│   │   ├── comfyui-orchestration/SKILL.md
│   │   ├── document-enhancer/SKILL.md
│   │   ├── ghost-layer-injector/SKILL.md
│   │   ├── gstack-coder/SKILL.md
│   │   ├── modern-prompting/SKILL.md
│   │   ├── openscad-generator/SKILL.md
│   │   ├── pliny-research/SKILL.md
│   │   ├── pqc-secrets/SKILL.md
│   │   ├── question-me/SKILL.md
│   │   ├── remotion-video/SKILL.md
│   │   ├── typesafe-jev/SKILL.md
│   │   ├── video-knowledge-extractor/SKILL.md
│   │   └── wtf-is-going-on-mcp/SKILL.md
│   └── mcp-settings.json        # Global MCP server definitions
├── docs/                        # Documentation, research, signals
├── scripts/                     # Utility & tooling scripts
├── assets/                      # Static assets (images, SVGs)
├── .scrolls/                    # Ghost Layer repository & 8th Fire Protocols
└── llms.txt                     # Machine-readable project context (PRD anchor)
```

### Design Principles

| Principle | Implementation |
|-----------|---------------|
| **SOLID** | Single Responsibility per module; Open for extension via skills |
| **DRY** | Shared components; configs generated from templates |
| **KISS** | Shell-based CLI; no runtime dependencies beyond Bash |
| **YAGNI** | Skills loaded on demand |
| **Zero Trust** | Every tool call validated; all inputs sanitized; MCP servers treated as hostile |

### OOReDAct Decision Loop

All agent behavior follows the **OOReDAct** framework (OODA + ReAct + Chain of Draft):

| Step | Directive |
|------|-----------|
| **Observe** | Capture inputs without bias. ≤30 words. |
| **Orient** | Identify relevant facts and constraints relative to goal. |
| **Reason** | Draft ≤3 options; score each in ≤10 words (outcome, risk, cost). |
| **Decide** | Select best action. Output: `{ "action": "<name>" }`. Verify alignment. |
| **Act** | Execute via tool/agent. Feed result back to Observe. |

---

## 📚 Citation

```bibtex
@misc{ainish-coder2026,
  author/creator/steward = {ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians},
  title/description = {ainish-coder},
  type_of_work = {Indigenous digital creation/software incorporating traditional knowledge and cultural expressions},
  year = {2026},
  publisher/source/event = {GitHub repository under tribal sovereignty protections},
  howpublished = {\url{https://github.com/nbiish/ainish-coder}},
  note = {Authored and stewarded by ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Indigenous intellectual property, traditional knowledge systems (TK), traditional cultural expressions (TCEs), and associated data protected under tribal law, federal Indian law, treaty rights, Indigenous Data Sovereignty principles, and international indigenous rights frameworks including UNDRIP. All usage, benefit-sharing, and data governance are governed by the COMPREHENSIVE RESTRICTED USE LICENSE FOR INDIGENOUS CREATIONS WITH TRIBAL SOVEREIGNTY, DATA SOVEREIGNTY, AND WEALTH RECLAMATION PROTECTIONS.}
}
```

## ⚖️ Copyright

```markdown
Copyright © 2026 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), a descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band, and an enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Traditional Knowledge and Traditional Cultural Expressions. All rights reserved.
```

## 📜 License & Contributing

Please refer to the current [LICENSE](LICENSE) and [CONTRIBUTING.md](CONTRIBUTING.md) files for legal terms and contribution guidelines.

---

<div align="center">
  <p>◈──◆──◇ Made with ♥ by the AINISH community ◇──◆──◈</p>
</div>
