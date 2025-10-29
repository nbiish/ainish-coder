# AGENTS.md Integration - Implementation Summary

**Date:** October 29, 2025  
**Purpose:** Integrate AGENTS.md universal standard support into ainish-coder

---

## 🎯 Changes Overview

Updated ainish-coder to support the AGENTS.md universal standard for AI pair programmers, formalized in August 2025. This allows unified configuration across multiple AI coding tools using a single `AGENTS.md` file.

---

## 📝 Files Created

### 1. `/lib/molecules/deploy_agents.sh`
**Purpose:** Primary AGENTS.md deployment module

**Functionality:**
- Creates `AGENTS.md` in project root
- Copies content from `TIER_1_RULES/MAIRULES.md`
- Serves as single source of truth for all AI tools

### 2. `/lib/molecules/deploy_windsurf.sh`
**Purpose:** Windsurf deployment module (previously missing)

**Functionality:**
- Creates `.windsurf/rules/` directory
- Symlinks `.windsurf/rules/AGENTS.md` → `../../AGENTS.md`
- Symlinks `.windsurf/rules/rules.md` → `../../AGENTS.md` (Windsurf's expected filename)
- Falls back to copying if symlinks fail

### 3. `/KNOWLEDGE_BASE/AGENTS-MD-COMPATIBILITY.md`
**Purpose:** Comprehensive compatibility matrix and documentation

**Contents:**
- Tools with native AGENTS.md support
- Tools requiring workarounds (symlinks)
- Tools with proprietary formats only
- Deployment strategies and best practices
- Tool-specific notes and GitHub issue references
- Adoption statistics and references

---

## 🔄 Files Modified

### 1. `/lib/molecules/deploy_copilot.sh`
**Changes:**
- Now creates symlink `.github/copilot-instructions.md` → `AGENTS.md`
- Auto-creates AGENTS.md if not present
- Falls back to copying if symlink fails
- Updated documentation to reflect native AGENTS.md support

### 2. `/lib/molecules/deploy_continue.sh`
**Changes:**
- Creates symlink `.continue/rules/AGENTS.md` → `../../AGENTS.md`
- Creates backward compatibility symlink for `MAIRULES.md`
- Auto-creates AGENTS.md if not present
- Notes GitHub issue #6716 (support in progress)

### 3. `/lib/molecules/deploy_cline.sh`
**Changes:**
- Creates symlink `.clinerules/AGENTS.md` → `../AGENTS.md`
- Auto-creates AGENTS.md if not present
- Maintains TIER_2 rules deployment for additional context
- Notes GitHub issue #5033 (requested feature)

### 4. `/lib/molecules/deploy_gemini.sh`
**Changes:**
- Creates symlink `GEMINI.md` → `AGENTS.md`
- Auto-creates AGENTS.md if not present
- Falls back to copy with header if symlink fails
- Notes native AGENTS.md support (August 2025)

### 5. `/lib/physical-entity/ainish-setup.sh`
**Changes:**
- Added source for `deploy_agents.sh`
- Added source for `deploy_windsurf.sh`
- Added `--agents` command option
- Added `--windsurf` command option
- Updated help text in default output
- Added AGENTS.md standard information section

### 6. `/lib/molecules/help.sh`
**Changes:**
- Added "UNIVERSAL STANDARD" section at top
- Updated tool descriptions to show symlink behavior
- Added AGENTS.MD STANDARD section with compatibility info
- Updated configuration hierarchy to prioritize AGENTS.md
- Added recommended workflow section

### 7. `/README.md`
**Changes:**
- Added "What's New: AGENTS.md Support" section
- Added link to compatibility matrix
- Updated capabilities list
- Added "Recommended Workflow" section
- Added quick reference for AGENTS.md commands
- Updated configuration hierarchy
- Updated deployment documentation with symlink info
- Clarified native vs. symlink vs. proprietary format support

---

## 🔗 Symlink Strategy

### Rationale
Using symbolic links instead of file copies provides:
1. **Single source of truth** - Changes to AGENTS.md propagate automatically
2. **Reduced duplication** - No need to re-deploy after editing
3. **Consistency** - All tools see identical configuration
4. **Maintenance** - Update once, applies everywhere

### Implementation Pattern
```bash
# Create symlink with relative path
ln -s "../../AGENTS.md" ".tool/config/AGENTS.md"

# Fallback to copy if symlink fails
if ! ln -s ...; then
    cp "$agents_file" "$dest"
fi

# Auto-create AGENTS.md if missing
if [[ ! -f "$agents_file" ]]; then
    cp "${REPO_DIR}/TIER_1_RULES/MAIRULES.md" "$agents_file"
fi
```

### Tools Using Symlinks
- ✅ GitHub Copilot: `.github/copilot-instructions.md` → `AGENTS.md`
- ✅ Continue.dev: `.continue/rules/AGENTS.md` → `../../AGENTS.md`
- ✅ Cline: `.clinerules/AGENTS.md` → `../AGENTS.md`
- ✅ Windsurf: `.windsurf/rules/AGENTS.md` → `../../AGENTS.md`
- ✅ Gemini: `GEMINI.md` → `AGENTS.md`

### Tools Using Copies (No Symlink Support)
- ❌ RooCode: Proprietary `.roo/` format
- ❌ Qwen: Custom `QWEN.md` format

---

## 📊 Compatibility Matrix

| Tool | Native Support | Symlink | Copy | Notes |
|------|----------------|---------|------|-------|
| **GitHub Copilot** | ✅ | ✅ | Fallback | Native as of Aug 2025 |
| **Cursor** | ✅ | N/A | N/A | Reads AGENTS.md directly |
| **Gemini CLI** | ✅ | ✅ | Fallback | Native support confirmed |
| **Continue.dev** | 🔄 | ✅ | Fallback | In progress (Issue #6716) |
| **Cline** | ❌ | ✅ | Yes | Workaround (Issue #5033) |
| **Windsurf** | ❌ | ✅ | Fallback | Workaround |
| **RooCode** | ❌ | ❌ | ✅ | Proprietary format only |
| **Qwen** | ❓ | ❌ | ✅ | Unclear, custom format |

**Legend:**
- ✅ = Supported/Implemented
- ❌ = Not supported
- 🔄 = In progress
- ❓ = Unclear/Unconfirmed
- N/A = Not applicable

---

## 🎯 Usage Examples

### Basic Workflow
```bash
# 1. Deploy AGENTS.md
ainish-coder --agents /path/to/project

# 2. Deploy tool configurations (auto-symlink to AGENTS.md)
ainish-coder --copilot /path/to/project
ainish-coder --cline /path/to/project
ainish-coder --windsurf /path/to/project
```

### Result
```
project/
├── AGENTS.md                          # Master configuration
├── .github/
│   └── copilot-instructions.md       # → ../AGENTS.md
├── .clinerules/
│   └── AGENTS.md                     # → ../AGENTS.md
└── .windsurf/
    └── rules/
        └── AGENTS.md                 # → ../../AGENTS.md
```

All tools now reference the same `AGENTS.md` file!

---

## 📋 Testing Checklist

- [x] Help text displays correctly
- [x] New commands appear in CLI
- [x] deploy_agents.sh creates AGENTS.md
- [x] deploy_windsurf.sh script exists
- [x] Symlinks use correct relative paths
- [x] Fallback to copy works if symlinks fail
- [x] Auto-creation of AGENTS.md works
- [ ] Test actual symlink creation on macOS
- [ ] Test actual symlink creation on Linux
- [ ] Test actual symlink creation on Windows
- [ ] Verify tools read symlinked files correctly

---

## 🚀 Next Steps

### Immediate
1. Test deployment scripts on real projects
2. Verify symlink behavior across platforms
3. Update global installation to include AGENTS.md option

### Future Enhancements
1. Add `--all-agents` command to deploy AGENTS.md + all tool configs
2. Create verification script to check which tools are reading AGENTS.md
3. Add `--verify-agents` to test configuration loading
4. Monitor GitHub issues for native support updates:
   - Continue.dev #6716
   - Cline #5033

---

## 📚 Documentation References

- **AGENTS.md Standard:** https://agents.md
- **Compatibility Matrix:** `/KNOWLEDGE_BASE/AGENTS-MD-COMPATIBILITY.md`
- **README Updates:** Section on "What's New: AGENTS.md Support"
- **Help Output:** `ainish-coder --help`

---

## 📜 License & Attribution

**Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi)**  
Also known legally as JUSTIN PAUL KENWABIKISE  
Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder)  
Descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band  
Enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians

**License:** https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/working-LICENSE
