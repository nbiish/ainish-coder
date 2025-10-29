# KNOWLEDGE_BASE

This directory contains system documentation and reference materials that should NOT be deployed as rules to AI tools.

## Purpose

The KNOWLEDGE_BASE separates:
- **System Documentation** (belongs here) - How the ainish-coder system works
- **AI Rules** (belongs in TIER_*_RULES/) - Instructions for AI coding assistants

## Contents

### AI-TOOL-CONFIG-LOCATIONS.md

Comprehensive reference for where each AI coding tool reads configuration files:
- Native configuration locations for 8 major AI tools
- What ainish-coder deploys vs. what tools natively support
- Platform-specific paths (macOS/Windows/Linux)
- Official documentation links

## Why This Exists

Previously, `global-rules-hierarchy.md` was incorrectly placed in `TIER_2_RULES/` and would get deployed to projects as an AI rule. This caused confusion because:

1. It's documentation ABOUT the system, not instructions FOR AI tools
2. It would be deployed to `.clinerules/`, `.roo/`, etc. when not needed
3. Mixed concerns: system architecture vs. AI assistant instructions

## Guidelines

**Belongs in KNOWLEDGE_BASE:**
- Architecture documentation
- How ainish-coder works internally
- Tool configuration reference
- Development notes
- Research findings

**Belongs in TIER_*_RULES:**
- Instructions for AI coding assistants
- Code quality guidelines
- Security rules
- Style guides
- Prompting strategies

---

**Maintained By:** ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi)  
**Created:** October 29, 2025
