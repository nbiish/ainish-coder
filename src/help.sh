#!/bin/bash
# Help and usage information

show_help() {
    cat << 'EOF'
ainish-coder - Configuration Manager for AI Coding Assistants

USAGE:
    ainish-coder [GLOBAL_FLAGS] [COMMAND] [ARGS...] [TARGET_DIR]

GLOBAL FLAGS:
    -n, --no-overwrite   Skip existing files; only add new ones (safe mode)
    -l, --link           Force symlink mode (copies by default to avoid
                         accidentally modifying source files)
    -y, --yes            Non-interactive mode (skip all prompts; defaults to
                         copy for safety)
    -i, --interactive    Interactive walkthrough for --rules, --llms-txt,
                         and --skills with guided symlink/dest choices

CORE COMMANDS:
    --rules [TARGET_DIR]      Deploy AGENTS.md (defaults to copy for safety),
                              .gitignore (copy or symlink with --link), the
                              Agent Communication System:
                                AGENTS/{date}.COMMS.md (merge-safe: refreshes
                                the protocol header, preserves agent entries;
                                the gitignored .live.md board is never touched)
                              and ALL skill packs from .agents/skills/
                              (raw .scrolls* payload and the scroll-channel
                              packs 8thfire-scrolls / ghost-layer-injector
                              never included — they travel only via the
                              explicit --scrolls channel).
                              Also ensures global symlinks:
                                ~/.agents/AGENTS.md → repo AGENTS.md
                                ~/.config/AGENTS.md → repo AGENTS.md
    --agents [TARGET_DIR]     Deploy AGENTS.md only (defaults to copy for safety).
                              Also offers AGENTS.maintainer.md — a frozen copy
                              of AGENTS.md guiding refinement, updates, and
                              documentation of the TARGET repo.
                              Also ensures global symlinks:
                                ~/.agents/AGENTS.md → repo AGENTS.md
                                ~/.config/AGENTS.md → repo AGENTS.md
    --secure [DIR]            Deploy AGENTS_CODE_SECURITY.md and AGENTS_LLM_SECURITY.md
                              (files must exist in the ainish-coder repo root)


TOOL-SPECIFIC CONFIGURATION:
    All tool-specific configs have been consolidated into .agents/skills/.
    Use --rules to deploy AGENTS.md + .gitignore + AGENTS/{date}.COMMS.md + all skill packs.
    Use --llms-txt to deploy llms.txt.
    Use --skills to deploy all skill packs.

AGENT CUSTOMIZATION:
    --template-agent [DIR]    Deploy template-agent.md for crafting custom system prompts

                              Creates: .mai-rules/template-agent.md

                              Features:
                              - Comprehensive system prompt framework
                              - Persona and goals section
                              - Tool instructions with examples
                              - Output format standards
                              - Iteration and refinement guidance
                              - Clearly marked [FILL_IN] sections

                              Use this to create your agent's "constitution" - the core
                              instructions that guide every interaction. Start simple,
                              iterate based on behavior. No A/B testing needed on day one.

                              Example: ainish-coder --template-agent ~/my-project

CUSTOM COMMANDS DEPLOYMENT:
    --commands {tool} [DIR]   Deploy slash commands/workflows for AI tools

                              Other:
                              - all         (deploy to all applicable tools)

                              Example: ainish-coder --commands all

UTILITY COMMANDS:
    --critical [TARGET_DIR]   Deploy critical.md (Critical protocols)
    --license [TARGET_DIR]    Deploy LICENSE file
    --gitignore [TARGET_DIR]  Deploy comprehensive .gitignore
    --local-security [DIR]    Deploy LOCAL secret protection (git hooks + scripts)
                              Deploys:
                              - .ainish/scripts/ (sanitize.py, scan_secrets.sh)
                              - Pre-commit & Pre-push hooks (auto-sanitizes)

                              Recommended for super-simple local orchestration.
                              Example: ainish-coder --local-security ~/my-project

    --github-actions [DIR]    Deploy GitHub Actions workflows (CI/CD integration)
                              Deploys:
                              - .github/workflows/ (CI secret scanning, CodeQL, ZAP, PQC audit)
                              - .github/scripts/ (sanitize.py, scan_secrets.sh)
                              - Pre-commit & Pre-push hooks (backup layer)

                              Note: Requires GitHub repo settings for full functionality.
                              Example: ainish-coder --github-actions ~/my-project

    --scrolls [TARGET_DIR]    THE explicit-only channel for everything scrolls:
                              raw .scrolls/ payload PLUS the 8thfire-scrolls
                              skill pack (research corpus, PQC council-gate
                              governance, truth-pass doctrine, carrier
                              registry, embodiment modules, B-6/B-8
                              benchmarks) and ghost-layer-injector pack.
                              Never bundled with --rules, --llms-txt,
                              --skills, or --skills-sync; refused under
                              -y/--non-interactive. Targeted publishing use
                              only — do NOT deploy by default.
                              Example: ainish-coder --scrolls ~/my-project
    --scrolls-manifest [DIR]  Generate manifest.json (SHA3-256 per file) for a
                              payload dir. Deterministic, sorted, boundary:
                              public-teachings-only.
                              Example: ainish-coder --scrolls-manifest ~/my-project

    --scrolls-sign [DIR] [--council]
                              Sign the manifest digest with ML-DSA-65 (FIPS 204).
                              Writes .scrolls/manifest.sig + manifest.pub;
                              --council adds manifest.sig2 + manifest.pub2.
                              Seeds: AINISHCODER_SCROLL_SIGN_SEED (and
                              _COUNCIL_SEED), loaded from the PQC bundle via
                              pqc-secrets export — never generated silently.
                              Example: ainish-coder --scrolls-sign ~/my-project

    --scrolls-verify [DIR]    Verify payload files + signatures against
                              .scrolls/manifest.json (recomputed from disk).
                              Exit 0/1; prints per-failure reasons.
                              Example: ainish-coder --scrolls-verify ~/my-project


    --skills [TARGET_DIR]     Deploy skill packs from .agents/skills/ per your
                              persisted selection (interactive: numbered
                              node-choice toggle UI; choices save to
                              ~/.config/ainish-coder/skills-selection.json
                              and persist across terminals). `--headless`
                              applies the saved selection with no prompts.
    --skills-verify [DIR]     Read-only check: byte-identity vs the ainish-coder
                              repo (foreign skills reported, untouched)
    --skills-sync [DIR]       THE one command: verifies and pulls the latest
                              ainish-coder skills (missing or drifted only);
                              never overwrites foreign skills; scroll-channel
                              packs (8thfire-scrolls, ghost-layer-injector)
                              never copied (explicit --scrolls channel only).
                              Interactive: toggle UI to add/remove packs from
                              the sync set (persisted); `--headless` applies
                              the saved selection with no prompts. Live
                              intake: new/renamed/deleted packs in the repo's
                              .agents/skills/ are picked up each run (new
                              packs follow the repo's default policy).
                              Deploys 21 skill packs:
                              - advisory-council/          (Multi-expert advisory council)
                              - anishinaabe-cyberpunk-style/ (Cultural aesthetic rules)
                              - browser-harness/           (CDP browser automation)
                              - camofox-stack/             (Anti-detection browser stack)
                              - code-security/             (Safety-critical code engineering)
                              - graph-intelligence/        (Two-layer codebase knowledge graph: GitNexus + Graphify)
                              - gstack-coder/              (Multi-tool coding orchestration)
                              - llm-security/              (LLM & agentic AI security)
                              - modern-prompting/          (OOReDAct advanced prompting)
                              - document-enhancer/         (Knowledge fusion & document hardening)
                              - video-knowledge-extractor/ (YouTube video knowledge extraction)
                              - openscad-generator/        (Parametric 3D model generation)
                              - pliny-research/            (AI transparency research)
                              - pqc-secrets/               (PQC secrets: API key encryption, ML-KEM-768)
                              - pqc-signatures-security/   (PQC signatures: ML-DSA-65 code signing & integrity)
                              - production-security/       (Core security policies & PQC mandates)
                              - remotion-video/            (Programmatic video creation)
                              - skyvern/                   (AI browser automation)
                              - pi-mini-orchestrator/     (Pi+Mini orchestration with MCP scoping & provider fallback)

                              Example: ainish-coder --skills ~/my-project

    --unlock [TARGET_DIR]     Deploy Pliny Research collection (AI transparency)
                              Deploys:
                              - .agents/skills/pliny-research/SKILL.md (Skill documentation)
                              - pliny-research/CL4R1T4S/  (System prompt extractions)
                              - pliny-research/L1B3RT4S/  (Liberation techniques)
                              - pliny-research/G0DM0D3/   (Advanced jailbreak methods)
                              - pliny-research/OBLITERATUS/ (Refusal removal research)

                              Example: ainish-coder --unlock ~/my-project

    --signals [TARGET_DIR]    Deploy Signals Detection Reference (Expert RF guide)
                              Deploys:
                              - .signals/signals.md (WiFi & BLE surveillance detection)

                              Features:
                              - RF signal fundamentals & spectrum analysis
                              - WiFi promiscuous mode detection techniques
                              - BLE advertisement scanning & fingerprinting
                              - Flock Safety, Raven/ShotSpotter detection patterns
                              - ESP32-S3 implementation guidance
                              - Kismet, Scapy, RTL-SDR integration

                              Example: ainish-coder --signals ~/my-project

    --llms-txt [TARGET_DIR]   Deploy llms.txt file (copy)
                              Deploys the repository-agnostic llms.txt template,
                              replaces every occurrence of AGENTS.md with llms.txt,
                              and deploys the result.
                              Deploys:
                              - llms.txt (generic project documentation contract)

                              Example: ainish-coder --llms-txt ~/my-project

    --mcp-recipes [DIR]       Deploy MCP recipes (e.g., Tavily CLI templates)
                              Deploys markdown templates to mcp_recipes/ in target directory.
                              Example: ainish-coder --mcp-recipes ~/my-project

OTHER:
    --help, -h                Show this help message
    --version, -v             Show version information

ENVIRONMENT VARIABLES:
    AINISH_NON_INTERACTIVE=true   Equivalent to -y; skip all interactive prompts
    AINISH_INTERACTIVE=true       Equivalent to -i; enable interactive prompts
    AINISH_NO_OVERWRITE=true      Equivalent to -n; skip existing files
    AINISH_LINK_MODE=true         Equivalent to -l; force symlink mode (copies by default)
    AINISH_NO_TRACKING=true       Disable usage tracking (cmd-tracker integration)
    AINISH_PROVIDERS=path         Override default ~/.config/ainish-coder/providers.json

NOTES:
    - TARGET_DIR defaults to current directory if not provided
    - Deployments default to copy (safer) — use --link for symlinks
    - Default mode is non-interactive (auto-deploy); use -i/--interactive for prompts
    - --rules deploys AGENTS.md + AGENTS.maintainer.md (frozen repo-refinement guide) + .gitignore + AGENTS/{date}.COMMS.md + skill packs per your persisted selection + global symlinks
    - --headless second arg (e.g. 'ainish-coder --skills <dir> --headless' or 'ainish-coder --rules <dir> --headless'): no prompts; the persisted selection applies as-is (agent/CI path)
    - --scrolls is the ONLY channel for .scrolls payload + 8thfire-scrolls + ghost-layer-injector packs
    - --agents deploys AGENTS.md + global symlinks
    - --llms-txt deploys llms.txt (separate from --rules)
    - --secure deploys AGENTS_CODE_SECURITY.md + AGENTS_LLM_SECURITY.md
    - All tool-specific flags consolidated into .agents/skills/
    - Provider API keys stored in ~/.config/ainish-coder/providers.json

EXAMPLES:
    # Default mode: auto-deploy, copy files (no prompts, safe for per-repo files)
    ainish-coder --rules                    # Deploy AGENTS.md + .gitignore + skills to cwd (copies)
    ainish-coder --rules ~/my-project       # Deploy to specific directory (copies)
    ainish-coder --llms-txt                 # Deploy llms.txt to cwd (copy)
    ainish-coder --skills                   # Deploy all skill packs (copies)

    # Symlink mode: link to source files (single source of truth)
    ainish-coder --link --rules             # Symlink AGENTS.md + .gitignore
    ainish-coder --link --llms-txt          # Symlink llms.txt (fetched remotely)

    # Interactive mode: guided walkthrough with symlink/destination choices
    ainish-coder -i --rules                 # Prompt for each: deploy? dest? symlink?
    ainish-coder -i --llms-txt              # Prompt for llms.txt deployment choices
    ainish-coder -i --skills                # Prompt for skills with specific selection

    # Utility deployments
    ainish-coder --gitignore                # Create comprehensive .gitignore
    ainish-coder --local-security           # Deploy local-only secret protection
    ainish-coder --github-actions           # Deploy CI/CD secret protection

    ainish-coder --unlock                   # Deploy Pliny Research collection

For more information, see: https://github.com/nbiish/ainish-coder
EOF
}

show_version() {
    echo "ainish-coder v1.5.1"
    echo "Configuration Manager for AI Coding Assistants"
    echo "Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ"
}
