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
MAX_LIVE_SKILLS = 3
DOMAIN_PRIOR_MAX = 12
TERM_MAX = 32
TERM_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")
NAME_RE = re.compile(r"^" + re.escape(SKILL_PREFIX) + r"[a-z0-9][a-z0-9_-]*$")

# Markers of the measurement itself. A learned artefact naming one of these could optimise the gate
# rather than the prime — the practitioner video's criterion-leakage failure. The improver never
# sees these strings; this is the code-level backstop.
ACCEPTANCE_MARKERS = (
    "coverage", "concentration", "freshness", "redundancy", "acceptance", "gate",
    "win_rate", "winrate", "signal", "tolerance", "threshold", "metric",
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
    "graph.max_wiki_pages": (1, 16),
    "graph.max_artifacts": (1, 6),
    "graph.chapter_chars": (400, 2400),
    "graph.hop_bonus": (0.0, 1.0),
    "graph.recency_floor": (0.0, 0.95),
    "graph.shared_term_threshold": (2, 8),
}
INT_FIELDS = frozenset({
    "graph.max_wiki_pages", "graph.max_artifacts", "graph.chapter_chars",
    "graph.shared_term_threshold",
})
WEIGHT_KEYS = ("wiki", "comms", "memories", "plans", "suggestions", "tasks", "map")
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
        "max_wiki_pages": 8,
        "max_artifacts": 2,
        "chapter_chars": 1400,
        "hop_bonus": 0.35,
        "recency_floor": 0.55,
        "shared_term_threshold": 3,
    },
    "weights": {k: 1.0 for k in WEIGHT_KEYS},
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
    for key in WEIGHT_KEYS:
        val = weights.get(key, 1.0)
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
        if not NAME_RE.match(name):
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
            if not m_name:
                errs.append(f"skills/{name}/SKILL.md needs `name: {name}` in frontmatter "
                            f"(without it the skill is dropped silently at load)")
            elif m_name.group(1) != name:
                errs.append(f"skills/{name}/SKILL.md declares `name: {m_name.group(1)}` but lives "
                            f"in {name}/; the mismatch makes the skill silently unloadable")
            if not re.search(r"^description:\s*\S", fm, re.M):
                errs.append(f"skills/{name}/SKILL.md needs a `description:` in frontmatter "
                            f"(without it the skill is dropped silently at load)")

        hit = _contains_acceptance_marker(body)
        if hit:
            errs.append(f"skills/{name}/SKILL.md names the measurement ({hit!r}); a learned "
                        f"procedure that names its own scoring optimises the score")
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
    """The resolved settings a fresh repo gets: the shipped constants, named once."""
    return apply_to_settings(BASE_PROFILE, {
        "max_wiki_pages": 8, "max_artifacts": 2, "chapter_chars": 1400, "hop_bonus": 0.35,
        "recency_floor": 0.55, "shared_term_threshold": 3,
        "weights": {}, "section_caps": {}, "domain_prior": {},
    })


def settings_for(repo_root: Path) -> Tuple[Dict[str, Any], str, List[str]]:
    profile, source, errs = load_profile(repo_root)
    return apply_to_settings(profile, base_settings()), source, errs


# ── outcome signal (the non-circular one) ───────────────────────────────────

def outcome_signal(repo_root: Path, task: str, *, max_commits: int = 60) -> Dict[str, Any]:
    """An external referent for "did the prime help?", independent of the prime's own output.

    Phase 0 (`08-phase0-findings.md`) proved a gate computed from the rendered prime is circular:
    every quality signal was monotone in the knob that produced it (rho up to 1.000). So the gate
    must observe something the prime did not produce. Two such things exist in this repository:

      completion  the task's own record reached `status: done`, and a commit exists that touches
                  code (not only coordination files) after the task's COMMIT_REF
      goldfish    Goldfish's readiness verdict on the same task: `ready` vs `not-ready`

    Neither is ground truth, and both are stated as what they are. `completion` is the stronger of
    the two because it is produced by the operator's own merge, not by a model.

    Returns a dict with `available` False when there is nothing to measure — absence is reported,
    never silently treated as a zero.
    """
    out: Dict[str, Any] = {"available": False, "reason": "", "completion": None, "commits": 0}
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
    if not lines:
        out["reason"] = "no commits yet"
        return out
    # A task is "completed" when a commit subject carries the task's DISTINCTIVE vocabulary — the
    # words that identify this work rather than words that appear in every subject. Matching one
    # word would be nearly always true ("parser" appears in half the commits of a parser repo), and a
    # signal that is always positive cannot gate anything.
    words = _slug_words(task)
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
    if completed is None:
        completed = False
    out["completion"] = completed
    out["available"] = bool(words)
    out["matched_words"] = best_hits
    out["words_considered"] = len(words)
    out["reason"] = "" if out["available"] else "no distinctive words in the task text"
    return out


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
    """
    words = [w for w in re.findall(r"[a-z0-9]+", (task or "").lower())
             if len(w) >= 5 and w not in _STOP]
    return sorted(set(words), key=lambda w: (-len(w), w))[:6]


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
    """
    gen = int(current.get("generation") or 0)
    hdir = history_root(repo_root)
    hdir.mkdir(parents=True, exist_ok=True)
    slug = re.sub(r"[^a-z0-9]+", "-", (note or "generation").lower()).strip("-")[:40] or "generation"
    dest = hdir / f"{gen:04d}-{slug}.json"
    try:
        dest.write_text(json.dumps(current, indent=2) + "\n", encoding="utf-8")
    except OSError:
        pass


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


def prune_work(root: Path, *, keep: int = 10) -> int:
    """Keep only the newest `keep` evidence trees; return how many were removed.

    Every learning pass writes its evidence under `work/<stamp>/`, and a background process that runs
    for months would otherwise accumulate them forever — the exact unbounded-growth failure this
    whole design exists to avoid (findings R2). The trees are audit records, not state: the newest few
    are enough to reconstruct recent reasoning, and anything that produced an accepted generation is
    already archived under `history/`.
    """
    work = Path(root) / "work"
    if not work.is_dir():
        return 0
    dirs = sorted((p for p in work.iterdir() if p.is_dir()), key=lambda p: p.name, reverse=True)
    removed = 0
    for stale in dirs[keep:]:
        shutil.rmtree(stale, ignore_errors=True)
        removed += 1
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
    write_experience(
        repo_root, payload,
        why=f"rolled back from generation {current.get('generation')} to {generation}",
        evidence=f"history entry `{matches[-1].name}`",
    )
    return {"ok": True, "generation": generation, "from": current.get("generation")}


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


def status(repo_root: Path) -> Dict[str, Any]:
    """What is live, where it came from, how old each hint is, and what was recently refused."""
    profile, source, errs = load_profile(repo_root)
    root = harness_root(repo_root)
    hist = sorted(p.name for p in history_root(repo_root).glob("*.json")) if history_root(repo_root).is_dir() else []
    rej = sorted(p.name for p in rejected_root(repo_root).glob("*.md")) if rejected_root(repo_root).is_dir() else []
    staged = sorted(p.name for p in skills_root(repo_root).iterdir() if p.is_dir()) if skills_root(repo_root).is_dir() else []
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
