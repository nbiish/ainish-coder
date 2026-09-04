# TASK.2026-09-04 — compiler security expert sync

llms.txt PRD anchor read. Worktree docs/security-expert-sync from main.
Video WU7SEq2hYpY identified: Domas on Bombal, compiler-vs-secure-code.
Extractors missing: yt-dlp installed; extractor lacked fallback.
Extractor rewritten: argparse, transcript-only fallback, PQC-first creds.
Also: retries+backoff, SSRF scheme guard, path containment, resume.
Frames aspect-preserving; VTT variant pick + rolling dedup.
Plugin verification: ruff, bandit, py_compile, detect-secrets, markdownlint.
Zero ruff; zero bandit medium+; secrets findings pre-existing examples.
Knowledge synced: code-security §2 (compiler TOCTOU, wipe barriers).
llm-security §15 (AI dual-use analyzer); production-security CI gates.
Root docs: AGENTS_CODE_SECURITY.md, AGENTS_LLM_SECURITY.md updated.
Research KB: research/video/WU7SEq2hYpY/ (KEY-FINDINGS + transcript).
Adversarial subagent review dispatched on all changed files.
DOX pass: content-only changes; no contract/structure/index shift.

####
Ship improved extractor + expert-synced security content; commit on task branch; operator confirms merge to main.
