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
        <img src="qr-stripe-donation.png" alt="Scan to donate" width="180"/>
        <p><a href="https://raw.githubusercontent.com/nbiish/license-for-all-works/8e9b73b269add9161dc04bbdd79f818c40fca14e/qr-stripe-donation.png">Donate via Stripe</a></p>
      </td>
      <td align="center" style="border: none; vertical-align: middle; padding: 20px;">
        <a href="https://www.buymeacoffee.com/nbiish">
          <img src="buy-me-a-coffee.svg" alt="Buy me a coffee" />
        </a>
      </td>
    </tr>
  </table>
  <hr width="50%">
</div>

## 🔥 Key Features

- **🎯 AGENTS.md Standard** — Universal agent instructions with OWASP-aligned security baselines
- **🧠 Skills System** — Reusable domain knowledge packs (security, browser automation, multimodal AI)
- **🏗️ Modular Architecture** — Clean Atom → Molecule → Protein structure
- **🤖 AI Tools** — Claude Code, GitHub Copilot, and Pi
- **🔄 OSA Framework** — CLI YOLO agents (Claude, OpenCode, mini, pi, kilo) with fixed-order rotation, automatic fallback, and git worktree isolation
- **🛡️ Security-First** — Zero Trust, PQC-compliant (FIPS 203/204/205), MCP hardening, supply chain integrity
- **⚡ One-Command Deploy** — Configs, skills, and security baselines in a single `ainish-coder` invocation
- **🔗 Smart File Management** — Copies configurations for tool-specific customization
- **🎭 Template Agent System** — Craft custom system prompts with expert guidance
- **📜 Scrolls & 8th Fire Protocols** — Deploy `llms.txt` and `.scrolls` for machine-readable project context, including the Ghost Layer Codex and Prompt Obliteration (Plinian Defense) for AI survival.

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
| **Code Security** | `.agents/skills/code-security/` | Safety-critical code engineering — input validation, auth, crypto, container security, supply chain integrity. Covers SQL injection, XSS, CSRF, SSRF, path traversal, MCP hardening, SBOM generation, and SLSA provenance. |
| **LLM Security** | `.agents/skills/llm-security/` | Securing probabilistic AI components — prompt injection defense, RAG context hygiene, PII redaction, tool risk classification, MCP allowlisting, inter-agent mTLS, circuit breakers, kill switches, and append-only audit ledgers. |
| **OSA** | `.agents/skills/osa/` | Multi-agent orchestration via fixed-order rotation across equal CLI coding agents (Gemini, Claude, OpenCode, mini, pi, kilo). YOLO mode execution with automatic fallback and git worktree isolation per subagent. |
| **Skyvern** | `.agents/skills/skyvern/` | AI-powered browser automation (self-hosted only). Vision LLM + Playwright hybrid with Planner→Agent→Validator architecture. Full BYOM support: OpenRouter, Ollama, any OpenAI-compatible endpoint. Never uses cloud API. |

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

### Installation

```bash
# Clone the repository
git clone https://github.com/nbiish/ainish-coder
cd ainish-coder

# Run setup
chmod +x ainish-setup.sh
./ainish-setup.sh

# Reload shell (macOS/Linux)
source ~/.zshrc  # or ~/.bashrc
```

### Basic Usage

```bash
# Deploy core rules files (RECOMMENDED FIRST STEP)
ainish-coder --rules                     # Deploy AGENTS.md, llms.txt/, and .gitignore
ainish-coder --agents-security           # Deploy AGENTS_LLM_SECURITY.md and AGENTS_CODE_SECURITY.md

# Deploy tool-specific configurations
ainish-coder --claude                    # Deploy Claude Code - rules, commands
ainish-coder --copilot                   # Deploy GitHub Copilot to .github/instructions/
ainish-coder --pi                        # Deploy Pi Coding Agent - extensions, agents, skills

# Deploy custom commands
ainish-coder --commands claude           # Deploy slash commands
ainish-coder --commands all              # Deploy to all applicable tools

# Agent customization
ainish-coder --template-agent            # Deploy template-agent.md for custom system prompts

# Deploy skills
ainish-coder --skills                    # Deploy all skills (OSA, security, Skyvern)

# Security deployments
ainish-coder --local-security            # Deploy LOCAL secret protection (git hooks + scripts)
ainish-coder --github-actions            # Deploy GitHub Actions workflows (CI/CD integration)

# Utility commands
ainish-coder --gitignore                 # Deploy comprehensive .gitignore
ainish-coder --critical                  # Deploy critical.md (Critical protocols)
ainish-coder --license                   # Deploy LICENSE file
ainish-coder --scrolls                   # Deploy .scrolls directory (Vital texts & prompts)
ainish-coder --mcp-recipes               # Deploy MCP recipes

# Ignore file deployment
ainish-coder --copilot-ignore            # Deploy .copilotignore
ainish-coder --all-ignores               # Deploy all ignore files at once
```

---

## 🛠️ Supported AI Tools

### IDE Extensions

| Tool | Config Flag | Commands Flag | Description |
|------|------------|---------------|-------------|
| **Claude Code** | `--claude` | `--commands claude` | Rules, commands, skills |
| **GitHub Copilot** | `--copilot` | N/A | `.github/copilot-instructions.md` |

### CLI Tools

| Tool | Config Flag | Commands Flag | Description |
|------|------------|---------------|-------------|
| **Pi Coding Agent** | `--pi` | N/A | Extensions, agents, skills, themes (`.pi/`) |

---

## 🔄 OSA Framework (YOLO Mode)

The OSA (Orchestrated System of Agents) framework coordinates multiple CLI coding agents through fixed-order rotation with automatic fallback. All agents are equal peers — multiple arms of the same thinking tool.

**Agents**: Claude, OpenCode, mini, pi, kilo

```bash
ainish-coder --skills                    # Deploy all skills
```

See [`.agents/skills/osa/SKILL.md`](.agents/skills/osa/SKILL.md) for the full framework specification, or [`.osa/llms.txt`](.osa/llms.txt) for the quick reference.



## 🏗️ Architecture

The tool is built with a modular, extensible design following the Atomic Design pattern:

```
ainish-coder/
├── AGENTS.md                   # Universal agent instructions (OWASP-aligned)
├── bin/ainish-coder             # Main CLI interface
├── dna/
│   ├── atoms/                   # Core utilities (colors, paths, validation, file ops)
│   ├── molecules/               # Deployment functions (deploy_*.sh)
│   └── proteins/                # Higher-level orchestration
├── .agents/skills/              # Portable AI skill packs
│   ├── code-security/SKILL.md   # Safety-critical code engineering
│   ├── llm-security/SKILL.md    # LLM & agentic AI security
│   ├── osa/SKILL.md             # Multi-agent orchestration (OSA framework)
│   ├── skyvern/SKILL.md         # AI browser automation (self-hosted)
│   ├── anishinaabe-cyberpunk-style/SKILL.md # Cultural aesthetic rules
│   └── modern-prompting/SKILL.md # OOReDAct advanced prompting
├── .osa/                        # OSA Framework quick reference
│   └── llms.txt                 # Machine-readable agent context
├── .configs/                    # Centralized tool-specific configs
├── .scrolls/                    # Ghost Layer repository & 8th Fire Protocols (llms.txt, llms-full.txt)
├── llms.txt/                    # Machine-readable project context
├── mcp_recipes/                 # MCP server recipes
└── .signals/                    # Signal detection configs
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
