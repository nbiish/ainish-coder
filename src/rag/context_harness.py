#!/usr/bin/env python3
"""Context harness: per-repo learned configuration for `ainish-rag --context`.

The design and its evidence base are in `research/context-priming-master/`. This module is the
whole implementation of that design, kept separate from `rag.py` because the engine is stdlib-only
and already 7,854 lines; a self-contained module with no third-party imports keeps both properties.

Three surfaces, all of them DECLARATIVE DATA — nothing here can execute:

    prime-profile.json          bounded scalars + short token lists (retrieval tuning)
    skills/<name>/SKILL.md      an on-demand procedure, staged, never auto-loaded
    skills/<name>/scripts/*.py  a helper shipped with its skill, static-checked

Two things are deliberately absent, and their absence is the design:

  * No always-on prose. A skill costs nothing until invoked; always-on text is paid on every run.
    That is why the practitioner video's self-bloat failure cannot recur here (findings §1).
  * No accept-path that measures only the prime's own output. Phase 0 proved that gate is circular
    (`08-phase0-findings.md`), so acceptance requires an OUTCOME signal — see `outcome_signal()`.

Everything that refuses, refuses in code. See `validate_profile()` / `validate_tree()`.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

HARNESS_DIR = ".agents"        # relative to repo root
HARNESS_SUBDIR = "context-harness"
PROFILE_NAME = "prime-profile.json"
PROFILE_FORMAT = "ainish-rag/prime-profile/v1"
SKILL_PREFIX = "learned-"
SKILL_BODY_MAX = 4000
SKILL_SCRIPT_MAX = 8000
MAX_LIVE_SKILLS = 8
# Was 3. Raised deliberately, not to hide a bloat failure: the six lessons this repo had already
# learned (cheap-form-first, contrast-not-score, evidence-as-files, frozen-baseline-first,
# improver-blind-to-its-gate, cap-growth-in-the-unit) are six DIFFERENT procedures, and a cap of 3
# would have meant deleting three real lessons to satisfy a number. The cap still exists because an
# unbounded toolbox is the failure it guards; 8 keeps it bounded while fitting what is actually
# there. Each skill remains on-demand, so the cost is zero until one is invoked.
MAX_SKILL_BODY_CHARS = SKILL_BODY_MAX
DOMAIN_PRIOR_MAX = 12
TERM_MAX = 32
TERM_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")
NAME_RE = re.compile(r"^" + re.escape(SKILL_PREFIX) + r"[a-z0-9][a-z0-9_-]*$")

# Markers of the measurement itself: the names of the acceptance signals this system computes. A learned
# artefact naming one of these could optimise the gate rather than the thing being gated. The list is
# deliberately narrow — it is signal NAMES, not words like "threshold" or "acceptance", which a lesson
# ABOUT guarding a gate legitimately uses (and which an earlier, broader list wrongly rejected).
# The improver is never shown these strings; this is the code-level backstop.
ACCEPTANCE_MARKERS = (
    "coverage", "concentration", "freshness", "redundancy",
    "win_rate", "winrate", "noul", "decision_score",
)

# Import allowlist for learned helper scripts. No networking, no subprocess, no sockets: a learned
# helper must be a pure transformation of files it is handed.
SCRIPT_ALLOWED_IMPORTS = frozenset({
    "argparse", "collections", "csv", "dataclasses", "datetime", "decimal", "difflib", "enum",
    "fnmatch", "functools", "glob", "hashlib", "io", "itertools", "json", "math", "os.path",
    "pathlib", "re", "shlex", "statistics", "string", "sys", "textwrap", "typing", "unicodedata",
})
SCRIPT_DENIED_TOKENS = (
    "import subprocess", "import socket", "import urllib", "import http", "import requests",
    "import ftplib", "import telnetlib", "import smtplib", "os.system", "os.popen",
    "shutil.rmtree", "__import__", "eval(", "exec(", "compile(",
)
SECRET_PATTERNS = (
    re.compile(r"\b[A-Z][A-Z0-9_]*_(KEY|TOKEN|SECRET|PASSWORD|PASSWD)\b"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\b(sk|pk|ghp|gho|xox[baprs])[-_][A-Za-z0-9]{12,}\b"),
)
NETWORK_PATTERNS = (re.compile(r"https?://", re.I), re.compile(r"\b(curl|wget|nc|ssh)\s", re.I))

# Bounds. Each is (min, max) or a validation callable; a value outside is refused with a named error.
BOUNDS: Dict[str, Tuple[float, float]] = {
    # 0 means "index everything" for both caps, which is what the engine constants say and what the
    # 2026-11-18 finding requires: capping at 2 per folder left 105 of 115 coordination files unread,
    # so the system could not learn from its own history. The upper bound is a sanity ceiling, not a
    # recommendation — a corpus that big would be a different problem.
    "graph.max_wiki_pages": (0, 64),
    "graph.max_artifacts": (0, 64),
    "graph.chapter_chars": (400, 2400),
    "graph.hop_bonus": (0.0, 1.0),
    "graph.recency_floor": (0.0, 0.95),
    "graph.shared_term_threshold": (2, 8),
}
INT_FIELDS = frozenset({
    "graph.max_wiki_pages", "graph.max_artifacts", "graph.chapter_chars",
    "graph.shared_term_threshold",
})
WEIGHT_KEYS = ("contract", "wiki", "pseudoskill", "map", "templates", "memories",
               "plans", "suggestions", "tasks", "comms", "research")
WEIGHT_BOUNDS = (0.25, 4.0)
CAP_KEYS = ("orientation", "retrieval", "elephant", "goldfish")
CAP_FLOOR = 0.02
DOMAINS = ("codebase_symbols", "architectural_wiki", "security_governance",
           "technical_debt", "general_knowledge")

# The shipped hand-tuned values, and the fallback whenever a profile is absent or invalid.
BASE_PROFILE: Dict[str, Any] = {
    "format": PROFILE_FORMAT,
    "generation": 0,
    "source": "baseline",
    "graph": {
        # 0 = index every wiki page / every coordination artifact. These MUST match the engine
        # constants in `rag.py` (GRAPH_MAX_WIKI_PAGES / GRAPH_MAX_ARTIFACTS): a profile is always
        # folded over these values, so a smaller number here silently overrides the engine and
        # hides most of the corpus. That divergence shipped on 2026-11-18 and left 107 of 167 files
        # unreachable on every call.
        "max_wiki_pages": 0,
        "max_artifacts": 0,
        "chapter_chars": 1400,
        "hop_bonus": 0.35,
        "recency_floor": 0.55,
        "shared_term_threshold": 3,
    },
    "weights": {},
    "section_caps": {"orientation": 0.12, "retrieval": 0.54, "elephant": 0.20, "goldfish": 0.14},
    "domain_prior": {d: [] for d in DOMAINS},
    "calibration": {},
}


# ── paths ───────────────────────────────────────────────────────────────────

def harness_root(repo_root: Path) -> Path:
    """Where learned state lives. Tracked by git, unlike `.agents/rag/` — see findings R5."""
    return Path(repo_root) / HARNESS_DIR / HARNESS_SUBDIR


def profile_path(repo_root: Path) -> Path:
    return harness_root(repo_root) / PROFILE_NAME


def skills_root(repo_root: Path) -> Path:
    """STAGED skills. Never `.agents/skills/`, which every agent harness auto-discovers."""
    return harness_root(repo_root) / "skills"


def history_root(repo_root: Path) -> Path:
    return harness_root(repo_root) / "history"


def rejected_root(repo_root: Path) -> Path:
    return harness_root(repo_root) / "rejected"


def experience_path(repo_root: Path) -> Path:
    return harness_root(repo_root) / "EXPERIENCE.md"


def lock_path(repo_root: Path) -> Path:
    return harness_root(repo_root) / ".learn.lock"


def learn_state_path(repo_root: Path) -> Path:
    """Throttle state for the automatic learning pass.
    Inside `.agents/rag/` (gitignored) because it is machine-local bookkeeping, not learned state:
    each machine should be able to run its own pass without arguing about a committed timestamp.
    """
    return Path(repo_root) / ".agents" / "rag" / "context-harness-autolearn.json"


LEARN_MIN_INTERVAL_S = 6 * 3600      # at most one automatic pass per six hours
LEARN_MIN_NEW_COMMITS = 1            # and only when something actually happened since the last one


def should_autolearn(repo_root: Path, *, now: Optional[float] = None) -> Tuple[bool, str]:
    """Whether this call should spawn a learning pass, and the reason either way.

    Two conditions, both deliberately cheap to check: enough wall time has passed, and at least one
    commit landed since the last pass. The second is what makes the loop *continuous* rather than
    periodic — a repo nobody is touching does not need re-tuning, and a repo under active work
    accumulates the outcomes the gate needs.
    """
    path = learn_state_path(repo_root)
    state: Dict[str, Any] = {}
    if path.is_file():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            state = loaded if isinstance(loaded, dict) else {}
        except (OSError, ValueError):
            state = {}
    now = time.time() if now is None else now
    last = float(state.get("last_run_epoch") or 0.0)
    if last and (now - last) < LEARN_MIN_INTERVAL_S:
        remaining = int((LEARN_MIN_INTERVAL_S - (now - last)) / 60)
        return False, f"last pass {int((now - last) / 60)}m ago; next eligible in {remaining}m"
    commits = _commit_count(repo_root)
    if commits is None:
        return False, "not a git repository; the outcome signal needs commit history"
    last_commits = state.get("commit_count")
    if last_commits is not None and commits - int(last_commits) < LEARN_MIN_NEW_COMMITS:
        return False, f"no new commits since the last pass ({commits} total)"
    return True, f"{commits} commit(s), last pass {'never' if not last else f'{int((now - last) / 3600)}h ago'}"


def record_autolearn(repo_root: Path) -> None:
    path = learn_state_path(repo_root)
    payload = {
        "format": "ainish-rag/context-harness-autolearn/v1",
        "last_run_epoch": time.time(),
        "last_run_at": datetime.now(timezone.utc).isoformat(),
        "commit_count": _commit_count(repo_root) or 0,
    }
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    except OSError:
        pass


def _commit_count(repo_root: Path) -> Optional[int]:
    try:
        res = subprocess.run(
            ["git", "rev-list", "--count", "HEAD"], cwd=str(repo_root), capture_output=True,
            text=True, timeout=5, stdin=subprocess.DEVNULL,
        )
        if res.returncode != 0:
            return None
        return int((res.stdout or "0").strip() or 0)
    except (OSError, subprocess.SubprocessError, ValueError):
        return None


# ── validation ──────────────────────────────────────────────────────────────

def _get(doc: Dict[str, Any], dotted: str) -> Any:
    cur: Any = doc
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def _contains_acceptance_marker(text: str) -> Optional[str]:
    """The measurement vocabulary this text names, or None.

    Deliberately narrow. It fires on the names of the *acceptance signals this system computes*
    (`coverage`, `win_rate`, …) because a learned artefact naming those can raise the number without
    improving the thing. It does NOT fire on general words like `acceptance` or `threshold`, which
    appear when a page is *about* guarding a gate — refusing those would delete exactly the lessons
    worth keeping. Measured: an earlier, broader list rejected two correct pseudo-skills for using
    the word "acceptance" in its ordinary sense.
    """
    low = (text or "").lower()
    for marker in ACCEPTANCE_MARKERS:
        if marker in low:
            return marker
    return None


def validate_profile(profile: Dict[str, Any]) -> List[str]:
    """Every problem with `profile`, as actionable prose. Empty list means valid.

    Collects all problems rather than raising on the first: the message is fed back to the improver
    verbatim as retry feedback, and a list of five fixes beats five round trips (harness2's `validate`).
    """
    errs: List[str] = []
    if not isinstance(profile, dict):
        return ["profile must be a JSON object"]

    if profile.get("format") != PROFILE_FORMAT:
        errs.append(f"format must be {PROFILE_FORMAT!r}, got {profile.get('format')!r}")

    gen = profile.get("generation")
    if not isinstance(gen, int) or isinstance(gen, bool) or gen < 0:
        errs.append(f"generation must be a non-negative integer, got {gen!r}")

    graph = profile.get("graph")
    if not isinstance(graph, dict):
        errs.append("graph must be an object")
        graph = {}
    for field, (lo, hi) in BOUNDS.items():
        if not field.startswith("graph."):
            continue
        key = field.split(".", 1)[1]
        val = graph.get(key)
        if val is None:
            errs.append(f"graph.{key} is required (bounds {lo}..{hi})")
            continue
        if field in INT_FIELDS and (not isinstance(val, int) or isinstance(val, bool)):
            errs.append(f"graph.{key} must be an integer, got {type(val).__name__}")
            continue
        if not isinstance(val, (int, float)) or isinstance(val, bool):
            errs.append(f"graph.{key} must be a number, got {type(val).__name__}")
            continue
        if not (lo <= float(val) <= hi):
            errs.append(f"graph.{key} = {val} is outside the allowed range {lo}..{hi}")

    weights = profile.get("weights")
    if not isinstance(weights, dict):
        errs.append("weights must be an object")
        weights = {}
    # Only keys the profile actually names are checked and applied. An ABSENT key inherits the
    # engine's per-kind default (`GRAPH_KIND_WEIGHTS`), so the shipped profile must not pre-fill
    # every key with 1.0 — that would flatten the curated contract/wiki preference the ranking
    # depends on. A profile that wants uniform weighting names every key explicitly.
    for key, val in weights.items():
        if key not in WEIGHT_KEYS:
            errs.append(f"weights.{key} is not a known kind ({', '.join(WEIGHT_KEYS)})")
            continue
        if not isinstance(val, (int, float)) or isinstance(val, bool):
            errs.append(f"weights.{key} must be a number")
        elif not (WEIGHT_BOUNDS[0] <= float(val) <= WEIGHT_BOUNDS[1]):
            errs.append(f"weights.{key} = {val} is outside {WEIGHT_BOUNDS[0]}..{WEIGHT_BOUNDS[1]}")

    caps = profile.get("section_caps")
    if not isinstance(caps, dict):
        errs.append("section_caps must be an object")
        caps = {}
    total = 0.0
    for key in CAP_KEYS:
        val = caps.get(key, BASE_PROFILE["section_caps"][key])
        if not isinstance(val, (int, float)) or isinstance(val, bool):
            errs.append(f"section_caps.{key} must be a number")
            continue
        if float(val) < CAP_FLOOR:
            errs.append(f"section_caps.{key} = {val} is below the {CAP_FLOOR} floor; "
                        f"a section with no budget is a section that never appears")
            continue
        total += float(val)
    if total > 1.0 + 1e-9:
        errs.append(f"section_caps sum to {round(total, 4)}, over 1.0; every section cannot "
                    f"have a larger share than the whole budget")

    prior = profile.get("domain_prior")
    if not isinstance(prior, dict):
        errs.append("domain_prior must be an object")
        prior = {}
    for domain, terms in prior.items():
        if domain not in DOMAINS:
            errs.append(f"domain_prior.{domain} is not a known domain ({', '.join(DOMAINS)})")
            continue
        if not isinstance(terms, list):
            errs.append(f"domain_prior.{domain} must be a list of terms")
            continue
        if len(terms) > DOMAIN_PRIOR_MAX:
            errs.append(f"domain_prior.{domain} has {len(terms)} terms, over the {DOMAIN_PRIOR_MAX} cap")
        for term in terms:
            if not isinstance(term, str):
                errs.append(f"domain_prior.{domain} contains a non-string term")
                continue
            if not TERM_RE.match(term):
                errs.append(f"domain_prior.{domain} term {term!r} must match {TERM_RE.pattern}")
            hit = _contains_acceptance_marker(term)
            if hit:
                errs.append(
                    f"domain_prior.{domain} term {term!r} names the measurement ({hit!r}); "
                    f"a retrieval hint that names what it is scored by optimises the score, not "
                    f"the prime"
                )
    return errs


def validate_tree(repo_root: Path) -> List[str]:
    """Every problem with the staged skill tree. Empty list means valid.

    The checks mirror `harness2/core/tree.py:validate` where we have an equivalent, plus three that
    exist because we have no sandbox: no network, no secrets, allowlisted imports. Those three are
    a static substitute for an OS boundary and are weaker than one — that is recorded, not hidden.
    """
    errs: List[str] = []
    root = skills_root(repo_root)
    if not root.is_dir():
        return errs

    skill_dirs = sorted(p for p in root.iterdir() if p.is_dir())
    if len(skill_dirs) > MAX_LIVE_SKILLS:
        errs.append(f"{len(skill_dirs)} staged skills, over the {MAX_LIVE_SKILLS} cap; "
                    f"an unbounded toolbox is the bloat failure this cap exists to prevent")

    for d in skill_dirs:
        name = d.name
        # Two origins live here, and the validator must tell them apart:
        #   LEARNER-AUTHORED  `learned-*`, written by `--context-learn`. Every check below applies:
        #                     the prefix keeps it out of the deploy sweep, `name`/`description` are
        #                     what the loader needs, and a learner's artefact must never reach out.
        #   CURATED           anything else, written by the operator with `context-skill`. It is not
        #                     swept (it was never in the deploy payload) and its `source:` field is a
        #                     CITATION — the whole point of the evidence discipline is that a lesson
        #                     names where it came from, and several cite a URL. Refusing those would
        #                     delete exactly the sourced lessons worth keeping.
        learner_authored = name.startswith(SKILL_PREFIX)
        if learner_authored and not NAME_RE.match(name):
            errs.append(f"staged skill {name!r} must match {NAME_RE.pattern} "
                        f"(the {SKILL_PREFIX!r} prefix is what keeps it out of the deploy sweep)")
        skill_md = d / "SKILL.md"
        if not skill_md.is_file():
            errs.append(f"skills/{name}/SKILL.md is missing; a directory without a SKILL.md "
                        f"is not a skill")
            continue
        try:
            body = skill_md.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            errs.append(f"skills/{name}/SKILL.md is unreadable: {exc}")
            continue
        if len(body) > SKILL_BODY_MAX:
            errs.append(f"skills/{name}/SKILL.md is {len(body)} chars, over the {SKILL_BODY_MAX} cap")
        if not body.lstrip().startswith("---"):
            errs.append(f"skills/{name}/SKILL.md needs frontmatter (--- ... ---)")
        else:
            parts = body.split("---", 2)
            fm = parts[1] if len(parts) >= 3 else ""
            m_name = re.search(r"^name:\s*(\S+)\s*$", fm, re.M)
            m_title = re.search(r"^title:\s*(\S.*)$", fm, re.M)
            if not m_name and not m_title:
                errs.append(f"skills/{name}/SKILL.md needs `name: {name}` (or a `title:`); "
                            f"without it the skill is dropped silently at load")
            elif m_name and m_name.group(1) != name:
                errs.append(f"skills/{name}/SKILL.md declares `name: {m_name.group(1)}` but lives "
                            f"in {name}/; the mismatch makes the skill silently unloadable")
            if not re.search(r"^description:\s*\S", fm, re.M) and not re.search(r"^trigger:\s*\S", fm, re.M):
                errs.append(f"skills/{name}/SKILL.md needs a `description:` or `trigger:` in "
                            f"frontmatter (without it the skill can never be matched to a task)")

        hit = _contains_acceptance_marker(body)
        if hit:
            errs.append(f"skills/{name}/SKILL.md names the measurement ({hit!r}); a learned "
                        f"procedure that names its own scoring optimises the score")
        if learner_authored:
            # Only a learner's artefact is barred from the network. A curated lesson cites its
            # sources, and `source:`/`evidence:` are metadata, not instructions to fetch anything.
            for pat in NETWORK_PATTERNS:
                m = pat.search(body)
                if m:
                    errs.append(f"skills/{name}/SKILL.md references the network ({m.group(0)!r}); "
                                f"learned artefacts never reach out")
                    break
        for pat in SECRET_PATTERNS:
            if pat.search(body):
                errs.append(f"skills/{name}/SKILL.md contains what looks like a credential; "
                            f"secrets come from pqc-secrets at runtime and are never persisted")

        script_dir = d / "scripts"
        if script_dir.is_dir():
            for script in sorted(script_dir.glob("*.py")):
                errs.extend(_validate_script(name, script))
        else:
            for ref in re.findall(r"scripts/([A-Za-z0-9_.\-]+\.py)", body):
                errs.append(f"skills/{name}/SKILL.md invokes scripts/{ref} but no scripts/ "
                            f"directory ships with this skill")
    return errs


def _validate_script(skill: str, script: Path) -> List[str]:
    errs: List[str] = []
    rel = f"skills/{skill}/scripts/{script.name}"
    try:
        src = script.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return [f"{rel} is unreadable: {exc}"]
    if len(src) > SKILL_SCRIPT_MAX:
        errs.append(f"{rel} is {len(src)} chars, over the {SKILL_SCRIPT_MAX} cap")
    try:
        compile(src, rel, "exec")
    except (SyntaxError, ValueError) as exc:
        detail = f"{type(exc).__name__}: {getattr(exc, 'msg', exc)}"
        errs.append(f"{rel} does not compile: {detail[:160]}")
    for token in SCRIPT_DENIED_TOKENS:
        if token in src:
            errs.append(f"{rel} uses {token!r}; learned helpers may not shell out, execute "
                        f"dynamically, or delete trees")
    for mod in re.findall(r"^\s*(?:from|import)\s+([A-Za-z_][A-Za-z0-9_.]*)", src, re.M):
        root_mod = mod.split(".")[0]
        if root_mod in {"os", "sys", "pathlib", "re", "json", "csv", "math"}:
            continue
        allowed = any(mod == a or mod.startswith(a + ".") for a in SCRIPT_ALLOWED_IMPORTS)
        if not allowed:
            errs.append(f"{rel} imports {mod!r}, which is outside the allowlist for learned "
                        f"helpers: {', '.join(sorted(SCRIPT_ALLOWED_IMPORTS))}")
    return errs


# ── load / apply ────────────────────────────────────────────────────────────

def load_profile(repo_root: Path) -> Tuple[Dict[str, Any], str, List[str]]:
    """The live profile, where it came from, and any problems found.

    Never raises into `--context`: a context call must not block the task that asked for it. An
    invalid profile is REPORTED and the base values are used, so the failure is visible in
    provenance rather than silently absorbed (findings R1/R5).
    """
    path = profile_path(repo_root)
    if not path.is_file():
        return json.loads(json.dumps(BASE_PROFILE)), "absent", []
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return json.loads(json.dumps(BASE_PROFILE)), f"invalid: unreadable ({str(exc)[:80]})", []
    errs = validate_profile(raw)
    if errs:
        return json.loads(json.dumps(BASE_PROFILE)), "invalid: failed validation", errs
    merged = json.loads(json.dumps(BASE_PROFILE))
    for key in ("generation",):
        if key in raw:
            merged[key] = raw[key]
    for section in ("graph", "weights", "section_caps", "domain_prior", "calibration"):
        if isinstance(raw.get(section), dict):
            merged[section].update(raw[section])
    return merged, "learned", []


def apply_to_settings(profile: Dict[str, Any], settings: Dict[str, Any]) -> Dict[str, Any]:
    """Fold a profile onto a resolved-settings dict. One place, no scattered reads of the constants."""
    out = dict(settings)
    graph = profile.get("graph") or {}
    for key in ("max_wiki_pages", "max_artifacts", "chapter_chars", "hop_bonus",
                "recency_floor", "shared_term_threshold"):
        if key in graph:
            out[key] = graph[key]
    out["weights"] = dict(profile.get("weights") or {})
    out["section_caps"] = dict(profile.get("section_caps") or {})
    out["domain_prior"] = dict(profile.get("domain_prior") or {})
    return out


def base_settings() -> Dict[str, Any]:
    """The resolved settings a fresh repo gets.

    Derived FROM `BASE_PROFILE` rather than restating its numbers. The previous version repeated
    every graph literal here, so `BASE_PROFILE` and these defaults could disagree — and they did:
    the profile said 2 artifacts while the engine constant said unlimited, and because
    `apply_to_settings` always folds a profile over this dict, the smaller number won. One literal
    per value, in one place, is the only version of this that stays true.
    """
    graph = dict(BASE_PROFILE["graph"])
    return apply_to_settings(BASE_PROFILE, {
        "max_wiki_pages": graph["max_wiki_pages"],
        "max_artifacts": graph["max_artifacts"],
        "chapter_chars": graph["chapter_chars"],
        "hop_bonus": graph["hop_bonus"],
        "recency_floor": graph["recency_floor"],
        "shared_term_threshold": graph["shared_term_threshold"],
        "weights": {}, "section_caps": {}, "domain_prior": {},
    })


def settings_for(repo_root: Path) -> Tuple[Dict[str, Any], str, List[str]]:
    profile, source, errs = load_profile(repo_root)
    return apply_to_settings(profile, base_settings()), source, errs


# ── outcome signal (the non-circular one) ───────────────────────────────────

def _task_records(repo_root: Path) -> List[Path]:
    """Task records, newest first. `.agents/tasks/*.md` is the system of record for what was done."""
    d = Path(repo_root) / ".agents" / "tasks"
    if not d.is_dir():
        return []
    try:
        files = [p for p in d.glob("*.md") if p.is_file()]
    except OSError:
        return []
    files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return files


def _parse_task_record(path: Path) -> Dict[str, str]:
    """The front-matter-ish fields a task record carries on `- key: value` lines.

    The format is deliberately loose (`- status: done (merged 748cb8a; ...)`), so this reads the key
    and keeps the VALUE VERBATIM rather than guessing a schema. `status` and `branch` are what the
    outcome referent needs; `objective` and `scope` are used for vocabulary.
    """
    out: Dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return out
    for key in ("status", "branch", "plan", "objective", "scope"):
        m = re.search(rf"^-\s*{key}:\s*(.+?)(?=^-\s+[a-z_]+:|\Z)", text, re.S | re.M)
        if m:
            value = " ".join(m.group(1).split())
            # A quoted value is a YAML string, not part of the value: `status: "done (merged abc)"`
            # must read as `done (merged abc)`, or `_record_is_done` sees a leading quote and every
            # finished record looks unfinished. Measured on 2026-11-19 in the end-to-end fixture.
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1].strip()
            out[key] = value
    if "objective" not in out:
        # Continuation lines under a wrapped `- objective:` are indented, so the lookahead above
        # already captures them; this is the fallback for a record written without the dash form.
        m = re.search(r"^objective:\s*(.+?)(?=^## |\Z)", text, re.S | re.M)
        if m:
            out["objective"] = " ".join(m.group(1).split())
    return out


def _record_is_done(fields: Dict[str, str]) -> bool:
    """True when a task record says the work landed.

    `status: done (merged <sha>; ...)` is the form this repo writes. "done" must be the first word;
    `blocked`/`implementing`/`designing`/`abandoned` are all not-done, and a record that merely
    mentions the word "done" in prose must not satisfy this.
    """
    status = (fields.get("status") or "").strip().lower()
    return status.startswith("done") or status.startswith("complete")


def _commit_in_history(repo_root: Path, sha: str) -> bool:
    """Is `sha` a commit that exists in this repository's history?

    `git cat-file -e <sha>^{commit}` answers existence; `git merge-base --is-ancestor` answers whether
    it is reachable from HEAD. Both matter: a record referencing a commit that exists only on a side
    branch was not adopted.
    """
    sha = (sha or "").strip()
    if not re.fullmatch(r"[0-9a-f]{7,40}", sha):
        return False
    for argv in (
        ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
        ["git", "merge-base", "--is-ancestor", sha, "HEAD"],
    ):
        try:
            res = subprocess.run(argv, cwd=str(repo_root), capture_output=True, text=True,
                                 timeout=10, stdin=subprocess.DEVNULL)
        except (OSError, subprocess.SubprocessError):
            return False
        if res.returncode != 0:
            return False
    return True


def _commit_after_branch(repo_root: Path, fields: Dict[str, str]) -> Dict[str, Any]:
    """Did this record's work actually land?

    Two independent ways, because this repo deletes branches on merge (the contract requires it):
    the `status:` line usually names the merge sha (`done (merged 748cb8a; ...)`) — verifiable
    directly — and failing that, a commit subject or surviving ref naming the branch.
    """
    status = fields.get("status") or ""
    shas = re.findall(r"\b[0-9a-f]{7,40}\b", status.lower())
    for sha in shas:
        if _commit_in_history(repo_root, sha):
            return {"ok": True, "how": "merged-sha", "sha": sha,
                    "reason": ""}

    branch = (fields.get("branch") or "").strip().strip("`")
    if not branch:
        return {"ok": False,
                "reason": "the record names no merged commit and no branch, so it cannot be credited"}
    try:
        named = subprocess.run(
            ["git", "log", "--all", "--format=%H\t%s", "-300"],
            cwd=str(repo_root), capture_output=True, text=True, timeout=10,
            stdin=subprocess.DEVNULL,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return {"ok": False, "reason": f"git log failed: {str(exc)[:80]}"}
    if named.returncode != 0:
        return {"ok": False, "reason": "git log failed"}
    hit = any(
        branch in subj
        for _, subj in (ln.split("\t", 1) for ln in named.stdout.splitlines() if "\t" in ln)
    )
    ref_exists = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"],
        cwd=str(repo_root), capture_output=True, text=True, timeout=5,
        stdin=subprocess.DEVNULL,
    ).returncode == 0
    return {
        "ok": bool(hit or ref_exists), "how": "branch" if (hit or ref_exists) else None,
        "merged": hit, "ref_exists": ref_exists,
        "reason": "" if (hit or ref_exists)
        else f"the record names no merged sha and no commit or ref for `{branch}`; "
             f"a status without a landing commit cannot be credited",
    }


def outcome_signal(
    repo_root: Path,
    task: str,
    *,
    max_commits: int = 60,
    task_record: Optional[Path] = None,
    override: Optional[str] = None,
) -> Dict[str, Any]:
    """An external referent for "did the prime help?", independent of the prime's own output.

    Phase 0 (`08-phase0-findings.md`) proved a gate computed from the rendered prime is circular:
    every quality signal was monotone in the knob that produced it (rho up to 1.000). So the gate
    must observe something the prime did not produce. In descending order of trust:

      override     the caller said so: `--outcome ok|fail`. An operator decision, recorded verbatim.
      task record  `.agents/tasks/<name>.md` says `status: done` AND its branch has a commit/merge.
                   This is the repo's own system of record — the strongest non-model referent.
      completion   a commit subject carries the task's distinctive vocabulary. Kept as a last resort
                   because it is weak (measured: 5/10 on real task objectives), and it is now only
                   consulted when there is no task record to read.

    Returns `{available, completion, reason, referent, ...}`. `completion` is `None` when the answer
    is genuinely UNKNOWN — that is distinct from `False`, because "we could not tell" and "the work
    did not land" are different facts and the gate refuses them for different reasons.
    """
    out: Dict[str, Any] = {
        "available": False, "reason": "", "completion": None, "commits": 0,
        "referent": None, "task_record": None,
    }

    # 1. An explicit operator decision wins, and is labelled as what it is.
    normalized = (override or "").strip().lower()
    if normalized in ("ok", "pass", "true", "yes"):
        out.update({"available": True, "completion": True, "referent": "override",
                    "reason": "caller asserted the outcome with --outcome ok"})
        return out
    if normalized in ("fail", "false", "no"):
        out.update({"available": True, "completion": False, "referent": "override",
                    "reason": "caller asserted the outcome with --outcome fail"})
        return out
    # `unknown` is an explicit statement that the outcome is NOT established. Falling through to the
    # commit-subject heuristic would silently substitute a weaker referent for the caller's answer,
    # so it refuses with a reason instead. Only an ABSENT flag falls through.
    if normalized in ("unknown", "unavailable"):
        out["reason"] = (
            "the caller recorded the outcome as unknown with --outcome unknown; a harness change "
            "cannot be accepted against an outcome nobody established"
        )
        return out
    if normalized:
        out["reason"] = f"unrecognised --outcome value {override!r}; expected ok|fail|unknown"
        return out

    if not _git_ok(repo_root):
        out["reason"] = "not a git repository"
        return out

    try:
        res = subprocess.run(
            ["git", "log", f"-{max(1, int(max_commits))}", "--format=%H%x09%s"],
            cwd=str(repo_root), capture_output=True, text=True, timeout=10,
            stdin=subprocess.DEVNULL,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        out["reason"] = f"git log failed: {str(exc)[:80]}"
        return out
    if res.returncode != 0:
        out["reason"] = f"git log returned {res.returncode}: {(res.stderr or '')[:80]}"
        return out
    lines = [ln for ln in res.stdout.splitlines() if ln.strip()]
    out["commits"] = len(lines)

    # 2. The repo's system of record: a completed task record, identified as the one that matches
    #    this task text when possible, else the newest record overall.
    record = Path(task_record) if task_record else None
    if record is not None and not record.is_file():
        out["reason"] = f"task record not found: {record}"
        return out
    words = _slug_words(task)
    if record is None:
        record = _best_matching_record(repo_root, words)
    if record is not None:
        fields = _parse_task_record(record)
        rel = str(record.relative_to(repo_root)) if record.is_relative_to(repo_root) else str(record)
        out["task_record"] = rel
        out["task_status"] = (fields.get("status") or "").strip()
        if fields:
            if not _record_is_done(fields):
                out["available"] = True
                out["completion"] = False
                out["referent"] = "task-record"
                out["reason"] = (
                    f"task record `{rel}` status is {fields.get('status', '(none)')!r}, "
                    f"not done; the work has not landed yet"
                )
                return out
            landed = _commit_after_branch(repo_root, fields)
            out["branch_check"] = landed
            # `status: done` is the REFERENT. It is written in a tracked file by the work that
            # closed the task, so it is not derived from the prime — which is the property Phase 0
            # requires. The landing check is CORROBORATION, and it cannot be a hard requirement:
            # measured on 2026-11-19, all four historical task records in this repo name merge shas
            # that no longer exist (the history was rebased across machines), so requiring a
            # verifiable sha would make the gate refuse forever and the loop could never accept.
            # A record whose landing cannot be verified is accepted and REPORTED as uncorroborated,
            # so an operator can see which generations rest on assertion alone.
            out.update({
                "available": True,
                "completion": True,
                "referent": "task-record",
                "corroborated": bool(landed.get("ok")),
                "reason": (
                    f"task record `{rel}` is done and its landing is verified "
                    f"({landed.get('how')})"
                    if landed.get("ok") else
                    f"task record `{rel}` says done; landing NOT corroborated "
                    f"({landed.get('reason')}). Accepted on the record alone — the record is the "
                    f"system of record, but this generation rests on assertion, not proof"
                ),
            })
            return out

    # 3. Last resort: commit-subject overlap. Weak, and said so. The task record's scope paths and
    #    branch slug join the objective's prose, because those are what a subject actually carries.
    if not lines:
        out["reason"] = "no commits yet"
        return out
    record_words = _record_vocabulary(_parse_task_record(record)) if record is not None else []
    words = sorted(set(words) | set(record_words), key=lambda w: (-len(w), w))[:10]
    if not words:
        out["reason"] = "no distinctive words in the task text"
        return out
    completed: Optional[bool] = None
    best_hits = 0
    for ln in lines:
        _, _, subject = ln.partition("\t")
        hits = sum(1 for w in words if w in subject.lower())
        best_hits = max(best_hits, hits)
        if len(words) >= 2 and hits >= 2:
            completed = True
            break
        if len(words) == 1 and hits == 1:
            completed = True
            break
    out["completion"] = bool(completed)
    out["available"] = True
    out["referent"] = "commit-subject"
    out["matched_words"] = best_hits
    out["words_considered"] = len(words)
    out["reason"] = (
        "" if completed
        else "no commit subject carries enough of this task's vocabulary; "
             "pass --task-record or --outcome to give the gate a referent it can read"
    )
    return out


def _best_matching_record(repo_root: Path, words: List[str]) -> Optional[Path]:
    """The task record whose filename/objective best matches the task, else the newest record.

    Returning the NEWEST record when nothing matches is deliberate: a learner run always has a task,
    and refusing to look at the record at all would leave the strongest referent unused. The record
    that is chosen is reported, so a mismatch is visible rather than silent.
    """
    records = _task_records(repo_root)
    if not records:
        return None
    if words:
        best: Optional[Tuple[int, float, Path]] = None
        for path in records[:60]:
            fields = _parse_task_record(path)
            hay = f"{path.stem} {fields.get('objective', '')}".lower()
            score = sum(1 for w in words if w in hay)
            try:
                mtime = path.stat().st_mtime
            except OSError:
                mtime = 0.0
            candidate = (score, mtime, path)
            if score > 0 and (best is None or candidate[:2] > best[:2]):
                best = candidate
        if best is not None:
            return best[2]
    return records[0]


# Public surface: other modules (`rag.py`) need the referent and its vocabulary when they spawn a
# learner. Reaching into `_`-prefixed helpers across a module boundary couples callers to internals
# that are free to change, so the two things that are genuinely used are named here.
def resolve_task_record(repo_root: Path, task: str) -> Optional[Path]:
    """The task record a task belongs to, or the newest one. `None` when there are no records."""
    return _best_matching_record(repo_root, _slug_words(task))


def task_record_fields(path: Optional[Path]) -> Dict[str, str]:
    """A task record's parsed fields, or an empty dict when there is no record."""
    if path is None:
        return {}
    try:
        return _parse_task_record(Path(path))
    except OSError:
        return {}


def _git_ok(repo_root: Path) -> bool:
    try:
        res = subprocess.run(
            ["git", "rev-parse", "--git-dir"], cwd=str(repo_root), capture_output=True,
            text=True, timeout=5, stdin=subprocess.DEVNULL,
        )
        return res.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


_STOP = frozenset({
    "the", "and", "for", "with", "that", "this", "from", "into", "over", "when", "what", "which",
    "should", "would", "could", "make", "made", "have", "been", "does", "only", "than", "then",
    "there", "their", "about", "must", "never", "each", "every", "some", "such", "more", "most",
})


def _slug_words(task: str) -> List[str]:
    """The distinctive words of a task, longest first. Empty means "cannot judge".

    Conservative on purpose: a false match would make the gate believe work completed when it did
    not, and a gate that is always positive cannot gate. Short and stopword-ish tokens are dropped,
    and the strongest few are kept so a subject has to carry real overlap to count.

    Prose objectives are the weak case: an objective reading "the prime must read the accumulated
    configuration" yields words no commit subject will ever carry. Callers that have a task record
    pass its `scope:` paths and `branch:` slug alongside the prose (see `_record_vocabulary`), because
    those DO appear in subjects and filenames.
    """
    words = [w for w in re.findall(r"[a-z0-9]+", (task or "").lower())
             if len(w) >= 5 and w not in _STOP]
    return sorted(set(words), key=lambda w: (-len(w), w))[:6]


def _record_vocabulary(fields: Dict[str, str]) -> List[str]:
    """The words a task record contributes to matching: its scope paths and branch slug.

    These are the identifiers that actually appear in commit subjects and merge lines —
    `docs(context): one command reads the rules` carries `context` and `command`, not the objective's
    prose. Used IN ADDITION to (never instead of) the objective's own words.
    """
    material = f"{fields.get('scope', '')} {fields.get('branch', '')}"
    words = [w for w in re.findall(r"[a-z0-9]+", material.lower())
             if len(w) >= 4 and w not in _STOP]
    return sorted(set(words), key=lambda w: (-len(w), w))[:8]


# ── fingerprints ────────────────────────────────────────────────────────────

def profile_fingerprint(profile: Dict[str, Any]) -> str:
    """Stable digest of the parts of a profile that change behaviour (not generation or timestamps)."""
    material = {
        "graph": profile.get("graph") or {},
        "weights": profile.get("weights") or {},
        "section_caps": profile.get("section_caps") or {},
        "domain_prior": profile.get("domain_prior") or {},
    }
    blob = json.dumps(material, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]


def tree_fingerprint(repo_root: Path) -> str:
    """Stable digest of the staged skill tree, so a cached comparison cannot reuse a stale one."""
    root = skills_root(repo_root)
    h = hashlib.sha256()
    if not root.is_dir():
        return "empty"
    for p in sorted(root.rglob("*")):
        if not p.is_file() or "__pycache__" in p.parts or p.suffix == ".pyc":
            continue
        h.update(str(p.relative_to(root)).encode())
        h.update(b"\0")
        try:
            h.update(p.read_bytes())
        except OSError:
            h.update(b"<unreadable>")
        h.update(b"\0")
    return h.hexdigest()[:16]


# ── storage ─────────────────────────────────────────────────────────────────

def write_profile(repo_root: Path, profile: Dict[str, Any], *, note: str = "") -> Dict[str, Any]:
    """Persist a validated profile as the new live generation, archiving the previous one.

    Refuses an invalid profile and refuses to move backwards: `generation` must be exactly one more
    than what is on disk, so a concurrent learner cannot clobber a newer generation (findings R9).
    """
    errs = validate_profile(profile)
    if errs:
        return {"ok": False, "errors": errs}
    current, source, _ = load_profile(repo_root)
    expected = int(current.get("generation") or 0) + 1
    if int(profile.get("generation") or -1) != expected:
        return {
            "ok": False,
            "errors": [f"generation {profile.get('generation')!r} is not exactly {expected}; "
                       f"another learner may have moved the profile — re-read and retry"],
        }
    root = harness_root(repo_root)
    root.mkdir(parents=True, exist_ok=True)
    if profile_path(repo_root).is_file():
        _archive_current(repo_root, current, note=note)
    payload = dict(profile)
    payload["format"] = PROFILE_FORMAT
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()
    payload["fingerprint"] = profile_fingerprint(payload)
    try:
        profile_path(repo_root).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    except OSError as exc:
        return {"ok": False, "errors": [f"could not write profile: {str(exc)[:120]}"]}
    return {"ok": True, "generation": payload["generation"], "path": str(profile_path(repo_root))}


def _archive_current(repo_root: Path, current: Dict[str, Any], *, note: str = "") -> None:
    """Copy the live profile into history/ under its generation, immutably.

    Rollback is then copying one file back — there is no "undo" operation that could itself be
    wrong (findings §5.5).

    Idempotent per generation: if a history entry for this generation already exists (the learner
    archives the outgoing generation deliberately, before staging, so the snapshot predates the new
    skills), this does not overwrite it. The first snapshot of a generation is the true one.

    The STAGED SKILL TREE is archived alongside it, because the profile and its skills are one
    generation: `write_profile` only accepts a generation whose skills already staged, so restoring
    the profile alone would leave a generation-0 profile beside generation-1 skills. That is a
    half-applied state no other rollback of the profile could repair — measured on 2026-11-19, where
    `context-rollback 0` restored the tuning but left `learned-plan-of-record-identification` staged.
    """
    gen = int(current.get("generation") or 0)
    hdir = history_root(repo_root)
    hdir.mkdir(parents=True, exist_ok=True)
    slug = re.sub(r"[^a-z0-9]+", "-", (note or "generation").lower()).strip("-")[:40] or "generation"
    existing = sorted(hdir.glob(f"{gen:04d}-*.json"))
    if existing:
        return
    dest = hdir / f"{gen:04d}-{slug}.json"
    try:
        dest.write_text(json.dumps(current, indent=2) + "\n", encoding="utf-8")
    except OSError:
        return
    # Snapshot the staged tree next to the profile. Absent when the generation added no skills, and
    # its absence is meaningful: rollback then removes whatever the newer generation staged.
    skills_dir = skills_root(repo_root)
    snap = hdir / f"{gen:04d}-{slug}.skills"
    if skills_dir.is_dir():
        try:
            if snap.is_dir():
                shutil.rmtree(snap, ignore_errors=True)
            shutil.copytree(skills_dir, snap)
        except (OSError, shutil.Error):
            pass


def archive_live_generation(repo_root: Path, *, note: str = "") -> None:
    """Archive the CURRENT live profile and its staged tree as an immutable generation.

    Exposed because ordering matters and only the caller knows it: the outgoing generation must be
    snapshotted BEFORE the new generation's skills are staged, or its snapshot captures the new tree
    and a rollback restores the wrong skills. `write_profile` still archives as a backstop.
    """
    current, _, _ = load_profile(repo_root)
    _archive_current(repo_root, current, note=note)


def record_rejection(repo_root: Path, proposal: Dict[str, Any], reasons: List[str]) -> Optional[Path]:
    """Write a refused proposal where a reviewer can see it, including the failing condition."""
    rdir = rejected_root(repo_root)
    rdir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    dest = rdir / f"{stamp}.md"
    lines = [f"# Rejected proposal {stamp}", "", "## Why", ""]
    lines += [f"- {r}" for r in reasons] or ["- (no reason recorded; this is a bug)"]
    lines += ["", "## Proposal", "", "```json",
              json.dumps(proposal, indent=2, sort_keys=True), "```", ""]
    try:
        dest.write_text("\n".join(lines), encoding="utf-8")
        return dest
    except OSError:
        return None


def prune_work(root: Path, *, keep: int = 10, keep_rejected: int = 50) -> int:
    """Keep only the newest `keep` evidence trees and `keep_rejected` refusals; return removals.

    Every learning pass writes its evidence under `work/<stamp>/`, and every refusal writes to
    `rejected/`. A background process that runs for months would otherwise accumulate both forever —
    the exact unbounded-growth failure this whole design exists to avoid (findings R2). `work/` is
    per-machine operational detail; `rejected/` is committed and so is capped more generously, because
    a refusal record is the audit trail for why the harness did NOT change.
    """
    removed = 0
    work = Path(root) / "work"
    if work.is_dir():
        dirs = sorted((p for p in work.iterdir() if p.is_dir()), key=lambda p: p.name, reverse=True)
        for stale in dirs[keep:]:
            shutil.rmtree(stale, ignore_errors=True)
            removed += 1
    rej = Path(root) / "rejected"
    if rej.is_dir():
        files = sorted((p for p in rej.iterdir() if p.is_file()), key=lambda p: p.name, reverse=True)
        for stale in files[keep_rejected:]:
            try:
                stale.unlink()
                removed += 1
            except OSError:
                pass
    return removed


def write_experience(repo_root: Path, profile: Dict[str, Any], *, why: str, evidence: str) -> None:
    """The human-readable record of why the live profile is what it is.

    A lesson with no cited evidence is not written at all — harness2's `has_experience` gate, and
    the rule that keeps an experience library from filling with confident prose.
    """
    if not (why or "").strip() or not (evidence or "").strip():
        return
    root = harness_root(repo_root)
    root.mkdir(parents=True, exist_ok=True)
    graph = profile.get("graph") or {}
    lines = [
        f"# Context harness — experience (generation {profile.get('generation')})",
        "",
        f"- updated: {datetime.now(timezone.utc).isoformat()}",
        f"- fingerprint: `{profile_fingerprint(profile)}`",
        f"- components: {len(graph)} tuned value(s), "
        f"{sum(len(v or []) for v in (profile.get('domain_prior') or {}).values())} domain hint(s), "
        f"{len(list(skills_root(repo_root).glob('*/SKILL.md'))) if skills_root(repo_root).is_dir() else 0} staged skill(s)",
        "",
        "## Why this generation was adopted",
        "",
        why.strip(),
        "",
        "## Evidence",
        "",
        evidence.strip(),
        "",
        "## Rollback",
        "",
        f"Copy any `history/*.json` back to `{PROFILE_NAME}` and delete `generation` from nothing —",
        "the file is self-describing. Or run `ainish-rag --context-rollback <generation>`.",
        "",
    ]
    try:
        experience_path(repo_root).write_text("\n".join(lines), encoding="utf-8")
    except OSError:
        pass


def seed(repo_root: Path) -> Dict[str, Any]:
    """Establish generation 0. Idempotent: an existing profile is never overwritten.

    Generation 0 is what any later contrast is measured against, so it must be frozen before a
    learner ever runs. Harness2 Figure 7 is the reason: refining without a reference regresses.
    """
    if profile_path(repo_root).is_file():
        return {"ok": True, "seeded": False, "reason": "profile already exists"}
    root = harness_root(repo_root)
    root.mkdir(parents=True, exist_ok=True)
    profile = json.loads(json.dumps(BASE_PROFILE))
    profile["generation"] = 0
    profile["calibration"] = calibrate(repo_root)
    errs = validate_profile(profile)
    if errs:
        return {"ok": False, "seeded": False, "errors": errs}
    try:
        profile_path(repo_root).write_text(json.dumps(profile, indent=2) + "\n", encoding="utf-8")
    except OSError as exc:
        return {"ok": False, "seeded": False, "errors": [str(exc)[:120]]}
    readme = root / "README.md"
    if not readme.is_file():
        try:
            readme.write_text(SEED_README, encoding="utf-8")
        except OSError:
            pass
    return {"ok": True, "seeded": True, "path": str(profile_path(repo_root)),
            "calibration": profile["calibration"]}


def calibrate(repo_root: Path) -> Dict[str, Any]:
    """Measure the corpus this repo actually has. Pure measurement, no model call, no network."""
    wiki = Path(repo_root) / ".agents" / "wiki"
    counts: Dict[str, int] = {}
    for folder in ("comms", "memories", "plans", "suggestions", "tasks"):
        d = Path(repo_root) / ".agents" / folder
        counts[folder] = len(list(d.glob("*.md"))) + len(list(d.glob("*.txt"))) if d.is_dir() else 0
    pages = len(list(wiki.glob("*.md"))) if wiki.is_dir() else 0
    return {
        "measured_at": datetime.now(timezone.utc).isoformat(),
        "wiki_pages": pages,
        "artifacts": counts,
        "corpus_nodes_estimate": pages * 6 + sum(counts.values()),
        "note": "generation 0 is frozen; later generations are compared against it",
    }


def rollback(repo_root: Path, generation: int) -> Dict[str, Any]:
    """Restore a historical generation as the live profile, recorded as its own event."""
    hdir = history_root(repo_root)
    if not hdir.is_dir():
        return {"ok": False, "errors": ["no history directory; nothing to roll back to"]}
    matches = sorted(hdir.glob(f"{int(generation):04d}-*.json"))
    if not matches:
        available = sorted({p.name.split("-", 1)[0] for p in hdir.glob("*.json")})
        return {"ok": False, "errors": [
            f"generation {generation} is not in history; available: {', '.join(available) or 'none'}"
        ]}
    try:
        payload = json.loads(matches[-1].read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return {"ok": False, "errors": [f"history entry unreadable: {str(exc)[:100]}"]}
    errs = validate_profile(payload)
    if errs:
        return {"ok": False, "errors": [f"history entry is itself invalid: {e}" for e in errs]}
    current, _, _ = load_profile(repo_root)
    try:
        profile_path(repo_root).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    except OSError as exc:
        return {"ok": False, "errors": [f"could not write profile: {str(exc)[:120]}"]}
    # Restore the staged tree that belonged to the restored generation. A generation whose snapshot
    # is missing had no skills of its own, so the newer generation's skills are removed rather than
    # left behind: a profile and a skill set must move together or the rollback is half-applied.
    skills_dir = skills_root(repo_root)
    snap = matches[-1].with_suffix(".skills")
    restored_skills: List[str] = []
    try:
        if skills_dir.is_dir():
            shutil.rmtree(skills_dir, ignore_errors=True)
        if snap.is_dir():
            shutil.copytree(snap, skills_dir)
            restored_skills = sorted(p.name for p in skills_dir.iterdir() if p.is_dir())
    except (OSError, shutil.Error) as exc:
        return {"ok": False, "errors": [f"profile restored but staged skills could not be: {str(exc)[:100]}"]}
    write_experience(
        repo_root, payload,
        why=f"rolled back from generation {current.get('generation')} to {generation}",
        evidence=f"history entry `{matches[-1].name}`"
                 + (f"; staged skills restored: {', '.join(restored_skills)}" if restored_skills
                    else "; no staged skills in that generation, so the newer ones were removed"),
    )
    return {"ok": True, "generation": generation, "from": current.get("generation"),
            "staged_skills": restored_skills}


def promote(repo_root: Path, name: str) -> Dict[str, Any]:
    """Copy a STAGED skill into `.agents/skills/learned-<name>/`, the only path to standing surface.

    Promotion is the one action that makes a learned skill visible to every agent harness in the
    repo, so it is operator-initiated by design and never taken by the learner (findings §4.2).
    """
    if not NAME_RE.match(name or ""):
        return {"ok": False, "errors": [f"{name!r} is not a {SKILL_PREFIX}* skill name"]}
    src = skills_root(repo_root) / name
    if not (src / "SKILL.md").is_file():
        return {"ok": False, "errors": [f"no staged skill at skills/{name}/SKILL.md"]}
    errs = validate_tree(repo_root)
    if errs:
        return {"ok": False, "errors": errs}
    dest = Path(repo_root) / ".agents" / "skills" / name
    if dest.exists():
        return {"ok": False, "errors": [
            f".agents/skills/{name}/ already exists; refusing to overwrite a standing pack"
        ]}
    try:
        shutil.copytree(src, dest)
    except OSError as exc:
        return {"ok": False, "errors": [f"copy failed: {str(exc)[:120]}"]}
    return {"ok": True, "promoted": str(dest),
            "note": "every agent harness in this repo now sees this pack; delete the directory to revoke"}


def expire_unsupported(profile: Dict[str, Any], *, max_unsupported: int = 5) -> Tuple[Dict[str, Any], List[str]]:
    """Drop `domain_prior` hints that have gone unsupported for too many generations.

    A hint recorded once and never re-justified is a stale anchor: the repository moved, the hint did
    not, and now every prime promotes something that used to matter. Harness2 lists "expiring stale
    experience" as its own future work; our surface is small enough to do it properly, and drift is the
    most likely way this system degrades (findings R8).

    Ages live in `profile["hint_age"]` as `{domain: {term: generations_unsupported}}`. A hint that a
    proposal re-asserts resets to 0. Returns `(profile, dropped)` where `dropped` is human-readable.
    """
    out = json.loads(json.dumps(profile))
    ages = out.get("hint_age")
    if not isinstance(ages, dict):
        return out, []
    prior = out.get("domain_prior") or {}
    live_terms = {t for terms in prior.values() if isinstance(terms, list) for t in terms}
    dropped: List[str] = []
    for domain, term_ages in list(ages.items()):
        if not isinstance(term_ages, dict):
            ages.pop(domain, None)
            continue
        for term, age in list(term_ages.items()):
            if term not in live_terms:
                term_ages.pop(term, None)  # the hint is already gone; the age is noise
                continue
            try:
                age_i = int(age)
            except (TypeError, ValueError):
                term_ages.pop(term, None)
                continue
            if age_i >= max_unsupported:
                terms = prior.get(domain) or []
                if term in terms:
                    terms = [t for t in terms if t != term]
                    prior[domain] = terms
                term_ages.pop(term, None)
                dropped.append(f"{domain}:{term} (unsupported for {age_i} generations)")
    out["domain_prior"] = prior
    out["hint_age"] = ages
    return out, dropped


def age_hints(previous: Dict[str, Any], candidate: Dict[str, Any]) -> Dict[str, Any]:
    """Carry hint ages forward: re-asserted hints reset to 0, untouched ones advance by one."""
    prev_prior = previous.get("domain_prior") or {}
    cand_prior = candidate.get("domain_prior") or {}
    prev_ages = previous.get("hint_age") if isinstance(previous.get("hint_age"), dict) else {}
    ages: Dict[str, Dict[str, int]] = {}
    for domain, terms in cand_prior.items():
        if not isinstance(terms, list):
            continue
        domain_ages = dict(prev_ages.get(domain) or {})
        prev_terms = set(prev_prior.get(domain) or [])
        for term in terms:
            if term in prev_terms:
                # Unchanged by this proposal: it is one generation older.
                domain_ages[term] = int(domain_ages.get(term, 0)) + 1
            else:
                domain_ages[term] = 0  # newly asserted, freshly justified
        ages[domain] = {t: a for t, a in domain_ages.items() if t in terms}
    out = json.loads(json.dumps(candidate))
    out["hint_age"] = ages
    return out


def pseudo_skills_root(repo_root: Path) -> Path:
    """The ONE place learned skills live: `.agents/context-harness/skills/`.

    There used to be two: this directory held staged `<name>/SKILL.md` packs that
    `render_staged_skills` could surface but the graph never indexed, while `.agents/wiki/skills/`
    held flat pages the graph indexed but nothing could surface. Neither was authoritative, so a
    lesson could be retrievable-but-unrenderable or renderable-but-unindexed depending on which
    writer produced it. One directory, read by both the graph and the prime, ends that.

    Kept as a named alias rather than folded into `skills_root` because the two call sites express
    different intents ("what the learner may write" vs "what the prime may surface") that happen to
    resolve to the same place — naming the intent is what keeps a future change from silently
    re-splitting them.
    """
    return skills_root(repo_root)


PSEUDO_REQUIRED = ("title", "tags", "trigger", "evidence", "source")


def validate_pseudo_skill(text: str, name: str) -> List[str]:
    """Problems with one pseudo-skill page. Empty list means valid.

    The frontmatter contract exists so a page is *retrievable as a skill* rather than as an essay:
    `trigger` is the vocabulary the retrieval graph matches on, and `evidence` is what stops an
    invented lesson from entering the corpus — the rule that a lesson with no cited support is not
    stored at all (harness2's `has_experience` gate, and Phase 0's warning that a self-measured
    improvement is circular).
    """
    errs: List[str] = []
    if not text.lstrip().startswith("---"):
        return [f"{name} needs YAML-ish frontmatter (--- ... ---); without it the page has no trigger "
                f"and cannot be matched as a skill"]
    parts = text.split("---", 2)
    if len(parts) < 3:
        return [f"{name} frontmatter is unterminated"]
    fm = parts[1]
    present = {m.group(1) for m in re.finditer(r"(?m)^([A-Za-z_]+):", fm)}
    # ONE format, two accepted spellings. The wiki pseudo-skill pages use `title`/`trigger` and the
    # harness packs use `name`/`description`; requiring one spelling would have meant rewriting six
    # pages that were already correct, purely to satisfy a validator. What actually matters is that
    # every page is retrievable (a trigger or a description) and supported (evidence), so both
    # spellings satisfy the same requirement and a page missing BOTH is refused.
    if "title" not in present and "name" not in present:
        errs.append(f"{name} needs `title:` (wiki spelling) or `name:` (pack spelling) in frontmatter")
    if "trigger" not in present and "description" not in present:
        errs.append(
            f"{name} needs `trigger:` or `description:`, or it can never be matched to a task"
        )
    for key in ("evidence", "source"):
        if key not in present:
            errs.append(
                f"{name} is missing `{key}:` in its frontmatter; without it the page is an "
                f"unsupported claim rather than a learned lesson"
            )
    m_tags = re.search(r"(?m)^tags:\s*\[([^\]]*)\]", fm)
    if m_tags and "ainish/wiki/skill" not in m_tags.group(1) and "ainish/learned" not in m_tags.group(1):
        errs.append(f"{name} tags must include `ainish/wiki/skill` or `ainish/learned` so the vault "
                    f"and the graph agree")
    m_ev = re.search(r"(?m)^evidence:\s*(.+)$", fm)
    if m_ev and not m_ev.group(1).strip().strip('"\''):
        errs.append(f"{name} has an empty `evidence:`; a lesson with no cited support is not stored")
    body = parts[2] if len(parts) > 2 else ""
    if len(body.strip()) < 80:
        errs.append(f"{name} body is {len(body.strip())} chars; a pseudo-skill is a procedure, not a title")
    hit = _contains_acceptance_marker(body)
    if hit:
        errs.append(f"{name} names the measurement ({hit!r}); a learned procedure that names its own "
                    f"scoring optimises the score")
    return errs


def validate_pseudo_skill_tree(repo_root: Path) -> List[str]:
    """Every problem across the pseudo-skill directory."""
    root = pseudo_skills_root(repo_root)
    if not root.is_dir():
        return []
    errs: List[str] = []
    for page in sorted(root.rglob("*.md")):
        try:
            text = page.read_text(encoding="utf-8", errors="replace")
        except OSError:
            errs.append(f"{page.name} is unreadable")
            continue
        errs.extend(validate_pseudo_skill(text, str(page.relative_to(root))))
    return errs


def write_pseudo_skill(
    repo_root: Path, name: str, *, title: str, trigger: List[str], source: str, evidence: str, body: str
) -> Dict[str, Any]:
    """Write one learned skill into the single surface: `.agents/context-harness/skills/<slug>/SKILL.md`.

    `SKILL.md` in a directory, matching the layout `validate_tree`, `render_staged_skills` and
    `context-promote` all already expect — so a page authored here is immediately indexed by the
    graph AND surfaced by the prime. The old flat `<slug>.md` in `.agents/wiki/skills/` was indexable
    but unsurfaceable, and that split is what this consolidation removes.

    `evidence` is required and non-empty: a lesson with no cited support is not stored at all.
    """
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:60]
    if not slug:
        return {"ok": False, "errors": ["a learned skill needs a name"]}
    tags = "[ainish/learned, ainish/skill]"
    text = (
        "---\n"
        f"name: {slug}\n"
        f"title: {title.strip() or slug}\n"
        f"tags: {tags}\n"
        f"trigger: [{', '.join(t.strip() for t in trigger if t.strip())}]\n"
        f"description: \"{(title.strip() or slug)[:200]}\"\n"
        f"source: \"{source.strip()}\"\n"
        f"evidence: \"{evidence.strip()}\"\n"
        "confidence: medium\n"
        "---\n\n"
        f"{body.strip()}\n"
    )
    errs = validate_pseudo_skill(text, f"{slug}/SKILL.md")
    if errs:
        return {"ok": False, "errors": errs}
    root = pseudo_skills_root(repo_root)
    root.mkdir(parents=True, exist_ok=True)
    dest = root / slug / "SKILL.md"
    try:
        if dest.is_file():
            return {"ok": False, "errors": [
                f"{dest.relative_to(repo_root)} already exists; refusing to overwrite a learned skill"
            ]}
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding="utf-8")
    except OSError as exc:
        return {"ok": False, "errors": [f"could not write {slug}.md: {str(exc)[:120]}"]}
    return {"ok": True, "path": str(dest), "slug": slug}

def status(repo_root: Path) -> Dict[str, Any]:
    """What is live, where it came from, how old each hint is, and what was recently refused."""
    profile, source, errs = load_profile(repo_root)
    root = harness_root(repo_root)
    hist = sorted(p.name for p in history_root(repo_root).glob("*.json")) if history_root(repo_root).is_dir() else []
    rej = sorted(p.name for p in rejected_root(repo_root).glob("*.md")) if rejected_root(repo_root).is_dir() else []
    staged = sorted(p.name for p in skills_root(repo_root).iterdir() if p.is_dir()) if skills_root(repo_root).is_dir() else []
    # One surface now: `staged_skills` is the authoritative list. `pseudo_skills` is kept in the
    # payload because existing callers read it, and carries the same names rather than a second walk.
    pseudo = list(staged)
    promoted = sorted(p.name for p in (Path(repo_root) / ".agents" / "skills").iterdir()
                      if p.is_dir() and p.name.startswith(SKILL_PREFIX)) \
        if (Path(repo_root) / ".agents" / "skills").is_dir() else []
    return {
        "format": "ainish-rag/context-harness-status/v1",
        "present": profile_path(repo_root).is_file(),
        "root": str(root),
        "source": source,
        "generation": profile.get("generation"),
        "fingerprint": profile_fingerprint(profile),
        "graph": profile.get("graph"),
        "staged_skills": staged,
        "promoted_skills": promoted,
        "pseudo_skills": pseudo,
        "pseudo_skill_errors": validate_pseudo_skill_tree(repo_root) if skills_root(repo_root).is_dir() else [],
        "history": hist[-10:],
        "history_total": len(hist),
        "rejected": rej[-10:],
        "rejected_total": len(rej),
        "errors": errs,
        "tree_errors": validate_tree(repo_root) if root.is_dir() else [],
    }


SEED_README = """# `.agents/context-harness/` — the per-repo context harness

Written by `ainish-coder --rules` at generation 0, and by `ainish-rag --context-learn` thereafter.

| File | What it is |
|---|---|
| `prime-profile.json` | Bounded retrieval tuning for this repository only. Numbers and short token lists; nothing here can execute. |
| `skills/<name>/` | STAGED skills. Reached only through `--context`, never auto-loaded. |
| `EXPERIENCE.md` | Why the live generation is what it is, with the evidence behind it. |
| `history/` | Every past generation, immutable. |
| `rejected/` | Proposals refused, with the condition that refused them. |

## Rollback in three lines

    ls .agents/context-harness/history/
    ainish-rag --context-rollback <generation>
    ainish-rag --context-status

## Revoking a promoted skill

    rm -rf .agents/skills/learned-<name>/

A promoted pack is standing prompt surface for every agent harness in this repository.
That is why the learner never promotes; only you do.
"""


def acquire_lock(repo_root: Path) -> Tuple[bool, str]:
    """One writer per mutation boundary. A stale lock is reported, never silently stolen."""
    path = lock_path(repo_root)
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        path.write_text(json.dumps({
            "pid": __import__("os").getpid(),
            "at": datetime.now(timezone.utc).isoformat(),
        }), encoding="utf-8")
        return True, ""
    except FileExistsError:
        try:
            holder = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            holder = {}
        return False, f"another learner holds {path} (pid {holder.get('pid', '?')})"
    except OSError:
        # A filesystem that cannot create the lock is not a reason to block learning entirely, but
        # it must be stated so a race is diagnosable rather than mysterious.
        return True, "lock could not be created; proceeding without mutual exclusion"


def release_lock(repo_root: Path) -> None:
    try:
        lock_path(repo_root).unlink()
    except OSError:
        pass
