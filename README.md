# ainish-coder

A configuration manager for AI coding assistants. Deploys Indigenous-governed MAI RULES, `AGENTS.md`, tiered guidance, and tool-specific prompts so every IDE, CLI, and orchestrator follows a single trusted source of truth.

<div align="center">
  <hr width="50%">
  <h3>Support This Project</h3>
  <div style="display: flex; justify-content: center; gap: 20px; margin: 20px 0; align-items: center;">
    <div>
      <h4>Stripe</h4>
      <img src="qr-stripe-donation.png" alt="Scan to donate" width="160"/>
      <p><a href="https://raw.githubusercontent.com/nbiish/license-for-all-works/8e9b73b269add9161dc04bbdd79f818c40fca14e/qr-stripe-donation.png">Donate via Stripe</a></p>
    </div>
    <div>
      <a href="https://www.buymeacoffee.com/nbiish"><img src="buy-me-a-coffee.png" alt="Buy me a coffee" width="180"/></a>
    </div>
  </div>
  <hr width="50%">
</div>

## Quick Start

```bash
git clone https://github.com/nbiish/ainish-coder
cd ainish-coder
chmod +x ainish-setup.sh && ./ainish-setup.sh
source ~/.zshrc
```

### Typical Workflow

```bash
ainish-coder --rules                 # Seed AGENTS.md, MAIRULES.md, critical.md, .gitignore, llms.txt
ainish-coder --tier all              # Append tier guidance into MAIRULES.md
ainish-coder --cursor --copilot      # Deploy tool-specific rules
ainish-coder --commands cursor       # Deploy slash commands/workflows
ainish-coder --github-actions        # Enable secret scanning workflows
```

## Architecture

The CLI follows the **DNA Design** pattern:

| Layer | Path | Purpose |
|-------|------|---------|
| **Atoms** | `dna/atoms/` | Path, validation, colors, and security utilities |
| **Molecules** | `dna/molecules/` | Deployment scripts (e.g., `deploy_copilot.sh`) |
| **Proteins** | `dna/proteins/` | Orchestration flows such as `install.sh` |

## Command Reference

| Command | Purpose |
|---------|---------|
| `--rules` | Deploy AGENTS.md, MAIRULES.md, `critical.md`, `.gitignore`, `llms.txt` |
| `--tier {0-4\|all}` | Append tiered rules (docs, security, culture, prompting) |
| `--cursor`, `--windsurf`, `--copilot`, `--trae`, etc. | Copy AGENTS/MAIRULES into tool-native directories |
| `--commands {tool\|all}` | Install slash commands, workflows, TOML/YAML recipes per tool |
| `--osa` | Distribute orchestration schemas via `OSA.md` |
| `--template-agent` | Generate `.mai-rules/template-agent.md` |
| `--github-actions` | Provision secret scanning and sanitization workflows |
| `--gitignore` | Deploy curated multi-platform `.gitignore` |
| `--critical` | Copy `critical.md` sovereignty instructions |

## Supported Tools

| Tool | Config Flag | Commands Flag | Output |
|------|-------------|---------------|--------|
| Cursor | `--cursor` | `--commands cursor` | `.cursor/rules/*.md`, `.cursor/commands/*.md` |
| Roo Code | `--roocode` | `--commands roocode` | `.roo/rules/*.md`, `.roo/commands/*.md` |
| WindSurf | `--windsurf` | `--commands windsurf` | `.windsurf/rules/*.md`, `.windsurf/workflows/*.md` |
| Cline | `--cline` | `--commands cline` | `.clinerules/*.md` (rules only) |
| Continue Dev | `--continue` | `--commands continue` | `.continue/rules/`, config guidance |
| GitHub Copilot | `--copilot` | N/A | `.github/copilot-instructions.md` |
| Gemini CLI | `--gemini` | `--commands gemini-cli` | `.gemini/*.md`, `.gemini/commands/*.toml` |
| Qwen Code | `--qwen` | `--commands qwen` | `QWEN.md`, `.qwen/commands/*.toml` |
| Goose | N/A | `--commands goose` | `.goose/recipes/*.yaml` |
| Trae | `--trae` | N/A | `.trae/rules/*.md` |

> **Note**: Cline does **NOT** support custom slash commands—only `.clinerules` files with mandatory instructions.

## Tier Rules

Rules organized by priority:

| Tier | Focus | File |
|------|-------|------|
| **TIER_0** | Documentation protocols | `docs-protocol.md` |
| **TIER_1** | Code security | `uv-python.md`, `rust-cargo.md` |
| **TIER_2** | Prompt security | `code-security.md`, `prompt-security.md` |
| **TIER_3** | Cultural styling | `anishinaabe-cyberpunk-style.md` |
| **TIER_4** | Advanced prompting | `modern-prompting.md` |

```bash
ainish-coder --tier 2    # Append TIER_2 to MAIRULES.md
ainish-coder --tier all  # Append all tiers
```

## Extended Modules

- **Template Agent System** — `--template-agent` for persona, tool-use, QA checklists
- **OSA Orchestrator Patterns** — `--osa` for execution patterns and sub-agent mappings
- **GitHub Actions Secret Protection** — `--github-actions` for local + CI scanning

## Documentation

| Resource | Description |
|----------|-------------|
| `dna/README.md` | DNA Design pattern overview |
| `knowledge-base/` | Deployment notes and verification reports |
| `AGENTS.md` & `MAIRULES.md` | Canonical governance documents |
| `critical.md` | Licensing and synchronization steps |

## Important Links

- [LICENSE](LICENSE)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [Terms-of-Service.md](Terms-of-Service.md)
- [Privacy-Policy.md](Privacy-Policy.md)
- [critical.md](critical.md)

---

## Scholarly Citation

```bibtex
@misc{ainish-coder2025,
  author/creator/steward = {ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), 
    also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as 
    Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), 
    descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled 
    member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians},
  title/description = {ainish-coder},
  type_of_work = {Indigenous digital creation/software incorporating traditional 
    knowledge and cultural expressions},
  year = {2025},
  publisher/source/event = {GitHub repository under tribal sovereignty protections},
  howpublished = {\url{https://github.com/nbiish/ainish-coder}},
  note = {This work embodies Indigenous intellectual property, traditional knowledge 
    systems (TK), traditional cultural expressions (TCEs), and associated data protected 
    under tribal law, federal Indian law, treaty rights, Indigenous Data Sovereignty 
    principles, and international indigenous rights frameworks including UNDRIP. All usage, 
    benefit-sharing, and data governance are governed by the COMPREHENSIVE RESTRICTED USE 
    LICENSE FOR INDIGENOUS CREATIONS WITH TRIBAL SOVEREIGNTY, DATA SOVEREIGNTY, AND WEALTH 
    RECLAMATION PROTECTIONS.}
}
```

---

<div align="center">
  <p>◈──◆──◇ Made with ♥ by the AINISH community ◇──◆──◈</p>
</div>

**Copyright © 2025** ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), a descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band, and an enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Traditional Knowledge and Traditional Cultural Expressions. All rights reserved.
