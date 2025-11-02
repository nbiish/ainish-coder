# Tasks

## Completed

### ✅ Goose CLI Tool Support (2025-11-02)

Added support for Goose CLI agentic tool alongside other supported AI tools.

**Implementation:**
- Added `deploy_goose()` function in `bin/ainish-coder`
- Copies `AGENTS.md` to current directory
- Creates `.goosehints` context file
- Provides environment variable setup instructions

**Files Modified:**
- `bin/ainish-coder` - Added `--goose` flag and deployment function
- `README.md` - Documented Goose CLI support in tool list and usage sections

**Usage:**
```bash
ainish-coder --goose
export CONTEXT_FILE_NAMES='["AGENTS.md", "MAIRULES.md", ".goosehints"]'
```

---

## Pending


