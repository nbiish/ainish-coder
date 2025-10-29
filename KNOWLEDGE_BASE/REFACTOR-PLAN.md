# ainish-coder Refactoring Plan

**Date:** October 29, 2025  
**Purpose:** Simplify deployment scripts to eliminate redundancies and align with verified tool intake patterns

---

## 🎯 Core Principle

**AGENTS.md is the single source of truth.** All AI tools should consume AGENTS.md directly or via symlinks. MAIRULES.md becomes an optional supplementary resource deployed to `.mai-rules/` for legacy/manual workflows.

---

## 📋 Current Issues

1. **Redundant rule intake**: Tools may be reading multiple copies of the same rules
2. **Complex deployment logic**: Scripts auto-create AGENTS.md, copy TIER files, and create nested structures
3. **Inconsistent patterns**: Some tools copy, others symlink, no clear standard
4. **Over-engineering**: Too many fallbacks and edge cases

---

## ✅ Simplified Behavior

### Core Commands

| Command | Action | Location |
|---------|--------|----------|
| `--agents` | Copy `TIER_1_RULES/MAIRULES.md` → `AGENTS.md` | Project root |
| `--mairules` | Copy `TIER_1_RULES/MAIRULES.md` → `.mai-rules/MAIRULES.md` | Project root |
| `--critical` | Symlink `TIER_0/critical.md` → `critical.md` | Project root |

### Tier Deployments

| Command | Action | Location |
|---------|--------|----------|
| `--tier0` | Copy all `TIER_0_RULES/*.md` → `.mai-rules/` | Project root |
| `--tier1` | Copy all `TIER_1_RULES/*.md` → `.mai-rules/` | Project root |
| `--tier2` | Copy all `TIER_2_RULES/*.md` → `.mai-rules/` | Project root |
| `--tier3` | Copy all `TIER_3_RULES/*.md` → `.mai-rules/` | Project root |
| `--tier4` | Copy all `TIER_4_RULES/*.md` → `.mai-rules/` | Project root |

### Tool-Specific Symlinks

All tool commands assume `AGENTS.md` already exists in the project root. If not, they fail with clear error message directing user to run `--agents` first.

| Command | Tool | Verified Intake Location | Action |
|---------|------|-------------------------|--------|
| `--copilot` | GitHub Copilot | `AGENTS.md` + `.github/copilot-instructions.md` | Symlink `.github/copilot-instructions.md` → `AGENTS.md` |
| `--cn` | Continue.dev | `AGENTS.md` (native) | Symlink `.continue/rules/AGENTS.md` → `../../AGENTS.md` |
| `--cline` | Cline | `AGENTS.md` + `.clinerules/` | Symlink `.clinerules/AGENTS.md` → `../AGENTS.md` |
| `--windsurf` | Windsurf | `.windsurf/rules/rules.md` | Symlink `.windsurf/rules/rules.md` → `../../AGENTS.md` |
| `--roocode` | Roo Code | `AGENTS.md` (native, fallback to `AGENT.md`) | Symlink `.roo/AGENTS.md` → `../AGENTS.md` + create `.rooignore` |
| `--qwen` | Qwen Code CLI | `AGENTS.md` (native) | Symlink `QWEN.md` → `AGENTS.md` |
| `--gemini` | Gemini CLI | `AGENTS.md` (native) | Symlink `GEMINI.md` → `AGENTS.md` |

---

## 🔄 Changes Required

### Files to Modify

1. **`lib/molecules/deploy_agents.sh`**
   - Remove auto-creation logic
   - Simply copy `TIER_1_RULES/MAIRULES.md` → `AGENTS.md`
   - No fallbacks, no checks beyond target_dir validation

2. **`lib/molecules/deploy_mairules.sh`**
   - Copy `TIER_1_RULES/MAIRULES.md` → `.mai-rules/MAIRULES.md`
   - Create `.mai-rules/` if needed
   - No AGENTS.md interaction

3. **`lib/molecules/deploy_critical.sh`** (NEW)
   - Symlink `TIER_0/critical.md` → `critical.md` at project root
   - Create if doesn't exist

4. **`lib/molecules/deploy_copilot.sh`**
   - Remove AGENTS.md auto-creation
   - Check if `AGENTS.md` exists; error if not
   - Symlink `.github/copilot-instructions.md` → `../AGENTS.md`
   - No fallback copying

5. **`lib/molecules/deploy_continue.sh`**
   - Remove AGENTS.md auto-creation
   - Check if `AGENTS.md` exists; error if not
   - Symlink `.continue/rules/AGENTS.md` → `../../AGENTS.md`
   - Remove MAIRULES.md symlink (redundant)

6. **`lib/molecules/deploy_cline.sh`**
   - Remove AGENTS.md auto-creation
   - Check if `AGENTS.md` exists; error if not
   - Symlink `.clinerules/AGENTS.md` → `../AGENTS.md`
   - Remove TIER_2 copying (user can run `--tier2` if needed)

7. **`lib/molecules/deploy_windsurf.sh`**
   - Remove AGENTS.md auto-creation
   - Check if `AGENTS.md` exists; error if not
   - Symlink `.windsurf/rules/rules.md` → `../../AGENTS.md`
   - Remove duplicate `.windsurf/rules/AGENTS.md` symlink

8. **`lib/molecules/deploy_gemini.sh`**
   - Remove AGENTS.md auto-creation
   - Check if `AGENTS.md` exists; error if not
   - Symlink `GEMINI.md` → `AGENTS.md`
   - No copy fallback

9. **`lib/molecules/deploy_qwen.sh`**
   - Remove AGENTS.md auto-creation
   - Check if `AGENTS.md` exists; error if not
   - Symlink `QWEN.md` → `AGENTS.md`
   - No copy fallback

10. **`lib/molecules/deploy_roocode.sh`**
    - Remove AGENTS.md auto-creation
    - Check if `AGENTS.md` exists; error if not
    - Create `.roo/` directory
    - Symlink `.roo/AGENTS.md` → `../AGENTS.md`
    - Create `.rooignore`
    - No TIER copying

11. **`lib/molecules/deploy_tiers.sh`**
    - Keep existing tier deployment logic
    - Ensure all files copy to `.mai-rules/` subdirectory

---

## 🚫 What Gets Removed

- Auto-creation of AGENTS.md in tool-specific scripts
- Fallback copying when symlinks fail
- TIER_2 automatic deployment in tool scripts
- Multiple symlink creation (e.g., both AGENTS.md and rules.md)
- Complex conditional logic for missing source files

---

## ✅ New User Workflow

### Recommended Setup (Clean Project)

```bash
# 1. Deploy AGENTS.md (required first step)
ainish-coder --agents /path/to/project

# 2. Deploy tool symlinks
ainish-coder --copilot /path/to/project
ainish-coder --cline /path/to/project
ainish-coder --cn /path/to/project
ainish-coder --windsurf /path/to/project
ainish-coder --qwen /path/to/project
ainish-coder --gemini /path/to/project
ainish-coder --roocode /path/to/project

# 3. (Optional) Deploy supplementary rules
ainish-coder --mairules /path/to/project   # Adds .mai-rules/MAIRULES.md
ainish-coder --critical /path/to/project   # Symlinks critical.md
ainish-coder --tier2 /path/to/project      # Adds .mai-rules/ tier files
```

### If User Tries Tools Before AGENTS.md

```bash
$ ainish-coder --copilot /path/to/project
Error: AGENTS.md not found in /path/to/project
Run: ainish-coder --agents /path/to/project first
```

---

## 📊 Verification Points

### Tool Intake Verification (from web research)

| Tool | Primary Intake | Secondary Intake | Verified |
|------|----------------|------------------|----------|
| GitHub Copilot | `AGENTS.md` | `.github/copilot-instructions.md` | ✅ |
| Continue.dev | `AGENTS.md` | `.continue/rules/` | ✅ |
| Cline | `AGENTS.md` | `.clinerules/` | ✅ |
| Windsurf | `.windsurf/rules/rules.md` | N/A | ✅ |
| Roo Code | `AGENTS.md` | `AGENT.md` (fallback) | ✅ |
| Qwen Code CLI | `AGENTS.md` | Config: `contextFileName` | ✅ |
| Gemini CLI | `AGENTS.md` | Config: `contextFileName` | ✅ |

### No Redundant Intake

After refactor, each tool reads rules exactly once:
1. Native AGENTS.md readers: Read from project root
2. Symlink users: Read via their expected location → AGENTS.md
3. No tool reads both `.mai-rules/MAIRULES.md` AND `AGENTS.md`

---

## 🎯 Success Criteria

1. ✅ Running `--agents` creates single `AGENTS.md` at project root
2. ✅ Tool commands create only symlinks (no copies except .rooignore)
3. ✅ Tool commands fail gracefully if `AGENTS.md` missing
4. ✅ `--mairules` deploys to `.mai-rules/` (separate from AGENTS.md)
5. ✅ Tier commands deploy to `.mai-rules/` (separate from AGENTS.md)
6. ✅ No tool reads rules more than once
7. ✅ All symlinks use relative paths
8. ✅ Help text reflects simplified workflow
9. ✅ README updated with new workflow

---

## 🔧 Implementation Order

1. Create `deploy_critical.sh`
2. Simplify `deploy_agents.sh` (remove auto-create from tools)
3. Update `deploy_mairules.sh` (ensure .mai-rules/ target)
4. Simplify all tool deployment scripts (remove auto-create, fallbacks)
5. Update `help.sh` with new workflow
6. Update `README.md` with required-first pattern
7. Update main `ainish-setup.sh` to source new scripts
8. Test workflow on clean project

---

## 📜 License & Attribution

**Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi)**  
Also known legally as JUSTIN PAUL KENWABIKISE  
Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder)  
Descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band  
Enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians

**License:** https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/working-LICENSE
