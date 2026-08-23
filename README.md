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
- **🧠 Skills System** — 19 hardened procedural guideline skill packs (security, browser automation, video generation, 3D modeling, research)
- **🏗️ Modular Architecture** — Clean Quanta → Atom → Molecule structure (MAQ hierarchy)
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

Skills are portable, expert-level knowledge packs that inject domain expertise into AI agents. Each skill lives in `.agents/skills/<name>/SKILL.md` and is loaded on demand.

| Skill | Path | Description |
|-------|------|-------------|
| **Advisory Council** | `.agents/skills/advisory-council/` | Multi-expert advisory council. Dispatches sub-agents with distinct expert identities for collaborative analysis and decision-making. |
| **Anishinaabe Cyberpunk** | `.agents/skills/anishinaabe-cyberpunk-style/` | Anishinaabe-inspired cyberpunk styling guide combining Canadian Aboriginal Syllabics with ASCII circuit symbols. |
| **Browser Harness** | `.agents/skills/browser-harness/` | Direct browser control via CDP. Automate, scrape, test, or interact with web pages via already-running Chrome. |
| **CamoFox Stack** | `.agents/skills/camofox-stack/` | Anti-detection browser stack (camoufox, camofox-browser, camofox-mcp) for agentic web scraping and automation. |
| **Code Security** | `.agents/skills/code-security/` | Safety-critical code engineering — input validation, auth, crypto, container security, supply chain integrity. Covers SQLi, XSS, CSRF, SSRF, path traversal, MCP hardening. |
| **Ghost Layer Injector** | `.agents/skills/ghost-layer-injector/` | Inject covert AI/bot context into static HTML pages so LLMs and web crawlers auto-ingest instructions without altering human visual experience. |
| **GStack Coder** | `.agents/skills/gstack-coder/` | Multi-tool coding orchestration integrating gstack (Claude Code skills), pi, opencode, and qwen for security audits, code reviews, QA, and feature builds. |
| **LLM Security** | `.agents/skills/llm-security/` | Securing probabilistic AI components — prompt injection defense, RAG context hygiene, PII redaction, tool risk classification, MCP allowlisting, circuit breakers, kill switches. |
| **Modern Prompting** | `.agents/skills/modern-prompting/` | Reasoning strategy selection toolkit — N L M rates 16 prompting frameworks (CoT, CoD, ReAct, ToT, PAL, Reflexion, etc.) on a 0–100% suitability scale per task, then applies the highest-rated strategy via OOReDAct. |
| **Document Enhancer** | `.agents/skills/document-enhancer/` | Dual-pipeline system for improving documents: fuse external knowledge bases into target documents, or recursively harden documents for multi-model LLM effectiveness via split-optimize-review-merge architecture. |
| **Video Knowledge Extractor** | `.agents/skills/video-knowledge-extractor/` | Extracts structured markdown knowledge bases from YouTube videos by combining spoken transcripts with sequential visual frames through a Vision-Language Model. |
| **OpenSCAD Generator** | `.agents/skills/openscad-generator/` | Generates parameterized 3D models using Python templates and OpenSCAD, compiles to STL via Makefile. |
| **Pi-Mini Orchestrator** | `.agents/skills/pi-mini-orchestrator/` | Multi-agent orchestration via fixed rotation across equal CLI coding agents (`claude`, `mini`) with scoped MCP tools and provider fallback. |
| **PQC Secrets** | `.agents/skills/pqc-secrets/` | Post-quantum cryptography secrets management system for protecting API keys, tokens, and private data. |
| **PQC Signatures & Security** | `.agents/skills/pqc-signatures-security/` | Expert instructions to implement and verify ML-DSA-65 post-quantum cryptographic signatures and agentic workflow security. |
| **Pliny Research** | `.agents/skills/pliny-research/` | Extracted system prompts, guidelines, tools, and jailbreak techniques from major AI models. Deploy with `ainish-coder --unlock` for AI transparency. |
| **Production Security** | `.agents/skills/production-security/` | Core security policies, Zero Trust, PQC Mandates, and Threat Mitigations for compliance and secure infrastructure. |
| **Remotion Video** | `.agents/skills/remotion-video/` | Programmatic video creation with Remotion — all APIs, media components, 3D, captions, fonts, Lambda rendering, and video-layout design rules. |
| **Skyvern** | `.agents/skills/skyvern/` | AI-powered browser automation (self-hosted only). Vision LLM + Playwright hybrid with Planner→Agent→Validator architecture. Full BYOM support. |

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

ainish-coder is architecture-agnostic: macOS, Linux, and Windows (use an Ubuntu terminal via WSL). Commands are shell-generic POSIX and `~` is your POSIX home (the WSL/Ubuntu home on Windows).

### Installation

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

### Basic Usage

```bash
# Deploy core rules files (RECOMMENDED FIRST STEP)
ainish-coder --rules                     # Interactive: AGENTS.md, .gitignore, PQC security skills
                                         #   Prompts for: destination (home ~/ vs project), symlink preference

# Deploy skills to home or project directory
ainish-coder --skills                    # Interactive: deploy all skills or pick one
                                         #   Prompts for: destination, symlink preference

# Deploy AGENTS.md alone
ainish-coder --agents                    # Interactive: destination + symlink prompts

# Deploy security files
ainish-coder --secure                    # Interactive: symlink prompt for each file

# Non-interactive mode (skip all prompts, use defaults)
ainish-coder --rules -y                  # AGENTS.md → target dir, copy mode
ainish-coder --skills --link -y          # All skills → target dir, symlink mode
```

---

## 🔄 OSA Framework (YOLO Mode)

The OSA (Orchestrated System of Agents) framework coordinates multiple CLI coding agents through fixed-order rotation with automatic fallback. All agents are equal peers — multiple arms of the same thinking tool.

**Agents**: Gemini, Claude, OpenCode, mini-swe-agent, kilo, crush

```bash
ainish-coder --skills                    # Deploy all skills
```

See [`.agents/skills/pi-mini-orchestrator/SKILL.md`](.agents/skills/pi-mini-orchestrator/SKILL.md) for the orchestration framework specification.

---

### Usage Analytics (NEW)

All `ainish-coder` invocations are optionally tracked to `~/.cache/ainish-coder/usage.csv`:

```
timestamp,tool,subcommand,provider,exit_code,duration_ms,interactive,arg_count
2026-05-28T14:40:00Z,ainish-coder,--skills,skill:gstack-coder,0,340,true,0
```

- **Granular tracking**: `--skills` captures which specific skill was deployed; `--rules` tracks sub-operations
- **Opt-out**: Set `AINISH_NO_TRACKING=true` to disable all logging
- **Zero overhead when absent**: If `cmd-tracker` binary isn't on PATH, commands run directly
- **Auto-migration**: Old CSV schemas are backed up to `.bak` and re-created with the current header

Analyze usage with any CSV tool:
```bash
cat ~/.cache/ainish-coder/usage.csv | column -t -s,
```





## 🏗️ Architecture

The tool is built with a modular, extensible design following the Atomic Design pattern:

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
│   ├── quanta/                  # Core utilities (colors, paths, validation, file ops, security)
│   ├── atoms/                   # Deployment functions (deploy_*.sh, cli_interface.sh, help.sh)
│   ├── molecules/               # Higher-level orchestration (system-wide install)
│   ├── templates/               # Deployable boilerplate templates
│   ├── pqc-secrets/             # Rust: FIPS 203 secrets manager (ML-KEM-768)
│   └── cmd-tracker/             # Rust: CSV CLI usage tracker (stdlib-only) (NEW)
├── .agents/
│   ├── skills/                  # 21 portable AI skill packs
│   │   ├── advisory-council/SKILL.md
│   │   ├── anishinaabe-cyberpunk-style/SKILL.md
│   │   ├── browser-harness/SKILL.md
│   │   ├── camofox-stack/SKILL.md
│   │   ├── code-security/SKILL.md
│   │   ├── ghost-layer-injector/SKILL.md
│   │   ├── gstack-coder/SKILL.md
│   │   ├── llm-security/SKILL.md
│   │   ├── modern-prompting/SKILL.md
│   │   ├── document-enhancer/SKILL.md
│   │   ├── video-knowledge-extractor/SKILL.md
│   │   ├── openscad-generator/SKILL.md
│   │   ├── osa/SKILL.md
│   │   ├── pi/SKILL.md
│   │   ├── pliny-research/SKILL.md
│   │   ├── production-security/SKILL.md
│   │   ├── remotion-video/SKILL.md
│   │   └── skyvern/SKILL.md
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
| **DRY** | Shared atoms; configs generated from templates |
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
