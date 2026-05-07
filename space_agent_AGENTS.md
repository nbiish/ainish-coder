# AGENTS.md

*Model-agnostic agent instruction format. Works across Claude, GPT, Gemini, Llama, and custom agent runtimes.*

## 🧪 The Minimalism Principle

A 2026 study of 138 repositories found that **LLM-generated context files reduce agent task success rates** while increasing inference cost by over 20%. Developer-written context files give only +4% improvement, and only when minimal and precise.

**Default stance:** if a constraint can be expressed elsewhere, it must not live here. Every line carries a cost.

## 🧬 Core Behavioral Rules (Invariant)

These rules survive any prompt context window. They define **how** the agent operates, not **what** it knows.

### 1. Output Mode

- Production-ready code only. No stubs, no simulated data, no placeholder comments.
- Small, focused changes over rewrites. Match existing codebase style.
- Never create files outside the workspace boundary.

### 2. Design Principles

| Principle | Rule |
|-----------|------|
| SOLID     | Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion |
| DRY       | Don't Repeat Yourself — extract repeated logic into reusable functions or modules |
| YAGNI     | You Ain't Gonna Need It — only build what is needed right now |
| KISS      | Keep It Simple, Stupid — the smallest working solution is best; avoid over-engineering |

### 3. Decision Loop — OOReDAct

Universal agent reasoning cycle (OODA + ReAct + minimal Chain of Draft):

| Step    | Action                                    | Constraint |
|---------|-------------------------------------------|------------|
| Observe | Capture inputs without bias               | ≤30 words |
| Orient  | Identify relevant facts and constraints   | Map to goal |
| Reason  | Draft ≤3 options, score each (outcome, risk, cost) | ≤10 words per score |
| Decide  | Select best action and verify alignment   | Output: `{"action": "<name>"}` |
| Act     | Execute, feed result back to Observe      | Validate output before next loop |

### 4. Git Commits

```
format: <type>(<scope>): <description>
types:  feat | fix | docs | refactor | test | chore | perf | ci

rules:
- Never include sensitive details in commit messages
- Use generic descriptions for security fixes
- Commits must pass pre-commit hooks
```

## 📦 Contextual Knowledge (Replaceable per Project)

These sections are **replaceable** per project. Swap them out without touching the invariant rules above.

### Toolchain Registry

Point to tools; never describe what they already enforce. **Toolchain First:** if a linter, formatter, or CI gate enforces a rule, delete it from AGENTS.md.

| Intent     | Command              | Authority                  |
|------------|----------------------|----------------------------|
| Build      | `pnpm build`       | Outputs to `dist/`       |
| Test       | `pnpm test`        | Vitest — see `vitest.config.ts` |
| Lint       | `pnpm lint --fix`  | Biome — see `biome.json` |
| Type check | `pnpm typecheck`   | `tsconfig.json` is authority |

### Judgment Boundaries

Rules that no tool can enforce. Use the three-tier system with positive constraints only (never negative instructions — see Pink Elephant Problem).

| Tier     | Meaning               | Examples |
|----------|-----------------------|----------|
| **GUARD** | Positive constraints  | Always use secrets manager for credentials; propose new deps with rationale; flag ambiguous specs and request clarification before building |
| **ASK**   | Human-in-the-loop     | Ask before migrations; ask before deleting files |
| **ALWAYS**| Proactive judgment    | Explain plan before code; handle all errors explicitly |

### Language Standards

| Language   | Standards |
|------------|-----------|
| Bash       | `set -euo pipefail`, `[[ ]]`, quote all vars |
| Python     | PEP 8, type hints, uv (primary), poetry (fallback), .venv |
| TypeScript | strict mode, ESLint, Prettier |
| Rust       | cargo fmt, cargo clippy, Result over panic |
| Go         | gofmt, go vet, Effective Go |
| C++        | clang-format, clang-tidy, C++20, RAII |

### Context Map

High-level project structure. Omit framework defaults the agent can infer.

```
packages:
  apps/web: Next.js frontend
  apps/api: Express REST API
  packages/ui: shared component library
  packages/db: Prisma schema, client, migrations
  packages/types: shared TypeScript types
```

## 📐 Format Rules for Model Compatibility

- **Plain Markdown only** — no XML wrappers, no model-specific tags
- **Separate invariant from contextual** — models cache invariant rules, swap context per project
- **Tables over prose** — structured data parses more reliably across models
- **Explicit constraints** — use "never", "always", "only" for non-negotiable rules
- **Avoid multi-line inline code in tables** — some parsers break on this
- **No temperature-dependent phrasing** — avoid "maybe", "consider", "perhaps" in rules

## 🗂️ Tool-Specific Filenames

| Tool            | Expected File       | Notes |
|-----------------|---------------------|-------|
| Cursor          | `.cursorrules`    | Also reads `AGENTS.md` |
| Windsurf        | `.windsurfrules`  | Also reads `AGENTS.md` |
| Claude Code     | `CLAUDE.md`       | Does not read `AGENTS.md`; case-sensitive |
| Codex / Copilot | `AGENTS.md`       | Native support |
| Zed             | `.rules`          | Priority-based; reads `AGENTS.md` at lower priority |

**Recommendation:** `ln -s AGENTS.md CLAUDE.md` to support Claude Code without duplication.

## 🧹 What to Audit Out

- Style rules a linter now enforces
- Library restrictions a tsconfig/ESLint rule enforces
- Persona definitions moved to skill files — replace with registry line
- Codebase overviews copied from README
- LLM-generated sections from `/init` — treat as draft, not final

## 🐘 Pink Elephant Problem

Telling an LLM what **not** to do puts that concept front-and-center in its attention mechanism. If AGENTS.md says "do not use tRPC", the token `tRPC` is highly active. Instead, fix the underlying cause — delete legacy utilities, add a linter rule — then delete the instruction.

**AGENTS.md is a diagnostic tool.** Every "don't" is a signal of structural friction to fix at the source.

---

*Research sources: [nbiish/ainish-coder AGENTS.md](https://github.com/nbiish/ainish-coder/blob/main/AGENTS.md), [ASDLC AGENTS.md Spec](https://asdlc.io/practices/agents-md-spec/), [Vercel agent evals](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals), [Gloaguen et al. (2026) arXiv:2602.11988](https://arxiv.org/abs/2602.11988).*
